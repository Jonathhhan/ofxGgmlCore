$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$output = & (Join-Path $scriptRoot "status-family.ps1") *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "family status smoke test failed."
}
$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml family status",
	"ofxGgmlCore",
	"ofxGgmlLlama",
	"ofxGgmlDiffusion",
	"ofxGgmlWorkflows",
	"Validate"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "family status output did not contain expected text: $expected"
	}
}

$json = & (Join-Path $scriptRoot "status-family.ps1") -Json
$parsed = $json | ConvertFrom-Json
if (!$parsed.Summary) {
	throw "family status JSON did not include Summary."
}
foreach ($property in @(
	"Repositories",
	"ManagedRepositories",
	"PresentManagedRepositories",
	"ReadyManagedRepositories",
	"DetectedReferenceRepositories",
	"ClassifiedReferenceRepositories",
	"UnclassifiedDetectedRepositories",
	"DirtyManagedRepositories",
	"MissingManagedRepositories",
	"MissingValidationEntrypoints",
	"MissingDoctorEntrypoints",
	"AgentWorkflowGuideCoverage"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "family status JSON Summary did not include $property."
	}
}
if ($parsed.Summary.ManagedRepositories -lt 11) {
	throw "family status JSON Summary did not count managed repositories."
}
if ($parsed.Summary.ReadyManagedRepositories -lt 10) {
	throw "family status JSON Summary did not count ready managed repositories."
}
if (!$parsed.NextCommands -or @($parsed.NextCommands).Count -eq 0) {
	throw "family status JSON did not include NextCommands."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-ecosystem.bat -Json -SummaryOnly") {
	throw "family status JSON NextCommands did not include compact ecosystem planning."
}
if (@($parsed.NextCommands) -notcontains "scripts\check-ecosystem-readiness.bat -SkipDoctorTests -Json -SummaryOnly") {
	throw "family status JSON NextCommands did not include compact readiness planning."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly") {
	throw "family status JSON NextCommands did not include compact branch cleanup planning."
}
if (!$parsed.RepositorySummaries -or $parsed.RepositorySummaries.Count -lt 11) {
	throw "family status JSON did not contain compact repository summaries."
}
if (!$parsed.Addons -or $parsed.Addons.Count -lt 11) {
	throw "family status JSON did not contain the expected addon list."
}
$core = @($parsed.Addons | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
if (!$core -or !$core.CopilotEcosystemInstructions) {
	throw "family status JSON did not report Core Copilot ecosystem instructions."
}

$summaryJson = & (Join-Path $scriptRoot "status-family.ps1") -Json -SummaryOnly
$summaryParsed = $summaryJson | ConvertFrom-Json
if (!$summaryParsed.SummaryOnly) {
	throw "family status summary JSON did not report SummaryOnly."
}
if (!$summaryParsed.Summary -or !$summaryParsed.RepositorySummaries -or $summaryParsed.RepositorySummaries.Count -lt 11) {
	throw "family status summary JSON did not retain compact summary evidence."
}
if ($summaryParsed.PSObject.Properties["Addons"]) {
	throw "family status summary JSON should omit full Addons inventory."
}
$summaryCore = @($summaryParsed.RepositorySummaries | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
foreach ($property in @("Name", "Known", "Classified", "Present", "Head", "DirtyCount", "ValidateScript", "DoctorScript", "AgentWorkflowGuide")) {
	if (!$summaryCore[0].PSObject.Properties[$property]) {
		throw "family status summary JSON repository summary did not include $property."
	}
}
