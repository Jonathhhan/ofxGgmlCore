$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$scriptPath = Join-Path $scriptRoot "fetch-workflow-status.py"
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-report.md"

if (Test-Path -LiteralPath $outputPath) {
	Remove-Item -LiteralPath $outputPath -Force
}

python $scriptPath --output $outputPath
if (!$?) {
	throw "fetch-workflow-status.py failed."
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
	"Optional Workflow Rollout Gaps",
	"Missing optional workflows",
	"Stale required workflows",
	"Stale threshold",
	"addon-hygiene.yml",
	"coding-agent-instructions.yml",
	"multi-platform-smoke.yml",
	"release-check.yml"
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "workflow status report did not contain expected text: $expected"
	}
}

Remove-Item -LiteralPath $outputPath -Force
