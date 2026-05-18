$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-release-readiness.ps1"
$testId = [guid]::NewGuid().ToString("N")
$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-plan-evidence-$testId.md"
$backendReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-capability-plan-evidence-$testId.md"
$backendRuntimePlan = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-runtime-plan-evidence-$testId.md"
$smokeBuildReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-smoke-build-ci-plan-evidence-$testId.json"
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-plan-$testId.md"
$jsonOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-json-plan-$testId.md"
$missingSmokeJsonOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-missing-smoke-json-plan-$testId.md"
$defaultOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-score.md"
$repoDefaultOutputPath = Resolve-Path (Join-Path $scriptRoot "..\docs\release-readiness-score.md") -ErrorAction SilentlyContinue
$repoSmokeBuildReport = Join-Path $scriptRoot "..\.smoke-build-ci-report.json"
$repoSmokeBuildBackup = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-smoke-build-ci-report-backup-$testId.json"

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
	'| Reference lanes ready | 1 |',
	'| Runtime-smoke entrypoints | 1 |',
	'| Validated runtime-smoke entrypoints | 1 |',
	'| Inference-smoke entrypoints | 1 |',
	'| Inference-checked repositories | 1 |',
	'| Repositories with models | 8 |',
	'| Repositories with built examples | 4 |',
	'| Example build evidence gaps | 0 |',
	'| Actionable repositories missing built examples | 0 |',
	'| Repositories needing runtime-smoke plans | 8 |',
	'',
	'## Repository Evidence',
	'',
	'| Repository | Lane | Backends | Models | Built examples | Runtime smoke | Inference smoke | Gate state | Action |',
	'| --- | --- | --- | --- | --- | --- | --- | --- | --- |',
	'| ofxGgmlCore | backend-neutral runtime base | cpu, cuda | available (1) | complete (1/1) | available-and-validated | inference-checked (cpu) | core-runtime-smoke-seeded | keep Core CPU graph smoke active |',
	'| ofxGgmlSam | segmentation | cpu, cuda, metal | available (1) | complete (1/1) | missing | inference-checked (cuda) | inference-checked | add SAM3 CPU/CUDA runtime-smoke handoff |'
) | Set-Content -LiteralPath $backendRuntimePlan

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
if (Test-Path -LiteralPath $jsonOutputPath) {
	Remove-Item -LiteralPath $jsonOutputPath -Force
}
if (Test-Path -LiteralPath $missingSmokeJsonOutputPath) {
	Remove-Item -LiteralPath $missingSmokeJsonOutputPath -Force
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

& $planScript -WorkflowStatusReport $workflowReport -BackendCapabilityReport $backendReport -BackendRuntimePlan $backendRuntimePlan -SmokeBuildCiReport $smokeBuildReport -OutputPath $outputPath
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
	"Backend runtime verification evidence",
	"inference-checked",
	"Smoke-build CI evidence",
	"passed 14 target(s), 3 stage(s), 14 command(s)",
	"Repository readiness checklist"
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "release readiness plan did not contain expected text: $expected"
	}
}

