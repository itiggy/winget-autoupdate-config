#requires -Version 5.1

<#
.SYNOPSIS
    Generates an excluded_apps.txt file for Winget-AutoUpdate based on a 5-day maturity rule and custom rules.

.DESCRIPTION
    This script builds a combined list of excluded apps for Winget-AutoUpdate using 3 layers:
    1. Remote default exclusions from WAU (with local cached fallback).
    2. User-defined custom exclusions from user_excluded_apps.txt.
    3. Package IDs updated in the microsoft/winget-pkgs repository within the last N days (5-day rule).

    Additionally, it synchronizes official WAU default mods and auto-generates mods/index.html.

.PARAMETER DaysThreshold
    Number of days to check for recent package updates in winget-pkgs. Default is 5.

.PARAMETER GitHubToken
    Optional GitHub token to increase API rate limits. Automatically checks $env:GITHUB_TOKEN if omitted.

.PARAMETER OutputPath
    Target file path for the generated excluded_apps.txt list.

.PARAMETER UserExcludedAppsPath
    File path to user_excluded_apps.txt containing custom app exclusions.

.PARAMETER CachePath
    File path to the local cached default_excluded_apps.txt.

.EXAMPLE
    .\Update-ExcludedApps.ps1 -DaysThreshold 5
#>
[CmdletBinding()]
param (
    [int]$DaysThreshold = 5,

    [string]$GitHubToken = $env:GITHUB_TOKEN,

    [string]$OutputPath = (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) `
        -ChildPath "list\excluded_apps.txt"),

    [string]$UserExcludedAppsPath = (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "config\user_excluded_apps.txt"),

    [string]$CachePath = (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "config\default_excluded_apps.txt")
)

$ErrorActionPreference = 'Stop'

#region Functions

function Get-WauDefaultExclusions {
    <#
    .SYNOPSIS
        Downloads official WAU default exclusions with local cache fallback.
    #>
    [CmdletBinding()]
    param (
        [string]$RemoteUrl = "https://raw.githubusercontent.com/Romanitho/Winget-AutoUpdate/refs/heads/main/Sources/Winget-AutoUpdate/config/default_excluded_apps.txt",
        [string]$LocalCachePath
    )

    $exclusions = @()

    try {
        Write-Verbose "Downloading default exclusions from $RemoteUrl"
        $remoteContent = Invoke-RestMethod -Uri $RemoteUrl -Method Get -TimeoutSec 15 -ErrorAction Stop
        if ($remoteContent) {
            $exclusions = $remoteContent -split "`r?\n"
            if ($LocalCachePath) {
                $cacheDir = Split-Path -Path $LocalCachePath -Parent
                if (-not (Test-Path -Path $cacheDir)) {
                    $null = New-Item -Path $cacheDir -ItemType Directory -Force -ErrorAction Stop
                }
                Set-Content -Path $LocalCachePath -Value $exclusions -Encoding UTF8 -ErrorAction Stop
            }
        }
    } catch {
        $lastError = $_
        Write-Warning "Failed to download remote default exclusions: $($lastError.Exception.Message)"
        if ($LocalCachePath -and (Test-Path -Path $LocalCachePath)) {
            Write-Verbose "Loading fallback exclusions from local cache: $LocalCachePath"
            $exclusions = Get-Content -Path $LocalCachePath -ErrorAction Stop
        }
    }

    return $exclusions
}


function Get-UserExclusions {
    <#
    .SYNOPSIS
        Reads user-defined custom exclusions from a local text file.
    #>
    [CmdletBinding()]
    param (
        [string]$FilePath
    )

    $exclusions = @()

    if (Test-Path -Path $FilePath) {
        $lines = Get-Content -Path $FilePath -ErrorAction Stop
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -and -not $trimmed.StartsWith("#")) {
                $exclusions += $trimmed
            }
        }
    }

    return $exclusions
}


