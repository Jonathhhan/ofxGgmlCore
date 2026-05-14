$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-of-smoke-build.ps1"
$selectScript = Join-Path $scriptRoot "select-smoke-build-target.ps1"
$handoffScript = Join-Path $scriptRoot "plan-smoke-build-target-handoff.ps1"
$preflightScript = Join-Path $scriptRoot "check-smoke-build-target-preflight.ps1"

$output = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-of-smoke-build.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"openFrameworks Smoke Build Plan",
	"ProjectGenerator:",
	"Repository Plan",
	"Ready for project-generation checks",
	"Examples with addons.make",
	"Examples missing owner addon",
	"Examples with projectGenerator commands",
	"Generate-project targets",
	"Next Targets",
	"Example metadata",
	"ready-for-project-generation-check",
	"ofxGgmlCore",
	"ofxGgmlWorkflows",
	"Keep generated openFrameworks project files"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "openFrameworks smoke build plan output did not contain expected text: $expected"
	}
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-of-smoke-build.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Records -or $parsed.Records.Count -eq 0) {
	throw "openFrameworks smoke build plan JSON did not include records."
}

if ($null -eq $parsed.ProjectGeneratorPath) {
	throw "openFrameworks smoke build plan JSON did not include projectGenerator detection state."
}

if (!$parsed.Targets -or $parsed.Targets.Count -eq 0) {
	throw "openFrameworks smoke build plan JSON did not include a target queue."
}

$ready = @($parsed.Records | Where-Object { $_.Phase -eq "ready-for-project-generation-check" })
if ($ready.Count -eq 0) {
	throw "openFrameworks smoke build plan did not find any project-generation candidates."
}

$examplesWithMetadata = @($parsed.Records | ForEach-Object { $_.ExampleMetadata } | Where-Object { $_.HasAddonsMake })
if ($examplesWithMetadata.Count -eq 0) {
	throw "openFrameworks smoke build plan did not report example addons.make metadata."
}

$missingMetadata = @($parsed.Records | ForEach-Object { $_.ExampleMetadata } | Where-Object {
	!$_.HasAddonsMake -or !$_.HasOwnerAddon -or !$_.HasCoreAddon
})
if ($missingMetadata.Count -gt 0) {
	throw "openFrameworks smoke build plan found examples missing addons.make, owner addon, or ofxGgmlCore references."
}

$examples = @($parsed.Records | ForEach-Object { $_.ExampleMetadata })
if ($examples.Count -eq 0) {
	throw "openFrameworks smoke build plan JSON did not include example metadata."
}

$missingGeneratedProjectState = @($examples | Where-Object { $null -eq $_.HasGeneratedProject })
if ($missingGeneratedProjectState.Count -gt 0) {
	throw "openFrameworks smoke build plan JSON did not include generated project state for every example."
}

if (![string]::IsNullOrWhiteSpace([string]$parsed.ProjectGeneratorPath)) {
	$commands = @($examples | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_.ProjectGeneratorCommand) })
	if ($commands.Count -eq 0) {
		throw "openFrameworks smoke build plan detected projectGenerator but did not emit example commands."
	}
	$generateTargets = @($parsed.Targets | Where-Object { $_.Stage -eq "generate-project" })
	if ($generateTargets.Count -eq 0) {
		throw "openFrameworks smoke build plan detected projectGenerator but did not identify project-generation targets."
	}
}

$targetOutput = & $selectScript -Stage "generate-project" -First 1 *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "select-smoke-build-target.ps1 failed."
}

$targetText = $targetOutput -join "`n"
foreach ($expected in @(
	"openFrameworks Smoke Build Target",
	"Stage filter: generate-project",
	"generate-project",
	"Commands"
)) {
	if ($targetText -notmatch [regex]::Escape($expected)) {
		throw "smoke build target selector output did not contain expected text: $expected"
	}
}

$targetJsonOutput = & $selectScript -Stage "generate-project" -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "select-smoke-build-target.ps1 -Json failed."
}

$targetParsed = ($targetJsonOutput -join "`n") | ConvertFrom-Json
if (!$targetParsed.Targets -or $targetParsed.Targets.Count -ne 1) {
	throw "smoke build target selector JSON did not include exactly one target."
}
if ($targetParsed.Targets[0].Stage -ne "generate-project") {
	throw "smoke build target selector returned the wrong target stage."
}

$handoffOutput = & $handoffScript -Stage "generate-project" -First 1 *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-target-handoff.ps1 failed."
}

$handoffText = $handoffOutput -join "`n"
foreach ($expected in @(
	"Smoke Build Target Handoff",
	"Targets",
	"Validation",
	"Guardrails",
	"test-artifact-hygiene.ps1",
	"Do not commit generated openFrameworks project files"
)) {
	if ($handoffText -notmatch [regex]::Escape($expected)) {
		throw "smoke build target handoff output did not contain expected text: $expected"
	}
}

$handoffJsonOutput = & $handoffScript -Stage "generate-project" -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-target-handoff.ps1 -Json failed."
}

$handoffParsed = ($handoffJsonOutput -join "`n") | ConvertFrom-Json
if (!$handoffParsed.Targets -or $handoffParsed.Targets.Count -ne 1) {
	throw "smoke build target handoff JSON did not include exactly one target."
}
if (!$handoffParsed.Validation -or $handoffParsed.Validation.Count -eq 0) {
	throw "smoke build target handoff JSON did not include validation commands."
}

$preflightOutput = & $preflightScript -Stage "generate-project" -First 1 *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-preflight.ps1 failed."
}

$preflightText = $preflightOutput -join "`n"
foreach ($expected in @(
	"Smoke Build Target Preflight",
	"projectGenerator detected",
	"owning repository clean",
	"target stage matches filesystem",
	"Ready:"
)) {
	if ($preflightText -notmatch [regex]::Escape($expected)) {
		throw "smoke build target preflight output did not contain expected text: $expected"
	}
}

$preflightJsonOutput = & $preflightScript -Stage "generate-project" -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-preflight.ps1 -Json failed."
}

$preflightParsed = ($preflightJsonOutput -join "`n") | ConvertFrom-Json
if (!$preflightParsed.Preflights -or $preflightParsed.Preflights.Count -ne 1) {
	throw "smoke build target preflight JSON did not include exactly one preflight."
}
if (!$preflightParsed.Preflights[0].Checks -or $preflightParsed.Preflights[0].Checks.Count -eq 0) {
	throw "smoke build target preflight JSON did not include checks."
}
