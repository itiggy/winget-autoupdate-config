Get-Process -Name 'NAPS2*' -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() }
