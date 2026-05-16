$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-backend-runtime-verification.ps1"
$addonRoot = Split-Path -Parent $scriptRoot
$addonsRoot = Split-Path -Parent $addonRoot
$testId = [guid]::NewGuid().ToString("N")
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-runtime-verification-plan-$testId.md"

function Assert-InferenceSmokeReportMetadata {
	param(
		[string]$Repository,
		[string]$ExpectedReportFile
	)

	$metaPath = Join-Path $addonsRoot "$Repository\\ofxggml-addon.json"
	$metadata = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
	if (!$metadata.inferenceSmokeReport) {
		throw "$Repository metadata is missing inferenceSmokeReport."
	}
	if ([string]::IsNullOrWhiteSpace([string]$metadata.inferenceSmokeReport)) {
		throw "$Repository inferenceSmokeReport metadata value is blank."
	}
	if (![string]::IsNullOrWhiteSpace($ExpectedReportFile) -and [string]$metadata.inferenceSmokeReport -ne $ExpectedReportFile) {
		throw "$Repository inferenceSmokeReport metadata does not match expected value '$ExpectedReportFile'."
	}
}

if (Test-Path -LiteralPath $outputPath) {
	Remove-Item -LiteralPath $outputPath -Force
}

$markdownOutput = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-backend-runtime-verification.ps1 failed."
}
$markdown = $markdownOutput -join "`n"
foreach ($expected in @(
	"Backend Runtime Verification Plan",
	'Reference target: `ofxGgmlSam`',
	"ofxGgmlSam",
	"runtime-smoke-entrypoint-present",
	"Core runtime-smoke seeded",
	"Validated runtime-smoke entrypoints",
	"scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly"
)) {
	if ($markdown -notmatch [regex]::Escape($expected)) {
		throw "backend runtime verification markdown did not contain expected text: $expected"
	}
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-backend-runtime-verification.ps1 -Json failed."
}
$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Summary) {
	throw "backend runtime verification JSON did not include Summary."
}
foreach ($property in @(
	"ManagedRepositories",
	"RuntimeApplicableRepositories",
	"CoreRuntimeSmokeSeeded",
	"ReferenceLaneReady",
	"RuntimeSmokeEntrypoints",
	"ValidatedRuntimeSmokeEntrypoints",
	"InferenceSmokeEntrypoints",
	"InferenceCheckedRepositories",
	"RepositoriesWithModels",
	"RepositoriesWithBuiltExamples",
	"ExampleBuildEvidenceGaps",
	"ExampleBuildGapsCoveredByInference",
	"ExampleBuildGaps",
	"RepositoriesMissingBuiltExamples",
	"NeedsRuntimeSmokePlan",
	"ReferenceTarget"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "backend runtime verification JSON Summary did not include $property."
	}
}
if ($parsed.Summary.ReferenceTarget -ne "ofxGgmlSam") {
	throw "backend runtime verification JSON did not prioritize ofxGgmlSam."
}
if ($parsed.Summary.ValidatedRuntimeSmokeEntrypoints -lt 1) {
	throw "backend runtime verification JSON did not count validated runtime-smoke entrypoints."
}
if ($parsed.Summary.InferenceSmokeEntrypoints -lt 0 -or $parsed.Summary.InferenceCheckedRepositories -lt 0) {
	throw "backend runtime verification JSON reported negative inference-smoke counts."
}
if ($parsed.Summary.ExampleBuildGaps -lt 0) {
	throw "backend runtime verification JSON reported a negative example build gap count."
}
if ($parsed.Summary.ExampleBuildEvidenceGaps -lt $parsed.Summary.ExampleBuildGaps) {
	throw "backend runtime verification JSON reported more actionable build gaps than total evidence gaps."
}
if ($parsed.Summary.ExampleBuildGapsCoveredByInference -lt 0) {
	throw "backend runtime verification JSON reported a negative inference-covered build gap count."
}
if ($parsed.Summary.ExampleBuildGaps -gt 0 -and @($parsed.Summary.RepositoriesMissingBuiltExamples).Count -lt 1) {
	throw "backend runtime verification JSON did not expose repositories for example build evidence gaps."
}
if ($parsed.Summary.ExampleBuildGaps -eq 0 -and @($parsed.Summary.RepositoriesMissingBuiltExamples).Count -ne 0) {
	throw "backend runtime verification JSON reported missing example builds despite zero gap count."
}
if (!$parsed.Repositories -or @($parsed.Repositories).Count -eq 0) {
	throw "backend runtime verification full JSON did not include repositories."
}
$samRows = @($parsed.RepositorySummaries | Where-Object { $_.Repository -eq "ofxGgmlSam" } | Select-Object -First 1)
if ($samRows.Count -eq 0) {
	throw "backend runtime verification JSON did not include SAM repository summary."
}
$sam = $samRows[0]
if (!$sam.CudaDeclared -or $sam.GateState -notin @("runtime-smoke-entrypoint-present", "inference-checked")) {
	throw "backend runtime verification JSON did not expose SAM CUDA runtime-smoke readiness."
}
if ($sam.RuntimeSmokeEvidence -ne "available-and-validated") {
	throw "backend runtime verification JSON did not expose validated SAM runtime smoke evidence."
}
if (!$sam.PSObject.Properties["InferenceSmokeEvidence"]) {
	throw "backend runtime verification JSON did not expose SAM inference smoke evidence."
}
if ($sam.InferenceSmokeEvidence -notin @("inference-checked", "inference-smoke-entrypoint-validated", "inference-smoke-entrypoint-present", "inference-smoke-stale", "missing")) {
	throw "backend runtime verification JSON reported an unexpected SAM inference smoke state."
}
Assert-InferenceSmokeReportMetadata -Repository "ofxGgmlSam" -ExpectedReportFile ".sam3-runtime-smoke.json"
$llamaRows = @($parsed.RepositorySummaries | Where-Object { $_.Repository -eq "ofxGgmlLlama" } | Select-Object -First 1)
if ($llamaRows.Count -eq 0) {
	throw "backend runtime verification JSON did not include Llama repository summary."
}
$llama = $llamaRows[0]
if (!$llama.PSObject.Properties["InferenceSmokeEvidence"]) {
	throw "backend runtime verification JSON did not expose Llama inference smoke evidence."
}
if ($llama.InferenceSmokeEvidence -notin @("inference-checked", "inference-smoke-entrypoint-validated", "inference-smoke-entrypoint-present", "inference-smoke-stale", "missing")) {
	throw "backend runtime verification JSON reported an unexpected Llama inference smoke state."
}
Assert-InferenceSmokeReportMetadata -Repository "ofxGgmlLlama" -ExpectedReportFile ".llama-runtime-smoke.json"
$audioRows = @($parsed.RepositorySummaries | Where-Object { $_.Repository -eq "ofxGgmlAudio" } | Select-Object -First 1)
if ($audioRows.Count -eq 0) {
	throw "backend runtime verification JSON did not include Audio repository summary."
}
$audio = $audioRows[0]
if (!$audio.PSObject.Properties["InferenceSmokeEvidence"]) {
	throw "backend runtime verification JSON did not expose Audio inference smoke evidence."
}
if ($audio.InferenceSmokeEvidence -notin @("inference-checked", "inference-smoke-entrypoint-validated", "inference-smoke-entrypoint-present", "inference-smoke-stale", "missing")) {
	throw "backend runtime verification JSON reported an unexpected Audio inference smoke state."
}
if ($audio.InferenceSmokeEvidence -eq "inference-checked" -and @($parsed.Summary.RepositoriesMissingBuiltExamples) -contains "ofxGgmlAudio") {
	throw "backend runtime verification JSON treated Audio's missing generated example binary as actionable despite inference evidence."
}
Assert-InferenceSmokeReportMetadata -Repository "ofxGgmlAudio" -ExpectedReportFile ".audio-runtime-smoke.json"
$agentsRows = @($parsed.RepositorySummaries | Where-Object { $_.Repository -eq "ofxGgmlAgents" } | Select-Object -First 1)
if ($agentsRows.Count -eq 0) {
	throw "backend runtime verification JSON did not include Agents repository summary."
}
$agents = $agentsRows[0]
if (!$agents.PSObject.Properties["InferenceSmokeEvidence"]) {
	throw "backend runtime verification JSON did not expose Agents inference smoke evidence."
}
if ($agents.InferenceSmokeEvidence -notin @("inference-checked", "inference-smoke-entrypoint-validated", "inference-smoke-entrypoint-present", "inference-smoke-stale", "missing")) {
	throw "backend runtime verification JSON reported an unexpected Agents inference smoke state."
}
Assert-InferenceSmokeReportMetadata -Repository "ofxGgmlAgents" -ExpectedReportFile ".agents-runtime-smoke.json"
if (@($parsed.NextCommands) -notcontains "scripts\plan-release-readiness.bat -Json -SummaryOnly") {
	throw "backend runtime verification JSON did not include release-readiness follow-up."
}
if (@($parsed.NextCommands) -notcontains "cd ..\ofxGgmlLlama && scripts\run-llama-runtime-smoke.bat -Backend cpu -Json -SummaryOnly -OutputPath .llama-runtime-smoke.json") {
	throw "backend runtime verification JSON did not include the Llama inference smoke evidence command."
}
if (@($parsed.NextCommands) -notcontains "cd ..\ofxGgmlSam && scripts\run-sam3-runtime-smoke.bat -DryRun") {
	throw "backend runtime verification JSON did not include the SAM3 runtime smoke follow-up."
}
if (@($parsed.NextCommands) -notcontains "cd ..\ofxGgmlSam && scripts\run-sam3-runtime-smoke.bat -Backend cuda -Json -SummaryOnly -OutputPath .sam3-runtime-smoke.json") {
	throw "backend runtime verification JSON did not include the SAM3 inference smoke evidence command."
}
if (@($parsed.NextCommands) -notcontains "cd ..\ofxGgmlAudio && scripts\run-audio-runtime-smoke.bat -Mode simple -Json -SummaryOnly -OutputPath .audio-runtime-smoke.json") {
	throw "backend runtime verification JSON did not include the Audio inference smoke evidence command."
}
if (@($parsed.NextCommands) -notcontains "cd ..\ofxGgmlAgents && scripts\run-agents-runtime-smoke.bat -Json -SummaryOnly -OutputPath .agents-runtime-smoke.json") {
	throw "backend runtime verification JSON did not include the Agents inference smoke evidence command."
}

$summaryJsonOutput = & $planScript -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-backend-runtime-verification.ps1 -Json -SummaryOnly failed."
}
$summaryParsed = ($summaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$summaryParsed.SummaryOnly) {
	throw "backend runtime verification summary JSON did not report SummaryOnly."
}
if (!$summaryParsed.RepositorySummaries -or @($summaryParsed.RepositorySummaries).Count -eq 0) {
	throw "backend runtime verification summary JSON did not include compact repository summaries."
}
if ($summaryParsed.PSObject.Properties["Repositories"]) {
	throw "backend runtime verification summary JSON should omit full repositories."
}

& $planScript -OutputPath $outputPath
if (!$?) {
	throw "plan-backend-runtime-verification.ps1 -OutputPath failed."
}
if (!(Test-Path -LiteralPath $outputPath -PathType Leaf)) {
	throw "backend runtime verification plan was not written: $outputPath"
}

Remove-Item -LiteralPath $outputPath -Force
