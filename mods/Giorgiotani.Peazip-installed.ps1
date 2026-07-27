$Paths = @(
	"$env:USERPROFILE\Desktop"
	"$env:PUBLIC\Desktop"
)
$LnkName = 'PeaZip'

foreach ($Path in $Paths) {
    Get-Item -Path "$Path\*$LnkName*.lnk" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
}
