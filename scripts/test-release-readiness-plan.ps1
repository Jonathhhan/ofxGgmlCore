$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-release-readiness.ps1"
$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-plan-evidence.md"
$backendReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-capability-plan-evidence.md"
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-plan.md"
$defaultOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-score.md"
$repoDefaultOutputPath = Resolve-Path (Join-Path $scriptRoot "..\docs\release-readiness-score.md") -ErrorAction SilentlyContinue

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

@(
	'# Backend Capability Report',
	'',
	'| Backend | Declared support | Local runtime evidence | Inference smoke | Status |',
	'| --- | --- | --- | --- | --- |',
	'| `cpu` | yes | runtime smoke passed | passed | verified |'
) | Set-Content -LiteralPath $backendReport

if (Test-Path -LiteralPath $outputPath) {
	Remove-Item -LiteralPath $outputPath -Force
}
if (Test-Path -LiteralPath $defaultOutputPath) {
	Remove-Item -LiteralPath $defaultOutputPath -Force
}
if ($repoDefaultOutputPath) {
	Remove-Item -LiteralPath $repoDefaultOutputPath.Path -Force
}

& $planScript -SkipWorkflowStatus
if (!$?) {
	throw "plan-release-readiness.ps1 default run failed."
}
if (!(Test-Path -LiteralPath $defaultOutputPath -PathType Leaf)) {
	throw "default release readiness plan was not written to temp: $defaultOutputPath"
}
if (Test-Path -LiteralPath (Join-Path $scriptRoot "..\docs\release-readiness-score.md") -PathType Leaf) {
	throw "default release readiness plan should not write into docs without -OutputPath."
}

& $planScript -WorkflowStatusReport $workflowReport -BackendCapabilityReport $backendReport -OutputPath $outputPath
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
	"Backend capability evidence",
	"runtime smoke passed",
	"Repository readiness checklist"
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "release readiness plan did not contain expected text: $expected"
	}
}

Remove-Item -LiteralPath $workflowReport -Force
Remove-Item -LiteralPath $backendReport -Force
Remove-Item -LiteralPath $outputPath -Force
Remove-Item -LiteralPath $defaultOutputPath -Force
