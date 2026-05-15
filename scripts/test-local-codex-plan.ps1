$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-local-codex.ps1"
$testId = [guid]::NewGuid().ToString("N")
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-local-codex-$testId"
$configPath = Join-Path $tempRoot "config.toml"
$outputPath = Join-Path $tempRoot "local-codex-plan.md"

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
Set-Content -LiteralPath $configPath -Value @"
[model_providers.local_llama]
name = "local-llama"
base_url = "http://127.0.0.1:9/v1"
wire_api = "responses"

[profiles.ofxggml_local]
model = "local-coder"
model_provider = "local_llama"
"@

try {
	$markdownOutput = & $planScript -ConfigPath $configPath -Endpoint "http://127.0.0.1:9/v1" -SkipDefaultEndpoints *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "plan-local-codex.ps1 failed."
	}
	$markdown = $markdownOutput -join "`n"
	foreach ($expected in @(
		"Local Codex Readiness Plan",
		"llama-server",
		"Readiness state",
		"server-missing",
		"Recommended Actions",
		"Start or repoint the local OpenAI-compatible llama-server endpoint",
		"http://127.0.0.1:9/v1",
		"scripts\plan-local-codex.bat -Json -SummaryOnly"
	)) {
		if ($markdown -notmatch [regex]::Escape($expected)) {
			throw "local Codex plan markdown did not contain expected text: $expected"
		}
	}

	$jsonOutput = & $planScript -ConfigPath $configPath -Endpoint "http://127.0.0.1:9/v1" -SkipDefaultEndpoints -Json *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "plan-local-codex.ps1 -Json failed."
	}
	$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
	foreach ($property in @(
		"ReadinessState",
		"ConfigFilesChecked",
		"ConfigFilesFound",
		"ConfigFilesWithLocalEndpoints",
		"LocalEndpointCandidates",
		"ReachableEndpoints",
		"ModelsReported",
		"EnvKeysDeclared",
		"EnvKeysPresent"
	)) {
		if (!$parsed.Summary.PSObject.Properties[$property]) {
			throw "local Codex plan JSON Summary did not include $property."
		}
	}
	if ($parsed.Summary.ReadinessState -ne "server-missing") {
		throw "local Codex plan did not report server-missing for an unreachable configured endpoint."
	}
	if ($parsed.Summary.ConfigFilesFound -ne 1 -or $parsed.Summary.ConfigFilesWithLocalEndpoints -ne 1) {
		throw "local Codex plan did not detect the test config local endpoint."
	}
	if ($parsed.Summary.EnvKeysDeclared -ne 0) {
		throw "local Codex plan unexpectedly detected env keys for the unauthenticated test config."
	}
	if ($parsed.Summary.ReachableEndpoints -ne 0) {
		throw "local Codex plan unexpectedly reached the closed test endpoint."
	}
	if (!$parsed.Configs -or !$parsed.Endpoints) {
		throw "local Codex full JSON did not include config and endpoint evidence."
	}
	if (!$parsed.RecommendedActions -or @($parsed.RecommendedActions).Count -lt 2) {
		throw "local Codex JSON did not include recommended actions."
	}
	$stateAction = @($parsed.RecommendedActions | Where-Object { $_.State -eq "server-missing" } | Select-Object -First 1)
	if ($stateAction.Count -eq 0 -or $stateAction[0].Command -notmatch [regex]::Escape("scripts\plan-local-codex.bat -Json -SummaryOnly")) {
		throw "local Codex JSON did not include a server-missing action with a rerun command."
	}
	if (@($parsed.NextCommands) -notcontains "scripts\release-candidate.bat") {
		throw "local Codex plan JSON did not include release-candidate follow-up."
	}

	$summaryJsonOutput = & $planScript -ConfigPath $configPath -Endpoint "http://127.0.0.1:9/v1" -SkipDefaultEndpoints -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "plan-local-codex.ps1 -Json -SummaryOnly failed."
	}
	$summaryParsed = ($summaryJsonOutput -join "`n") | ConvertFrom-Json
	if (!$summaryParsed.SummaryOnly) {
		throw "local Codex summary JSON did not report SummaryOnly."
	}
	if ($summaryParsed.PSObject.Properties["Configs"] -or $summaryParsed.PSObject.Properties["Endpoints"]) {
		throw "local Codex summary JSON should omit full config and endpoint evidence."
	}
	if (!$summaryParsed.RecommendedActions -or @($summaryParsed.RecommendedActions).Count -eq 0) {
		throw "local Codex summary JSON should retain recommended actions."
	}

	& $planScript -ConfigPath $configPath -Endpoint "http://127.0.0.1:9/v1" -SkipDefaultEndpoints -OutputPath $outputPath
	if (!$?) {
		throw "plan-local-codex.ps1 -OutputPath failed."
	}
	if (!(Test-Path -LiteralPath $outputPath -PathType Leaf)) {
		throw "local Codex plan was not written: $outputPath"
	}
} finally {
	if (Test-Path -LiteralPath $tempRoot) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}
