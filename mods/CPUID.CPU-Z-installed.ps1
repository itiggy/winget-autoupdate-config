$Paths = @(
	"$env:USERPROFILE\Desktop"
	"$env:PUBLIC\Desktop"
)
$LnkName = 'CPU-Z'

foreach ($Path in $Paths) {
    Get-Item -Path "$Path\*$LnkName*.lnk" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
}
