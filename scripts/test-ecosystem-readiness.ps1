$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$readinessScript = Join-Path $scriptRoot "check-ecosystem-readiness.ps1"

$output = & $readinessScript -SkipDoctorTests *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-ecosystem-readiness.ps1 -SkipDoctorTests failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml Ecosystem Readiness Check",
	"Control Plane",
	"Doctor Smoke Tests",
	"workflow guide coverage",
	"agent instructions current",
	"ecosystem audit strict",
	"doctor rollout plan",
	"structured ecosystem plan",
	"coding agent work queue",
	"structured coding agent work queue",
	"openFrameworks smoke build plan",
	"openFrameworks smoke build target selection",
	"openFrameworks smoke build target handoff",
	"openFrameworks smoke build target preflight",
	"openFrameworks smoke build target postflight",
	"release readiness plan",
	"agent branch cleanup plan",
	"Readiness passed"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "ecosystem readiness output did not contain expected text: $expected"
	}
}

$jsonOutput = & $readinessScript -SkipDoctorTests -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-ecosystem-readiness.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Passed) {
	throw "ecosystem readiness JSON did not report Passed."
}
if (!$parsed.Summary) {
	throw "ecosystem readiness JSON did not include Summary."
}
if ($parsed.Summary.TotalSteps -le 0 -or $parsed.Summary.FailedSteps -ne 0) {
	throw "ecosystem readiness JSON Summary did not report passing control-plane steps."
}
if ($parsed.Summary.TotalDoctorTests -ne 0 -or $parsed.Summary.FailedDoctorTests -ne 0) {
	throw "ecosystem readiness JSON Summary did not reflect skipped doctor tests."
}
if (@($parsed.Summary.FailedChecks).Count -ne 0) {
	throw "ecosystem readiness JSON Summary reported failed checks for a passing run."
}
if (!$parsed.Steps -or $parsed.Steps.Count -eq 0) {
	throw "ecosystem readiness JSON did not include steps."
}

$workflowGuideStep = @($parsed.Steps | Where-Object { $_.Name -eq "workflow guide coverage" } | Select-Object -First 1)
if ($workflowGuideStep.Count -eq 0 -or $workflowGuideStep[0].State -ne "OK") {
	throw "ecosystem readiness JSON did not report workflow guide coverage as OK."
}

$auditStep = @($parsed.Steps | Where-Object { $_.Name -eq "ecosystem audit strict" } | Select-Object -First 1)
if ($auditStep.Count -eq 0 -or $auditStep[0].State -ne "OK") {
	throw "ecosystem readiness JSON did not report ecosystem audit strict as OK."
}
if (!$auditStep[0].Output -or @($auditStep[0].Output).Count -eq 0) {
	throw "ecosystem readiness JSON did not retain output for ecosystem audit strict."
}
$auditJson = (@($auditStep[0].Output) -join "`n") | ConvertFrom-Json
if (!$auditJson.SummaryOnly) {
	throw "ecosystem readiness strict audit should use SummaryOnly output."
}
if (!$auditJson.RepositorySummaries -or $auditJson.PSObject.Properties["Repositories"]) {
	throw "ecosystem readiness strict audit did not use compact repository summaries."
}

foreach ($stepName in @("structured ecosystem plan", "structured coding agent work queue")) {
	$step = @($parsed.Steps | Where-Object { $_.Name -eq $stepName } | Select-Object -First 1)
	if ($step.Count -eq 0 -or $step[0].State -ne "OK") {
		throw "ecosystem readiness JSON did not report $stepName as OK."
	}
	if (!$step[0].Output -or @($step[0].Output).Count -eq 0) {
		throw "ecosystem readiness JSON did not retain output for $stepName."
	}
}

$structuredPlanStep = @($parsed.Steps | Where-Object { $_.Name -eq "structured ecosystem plan" } | Select-Object -First 1)
$structuredPlanJson = (@($structuredPlanStep[0].Output) -join "`n") | ConvertFrom-Json
if (!$structuredPlanJson.SummaryOnly) {
	throw "ecosystem readiness structured ecosystem plan should use SummaryOnly output."
}
if (!$structuredPlanJson.RepositorySummaries -or $structuredPlanJson.PSObject.Properties["Addons"]) {
	throw "ecosystem readiness structured ecosystem plan did not use compact repository summaries."
}

