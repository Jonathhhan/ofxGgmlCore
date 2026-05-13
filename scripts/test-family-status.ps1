$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$output = & (Join-Path $scriptRoot "status-family.ps1") *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "family status smoke test failed."
}
$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml family status",
	"ofxGgmlCore",
	"ofxGgmlLlama",
	"ofxGgmlDiffusion",
	"ofxGgmlWorkflows",
	"Validate"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "family status output did not contain expected text: $expected"
	}
}

$json = & (Join-Path $scriptRoot "status-family.ps1") -Json
$parsed = $json | ConvertFrom-Json
if (!$parsed.Addons -or $parsed.Addons.Count -lt 11) {
	throw "family status JSON did not contain the expected addon list."
}
