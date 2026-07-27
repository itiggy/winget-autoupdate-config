$Paths = @(
	"$env:USERPROFILE\Desktop"
	"$env:PUBLIC\Desktop"
)
$LnkName = 'Betterbird'

foreach ($Path in $Paths) {
    Get-Item -Path "$Path\*$LnkName*.lnk" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
}