$jsonOutput = @(& $planScript -WorkflowStatusReport $workflowReport -BackendCapabilityReport $backendReport -BackendRuntimePlan $backendRuntimePlan -SmokeBuildCiReport $smokeBuildReport -OutputPath $jsonOutputPath -Json -SkipManagedGitStatus)
if (!$?) {
	throw "plan-release-readiness.ps1 JSON run failed."
}
if (!(Test-Path -LiteralPath $jsonOutputPath -PathType Leaf)) {
	throw "release readiness JSON run did not write report: $jsonOutputPath"
}
$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Summary) {
	throw "release readiness JSON did not include Summary."
}
if ($parsed.SummaryOnly) {
	throw "release readiness full JSON unexpectedly reported SummaryOnly."
}
foreach ($property in @(
	"ReleaseReportExists",
	"WorkflowStatusEvidenceProvided",
	"WorkflowStatusEvidenceGenerated",
	"WorkflowStatusEvidenceExists",
	"BackendCapabilityEvidenceProvided",
	"BackendCapabilityDefaultUsed",
	"BackendCapabilityEvidenceExists",
	"BackendRuntimePlanEvidenceProvided",
	"BackendRuntimePlanEvidenceGenerated",
	"BackendRuntimePlanEvidenceExists",
	"BackendRuntimeInferenceSmokeEntrypoints",
	"BackendRuntimeInferenceCheckedRepositories",
	"BackendRuntimeExampleBuildGaps",
	"SmokeBuildCiEvidenceProvided",
	"SmokeBuildCiDefaultUsed",
	"SmokeBuildCiEvidenceFetched",
	"SmokeBuildCiEvidenceExists",
	"ManagedGitStatusChecked",
	"ManagedGitStatusAvailable",
	"DirtyManagedRepositories",
	"DirtyManagedRepositoryNames",
	"DirtyReferenceRepositories",
	"DirtyReferenceRepositoryNames",
	"OutputPathIsTemporary",
	"EvidenceGapCount"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "release readiness JSON Summary did not include $property."
	}
}
if (!$parsed.Summary.ReleaseReportExists) {
	throw "release readiness JSON Summary did not report generated release report."
}
if (!$parsed.Summary.WorkflowStatusEvidenceProvided -or !$parsed.Summary.WorkflowStatusEvidenceExists) {
	throw "release readiness JSON Summary did not report workflow status evidence."
}
if (!$parsed.Summary.BackendCapabilityEvidenceProvided -or !$parsed.Summary.BackendCapabilityEvidenceExists) {
	throw "release readiness JSON Summary did not report backend capability evidence."
}
if (!$parsed.Summary.BackendRuntimePlanEvidenceProvided -or !$parsed.Summary.BackendRuntimePlanEvidenceExists) {
	throw "release readiness JSON Summary did not report backend runtime verification evidence."
}
if (!$parsed.Summary.SmokeBuildCiEvidenceProvided -or !$parsed.Summary.SmokeBuildCiEvidenceExists) {
	throw "release readiness JSON Summary did not report smoke-build CI evidence."
}
if (!$parsed.NextCommands -or @($parsed.NextCommands).Count -eq 0) {
	throw "release readiness JSON did not include NextCommands."
}
if (@($parsed.NextCommands) -notcontains "scripts\check-ecosystem-readiness.bat -SkipDoctorTests") {
	throw "release readiness JSON NextCommands did not include ecosystem readiness check."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-local-codex.bat -Json -SummaryOnly") {
	throw "release readiness JSON NextCommands did not include local codex readiness planning."
}
if (@($parsed.NextCommands | Where-Object { $_ -match "ofxGgmlLlama.*test-local-codex" }).Count -eq 0) {
	throw "release readiness JSON NextCommands did not include Llama-owned local Codex smoke."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly") {
	throw "release readiness JSON NextCommands did not include compact branch cleanup planning."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly") {
	throw "release readiness JSON NextCommands did not include compact backend runtime verification planning."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-release-readiness.bat -Json -SummaryOnly") {
	throw "release readiness JSON NextCommands did not include compact release readiness planning."
}
if (@($parsed.NextCommands) -notcontains "scripts\fetch-smoke-build-ci-report.bat -Force") {
	throw "release readiness JSON NextCommands did not include smoke-build CI artifact fetch."
}
if (@($parsed.NextCommands) -notcontains "scripts\run-smoke-build-ci.bat -CloneAddonRepos -TargetsPerStage 0") {
	throw "release readiness JSON NextCommands did not include smoke-build CI report generation."
}
if (@($parsed.NextCommands) -notcontains "scripts\release-candidate.bat") {
	throw "release readiness JSON NextCommands did not include release-candidate.bat."
}
if (!$parsed.EvidenceSummaries -or @($parsed.EvidenceSummaries).Count -ne 4) {
	throw "release readiness JSON did not include evidence summaries."
}
if (!$parsed.EvidenceSummaries[0].PSObject.Properties["Path"]) {
	throw "release readiness full JSON evidence summaries should include paths."
}
if (!$parsed.PSObject.Properties["EvidenceGaps"]) {
	throw "release readiness JSON did not include EvidenceGaps."
}
if (!$parsed.PSObject.Properties["FailOnEvidenceGaps"]) {
	throw "release readiness JSON did not include FailOnEvidenceGaps."
}
if ($parsed.Summary.EvidenceGapCount -ne 0) {
	throw "release readiness JSON unexpectedly reported evidence gaps for complete evidence."
}

