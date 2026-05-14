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
	"coding agent work queue",
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
if (!$parsed.Steps -or $parsed.Steps.Count -eq 0) {
	throw "ecosystem readiness JSON did not include steps."
}

$workflowGuideStep = @($parsed.Steps | Where-Object { $_.Name -eq "workflow guide coverage" } | Select-Object -First 1)
if ($workflowGuideStep.Count -eq 0 -or $workflowGuideStep[0].State -ne "OK") {
	throw "ecosystem readiness JSON did not report workflow guide coverage as OK."
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
