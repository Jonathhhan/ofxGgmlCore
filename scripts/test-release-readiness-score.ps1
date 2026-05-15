$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptRoot "generate-release-readiness-score.py"
$testId = [guid]::NewGuid().ToString("N")
$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-evidence-$testId.md"
$backendReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-capability-evidence-$testId.md"
$smokeBuildReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-smoke-build-ci-evidence-$testId.json"
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-score-$testId.md"

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
	'- Stale required workflows: `2`',
	'',
	'## Action Required',
	'',
	'### Required Workflow Blockers',
	'',
	'- `Jonathhhan/ofxGgmlCore` / `multi-platform-smoke.yml`: latest run is stale (45d).',
	'',
	'### Optional Workflow Rollout Gaps',
	'',
	'- `Jonathhhan/ofxGgmlVision` / `release-check.yml`: workflow file missing.',
	'',
	'## Notes',
	'',
	'- Set `GITHUB_TOKEN` for higher API limits and private-repo access.'
) | Set-Content -LiteralPath $workflowReport

@(
	'# Backend Capability Report',
	'',
	'| Backend | Declared support | Local runtime evidence | Inference smoke | Status |',
	'| --- | --- | --- | --- | --- |',
	'| `cpu` | yes | runtime smoke passed | passed | verified |',
	'| `cuda` | yes | local library present | not checked | ready for runtime init smoke |',
	'| `metal` | yes | not installed locally | not checked | optional backend absent |'
) | Set-Content -LiteralPath $backendReport

@{
	Summary = @{
		Outcome = "passed"
		StageCount = 3
		ReportedStages = 3
		TargetsRun = 14
		ReportedTargets = 14
		CommandsRun = 14
		FailedTargets = 0
		FailedCommands = 0
		StageNames = @("generate-project", "repair-generated-project", "compile-example")
		FailedStageNames = @()
		HasFailures = $false
	}
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smokeBuildReport

if (Test-Path -LiteralPath $outputPath) {
	Remove-Item -LiteralPath $outputPath -Force
}

python $scriptPath --workflow-status-report $workflowReport --backend-capability-report $backendReport --smoke-build-ci-report $smokeBuildReport --output $outputPath
if (!$?) {
	throw "generate-release-readiness-score.py failed."
}

if (!(Test-Path -LiteralPath $outputPath -PathType Leaf)) {
	throw "release readiness score was not written: $outputPath"
}

$content = Get-Content -LiteralPath $outputPath -Raw
$notesPattern = [regex]::Escape("- Set `GITHUB_TOKEN` for higher API limits and private-repo access.")
if ($content -match $notesPattern) {
	throw "release readiness score copied workflow report notes into action evidence."
}

foreach ($expected in @(
	"Release Readiness Score",
	"Evidence inputs",
	"Workflow status evidence",
	"blocked by 3 required workflow signal",
	"Required workflow blockers",
	"latest run is stale (45d)",
	"Optional workflow rollout gaps",
	"workflow file missing",
	"Backend capability report",
	"Backend capability evidence",
	"1 backend(s) runtime-smoke checked",
	"runtime smoke passed",
	"Smoke-build CI report",
	"Smoke-build CI evidence",
	"passed 14 target(s), 3 stage(s), 14 command(s)",
	"Failed commands",
	"Stale required workflows",
	"Repository readiness checklist"
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "release readiness score did not contain expected text: $expected"
	}
}

Remove-Item -LiteralPath $workflowReport -Force
Remove-Item -LiteralPath $backendReport -Force
Remove-Item -LiteralPath $smokeBuildReport -Force
Remove-Item -LiteralPath $outputPath -Force