function Get-RecentWingetPkgsUpdates {
    <#
    .SYNOPSIS
        Queries GitHub API for winget-pkgs commits within the specified days threshold.
    #>
    [CmdletBinding()]
    param (
        [int]$Days,
        [string]$Token
    )

    $packageIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $cutoffDate = (Get-Date).AddDays(-$Days).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $baseUrl = "https://api.github.com/repos/microsoft/winget-pkgs/commits"

    $headers = @{
        "User-Agent" = "Winget-AutoUpdate-Rules-Bot"
    }
    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }

    $page = 1
    $maxPages = 100
    $hasMore = $true

    while ($hasMore -and ($page -le $maxPages)) {
        $uri = "${baseUrl}?since=${cutoffDate}&per_page=100&page=${page}"
        try {
            Write-Verbose "Fetching commits page $page from winget-pkgs"
            $commits = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 30 -ErrorAction Stop
            if (-not $commits -or $commits.Count -eq 0) {
                $hasMore = $false
                break
            }

            foreach ($item in $commits) {
                $msg = ($item.commit.message -split "`n")[0].Trim()

                # 1. Clear Ignore Rules: Skip locale/translation updates and version deletions/removals
                if ($msg -match '^(?:Added|Removed|Updated?)\s+locale' -or
                    $msg -match '^(?:Remove\s+version:|Removing\s+version:|Automatic\s+deletion\s+of|Delete\s+version:)') {
                    continue
                }

                $pkgId = $null

                # 2. Fast-Path (Top standard title patterns):
                if ($msg -match '^(?:New version:|Update version:|Update:|New package:|Add version:|Automatic update of:?)\s*([A-Za-z0-9_\-\.]+\.[A-Za-z0-9_\-\.]+)(?:\s+version|\s+[\d\.\-\+a-zA-Z]+|\s*$)') {
                    $candidate = $Matches[1].Trim()
                    if ($candidate -match '^[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-\.]+$') {
                        $pkgId = $candidate
                    }
                } elseif ($msg -match '^([A-Za-z0-9_\-]+\.[A-Za-z0-9_\-\.]+)\s+version\s+') {
                    $candidate = $Matches[1].Trim()
                    if ($candidate -match '^[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-\.]+$') {
                        $pkgId = $candidate
                    }
                }

                # 3. Diff-Fallback (For ALL other titles, Reverts, custom PR titles, and uncaptured formats):
                if (-not $pkgId -and $item.url) {
                    try {
                        $commitDetail = Invoke-RestMethod -Uri $item.url -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction SilentlyContinue
                        if ($commitDetail -and $commitDetail.files) {
                            foreach ($file in $commitDetail.files) {
                                # Skip deleted files and locale files
                                if ($file.status -ne "removed" -and $file.filename -notmatch '\.locale\.[^\.]+\.yaml$') {
                                    if ($file.filename -match 'manifests\/[a-z0-9]\/([^\/]+)\/([^\/]+)\/') {
                                        $pub = $Matches[1]
                                        $app = $Matches[2]
                                        $pkgId = "${pub}.${app}"
                                        break
                                    }
                                }
                            }
                        }
                    } catch {}
                }

                if ($pkgId) {
                    $null = $packageIds.Add($pkgId)
                }
            }

            if ($commits.Count -lt 100) {
                $hasMore = $false
            } else {
                $page++
            }
        } catch {
            $lastError = $_
            Write-Warning "Error fetching commits from GitHub API on page ${page}: $($lastError.Exception.Message)"
            $hasMore = $false
        }
    }

    return $packageIds
}


function Sync-WauDefaultMods {
    <#
    .SYNOPSIS
        Synchronizes official default WAU mod templates and functions into the mods directory.
    #>
    [CmdletBinding()]
    param (
        [string]$ModsDirectory
    )

    try {
        $apiUrl = "https://api.github.com/repos/Romanitho/Winget-AutoUpdate/contents/Sources/Winget-AutoUpdate/mods"
        $headers = @{ "User-Agent" = "PowerShell" }
        if ($env:GITHUB_TOKEN) {
            $headers["Authorization"] = "token $env:GITHUB_TOKEN"
        }

        $items = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
        foreach ($item in $items) {
            if ($item.type -eq 'file' -and $item.name -ne 'README.md') {
                $targetPath = Join-Path -Path $ModsDirectory -ChildPath $item.name
                Invoke-WebRequest -Uri $item.download_url -OutFile $targetPath -ErrorAction Stop

                # Enforce UTF-8 WITH BOM for .ps1, WITHOUT BOM for .txt, and CRLF
                $rawText = [System.IO.File]::ReadAllText($targetPath)
                $normalized = ($rawText -replace "\r?\n", "`n").TrimEnd() + "`n"
                $normalized = $normalized -replace "`n", "`r`n"
                $isPs1 = $targetPath.EndsWith(".ps1", [System.StringComparison]::OrdinalIgnoreCase)
                $encoding = [System.Text.UTF8Encoding]::new($isPs1)
                [System.IO.File]::WriteAllText($targetPath, $normalized, $encoding)

                Write-Verbose "Synced default WAU mod: $($item.name)"
            }
        }
    } catch {
        $lastError = $_
        Write-Warning "Failed to sync remote default WAU mods: $($lastError.Exception.Message)"
    }
}


