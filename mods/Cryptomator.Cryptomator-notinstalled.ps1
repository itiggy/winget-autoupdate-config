# Get currently logged in user
$loggedInUser = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName

if ($null -ne $loggedInUser) {
    $taskName = "CryptomatorUserStart"
    $lnkPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Cryptomator\Cryptomator.lnk"

    $action = New-ScheduledTaskAction -Execute "explorer.exe" -Argument "`"$lnkPath`""
    $null = Register-ScheduledTask -TaskName $taskName -Action $action -User $loggedInUser -Force -ErrorAction SilentlyContinue

    Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output "Cryptomator launched in user context for $loggedInUser."
}
else {
    Write-Output "No logged in user found. Cryptomator not started."
}
