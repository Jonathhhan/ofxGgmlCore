$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-doctor-rollout.ps1"

$output = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-doctor-rollout.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml Doctor Rollout Plan",
	"Summary",
	"Recommended Order",
	"Guardrails",
	"ofxGgmlLlama",
	"ofxGgmlWorkflows",
	"Do not operate on classified legacy/reference siblings"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "doctor rollout output did not contain expected text: $expected"
	}
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-doctor-rollout.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Summary) {
	throw "doctor rollout JSON output did not include Summary."
}
foreach ($property in @(
	"ManagedRepositories",
	"CompleteCoverage",
	"IncompleteCoverage",
	"NotApplicable",
	"MissingRepository",
	"MissingDoctor",
	"NeedsWrappers",
	"NeedsTestOrValidationHook",
	"BlockingRepositories"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "doctor rollout JSON Summary did not include $property."
	}
}
if ($parsed.Summary.ManagedRepositories -lt 11) {
	throw "doctor rollout JSON Summary did not count managed repositories."
}
if ($parsed.Summary.IncompleteCoverage -ne 0 -or @($parsed.Summary.BlockingRepositories).Count -ne 0) {
	throw "doctor rollout JSON Summary reported incomplete coverage for the current ecosystem."
}
if (!$parsed.NextCommands -or @($parsed.NextCommands).Count -eq 0) {
	throw "doctor rollout JSON output did not include NextCommands."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-doctor-rollout.bat -Json") {
	throw "doctor rollout JSON NextCommands did not include the structured planner command."
}
if (!$parsed.Repositories -or $parsed.Repositories.Count -lt 11) {
	throw "doctor rollout JSON output did not include managed repositories."
}

$workflows = @($parsed.Repositories | Where-Object { $_.Repository -eq "ofxGgmlWorkflows" } | Select-Object -First 1)
if (!$workflows -or $workflows.Coverage -ne "not-applicable") {
	throw "doctor rollout JSON did not mark ofxGgmlWorkflows as not applicable."
}
