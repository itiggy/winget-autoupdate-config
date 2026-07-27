@echo off
:: Check for Administrator privileges using net session
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Set working directory to script location
cd /D "%~dp0"

:: Launch install.ps1 with execution policy bypass
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1"

if %errorlevel% neq 0 (
    echo.
    echo Installation failed with exit code %errorlevel%.
) else (
    echo.
    echo Installation completed successfully.
)

pause
