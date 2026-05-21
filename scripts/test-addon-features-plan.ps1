$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-addon-features.ps1"

$output = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-addon-features.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml Addon Feature Plan",
	"Feature metadata coverage",
	"README feature coverage",
	"Recommended README Order",
	"ofxGgmlCore",
	"ofxGgmlLlama",
	"Leave classified reference repositories out of managed feature rollout"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "addon feature plan output did not contain expected text: $expected"
	}
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-addon-features.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Summary) {
	throw "addon feature plan JSON did not include Summary."
}
foreach ($property in @(
	"ManagedRepositories",
	"FeatureApplicableRepositories",
	"FeatureMetadataCoverage",
	"ReadmeFeatureCoverage",
	"MetadataOnlyRepositories",
	"MissingMetadataRepositories",
	"RecommendedReadmeOrder"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "addon feature plan Summary did not include $property."
	}
}
if ($parsed.Summary.FeatureApplicableRepositories -lt 9) {
	throw "addon feature plan did not count feature-applicable repositories."
}
if ($parsed.Summary.FeatureMetadataCoverage -lt 9) {
	throw "addon feature plan did not count metadata coverage."
}
if (!$parsed.RepositorySummaries -or @($parsed.RepositorySummaries).Count -lt 10) {
	throw "addon feature plan JSON did not include compact repository summaries."
}
if (!$parsed.Repositories -or @($parsed.Repositories).Count -lt 10) {
	throw "addon feature plan JSON did not include repository details."
}
$core = @($parsed.Repositories | Where-Object { $_.Repository -eq "ofxGgmlCore" } | Select-Object -First 1)
if (!$core -or @($core.Features).Count -lt 1) {
	throw "addon feature plan JSON did not expose Core feature details."
}
$workflows = @($parsed.Repositories | Where-Object { $_.Repository -eq "ofxGgmlWorkflows" } | Select-Object -First 1)
if (!$workflows -or $workflows.State -ne "not-applicable") {
	throw "addon feature plan JSON did not mark ofxGgmlWorkflows as not applicable."
}

$summaryJsonOutput = & $planScript -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-addon-features.ps1 -Json -SummaryOnly failed."
}

$summaryParsed = ($summaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$summaryParsed.SummaryOnly) {
	throw "addon feature plan summary JSON did not report SummaryOnly."
}
if (!$summaryParsed.Summary -or !$summaryParsed.RepositorySummaries -or @($summaryParsed.RepositorySummaries).Count -lt 10) {
	throw "addon feature plan summary JSON did not retain compact summary evidence."
}
if ($summaryParsed.PSObject.Properties["Repositories"]) {
	throw "addon feature plan summary JSON should omit full repository rows."
}
$summaryCore = @($summaryParsed.RepositorySummaries | Where-Object { $_.Repository -eq "ofxGgmlCore" } | Select-Object -First 1)
foreach ($property in @("Repository", "Lane", "Priority", "State", "FeatureCount", "ReadmeFeatures", "Action")) {
	if (!$summaryCore[0].PSObject.Properties[$property]) {
		throw "addon feature plan repository summary did not include $property."
	}
}

Write-Host "Addon feature planning coverage passed"
