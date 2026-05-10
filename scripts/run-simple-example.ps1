param(
	[switch]$Build,
	[switch]$DryRun,
	[string]$Configuration = "Release",
	[string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$exampleRoot = Join-Path $addonRoot "ofxGgmlSimpleExample"
$exeSuffix = if ($IsLinux -or $IsMacOS) { "" } else { ".exe" }
$exampleExe = Join-Path $exampleRoot "bin\ofxGgmlSimpleExample$exeSuffix"
. (Join-Path $scriptRoot "ofxGgml-launch-utils.ps1")

if ($env:OFXGGML_LAUNCH_DRY_RUN_ONLY -eq "1") {
	$Build = $false
	$DryRun = $true
}

if ($Build) {
	& (Join-Path $scriptRoot "build-simple-example.ps1") -Configuration $Configuration -Platform $Platform
	if (!$?) {
		exit 1
	}
}

if (!(Test-Path -LiteralPath $exampleExe -PathType Leaf)) {
	if ($DryRun) {
		Write-Warning "Simple example executable was not found: $exampleExe"
	} else {
		throw "Simple example executable was not found: $exampleExe. Run scripts\run-simple-example.bat -Build or scripts\build-simple-example.bat first."
	}
}

if ($DryRun) {
	Write-OfxGgmlStep "Executable: $exampleExe"
	return
}

Write-OfxGgmlStep "Starting ofxGgmlSimpleExample"
& $exampleExe
exit $LASTEXITCODE