$releaseReadinessStep = @($parsed.Steps | Where-Object { $_.Name -eq "release readiness plan" } | Select-Object -First 1)
if ($releaseReadinessStep.Count -eq 0 -or $releaseReadinessStep[0].State -ne "OK") {
	throw "ecosystem readiness JSON did not report release readiness plan as OK."
}
if (!$releaseReadinessStep[0].Output -or @($releaseReadinessStep[0].Output).Count -eq 0) {
	throw "ecosystem readiness JSON did not retain output for release readiness plan."
}
$releaseReadinessJson = (@($releaseReadinessStep[0].Output) -join "`n") | ConvertFrom-Json
if (!$releaseReadinessJson.SummaryOnly) {
	throw "ecosystem readiness release readiness plan should use SummaryOnly output."
}
if (!$releaseReadinessJson.EvidenceSummaries -or $releaseReadinessJson.PSObject.Properties["OutputPath"]) {
	throw "ecosystem readiness release readiness plan did not use compact evidence summaries."
}

$smokeBuildStep = @($parsed.Steps | Where-Object { $_.Name -eq "openFrameworks smoke build plan" } | Select-Object -First 1)
if ($smokeBuildStep.Count -eq 0 -or $smokeBuildStep[0].State -ne "OK") {
	throw "ecosystem readiness JSON did not report openFrameworks smoke build plan as OK."
}

foreach ($stepName in @(
	"openFrameworks smoke build target selection",
	"openFrameworks smoke build target handoff",
	"openFrameworks smoke build target preflight",
	"openFrameworks smoke build target postflight"
)) {
	$step = @($parsed.Steps | Where-Object { $_.Name -eq $stepName } | Select-Object -First 1)
	if ($step.Count -eq 0 -or $step[0].State -ne "OK") {
		throw "ecosystem readiness JSON did not report $stepName as OK."
	}
	if (!$step[0].Output -or @($step[0].Output).Count -eq 0) {
		throw "ecosystem readiness JSON did not retain output for $stepName."
	}
	$smokeJson = (@($step[0].Output) -join "`n") | ConvertFrom-Json
	if (!$smokeJson.SummaryOnly) {
		throw "ecosystem readiness $stepName should use SummaryOnly output."
	}
}

$smokeSelectionStep = @($parsed.Steps | Where-Object { $_.Name -eq "openFrameworks smoke build target selection" } | Select-Object -First 1)
$smokeSelectionJson = (@($smokeSelectionStep[0].Output) -join "`n") | ConvertFrom-Json
if (!$smokeSelectionJson.PSObject.Properties["TargetSummaries"] -or $smokeSelectionJson.PSObject.Properties["Targets"]) {
	throw "ecosystem readiness smoke target selection did not use compact target summaries."
}

$smokeHandoffStep = @($parsed.Steps | Where-Object { $_.Name -eq "openFrameworks smoke build target handoff" } | Select-Object -First 1)
$smokeHandoffJson = (@($smokeHandoffStep[0].Output) -join "`n") | ConvertFrom-Json
if (!$smokeHandoffJson.PSObject.Properties["TargetSummaries"] -or $smokeHandoffJson.PSObject.Properties["Targets"]) {
	throw "ecosystem readiness smoke target handoff did not use compact target summaries."
}

$smokePreflightStep = @($parsed.Steps | Where-Object { $_.Name -eq "openFrameworks smoke build target preflight" } | Select-Object -First 1)
$smokePreflightJson = (@($smokePreflightStep[0].Output) -join "`n") | ConvertFrom-Json
if (!$smokePreflightJson.PSObject.Properties["PreflightSummaries"] -or $smokePreflightJson.PSObject.Properties["Preflights"]) {
	throw "ecosystem readiness smoke target preflight did not use compact preflight summaries."
}

