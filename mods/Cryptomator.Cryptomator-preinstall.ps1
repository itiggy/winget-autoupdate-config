$processName = "Cryptomator"
$idleSecondsRequired = 3

Write-Output "Winget preparation: Waiting for Cryptomator write activity to stop..."

$proc = Get-Process -Name $processName -ErrorAction SilentlyContinue
if (-not $proc) {
    exit 0
}

$idleTicks = 0
while ($idleTicks -lt $idleSecondsRequired) {
    $startIO = $proc.WriteTransferCount
    Start-Sleep -Seconds 1

    $proc = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if (-not $proc) {
        break
    }

    if ($proc.WriteTransferCount -eq $startIO) {
        $idleTicks++
    }
    else {
        $idleTicks = 0
        Write-Output "Files are still being encrypted... ($($proc.WriteTransferCount))"
    }
}

Write-Output "Stopping $processName for update..."
Stop-Process -Name $processName -Force -ErrorAction SilentlyContinue
Write-Output "Ready for Winget update."
