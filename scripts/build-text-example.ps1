param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$Clean
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildScript = Join-Path $scriptRoot "build-simple-example.ps1"

$buildArgs = @(
	"-Configuration", $Configuration,
	"-Platform", $Platform,
	"-Example", "ofxGgmlTextExample"
)
if ($Clean) {
	$buildArgs += "-Clean"
}

& $buildScript @buildArgs
exit $LASTEXITCODE
