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

foreach ($stepName in @("structured ecosystem plan", "structured coding agent work queue")) {
	$step = @($parsed.Steps | Where-Object { $_.Name -eq $stepName } | Select-Object -First 1)
	if ($step.Count -eq 0 -or $step[0].State -ne "OK") {
		throw "ecosystem readiness JSON did not report $stepName as OK."
	}
	if (!$step[0].Output -or @($step[0].Output).Count -eq 0) {
		throw "ecosystem readiness JSON did not retain output for $stepName."
	}
}

$releaseReadinessStep = @($parsed.Steps | Where-Object { $_.Name -eq "release readiness plan" } | Select-Object -First 1)
if ($releaseReadinessStep.Count -eq 0 -or $releaseReadinessStep[0].State -ne "OK") {
	throw "ecosystem readiness JSON did not report release readiness plan as OK."
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
