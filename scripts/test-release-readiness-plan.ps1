$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-release-readiness.ps1"
$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-plan-evidence.md"
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-plan.md"

@(
	'# Workflow Status Report',
	'',
	'## Summary',
	'',
	'- Successful latest runs: `18`',
	'- Blocking latest runs: `0`',
	'- Missing required workflows: `0`',
	'- Required workflows with no runs: `0`',
	'- Unavailable required statuses: `1`',
	'- Stale required workflows: `0`',
	'',
	'## Action Required',
	'',
	'### Required Workflow Blockers',
	'',
	'- `Jonathhhan/ofxGgmlAudio` / `metadata-validation.yml`: unavailable: HTTP 403.',
	'',
	'### Optional Workflow Rollout Gaps',
	'',
	'- None.'
) | Set-Content -LiteralPath $workflowReport

if (Test-Path -LiteralPath $outputPath) {
	Remove-Item -LiteralPath $outputPath -Force
}

& $planScript -WorkflowStatusReport $workflowReport -OutputPath $outputPath
if (!$?) {
	throw "plan-release-readiness.ps1 failed."
}

if (!(Test-Path -LiteralPath $outputPath -PathType Leaf)) {
	throw "release readiness plan was not written: $outputPath"
}

$content = Get-Content -LiteralPath $outputPath -Raw
foreach ($expected in @(
	"Release Readiness Score",
	"Workflow status evidence",
	"blocked by 1 required workflow signal",
	"Required workflow blockers",
	"unavailable: HTTP 403",
	"Repository readiness checklist"
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "release readiness plan did not contain expected text: $expected"
	}
}

Remove-Item -LiteralPath $workflowReport -Force
Remove-Item -LiteralPath $outputPath -Force
