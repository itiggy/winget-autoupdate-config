# Pre-install: Close Greenshot process if running
Get-Process -Name 'Greenshot' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
