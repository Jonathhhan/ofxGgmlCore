param(
	[string]$ModelPath = $(if ($env:OFXGGML_SAM3_MODEL) { $env:OFXGGML_SAM3_MODEL } else { "" }),
	[string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (![string]::IsNullOrWhiteSpace($ModelPath)) {
	if (!(Test-Path -LiteralPath $ModelPath -PathType Leaf)) {
		throw "SAM3 model was not found: $ModelPath"
	}
	$env:OFXGGML_SAM3_MODEL = (Resolve-Path -LiteralPath $ModelPath).Path
	Write-Step "Running SAM3 smoke with model: $env:OFXGGML_SAM3_MODEL"
} else {
	Write-Step "Running SAM3 boundary smoke without a model"
	Write-Host "Set OFXGGML_SAM3_MODEL or pass -ModelPath after building the optional SAM3 adapter."
}

& (Join-Path $scriptRoot "test-addon.ps1") -Configuration $Configuration
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

Write-Step "SAM3 smoke path passed"