function Update-WauModsIndex {
    <#
    .SYNOPSIS
        Generates an index.html directory listing file inside the mods directory.
    #>
    [CmdletBinding()]
    param (
        [string]$ModsDirectory
    )

    if (Test-Path -Path $ModsDirectory) {
        $modFiles = Get-ChildItem -Path $ModsDirectory -File |
        Where-Object { $_.Name -ne "index.html" -and $_.Name -ne "README.md" } |
        Sort-Object Name

        $htmlLines = @(
            "<!DOCTYPE html>",
            "<html>",
            "<head><title>WAU Mods Index</title></head>",
            "<body>",
            "<ul>"
        )
        foreach ($file in $modFiles) {
            $htmlLines += "  <li><a href=`"$($file.Name)`">$($file.Name)</a></li>"
        }
        $htmlLines += "</ul>", "</body>", "</html>"

        $indexPath = Join-Path -Path $ModsDirectory -ChildPath "index.html"
        $htmlText = ($htmlLines -join "`n").TrimEnd() + "`n"
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($indexPath, $htmlText, $utf8NoBom)
        Write-Verbose "Updated $indexPath with $($modFiles.Count) mod entries."
    }
}


function Update-WauSiteIndex {
    <#
    .SYNOPSIS
        Updates dynamic stats (rule count, mod count, last sync timestamp) in root index.html.
    #>
    [CmdletBinding()]
    param (
        [string]$IndexPath,
        [int]$RuleCount,
        [int]$ModCount
    )

    if (Test-Path -Path $IndexPath) {
        try {
            $content = Get-Content -Path $IndexPath -Raw -Encoding UTF8
            $formattedRuleCount = "{0:N0}" -f $RuleCount
            $nowUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm") + " UTC"

            $content = $content -replace 'id="stat-rules">[^<]+<', "id=`"stat-rules`">$formattedRuleCount<"
            $content = $content -replace 'id="stat-mods">[^<]+<', "id=`"stat-mods`">$ModCount<"
            $content = $content -replace 'id="last-sync">[^<]+<', "id=`"last-sync`">$nowUtc<"

            # Trim trailing newlines and write exactly one single trailing newline (LF)
            $trimmedContent = $content.TrimEnd() + "`n"
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($IndexPath, $trimmedContent, $utf8NoBom)

            Write-Verbose "Updated $IndexPath with $formattedRuleCount rules and $ModCount mods."
        } catch {
            Write-Warning "Failed to update $IndexPath stats: $($lastError.Exception.Message)"
        }
    }
}

#endregion Functions

#region Main Execution

Write-Verbose "Starting Winget-AutoUpdate config update."

$modsDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "mods"

# Step 1: Sync WAU Default Mods & Update mods/index.html
Sync-WauDefaultMods -ModsDirectory $modsDir
Update-WauModsIndex -ModsDirectory $modsDir

# Step 2: Build 3-Layer Excluded Apps List
Write-Verbose "Generating excluded_apps.txt list."

$layer1 = Get-WauDefaultExclusions -LocalCachePath $CachePath
$layer2 = Get-UserExclusions -FilePath $UserExcludedAppsPath
$layer3 = Get-RecentWingetPkgsUpdates -Days $DaysThreshold -Token $GitHubToken

$combinedSet = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($item in $layer1) {
    $trimmed = $item.Trim()
    if ($trimmed -and -not $trimmed.StartsWith("#")) {
        $null = $combinedSet.Add($trimmed)
    }
}

foreach ($item in $layer2) {
    $trimmed = $item.Trim()
    if ($trimmed -and -not $trimmed.StartsWith("#")) {
        $null = $combinedSet.Add($trimmed)
    }
}

foreach ($item in $layer3) {
    $trimmed = $item.Trim()
    if ($trimmed -and -not $trimmed.StartsWith("#")) {
        $null = $combinedSet.Add($trimmed)
    }
}

$sortedList = $combinedSet | Sort-Object

$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path -Path $outputDir)) {
    $null = New-Item -Path $outputDir -ItemType Directory -Force -ErrorAction Stop
}

$text = ($sortedList -join "`r`n") + "`r`n"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($OutputPath, $text, $utf8NoBom)
Write-Verbose "Successfully wrote $($sortedList.Count) excluded app rules to $OutputPath."

# Step 3: Update Dynamic Stats in Root index.html
$rootIndex = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "index.html"
$activeModCount = (Get-ChildItem -Path $modsDir -File | Where-Object { $_.Name -ne "index.html" -and $_.Name -ne "README.md" }).Count
Update-WauSiteIndex -IndexPath $rootIndex -RuleCount $sortedList.Count -ModCount $activeModCount

#endregion Main Execution
