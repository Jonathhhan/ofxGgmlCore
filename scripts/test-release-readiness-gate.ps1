$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$gateScript = Join-Path $scriptRoot "assert-release-readiness.ps1"
$testId = [guid]::NewGuid().ToString("N")
$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-gate-evidence-$testId.md"
$blockedWorkflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-gate-blocked-$testId.md"
$backendReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-capability-gate-evidence-$testId.md"
$backendRuntimePlan = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-runtime-gate-evidence-$testId.md"
$smokeBuildReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-smoke-build-ci-gate-evidence-$testId.json"
$failedSmokeBuildReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-smoke-build-ci-gate-failed-$testId.json"

@(
	'# Workflow Status Report',
	'',
	'## Summary',
	'',
	'- Successful latest runs: `18`',
	'- Blocking latest runs: `0`',
	'- Missing required workflows: `0`',
	'- Required workflows with no runs: `0`',
	'- Unavailable required statuses: `0`',
	'- Stale required workflows: `0`',
	'',
	'## Action Required',
	'',
	'### Required Workflow Blockers',
	'',
	'- None.',
	'',
	'### Optional Workflow Rollout Gaps',
	'',
	'- None.'
) | Set-Content -LiteralPath $workflowReport

@(
	'# Workflow Status Report',
	'',
	'## Summary',
	'',
	'- Successful latest runs: `17`',
	'- Blocking latest runs: `1`',
	'- Missing required workflows: `0`',
	'- Required workflows with no runs: `0`',
	'- Unavailable required statuses: `0`',
	'- Stale required workflows: `0`',
	'',
	'## Action Required',
	'',
	'### Required Workflow Blockers',
	'',
	'- `Jonathhhan/ofxGgmlCore` / `release-check.yml`: failed.',
	'',
	'### Optional Workflow Rollout Gaps',
	'',
	'- None.'
) | Set-Content -LiteralPath $blockedWorkflowReport

@(
	'# Backend Capability Report',
	'',
	'| Backend | Declared support | Local runtime evidence | Inference smoke | Status |',
	'| --- | --- | --- | --- | --- |',
	'| `cpu` | yes | runtime smoke passed | passed | verified |'
) | Set-Content -LiteralPath $backendReport

@(
	'# Backend Runtime Verification Plan',
	'',
	'## Summary',
	'',
	'| Metric | Count |',
	'| --- | ---: |',
	'| Managed repositories | 11 |',
	'| Runtime-applicable repositories | 10 |',
	'| Core runtime-smoke seeded | 1 |',
	'| Reference lanes ready | 0 |',
	'| Runtime-smoke entrypoints | 10 |',
	'| Repositories with models | 11 |',
	'| Repositories with built examples | 4 |',
	'| Repositories needing runtime-smoke plans | 0 |',
	'',
	'## Repository Evidence',
	'',
	'| Repository | Lane | Backends | Models | Built examples | Runtime smoke | Gate state | Action |',
	'| --- | --- | --- | --- | --- | --- | --- | --- |',
	'| ofxGgmlCore | backend-neutral runtime base | cpu, cuda | available (1) | complete (1/1) | available-and-validated | core-runtime-smoke-seeded | keep Core CPU graph smoke active |'
) | Set-Content -LiteralPath $backendRuntimePlan

@{
	Summary = @{
		Outcome = "passed"
		ReportedStages = 3
		ReportedTargets = 14
		CommandsRun = 14
		FailedTargets = 0
		FailedCommands = 0
		HasFailures = $false
	}
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $smokeBuildReport

@{
	Summary = @{
		Outcome = "failed"
		ReportedStages = 3
		ReportedTargets = 14
		CommandsRun = 14
		FailedTargets = 1
		FailedCommands = 1
		HasFailures = $true
	}
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $failedSmokeBuildReport

try {
	$passOutput = @(& $gateScript `
		-WorkflowStatusReport $workflowReport `
		-BackendCapabilityReport $backendReport `
		-BackendRuntimePlan $backendRuntimePlan `
		-SmokeBuildCiReport $smokeBuildReport `
		-Json 2>&1)
	if (!$?) {
		throw "assert-release-readiness.ps1 failed for passing evidence: $($passOutput -join "`n")"
	}
	$pass = ($passOutput -join "`n") | ConvertFrom-Json
	if (!$pass.Ready -or $pass.BlockerCount -ne 0) {
		throw "release readiness gate did not pass clean evidence."
	}

	$failedOutput = @(& $gateScript `
		-WorkflowStatusReport $workflowReport `
		-BackendCapabilityReport $backendReport `
		-BackendRuntimePlan $backendRuntimePlan `
		-SmokeBuildCiReport $failedSmokeBuildReport `
		-Json 2>&1)
	$failedExitCode = $LASTEXITCODE
	if ($failedExitCode -eq 0) {
		throw "assert-release-readiness.ps1 unexpectedly passed failed smoke-build evidence."
	}
	$failed = ($failedOutput -join "`n") | ConvertFrom-Json
	if ($failed.Ready -or @($failed.Blockers) -notcontains "smoke-build CI evidence is not passing") {
		throw "release readiness gate did not report failed smoke-build evidence."
	}

	$blockedOutput = @(& $gateScript `
		-WorkflowStatusReport $blockedWorkflowReport `
		-BackendCapabilityReport $backendReport `
		-BackendRuntimePlan $backendRuntimePlan `
		-SmokeBuildCiReport $smokeBuildReport `
		-Json 2>&1)
	$blockedExitCode = $LASTEXITCODE
	if ($blockedExitCode -eq 0) {
		throw "assert-release-readiness.ps1 unexpectedly passed workflow blocker evidence."
	}
	$blocked = ($blockedOutput -join "`n") | ConvertFrom-Json
	if ($blocked.Ready -or @($blocked.Blockers) -notcontains "workflow status evidence reports required blockers") {
		throw "release readiness gate did not report workflow blocker evidence."
	}

	Write-Host "==> Release readiness gate coverage passed"
} finally {
	foreach ($path in @(
		$workflowReport,
		$blockedWorkflowReport,
		$backendReport,
		$backendRuntimePlan,
		$smokeBuildReport,
		$failedSmokeBuildReport
	)) {
		Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
	}
}
