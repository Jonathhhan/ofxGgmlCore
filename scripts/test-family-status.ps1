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
if (@($parsed.NextCommands) -notcontains "scripts\plan-ecosystem.bat -Json") {
	throw "family status JSON NextCommands did not include structured ecosystem planning."
}
if (!$parsed.Addons -or $parsed.Addons.Count -lt 11) {
	throw "family status JSON did not contain the expected addon list."
}
$core = @($parsed.Addons | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
if (!$core -or !$core.CopilotEcosystemInstructions) {
	throw "family status JSON did not report Core Copilot ecosystem instructions."
}
