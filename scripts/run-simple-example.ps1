param(
	[switch]$Build,
	[switch]$DryRun,
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[int]$Jobs = 1
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$exampleRoot = Join-Path $addonRoot "ofxGgmlCoreExample"
$exeSuffix = if ($IsLinux -or $IsMacOS) { "" } else { ".exe" }
$exampleExe = Join-Path $exampleRoot "bin\ofxGgmlCoreExample$exeSuffix"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

if ($env:OFXGGML_LAUNCH_DRY_RUN_ONLY -eq "1") {
	$Build = $false
	$DryRun = $true
}

if ($Build) {
	& (Join-Path $scriptRoot "build-simple-example.ps1") -Configuration $Configuration -Platform $Platform -Jobs $Jobs
	if (!$?) {
		exit 1
	}
}

if (!(Test-Path -LiteralPath $exampleExe -PathType Leaf)) {
	if ($DryRun) {
		Write-Warning "Core example executable was not found: $exampleExe"
	} else {
		throw "Core example executable was not found: $exampleExe. Run scripts\run-simple-example.bat -Build or scripts\build-simple-example.bat first."
	}
}

if ($DryRun) {
	Write-Step "Executable: $exampleExe"
	return
}

Write-Step "Starting ofxGgmlCoreExample"
& $exampleExe
exit $LASTEXITCODE
