$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-backend-runtime-verification.ps1"
$testId = [guid]::NewGuid().ToString("N")
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-runtime-verification-plan-$testId.md"

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
	"RepositoriesWithModels",
	"RepositoriesWithBuiltExamples",
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
if (!$parsed.Repositories -or @($parsed.Repositories).Count -eq 0) {
	throw "backend runtime verification full JSON did not include repositories."
}
$sam = @($parsed.RepositorySummaries | Where-Object { $_.Repository -eq "ofxGgmlSam" } | Select-Object -First 1)
if ($sam.Count -eq 0 -or !$sam.CudaDeclared -or $sam.GateState -ne "runtime-smoke-entrypoint-present") {
	throw "backend runtime verification JSON did not expose SAM CUDA runtime-smoke readiness."
}
if ($sam.RuntimeSmokeEvidence -ne "available-and-validated") {
	throw "backend runtime verification JSON did not expose validated SAM runtime smoke evidence."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-release-readiness.bat -Json -SummaryOnly") {
	throw "backend runtime verification JSON did not include release-readiness follow-up."
}
if (@($parsed.NextCommands) -notcontains "cd ..\ofxGgmlSam && scripts\run-sam3-runtime-smoke.bat -DryRun") {
	throw "backend runtime verification JSON did not include the SAM3 runtime smoke follow-up."
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
