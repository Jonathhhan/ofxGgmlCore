$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-local-codex.ps1"
$testId = [guid]::NewGuid().ToString("N")
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-local-codex-$testId"
$configPath = Join-Path $tempRoot "config.toml"
$agentRoot = Join-Path $tempRoot "agents"
$agentPath = Join-Path $agentRoot "worker.toml"
$developerAgentPath = Join-Path $agentRoot "developer.toml"
$staleAgentPath = Join-Path $agentRoot "stale.toml"
$outputPath = Join-Path $tempRoot "local-codex-plan.md"
$previousCodexHome = $env:CODEX_HOME

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
New-Item -ItemType Directory -Path $agentRoot -Force | Out-Null
Set-Content -LiteralPath $configPath -Value @"
[model_providers.local_llama]
name = "local-llama"
base_url = "http://127.0.0.1:9/v1"
wire_api = "responses"

[profiles.ofxggml_local]
model = "local-coder"
model_provider = "local_llama"
"@
Set-Content -LiteralPath $agentPath -Value @"
name = "worker"
description = "Execution-focused local worker using llama.cpp."
model = "local-agent-coder"
model_provider = "local_llama"
model_reasoning_effort = "medium"
developer_instructions = """
Keep edits scoped.
"""
"@
Set-Content -LiteralPath $developerAgentPath -Value @"
name = "developer"
description = "Developer subagent for implementation/status work."
model = "local-developer-coder"
model_provider = "local_llama"
model_reasoning_effort = "high"
developer_instructions = """
Report implementation status and keep edits scoped.
"""
"@
Set-Content -LiteralPath $staleAgentPath -Value @"
name = "stale"
model = "stale-local-coder"
reasoning_effort = "medium"
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
		"Llama-Owned Evidence",
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
		"AgentConfigFilesFound",
		"LocalEndpointCandidates",
		"ReachableEndpoints",
		"ModelsReported",
		"ConfigModelsDeclared",
		"ConfigModelProvidersDeclared",
		"ConfigReasoningEffortsDeclared",
		"AgentInstructionSignalsDeclared",
		"AgentConfigsMissingRequiredFields",
		"EnvKeysDeclared",
		"EnvKeysPresent",
		"LlamaCodexModelSource",
		"LlamaCodexPlanEntrypoint",
		"LlamaCodexSmokeEntrypoint",
		"LlamaCodexPlanInvoked",
		"LlamaCodexPlanSucceeded",
		"LlamaCodexPlanReady",
		"LlamaLocalServerInspection",
		"LlamaServedModelsReported",
		"LlamaLocalServerProcesses",
		"LlamaModelAliasMismatchCount"
	)) {
		if (!$parsed.Summary.PSObject.Properties[$property]) {
			throw "local Codex plan JSON Summary did not include $property."
		}
	}
	if (!$parsed.LlamaCodex -or !$parsed.LlamaCodex.PSObject.Properties["CodexLocalSmoke"]) {
		throw "local Codex plan JSON did not include Llama-owned Codex smoke metadata."
	}
	if (!$parsed.LlamaCodexPlanEvidence -or !$parsed.LlamaCodexPlanEvidence.PSObject.Properties["ServedModels"] -or !$parsed.LlamaCodexPlanEvidence.PSObject.Properties["LocalLlamaServer"]) {
		throw "local Codex plan JSON did not include Llama-owned served-model and local-server evidence."
	}
	if ($parsed.LlamaCodex.CodexLocalPlanPresent -and !$parsed.Summary.LlamaCodexPlanInvoked) {
		throw "local Codex plan did not invoke the Llama-owned planner despite the entrypoint being present."
	}
	if (@($parsed.NextCommands | Where-Object { $_ -match "ofxGgmlLlama.*test-local-codex" }).Count -eq 0) {
		throw "local Codex plan JSON did not include the Llama-owned Codex smoke follow-up command."
	}
	if ($parsed.Summary.ReadinessState -ne "server-missing") {
		throw "local Codex plan did not report server-missing for an unreachable configured endpoint."
	}
	if ($parsed.Summary.ConfigFilesFound -ne 1 -or $parsed.Summary.ConfigFilesWithLocalEndpoints -ne 1) {
		throw "local Codex plan did not detect the test config local endpoint."
	}
	if ($parsed.Summary.AgentConfigFilesFound -ne 0) {
		throw "local Codex plan unexpectedly counted a provider config as an agent config."
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
	if (!$summaryParsed.LlamaCodexPlanEvidence) {
		throw "local Codex summary JSON should retain Llama-owned planner evidence."
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

	$agentJsonOutput = & $planScript -ConfigPath $agentPath -Endpoint "http://127.0.0.1:9/v1" -SkipDefaultEndpoints -Json *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "plan-local-codex.ps1 agent config check failed."
	}
	$agentParsed = ($agentJsonOutput -join "`n") | ConvertFrom-Json
	if ($agentParsed.Summary.AgentConfigFilesFound -ne 1) {
		throw "local Codex plan did not count the agent TOML file."
	}
	if ($agentParsed.Summary.ConfigFilesFound -ne 1) {
		throw "local Codex plan should still report the existing agent TOML as a checked config file."
	}
	if ($agentParsed.Summary.ConfigFilesWithLocalEndpoints -ne 0) {
		throw "local Codex plan should not require local endpoints inside agent TOML files."
	}
	if ($agentParsed.Summary.ConfigModelsDeclared -ne 1 -or $agentParsed.Summary.ConfigModelProvidersDeclared -ne 1) {
		throw "local Codex plan did not read model and model_provider from the agent TOML file."
	}
	if ($agentParsed.Summary.ConfigReasoningEffortsDeclared -ne 1 -or $agentParsed.Summary.AgentInstructionSignalsDeclared -ne 1) {
		throw "local Codex plan did not read reasoning or instruction fields from the agent TOML file."
	}
	$agentConfig = @($agentParsed.Configs | Select-Object -First 1)
	if ($agentConfig.Count -eq 0 -or !$agentConfig[0].IsAgentConfig -or $agentConfig[0].Kind -ne "agent") {
		throw "local Codex plan did not classify the TOML file as an agent config."
	}
	if (@($agentParsed.Configs[0].ConfiguredModels) -notcontains "local-agent-coder") {
		throw "local Codex plan did not preserve the agent TOML model declaration."
	}
	if (@($agentParsed.Configs[0].ConfiguredModelProviders) -notcontains "local_llama") {
		throw "local Codex plan did not preserve the agent TOML provider declaration."
	}
	if (@($agentParsed.Configs[0].ConfiguredReasoningEfforts) -notcontains "medium") {
		throw "local Codex plan did not preserve the agent TOML reasoning declaration."
	}
	if (@($agentParsed.Configs[0].InstructionSignals) -notcontains "developer_instructions") {
		throw "local Codex plan did not preserve the agent TOML instruction signal."
	}
	if ($agentParsed.Summary.AgentConfigsMissingRequiredFields -ne 0) {
		throw "local Codex plan incorrectly marked a schema-valid agent TOML as missing required fields."
	}
	if ($agentParsed.LlamaCodexPlanEvidence.ModelSource -ne "codex-agent-config" -and $agentParsed.LlamaCodexPlanEvidence.ModelSource -ne "") {
		throw "local Codex plan did not source the Llama planner model from agent TOML when available."
	}

	$env:CODEX_HOME = $tempRoot
	$defaultAgentJsonOutput = & $planScript -Endpoint "http://127.0.0.1:9/v1" -SkipDefaultEndpoints -Json *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "plan-local-codex.ps1 default agent discovery check failed."
	}
	$defaultAgentParsed = ($defaultAgentJsonOutput -join "`n") | ConvertFrom-Json
	if ($defaultAgentParsed.Summary.AgentConfigFilesFound -lt 2) {
		throw "local Codex plan did not discover all agent TOML files under CODEX_HOME agents."
	}
	if ($defaultAgentParsed.Summary.ConfigFilesFound -lt 3) {
		throw "local Codex plan did not discover config.toml plus agent TOML files under CODEX_HOME."
	}
	if (@($defaultAgentParsed.Configs | Where-Object { $_.Path -eq $developerAgentPath -and $_.Kind -eq "agent" }).Count -ne 1) {
		throw "local Codex plan did not classify arbitrary developer.toml as an agent config."
	}
	if ($defaultAgentParsed.Summary.ConfigReasoningEffortsDeclared -lt 2 -or $defaultAgentParsed.Summary.AgentInstructionSignalsDeclared -lt 2) {
		throw "local Codex plan did not count reasoning and instruction fields across discovered agent TOML files."
	}
	if (@($defaultAgentParsed.Configs | Where-Object { @($_.ConfiguredModels) -contains "local-developer-coder" }).Count -ne 1) {
		throw "local Codex plan did not preserve the arbitrary developer TOML model declaration."
	}
	if ($defaultAgentParsed.Summary.AgentConfigsMissingRequiredFields -ne 1) {
		throw "local Codex plan did not count the stale agent TOML with missing required fields."
	}
	$staleConfig = @($defaultAgentParsed.Configs | Where-Object { $_.Path -eq $staleAgentPath } | Select-Object -First 1)
	if ($staleConfig.Count -ne 1 -or @($staleConfig[0].MissingRequiredAgentFields) -notcontains "description" -or @($staleConfig[0].MissingRequiredAgentFields) -notcontains "developer_instructions") {
		throw "local Codex plan did not report the stale agent TOML missing description and developer_instructions."
	}

	$missingConfigPath = Join-Path $tempRoot "missing-config.toml"
	$defaultJsonOutput = & $planScript -ConfigPath $missingConfigPath -Json *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "plan-local-codex.ps1 default endpoint check failed."
	}
	$defaultParsed = ($defaultJsonOutput -join "`n") | ConvertFrom-Json
	if ($defaultParsed.Summary.LocalEndpointCandidates -lt 3) {
		throw "local Codex plan did not include default localhost endpoint candidates."
	}
	$firstDefaultEndpoint = @($defaultParsed.Endpoints | Select-Object -First 1)
	if ($firstDefaultEndpoint.Count -eq 0 -or $firstDefaultEndpoint[0].BaseUrl -ne "http://127.0.0.1:8001/v1") {
		throw "local Codex plan did not prefer the Llama-owned 8001 endpoint."
	}
} finally {
	$env:CODEX_HOME = $previousCodexHome
	if (Test-Path -LiteralPath $tempRoot) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}
