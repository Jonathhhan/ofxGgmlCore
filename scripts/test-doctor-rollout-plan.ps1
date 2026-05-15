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
if (@($parsed.NextCommands) -notcontains "scripts\plan-doctor-rollout.bat -Json -SummaryOnly") {
	throw "doctor rollout JSON NextCommands did not include the compact structured planner command."
}
if (@($parsed.NextCommands) -notcontains "scripts\check-ecosystem-readiness.bat -SkipDoctorTests -Json -SummaryOnly") {
	throw "doctor rollout JSON NextCommands did not include compact readiness planning."
}
if (!$parsed.RepositorySummaries -or $parsed.RepositorySummaries.Count -lt 11) {
	throw "doctor rollout JSON output did not include compact repository summaries."
}
if (!$parsed.Repositories -or $parsed.Repositories.Count -lt 11) {
	throw "doctor rollout JSON output did not include managed repositories."
}

$workflows = @($parsed.Repositories | Where-Object { $_.Repository -eq "ofxGgmlWorkflows" } | Select-Object -First 1)
if (!$workflows -or $workflows.Coverage -ne "not-applicable") {
	throw "doctor rollout JSON did not mark ofxGgmlWorkflows as not applicable."
}

$summaryJsonOutput = & $planScript -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-doctor-rollout.ps1 -Json -SummaryOnly failed."
}

$summaryParsed = ($summaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$summaryParsed.SummaryOnly) {
	throw "doctor rollout summary JSON did not report SummaryOnly."
}
if (!$summaryParsed.Summary -or !$summaryParsed.RepositorySummaries -or $summaryParsed.RepositorySummaries.Count -lt 11) {
	throw "doctor rollout summary JSON did not retain compact summary evidence."
}
if ($summaryParsed.PSObject.Properties["Repositories"]) {
	throw "doctor rollout summary JSON should omit full repository rows."
}
$summaryWorkflows = @($summaryParsed.RepositorySummaries | Where-Object { $_.Repository -eq "ofxGgmlWorkflows" } | Select-Object -First 1)
foreach ($property in @("Repository", "Lane", "Present", "Priority", "Coverage", "ValidateHook", "Action")) {
	if (!$summaryWorkflows[0].PSObject.Properties[$property]) {
		throw "doctor rollout summary JSON repository summary did not include $property."
	}
}
