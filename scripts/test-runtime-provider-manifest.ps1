param()

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestScript = Join-Path $scriptRoot "runtime-provider-manifest.ps1"

$textOutput = & $manifestScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "runtime-provider-manifest.ps1 failed."
}
$text = $textOutput -join "`n"
foreach ($expected in @(
	"ofxGgmlCore runtime provider manifest",
	"Ready for companions",
	"ggml include",
	"Backends",
	"Backend readiness",
	"Readiness"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "runtime provider manifest output did not contain expected text: $expected"
	}
}

$jsonOutput = & $manifestScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "runtime-provider-manifest.ps1 -Json failed."
}
$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if ($parsed.SchemaVersion -ne 1) {
	throw "runtime provider manifest JSON did not include SchemaVersion 1."
}
if ($parsed.Provider -ne "ofxGgmlCore") {
	throw "runtime provider manifest JSON did not identify ofxGgmlCore."
}
if ([string]::IsNullOrWhiteSpace([string]$parsed.Ggml.IncludeDir) -or
	[string]::IsNullOrWhiteSpace([string]$parsed.Ggml.LibDir)) {
	throw "runtime provider manifest JSON did not include ggml include/lib dirs."
}
if (!$parsed.Ggml.PSObject.Properties["AceStepOpsReady"]) {
	throw "runtime provider manifest JSON did not include ACE-Step ggml op readiness."
}
if (!$parsed.Ggml.PSObject.Properties["AceStepCol2Im1DReady"]) {
	throw "runtime provider manifest JSON did not include ACE-Step col2im_1d readiness."
}
if (!$parsed.Ggml.PSObject.Properties["AceStepSnakeFusedReady"]) {
	throw "runtime provider manifest JSON did not include ACE-Step fused Snake readiness."
}
if (!$parsed.EnabledBackends.PSObject.Properties["CPU"]) {
	throw "runtime provider manifest JSON did not include CPU backend state."
}
if (!$parsed.BackendReadiness -or $parsed.BackendReadiness.Count -eq 0) {
	throw "runtime provider manifest JSON did not include backend readiness scoring."
}
$cpuReadiness = @($parsed.BackendReadiness | Where-Object { $_.Name -eq "CPU" } | Select-Object -First 1)
if (!$cpuReadiness -or [string]::IsNullOrWhiteSpace([string]$cpuReadiness.State)) {
	throw "runtime provider manifest JSON did not include CPU readiness state."
}
if (!$parsed.Readiness -or $parsed.Readiness.Count -eq 0) {
	throw "runtime provider manifest JSON did not include readiness checks."
}

$summaryOutput = & $manifestScript -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "runtime-provider-manifest.ps1 -Json -SummaryOnly failed."
}
$summary = ($summaryOutput -join "`n") | ConvertFrom-Json
if (!$summary.EnabledBackends.PSObject.Properties["CPU"]) {
	throw "runtime provider summary JSON did not include backend state."
}
if (!$summary.BackendReadiness -or $summary.BackendReadiness.Count -eq 0) {
	throw "runtime provider summary JSON did not include backend readiness scoring."
}
if (!$summary.PSObject.Properties["AceStepOpsReady"]) {
	throw "runtime provider summary JSON did not include ACE-Step ggml op readiness."
}
if (!$summary.PSObject.Properties["AceStepCol2Im1DReady"]) {
	throw "runtime provider summary JSON did not include ACE-Step col2im_1d readiness."
}
if (!$summary.PSObject.Properties["AceStepSnakeFusedReady"]) {
	throw "runtime provider summary JSON did not include ACE-Step fused Snake readiness."
}

Write-Host "==> Runtime provider manifest coverage passed"
