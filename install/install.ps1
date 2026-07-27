#requires -Version 5.1

<#
.SYNOPSIS
    Installs Winget-AutoUpdate configured with custom remote rules and mods.

.DESCRIPTION
    Downloads WAU.msi if not present in the current directory, then executes
    the installer with preconfigured LISTPATH and MODSPATH parameters pointing to
    the winget-autoupdate-config GitHub repository.

.EXAMPLE
    .\install.ps1
#>
[CmdletBinding()]
param (
    [string]$RepoUser = "itiggy",

    [string]$RepoName = "winget-autoupdate-config"
)

$ErrorActionPreference = 'Stop'

# Ensure script is running with Administrator privileges
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating privileges to Administrator..." -ForegroundColor Yellow
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    $processInfo.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($processInfo) | Out-Null
        exit 0
    }
    catch {
        $lastError = $_
        Write-Error "Administrator elevation was rejected: $($lastError.Exception.Message)"
        exit 1
    }
}

$scriptDir = $PSScriptRoot
$msiPath = Join-Path -Path $scriptDir -ChildPath "WAU.msi"

if (-not (Test-Path -Path $msiPath)) {
    Write-Host "WAU.msi not found locally. Downloading latest release from GitHub..." -ForegroundColor Cyan
    $releaseUrl = "https://api.github.com/repos/Romanitho/Winget-AutoUpdate/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ "User-Agent" = "WAU-Installer" } -ErrorAction Stop
        $asset = $release.assets | Where-Object { $_.name -like "*.msi" } | Select-Object -First 1
        if ($asset) {
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msiPath -ErrorAction Stop
            Write-Host "Successfully downloaded WAU.msi to $msiPath" -ForegroundColor Green
        }
        else {
            throw "No .msi release asset found in Romanitho/Winget-AutoUpdate."
        }
    }
    catch {
        $lastError = $_
        Write-Error "Failed to download WAU.msi: $($lastError.Exception.Message)"
        exit 1
    }
}

$listUrl = "https://${RepoUser}.github.io/${RepoName}/list/"
$modsUrl = "https://${RepoUser}.github.io/${RepoName}/mods/"

$msiArgs = @(
    "/package", "`"$msiPath`"",
    "/passive",
    "/norestart",
    "/log", "`"$scriptDir\WAU-install.log`"",
    "USERCONTEXT=1",
    "STARTMENUSHORTCUT=1",
    "UPDATESATLOGON=0",
    "UPDATESINTERVAL=Daily",
    "LISTPATH=`"$listUrl`"",
    "MODSPATH=`"$modsUrl`""
)

Write-Host "Launching WAU.msi installer with remote configuration..." -ForegroundColor Cyan
$process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "Winget-AutoUpdate installation completed successfully!" -ForegroundColor Green

    if (Test-Path -Path $msiPath) {
        $promptMsg = "Do you want to delete the downloaded WAU.msi file? ([Y]/N)"
        $response = Read-Host -Prompt $promptMsg
        if ([string]::IsNullOrWhiteSpace($response) -or $response.Trim() -match '^(y|yes)$') {
            Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
            Write-Host "Deleted WAU.msi successfully." -ForegroundColor Green
        }
        else {
            Write-Host "Retained WAU.msi in $msiPath." -ForegroundColor Yellow
        }
    }
}
else {
    Write-Error "Winget-AutoUpdate installation failed with Exit Code $($process.ExitCode)."
}
