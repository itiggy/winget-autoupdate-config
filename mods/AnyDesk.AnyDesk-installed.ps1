Get-Service -Name '*anydesk*' -ErrorAction SilentlyContinue | Stop-Service -ErrorAction SilentlyContinue
Get-Service -Name '*anydesk*' -ErrorAction SilentlyContinue | Set-Service -StartupType Manual -ErrorAction SilentlyContinue
Get-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\*AnyDesk*.lnk" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
