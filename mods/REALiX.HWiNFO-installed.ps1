Get-Process -Name 'HWiNFO64' -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() }
