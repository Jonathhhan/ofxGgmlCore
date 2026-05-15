$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-ecosystem.ps1"

$output = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-ecosystem.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml Ecosystem Agent Plan",
	"Snapshot",
	"classified legacy/reference siblings",
	"Agent Guardrails",
	"Do not edit addon source",
	"plan-coding-agent-work.bat",
	"plan-doctor-rollout.bat",
	"plan-agent-branch-cleanup.bat -Json -SummaryOnly",
	"Smoke-Build Target Lifecycle",
	"select-smoke-build-target.bat",
	"check-smoke-build-target-preflight.bat",
	"check-smoke-build-target-postflight.bat"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "ecosystem agent plan output did not contain expected text: $expected"
	}
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-ecosystem.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Addons -or $parsed.Addons.Count -eq 0) {
	throw "ecosystem agent JSON output did not include addons."
}
foreach ($property in @("Summary", "PlanningPriorities", "AgentGuardrails", "SmokeBuildLifecycle", "SuggestedValidation")) {
	if (!$parsed.PSObject.Properties[$property]) {
		throw "ecosystem agent JSON output did not include $property."
	}
}
foreach ($property in @(
	"ManagedRepositories",
	"PresentManagedRepositories",
	"ReadyManagedRepositories",
	"DetectedReferenceRepositories",
	"ClassifiedReferenceRepositories",
	"UnclassifiedDetectedRepositories",
	"DirtyManagedRepositories",
	"MissingManagedRepositories",
	"MissingValidationEntrypoints",
	"MissingDoctorEntrypoints"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "ecosystem agent JSON summary did not include $property."
	}
}
if (@($parsed.PlanningPriorities).Count -eq 0) {
	throw "ecosystem agent JSON output did not include planning priorities."
}
if (@($parsed.AgentGuardrails) -notcontains "Do not edit addon source unless the user explicitly asks for addon behavior.") {
	throw "ecosystem agent JSON output did not include the source-edit guardrail."
}
if (@($parsed.SmokeBuildLifecycle) -notcontains "scripts\check-smoke-build-target-preflight.bat -Stage generate-project") {
	throw "ecosystem agent JSON output did not include the smoke-build preflight command."
}
if (@($parsed.SuggestedValidation) -notcontains "scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly") {
	throw "ecosystem agent JSON output did not include the branch cleanup validation command."
}
if ($jsonOutput -join "`n" -notmatch '"PlanningPriorities":\s+\[') {
	throw "ecosystem agent JSON output did not preserve PlanningPriorities as an array."
}
