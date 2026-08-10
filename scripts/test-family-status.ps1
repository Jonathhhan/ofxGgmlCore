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
	"ManagedGitStatusUnavailableRepositories",
	"MissingManagedRepositories",
	"MissingValidationEntrypoints",
	"MissingDoctorEntrypoints",
	"AgentWorkflowGuideCoverage",
	"FeatureMetadataCoverage"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "family status JSON Summary did not include $property."
	}
}
if ($parsed.Summary.ManagedRepositories -lt 10) {
	throw "family status JSON Summary did not count managed repositories."
}
if ($parsed.Summary.ReadyManagedRepositories -lt 10) {
	throw "family status JSON Summary did not count ready managed repositories."
}
if ($parsed.Summary.FeatureMetadataCoverage -lt 9) {
	throw "family status JSON Summary did not count managed addon feature metadata."
}
if (!$parsed.NextCommands -or @($parsed.NextCommands).Count -eq 0) {
	throw "family status JSON did not include NextCommands."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-ecosystem.bat -Json -SummaryOnly") {
	throw "family status JSON NextCommands did not include compact ecosystem planning."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-addon-features.bat -Json -SummaryOnly") {
	throw "family status JSON NextCommands did not include compact addon feature planning."
}
if (@($parsed.NextCommands) -notcontains "scripts\audit-ecosystem.bat -Strict -Json -SummaryOnly") {
	throw "family status JSON NextCommands did not include compact strict ecosystem audit."
}
if (@($parsed.NextCommands) -notcontains "scripts\check-ecosystem-readiness.bat -SkipDoctorTests -Json -SummaryOnly") {
	throw "family status JSON NextCommands did not include compact readiness planning."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly") {
	throw "family status JSON NextCommands did not include compact branch cleanup planning."
}
if (!$parsed.RepositorySummaries -or $parsed.RepositorySummaries.Count -lt 10) {
	throw "family status JSON did not contain compact repository summaries."
}
if (!$parsed.Addons -or $parsed.Addons.Count -lt 10) {
	throw "family status JSON did not contain the expected addon list."
}
$core = @($parsed.Addons | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
if (!$core -or !$core.CopilotEcosystemInstructions) {
	throw "family status JSON did not report Core Copilot ecosystem instructions."
}
if ($core.RuntimeProviderMode -ne "core-ggml-provider") {
	throw "family status JSON did not report Core runtime provider mode."
}
foreach ($addon in @($parsed.Addons | Where-Object { $_.Present })) {
	foreach ($example in @($addon.Examples)) {
		$examplePath = Join-Path ([string]$addon.Path) ([string]$example)
		$sourceRoot = Join-Path $examplePath "src"
		$sourceFile = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -ErrorAction SilentlyContinue |
			Where-Object { $_.Extension -in @(".h", ".hpp", ".c", ".cc", ".cpp", ".mm") } |
			Select-Object -First 1
		if (!(Test-Path -LiteralPath (Join-Path $examplePath "addons.make") -PathType Leaf) -and $null -eq $sourceFile) {
			throw "family status reported an example without addons.make or source files: $($addon.Name)/$example"
		}
	}
}
$stableDiffusion = @($parsed.Addons | Where-Object { $_.Name -eq "ofxGgmlStableDiffusion" } | Select-Object -First 1)
if (!$stableDiffusion -or [string]::IsNullOrWhiteSpace([string]$stableDiffusion.RuntimeProviderMode)) {
	throw "family status JSON did not report Stable Diffusion runtime provider mode."
}

$summaryJson = & (Join-Path $scriptRoot "status-family.ps1") -Json -SummaryOnly
$summaryParsed = $summaryJson | ConvertFrom-Json
if (!$summaryParsed.SummaryOnly) {
	throw "family status summary JSON did not report SummaryOnly."
}
if (!$summaryParsed.Summary -or !$summaryParsed.RepositorySummaries -or $summaryParsed.RepositorySummaries.Count -lt 10) {
	throw "family status summary JSON did not retain compact summary evidence."
}
if ($summaryParsed.PSObject.Properties["Addons"]) {
	throw "family status summary JSON should omit full Addons inventory."
}
$summaryCore = @($summaryParsed.RepositorySummaries | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
foreach ($property in @("Name", "Known", "Classified", "Present", "GitStatusAvailable", "Head", "DirtyCount", "ValidateScript", "DoctorScript", "AgentWorkflowGuide", "RuntimeProviderMode", "FeatureCount")) {
	if (!$summaryCore[0].PSObject.Properties[$property]) {
		throw "family status summary JSON repository summary did not include $property."
	}
}
