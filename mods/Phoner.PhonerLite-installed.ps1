$Paths = @(
	"$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
	"$env:LOCALAPPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
)
$LnkName = 'PhonerLite'

foreach ($Path in $Paths) {
    Get-Item -Path "$Path\*$LnkName*.lnk" -ErrorAction SilentlyContinue | Invoke-Item -ErrorAction SilentlyContinue
}
