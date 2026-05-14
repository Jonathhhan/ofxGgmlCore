$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptRoot "generate-release-readiness-score.py"
$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-evidence.md"
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-score.md"

@(
	'# Workflow Status Report',
	'',
	'## Summary',
	'',
	'- Successful latest runs: `17`',
	'- Blocking latest runs: `0`',
	'- Missing required workflows: `0`',
	'- Required workflows with no runs: `1`',
	'- Unavailable required statuses: `0`',
	'- Stale required workflows: `2`'
) | Set-Content -LiteralPath $workflowReport

if (Test-Path -LiteralPath $outputPath) {
	Remove-Item -LiteralPath $outputPath -Force
}

python $scriptPath --workflow-status-report $workflowReport --output $outputPath
if (!$?) {
	throw "generate-release-readiness-score.py failed."
}

if (!(Test-Path -LiteralPath $outputPath -PathType Leaf)) {
	throw "release readiness score was not written: $outputPath"
}

$content = Get-Content -LiteralPath $outputPath -Raw
foreach ($expected in @(
	"Release Readiness Score",
	"Evidence inputs",
	"Workflow status evidence",
	"blocked by 3 required workflow signal",
	"Stale required workflows",
	"Repository readiness checklist"
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "release readiness score did not contain expected text: $expected"
	}
}

Remove-Item -LiteralPath $workflowReport -Force
Remove-Item -LiteralPath $outputPath -Force