$smokePostflightStep = @($parsed.Steps | Where-Object { $_.Name -eq "openFrameworks smoke build target postflight" } | Select-Object -First 1)
$smokePostflightJson = (@($smokePostflightStep[0].Output) -join "`n") | ConvertFrom-Json
if (!$smokePostflightJson.PSObject.Properties["PostflightSummaries"] -or $smokePostflightJson.PSObject.Properties["Postflights"]) {
	throw "ecosystem readiness smoke target postflight did not use compact postflight summaries."
}

$branchCleanupStep = @($parsed.Steps | Where-Object { $_.Name -eq "agent branch cleanup plan" } | Select-Object -First 1)
if ($branchCleanupStep.Count -eq 0 -or $branchCleanupStep[0].State -ne "OK") {
	throw "ecosystem readiness JSON did not report agent branch cleanup plan as OK."
}
if (!$branchCleanupStep[0].Output -or @($branchCleanupStep[0].Output).Count -eq 0) {
	throw "ecosystem readiness JSON did not retain output for agent branch cleanup plan."
}
$branchCleanupJson = (@($branchCleanupStep[0].Output) -join "`n") | ConvertFrom-Json
if (!$branchCleanupJson.SummaryOnly) {
	throw "ecosystem readiness branch cleanup handoff should use SummaryOnly output."
}
if (!$branchCleanupJson.Summary -or !$branchCleanupJson.PSObject.Properties["RepositorySummaries"]) {
	throw "ecosystem readiness branch cleanup handoff did not retain compact summary evidence."
}
if ($branchCleanupJson.PSObject.Properties["Inventory"] -or $branchCleanupJson.PSObject.Properties["Candidates"]) {
	throw "ecosystem readiness branch cleanup handoff should omit branch-level Inventory and Candidates."
}

$doctorRolloutStep = @($parsed.Steps | Where-Object { $_.Name -eq "doctor rollout plan" } | Select-Object -First 1)
if ($doctorRolloutStep.Count -eq 0 -or $doctorRolloutStep[0].State -ne "OK") {
	throw "ecosystem readiness JSON did not report doctor rollout plan as OK."
}
if (!$doctorRolloutStep[0].Output -or @($doctorRolloutStep[0].Output).Count -eq 0) {
	throw "ecosystem readiness JSON did not retain output for doctor rollout plan."
}
$doctorRolloutJson = (@($doctorRolloutStep[0].Output) -join "`n") | ConvertFrom-Json
if (!$doctorRolloutJson.SummaryOnly) {
	throw "ecosystem readiness doctor rollout should use SummaryOnly output."
}
if (!$doctorRolloutJson.RepositorySummaries -or $doctorRolloutJson.PSObject.Properties["Repositories"]) {
	throw "ecosystem readiness doctor rollout did not use compact repository summaries."
}

$summaryJsonOutput = & $readinessScript -SkipDoctorTests -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-ecosystem-readiness.ps1 -Json -SummaryOnly failed."
}

$summaryParsed = ($summaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$summaryParsed.SummaryOnly) {
	throw "ecosystem readiness summary JSON did not report SummaryOnly."
}
if (!$summaryParsed.Passed -or !$summaryParsed.Summary) {
	throw "ecosystem readiness summary JSON did not preserve pass summary."
}
$omittedOutputs = @($summaryParsed.Steps | Where-Object { $_.OutputOmitted })
if ($omittedOutputs.Count -eq 0) {
	throw "ecosystem readiness summary JSON did not omit successful step output."
}
$unexpectedOutput = @($summaryParsed.Steps | Where-Object { $_.State -eq "OK" -and @($_.Output).Count -gt 0 })
if ($unexpectedOutput.Count -gt 0) {
	throw "ecosystem readiness summary JSON retained successful step output."
}
$summaryBranchCleanupStep = @($summaryParsed.Steps | Where-Object { $_.Name -eq "agent branch cleanup plan" } | Select-Object -First 1)
if ($summaryBranchCleanupStep.Count -eq 0 -or !$summaryBranchCleanupStep[0].OutputOmitted) {
	throw "ecosystem readiness summary JSON did not compact branch cleanup output."
}
