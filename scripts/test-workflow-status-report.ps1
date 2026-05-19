$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$scriptPath = Join-Path $scriptRoot "fetch-workflow-status.bat"
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-report.md"

if (Test-Path -LiteralPath $outputPath) {
	Remove-Item -LiteralPath $outputPath -Force
}

& $scriptPath --output $outputPath
if ($LASTEXITCODE -ne 0) {
	throw "fetch-workflow-status.bat failed."
}

if (!(Test-Path -LiteralPath $outputPath -PathType Leaf)) {
	throw "workflow status report was not written: $outputPath"
}

$content = Get-Content -LiteralPath $outputPath -Raw
foreach ($expected in @(
	"Workflow Status Report",
	"## Summary",
	"## Action Required",
	"Required Workflow Blockers",
	"release-gate.yml",
	"smoke-build-ci.yml",
	"Current GitHub access mode",
	"HTTP 429 means GitHub rate limited workflow-status evidence",
	"Repository-scoped workflow expectations"
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "workflow status report did not contain expected text: $expected"
	}
}

Remove-Item -LiteralPath $outputPath -Force