try {
	if (Test-Path -LiteralPath $repoSmokeBuildReport -PathType Leaf) {
		Move-Item -LiteralPath $repoSmokeBuildReport -Destination $repoSmokeBuildBackup -Force
	}

	$missingSmokeJsonOutput = @(& $planScript -WorkflowStatusReport $workflowReport -BackendCapabilityReport $backendReport -BackendRuntimePlan $backendRuntimePlan -OutputPath $missingSmokeJsonOutputPath -Json -SummaryOnly -SkipManagedGitStatus)
	if (!$?) {
		throw "plan-release-readiness.ps1 missing-smoke JSON run failed."
	}
	$missingSmokeParsed = ($missingSmokeJsonOutput -join "`n") | ConvertFrom-Json
	if ($missingSmokeParsed.Summary.EvidenceGapCount -ne 1) {
		throw "release readiness JSON did not report the expected missing evidence gap count."
	}
	if (!$missingSmokeParsed.EvidenceGaps -or @($missingSmokeParsed.EvidenceGaps) -notcontains "smoke-build CI evidence is missing") {
		throw "release readiness JSON did not report missing smoke-build CI evidence."
	}
	if (!(Test-Path -LiteralPath $missingSmokeJsonOutputPath -PathType Leaf)) {
		throw "release readiness missing-smoke JSON run did not write report: $missingSmokeJsonOutputPath"
	}

	$failOnGapOutput = @(& $planScript -WorkflowStatusReport $workflowReport -BackendCapabilityReport $backendReport -BackendRuntimePlan $backendRuntimePlan -OutputPath $missingSmokeJsonOutputPath -Json -SummaryOnly -SkipManagedGitStatus -FailOnEvidenceGaps 2>&1)
	$failOnGapExitCode = $LASTEXITCODE
	if ($failOnGapExitCode -eq 0) {
		throw "plan-release-readiness.ps1 -FailOnEvidenceGaps unexpectedly passed missing evidence."
	}
	$failOnGapParsed = ($failOnGapOutput -join "`n") | ConvertFrom-Json
	if (!$failOnGapParsed.FailOnEvidenceGaps -or $failOnGapParsed.Summary.EvidenceGapCount -lt 1) {
		throw "plan-release-readiness.ps1 -FailOnEvidenceGaps did not preserve evidence gap details."
	}
} finally {
	if (Test-Path -LiteralPath $repoSmokeBuildBackup -PathType Leaf) {
		Move-Item -LiteralPath $repoSmokeBuildBackup -Destination $repoSmokeBuildReport -Force
	}
}

$summaryJsonOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-summary-json-plan-$testId.md"
if (Test-Path -LiteralPath $summaryJsonOutputPath) {
	Remove-Item -LiteralPath $summaryJsonOutputPath -Force
}
$summaryJsonOutput = @(& $planScript -WorkflowStatusReport $workflowReport -BackendCapabilityReport $backendReport -BackendRuntimePlan $backendRuntimePlan -SmokeBuildCiReport $smokeBuildReport -OutputPath $summaryJsonOutputPath -Json -SummaryOnly -SkipManagedGitStatus)
if (!$?) {
	throw "plan-release-readiness.ps1 summary JSON run failed."
}
if (!(Test-Path -LiteralPath $summaryJsonOutputPath -PathType Leaf)) {
	throw "release readiness summary JSON run did not write report: $summaryJsonOutputPath"
}
$summaryParsed = ($summaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$summaryParsed.SummaryOnly) {
	throw "release readiness summary JSON did not report SummaryOnly."
}
if (!$summaryParsed.Summary -or !$summaryParsed.EvidenceSummaries -or @($summaryParsed.EvidenceSummaries).Count -ne 4) {
	throw "release readiness summary JSON did not retain compact summary evidence."
}
foreach ($omitted in @("OutputPath", "WorkflowStatusReport", "BackendCapabilityReport", "BackendRuntimePlan", "SmokeBuildCiReport")) {
	if ($summaryParsed.PSObject.Properties[$omitted]) {
		throw "release readiness summary JSON should omit $omitted."
	}
}
if ($summaryParsed.EvidenceSummaries[0].PSObject.Properties["Path"]) {
	throw "release readiness summary JSON evidence summaries should omit paths."
}
if (@($summaryParsed.NextCommands) -notcontains "scripts\plan-release-readiness.bat -Json -SummaryOnly") {
	throw "release readiness summary JSON NextCommands did not include compact release readiness planning."
}
if (@($summaryParsed.NextCommands) -notcontains "scripts\release-candidate.bat") {
	throw "release readiness summary JSON NextCommands did not include release-candidate.bat."
}
if (@($summaryParsed.NextCommands | Where-Object { $_ -match "ofxGgmlLlama.*test-local-codex" }).Count -eq 0) {
	throw "release readiness summary JSON NextCommands did not include Llama-owned local Codex smoke."
}

Remove-Item -LiteralPath $workflowReport -Force
Remove-Item -LiteralPath $backendReport -Force
Remove-Item -LiteralPath $backendRuntimePlan -Force
Remove-Item -LiteralPath $smokeBuildReport -Force
Remove-Item -LiteralPath $outputPath -Force
Remove-Item -LiteralPath $jsonOutputPath -Force
Remove-Item -LiteralPath $missingSmokeJsonOutputPath -Force
Remove-Item -LiteralPath $summaryJsonOutputPath -Force
Remove-Item -LiteralPath $defaultOutputPath -Force
