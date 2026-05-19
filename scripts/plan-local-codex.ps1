param(
	[string[]]$ConfigPath = @(),
	[string[]]$Endpoint = @(),
	[string]$OutputPath = "",
	[switch]$SkipDefaultEndpoints,
	[switch]$SummaryOnly,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-UniqueFullPath {
	param([string[]]$Paths)

	$seen = @{}
	$items = New-Object System.Collections.Generic.List[string]
	foreach ($path in @($Paths)) {
		if ([string]::IsNullOrWhiteSpace($path)) {
			continue
		}
		$expanded = [Environment]::ExpandEnvironmentVariables($path)
		try {
			$fullPath = [System.IO.Path]::GetFullPath($expanded)
		} catch {
			continue
		}
		$key = $fullPath.ToLowerInvariant()
		if ($seen.ContainsKey($key)) {
			continue
		}
		$seen[$key] = $true
		$items.Add($fullPath)
	}

	return @($items.ToArray())
}

function Add-CodexConfigCandidates {
	param(
		[System.Collections.Generic.List[string]]$Candidates,
		[string]$CodexRoot
	)

	if ([string]::IsNullOrWhiteSpace($CodexRoot)) {
		return
	}

	$Candidates.Add((Join-Path $CodexRoot "config.toml"))
	$agentRoot = Join-Path $CodexRoot "agents"
	if (Test-Path -LiteralPath $agentRoot -PathType Container) {
		foreach ($agentConfig in @(Get-ChildItem -LiteralPath $agentRoot -Filter "*.toml" -File)) {
			$Candidates.Add($agentConfig.FullName)
		}
	} else {
		$Candidates.Add((Join-Path $agentRoot "explorer.toml"))
		$Candidates.Add((Join-Path $agentRoot "worker.toml"))
	}
}

function Get-DefaultCodexConfigPaths {
	param([string]$ProjectRoot = "")

	$candidates = New-Object System.Collections.Generic.List[string]
	if (![string]::IsNullOrWhiteSpace($ProjectRoot)) {
		Add-CodexConfigCandidates -Candidates $candidates -CodexRoot (Join-Path $ProjectRoot ".codex")
	}
	if (![string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
		Add-CodexConfigCandidates -Candidates $candidates -CodexRoot $env:CODEX_HOME
	}
	if (![string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
		Add-CodexConfigCandidates -Candidates $candidates -CodexRoot (Join-Path $env:USERPROFILE ".codex")
	}
	if (![string]::IsNullOrWhiteSpace($HOME)) {
		Add-CodexConfigCandidates -Candidates $candidates -CodexRoot (Join-Path $HOME ".codex")
	}
	return Get-UniqueFullPath -Paths @($candidates.ToArray())
}

function Get-LocalEndpointMatches {
	param([string]$Content)

	$matches = [regex]::Matches($Content, 'base_url\s*=\s*"([^"]+)"')
	$endpoints = New-Object System.Collections.Generic.List[string]
	foreach ($match in @($matches)) {
		$value = $match.Groups[1].Value.Trim()
		if ($value -match '^https?://(127\.0\.0\.1|localhost|\[::1\]|::1)(:\d+)?(/.*)?$') {
			$endpoints.Add($value.TrimEnd("/"))
		}
	}
	return @($endpoints.ToArray())
}

function Get-EnvKeyMatches {
	param([string]$Content)

	$matches = [regex]::Matches($Content, 'env_key\s*=\s*"([^"]+)"')
	$keys = New-Object System.Collections.Generic.List[string]
	foreach ($match in @($matches)) {
		$value = $match.Groups[1].Value.Trim()
		if (![string]::IsNullOrWhiteSpace($value)) {
			$keys.Add($value)
		}
	}
	return @($keys.ToArray() | Select-Object -Unique)
}

function Get-ConfiguredModelMatches {
	param([string]$Content)

	$matches = [regex]::Matches($Content, '(?m)^\s*model\s*=\s*"([^"]+)"')
	$models = New-Object System.Collections.Generic.List[string]
	foreach ($match in @($matches)) {
		$value = $match.Groups[1].Value.Trim()
		if (![string]::IsNullOrWhiteSpace($value)) {
			$models.Add($value)
		}
	}
	return @($models.ToArray() | Select-Object -Unique)
}

function Get-ConfiguredModelProviderMatches {
	param([string]$Content)

	$matches = [regex]::Matches($Content, '(?m)^\s*model_provider\s*=\s*"([^"]+)"')
	$providers = New-Object System.Collections.Generic.List[string]
	foreach ($match in @($matches)) {
		$value = $match.Groups[1].Value.Trim()
		if (![string]::IsNullOrWhiteSpace($value)) {
			$providers.Add($value)
		}
	}
	return @($providers.ToArray() | Select-Object -Unique)
}

function Get-ConfiguredReasoningEffortMatches {
	param([string]$Content)

	$matches = [regex]::Matches($Content, '(?m)^\s*(model_reasoning_effort|reasoning_effort)\s*=\s*"([^"]+)"')
	$efforts = New-Object System.Collections.Generic.List[string]
	foreach ($match in @($matches)) {
		$value = $match.Groups[2].Value.Trim()
		if (![string]::IsNullOrWhiteSpace($value)) {
			$efforts.Add($value)
		}
	}
	return @($efforts.ToArray() | Select-Object -Unique)
}

function Get-AgentInstructionSignalMatches {
	param([string]$Content)

	$signals = New-Object System.Collections.Generic.List[string]
	foreach ($key in @("instructions", "developer_instructions", "model_instructions_file")) {
		if ($Content -match "(?m)^\s*$([regex]::Escape($key))\s*=") {
			$signals.Add($key)
		}
	}
	return @($signals.ToArray() | Select-Object -Unique)
}

function Get-MissingRequiredAgentFields {
	param([string]$Content)

	$missing = New-Object System.Collections.Generic.List[string]
	foreach ($key in @("name", "description", "developer_instructions")) {
		if ($Content -notmatch "(?m)^\s*$([regex]::Escape($key))\s*=") {
			$missing.Add($key)
		}
	}
	return @($missing.ToArray())
}

function Test-CodexAgentConfigPath {
	param([string]$Path)

	$parent = Split-Path -Parent $Path
	if ([string]::IsNullOrWhiteSpace($parent)) {
		return $false
	}
	return ((Split-Path -Leaf $parent) -ieq "agents")
}

function Get-CodexConfigEvidence {
	param([string[]]$Paths)

	$records = New-Object System.Collections.Generic.List[object]
	foreach ($path in @($Paths)) {
		$exists = Test-Path -LiteralPath $path -PathType Leaf
		$content = ""
		if ($exists) {
			$content = Get-Content -LiteralPath $path -Raw
		}
		$localEndpoints = if ($exists) { Get-LocalEndpointMatches -Content $content } else { @() }
		$envKeys = if ($exists) { Get-EnvKeyMatches -Content $content } else { @() }
		$configuredModels = if ($exists) { Get-ConfiguredModelMatches -Content $content } else { @() }
		$configuredModelProviders = if ($exists) { Get-ConfiguredModelProviderMatches -Content $content } else { @() }
		$configuredReasoningEfforts = if ($exists) { Get-ConfiguredReasoningEffortMatches -Content $content } else { @() }
		$instructionSignals = if ($exists) { Get-AgentInstructionSignalMatches -Content $content } else { @() }
		$isAgentConfig = Test-CodexAgentConfigPath -Path $path
		$missingAgentFields = if ($exists -and $isAgentConfig) { Get-MissingRequiredAgentFields -Content $content } else { @() }
		$envKeyRecords = @($envKeys | ForEach-Object {
			[pscustomobject]@{
				Name = $_
				Present = ![string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
			}
		})
		$records.Add([pscustomobject]@{
			Path = $path
			Exists = [bool]$exists
			Kind = if ($isAgentConfig) { "agent" } else { "provider" }
			IsAgentConfig = [bool]$isAgentConfig
			HasModelProviders = [bool]($exists -and $content -match '\[model_providers\.')
			HasProfiles = [bool]($exists -and $content -match '\[profiles\.')
			LocalEndpoints = @($localEndpoints)
			ConfiguredModels = @($configuredModels)
			ConfiguredModelProviders = @($configuredModelProviders)
			ConfiguredReasoningEfforts = @($configuredReasoningEfforts)
			InstructionSignals = @($instructionSignals)
			MissingRequiredAgentFields = @($missingAgentFields)
			EnvKeys = @($envKeyRecords)
		})
	}

	return @($records.ToArray())
}

function Get-EndpointCandidates {
	param(
		[string[]]$ExplicitEndpoints,
		[array]$ConfigEvidence,
		[switch]$SkipDefault
	)

	$candidates = New-Object System.Collections.Generic.List[string]
	foreach ($endpoint in @($ExplicitEndpoints)) {
		if (![string]::IsNullOrWhiteSpace($endpoint)) {
			$candidates.Add($endpoint.TrimEnd("/"))
		}
	}
	foreach ($config in @($ConfigEvidence)) {
		foreach ($endpoint in @($config.LocalEndpoints)) {
			$candidates.Add($endpoint.TrimEnd("/"))
		}
	}
	if (!$SkipDefault) {
		$candidates.Add("http://127.0.0.1:8001/v1")
		$candidates.Add("http://localhost:8001/v1")
		$candidates.Add("http://127.0.0.1:8080/v1")
		$candidates.Add("http://localhost:8080/v1")
	}

	return @($candidates.ToArray() | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function Test-LocalCodexEndpoint {
	param([string]$BaseUrl)

	$modelsUrl = "$($BaseUrl.TrimEnd('/'))/models"
	try {
		$response = Invoke-RestMethod -Uri $modelsUrl -Method Get -TimeoutSec 2 -ErrorAction Stop
		$modelNames = @()
		if ($response.PSObject.Properties["data"]) {
			$modelNames = @($response.data | ForEach-Object {
				if ($_.PSObject.Properties["id"]) {
					[string]$_.id
				}
			} | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
		}
		return [pscustomobject]@{
			BaseUrl = $BaseUrl
			ModelsUrl = $modelsUrl
			Reachable = $true
			ModelCount = $modelNames.Count
			Models = @($modelNames | Select-Object -First 8)
			Error = ""
		}
	} catch {
		return [pscustomobject]@{
			BaseUrl = $BaseUrl
			ModelsUrl = $modelsUrl
			Reachable = $false
			ModelCount = 0
			Models = @()
			Error = $_.Exception.Message
		}
	}
}

function Get-LlamaLocalCodexMetadata {
	param([string]$CoreRoot)

	$addonsRoot = Split-Path -Parent $CoreRoot
	$llamaRoot = Join-Path $addonsRoot "ofxGgmlLlama"
	$metadataPath = Join-Path $llamaRoot "ofxggml-addon.json"
	$result = [ordered]@{
		Repository = "ofxGgmlLlama"
		RepositoryPath = $llamaRoot
		MetadataPath = $metadataPath
		Present = (Test-Path -LiteralPath $llamaRoot -PathType Container)
		MetadataPresent = (Test-Path -LiteralPath $metadataPath -PathType Leaf)
		CodexLocalPlan = ""
		CodexLocalPlanPresent = $false
		CodexLocalSmoke = ""
		CodexLocalSmokePresent = $false
	}

	if (!$result.MetadataPresent) {
		return [pscustomobject]$result
	}

	try {
		$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
		if ($metadata.PSObject.Properties["codexLocalPlan"] -and ![string]::IsNullOrWhiteSpace([string]$metadata.codexLocalPlan)) {
			$result.CodexLocalPlan = [string]$metadata.codexLocalPlan
			$result.CodexLocalPlanPresent = Test-Path -LiteralPath (Join-Path $llamaRoot $result.CodexLocalPlan) -PathType Leaf
		}
		if ($metadata.PSObject.Properties["codexLocalSmoke"] -and ![string]::IsNullOrWhiteSpace([string]$metadata.codexLocalSmoke)) {
			$result.CodexLocalSmoke = [string]$metadata.codexLocalSmoke
			$result.CodexLocalSmokePresent = Test-Path -LiteralPath (Join-Path $llamaRoot $result.CodexLocalSmoke) -PathType Leaf
		}
	} catch {
		$result.Error = $_.Exception.Message
	}

	return [pscustomobject]$result
}

function Invoke-LlamaLocalCodexPlan {
	param(
		[object]$LlamaCodex,
		[array]$Endpoints,
		[array]$Configs
	)

	$result = [ordered]@{
		Invoked = $false
		Succeeded = $false
		Endpoint = ""
		Model = ""
		ModelSource = ""
		ConfigPath = ""
		Ready = $false
		BlockerCount = 0
		ServedModels = $null
		LocalLlamaServer = $null
		Error = ""
	}

	if (!$LlamaCodex -or !$LlamaCodex.CodexLocalPlanPresent) {
		$result.Error = "Llama local Codex planner is not available."
		return [pscustomobject]$result
	}

	$planPath = Join-Path $LlamaCodex.RepositoryPath $LlamaCodex.CodexLocalPlan
	$endpoint = @($Endpoints | Where-Object { $_.Reachable } | Select-Object -First 1)
	if ($endpoint.Count -eq 0) {
		$endpoint = @($Endpoints | Select-Object -First 1)
	}
	if ($endpoint.Count -gt 0) {
		$result.Endpoint = [string]$endpoint[0].BaseUrl
	}

	$configWithLocalEndpoint = @($Configs |
		Where-Object { !$_.IsAgentConfig } |
		Where-Object { @($_.LocalEndpoints).Count -gt 0 } |
		Select-Object -First 1)
	if ($configWithLocalEndpoint.Count -gt 0) {
		$result.ConfigPath = [string]$configWithLocalEndpoint[0].Path
	}

	$configuredModelSource = "codex-config"
	$configuredModel = @($configWithLocalEndpoint |
		Where-Object { @($_.ConfiguredModels).Count -gt 0 } |
		ForEach-Object { @($_.ConfiguredModels) } |
		Select-Object -First 1)
	if ($configuredModel.Count -eq 0) {
		$configuredModel = @($Configs |
			Where-Object { $_.IsAgentConfig -and @($_.ConfiguredModels).Count -gt 0 } |
			ForEach-Object { @($_.ConfiguredModels) } |
			Select-Object -First 1)
		$configuredModelSource = "codex-agent-config"
	}
	if ($configuredModel.Count -gt 0) {
		$result.Model = [string]$configuredModel[0]
		$result.ModelSource = $configuredModelSource
	} elseif ($endpoint.Count -gt 0 -and @($endpoint[0].Models).Count -gt 0) {
		$result.Model = [string]@($endpoint[0].Models)[0]
		$result.ModelSource = "served-model"
	}

	try {
		$args = New-Object System.Collections.Generic.List[string]
		if (![string]::IsNullOrWhiteSpace($result.Endpoint)) {
			$args.Add("-Endpoint")
			$args.Add($result.Endpoint)
		}
		if (![string]::IsNullOrWhiteSpace($result.Model)) {
			$args.Add("-Model")
			$args.Add($result.Model)
		}
		if (![string]::IsNullOrWhiteSpace($result.ConfigPath)) {
			$args.Add("-ConfigPath")
			$args.Add($result.ConfigPath)
		}
		$args.Add("-Json")
		$args.Add("-SummaryOnly")

		$output = & $planPath @($args.ToArray()) 2>&1
		$result.Invoked = $true
		if (!$?) {
			$result.Error = ($output | ForEach-Object { $_.ToString() }) -join "`n"
			return [pscustomobject]$result
		}

		$parsed = ($output | ForEach-Object { $_.ToString() }) -join "`n" | ConvertFrom-Json
		$result.Succeeded = $true
		$result.Ready = [bool]$parsed.Ready
		$result.BlockerCount = @($parsed.Blockers).Count
		if ($parsed.PSObject.Properties["ServedModels"]) {
			$result.ServedModels = $parsed.ServedModels
		}
		if ($parsed.PSObject.Properties["LocalLlamaServer"]) {
			$result.LocalLlamaServer = $parsed.LocalLlamaServer
		}
	} catch {
		$result.Error = $_.Exception.Message
	}

	return [pscustomobject]$result
}

function Get-ReadinessState {
	param(
		[array]$Configs,
		[array]$Endpoints
	)

	$providerConfigs = @($Configs | Where-Object { !$_.IsAgentConfig })
	$configFound = @($providerConfigs | Where-Object { $_.Exists }).Count -gt 0
	$configWithLocalEndpoint = @($providerConfigs | Where-Object { @($_.LocalEndpoints).Count -gt 0 }).Count -gt 0
	$reachable = @($Endpoints | Where-Object { $_.Reachable }).Count -gt 0

	if ($configWithLocalEndpoint -and $reachable) {
		return "ready"
	}
	if (!$configFound -and $reachable) {
		return "config-missing"
	}
	if ($configWithLocalEndpoint -and !$reachable) {
		return "server-missing"
	}
	if ($configFound) {
		return "local-provider-missing"
	}
	return "not-configured"
}

function Get-NextCommands {
	param([object]$LlamaCodex)

	$commands = New-Object System.Collections.Generic.List[string]
	foreach ($command in @(
		"scripts\plan-local-codex.bat -Json -SummaryOnly",
		"scripts\plan-coding-agent-work.bat -Json",
		"scripts\check-ecosystem-readiness.bat -SkipDoctorTests -Json -SummaryOnly",
		"scripts\release-candidate.bat"
	)) {
		$commands.Add($command)
	}
	if ($LlamaCodex -and $LlamaCodex.CodexLocalPlanPresent) {
		$commands.Add(("cd ..\ofxGgmlLlama && {0} -SummaryOnly" -f $LlamaCodex.CodexLocalPlan))
	}
	if ($LlamaCodex -and $LlamaCodex.CodexLocalSmokePresent) {
		$commands.Add(("cd ..\ofxGgmlLlama && {0} -Json -SummaryOnly" -f $LlamaCodex.CodexLocalSmoke))
	}
	return @($commands.ToArray())
}

function New-LocalCodexAction {
	param(
		[string]$Priority,
		[string]$State,
		[string]$Action,
		[string]$Rationale,
		[string]$Command = ""
	)

	[pscustomobject]@{
		Priority = $Priority
		State = $State
		Action = $Action
		Rationale = $Rationale
		Command = $Command
	}
}

function Get-RecommendedActions {
	param(
		[string]$ReadinessState,
		[array]$Configs,
		[array]$Endpoints
	)

	$actions = New-Object System.Collections.Generic.List[object]
	$reachable = @($Endpoints | Where-Object { $_.Reachable })
	$firstReachable = @($reachable | Select-Object -First 1)
	$config = @($Configs | Where-Object { $_.Exists -and !$_.IsAgentConfig } | Select-Object -First 1)

	switch ($ReadinessState) {
		"ready" {
			$actions.Add((New-LocalCodexAction `
				-Priority "P2" `
				-State $ReadinessState `
				-Action "Use local Codex only for bounded non-interactive planning, docs, validation, and small patches." `
				-Rationale "The endpoint and config are visible, but tool-bearing sessions may still be rejected by llama-server and release truth comes from validation and CI." `
				-Command "Prefer codex exec smoke with explicit -c provider overrides and disabled apps/browser/computer/tool_search before enabling a full desktop profile."))
		}
		"local-provider-missing" {
			$endpoint = if ($firstReachable.Count -gt 0) { [string]$firstReachable[0].BaseUrl } else { "http://127.0.0.1:8001/v1" }
			$model = if ($firstReachable.Count -gt 0 -and @($firstReachable[0].Models).Count -gt 0) { [string]@($firstReachable[0].Models)[0] } else { "<model-id-from-v1-models>" }
			$configPath = if ($config.Count -gt 0) { [string]$config[0].Path } else { "%USERPROFILE%\.codex\config.toml" }
			$actions.Add((New-LocalCodexAction `
				-Priority "P1" `
				-State $ReadinessState `
				-Action "Keep the active Codex config minimal unless the local provider is isolated from tool-bearing sessions." `
				-Rationale "A Codex config exists, but no local provider endpoint was detected; enabling one globally can make Codex send non-function tools that llama-server rejects." `
				-Command "For non-interactive smoke, pass provider fields with codex -c overrides for $endpoint and disable apps/browser/computer/tool_search; use model $model. Quarantine experimental full configs outside active $configPath."))
		}
		"server-missing" {
			$endpoint = if (@($Endpoints).Count -gt 0) { [string]@($Endpoints)[0].BaseUrl } else { "http://127.0.0.1:8001/v1" }
			$actions.Add((New-LocalCodexAction `
				-Priority "P1" `
				-State $ReadinessState `
				-Action "Start or repoint the local OpenAI-compatible llama-server endpoint referenced by Codex config." `
				-Rationale "Codex config contains a local provider endpoint, but the planner could not reach `/v1/models`." `
				-Command "Start llama-server on $endpoint, then rerun scripts\plan-local-codex.bat -Json -SummaryOnly."))
		}
		"config-missing" {
			$endpoint = if ($firstReachable.Count -gt 0) { [string]$firstReachable[0].BaseUrl } else { "http://127.0.0.1:8001/v1" }
			$model = if ($firstReachable.Count -gt 0 -and @($firstReachable[0].Models).Count -gt 0) { [string]@($firstReachable[0].Models)[0] } else { "<model-id-from-v1-models>" }
			$actions.Add((New-LocalCodexAction `
				-Priority "P1" `
				-State $ReadinessState `
				-Action "Use explicit local-provider overrides for non-interactive Codex smoke before creating an active config." `
				-Rationale "A localhost model endpoint is reachable, but local providers should stay isolated until their tool compatibility is proven." `
				-Command "Run codex exec with -c provider overrides for $endpoint, disable apps/browser/computer/tool_search, and use model $model."))
		}
		default {
			$actions.Add((New-LocalCodexAction `
				-Priority "P2" `
				-State $ReadinessState `
				-Action "Keep local Codex disabled until a localhost model server and matching Codex provider are intentionally configured." `
				-Rationale "No local provider and no reachable default endpoint were detected." `
				-Command "scripts\plan-local-codex.bat -Json -SummaryOnly"))
		}
	}

	$actions.Add((New-LocalCodexAction `
		-Priority "P2" `
		-State "guardrail" `
		-Action "Before any repository edit, run the ecosystem and coding-agent planners and keep changes inside the suggested file scope." `
		-Rationale "Local model suggestions are helper evidence, not release or lane-ownership truth." `
		-Command "scripts\plan-ecosystem.bat -Json -SummaryOnly; scripts\plan-coding-agent-work.bat -Json"))

	return @($actions.ToArray())
}

function ConvertTo-LocalCodexMarkdown {
	param([object]$Result)

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# Local Codex Readiness Plan")
	$lines.Add("")
	$lines.Add("This non-mutating report checks whether a local Codex setup appears ready to use an OpenAI-compatible `llama-server` endpoint. It does not start a server, edit Codex config, or change addon runtime behavior.")
	$lines.Add("")
	$lines.Add("## Summary")
	$lines.Add("")
	$lines.Add("| Metric | Value |")
	$lines.Add("| --- | --- |")
	$lines.Add(('| Readiness state | `{0}` |' -f $Result.Summary.ReadinessState))
	$lines.Add("| Config files found | $($Result.Summary.ConfigFilesFound) |")
	$lines.Add("| Agent config files found | $($Result.Summary.AgentConfigFilesFound) |")
	$lines.Add("| Local endpoint candidates | $($Result.Summary.LocalEndpointCandidates) |")
	$lines.Add("| Reachable endpoints | $($Result.Summary.ReachableEndpoints) |")
	$lines.Add("| Models reported | $($Result.Summary.ModelsReported) |")
	$lines.Add("| Config models declared | $($Result.Summary.ConfigModelsDeclared) |")
	$lines.Add("| Config model providers declared | $($Result.Summary.ConfigModelProvidersDeclared) |")
	$lines.Add("| Config reasoning efforts declared | $($Result.Summary.ConfigReasoningEffortsDeclared) |")
	$lines.Add("| Agent instruction signals declared | $($Result.Summary.AgentInstructionSignalsDeclared) |")
	$lines.Add("| Agent configs missing required fields | $($Result.Summary.AgentConfigsMissingRequiredFields) |")
	$lines.Add("| Env keys declared | $($Result.Summary.EnvKeysDeclared) |")
	$lines.Add("| Env keys present | $($Result.Summary.EnvKeysPresent) |")
	$lines.Add("| Llama Codex model source | $($Result.Summary.LlamaCodexModelSource) |")
	$lines.Add("| Llama Codex plan entrypoint | $($Result.Summary.LlamaCodexPlanEntrypoint) |")
	$lines.Add("| Llama Codex smoke entrypoint | $($Result.Summary.LlamaCodexSmokeEntrypoint) |")
	$lines.Add("| Llama Codex plan invoked | $($Result.Summary.LlamaCodexPlanInvoked) |")
	$lines.Add("| Llama Codex plan ready | $($Result.Summary.LlamaCodexPlanReady) |")
	$lines.Add("| Llama process inspection | $($Result.Summary.LlamaLocalServerInspection) |")
	$lines.Add("| Llama served models reported | $($Result.Summary.LlamaServedModelsReported) |")
	$lines.Add("| Llama local server processes | $($Result.Summary.LlamaLocalServerProcesses) |")
	$lines.Add("| Llama model alias mismatches | $($Result.Summary.LlamaModelAliasMismatchCount) |")
	$lines.Add("")
	if ($Result.PSObject.Properties["Configs"]) {
		$lines.Add("## Config Evidence")
		$lines.Add("")
		$lines.Add("| Path | Kind | Exists | Local endpoints | Models | Providers | Reasoning | Instructions | Missing required agent fields | Env keys |")
		$lines.Add("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
		foreach ($config in @($Result.Configs)) {
			$endpointText = if (@($config.LocalEndpoints).Count -gt 0) { @($config.LocalEndpoints) -join ", " } else { "-" }
			$modelText = if (@($config.ConfiguredModels).Count -gt 0) { @($config.ConfiguredModels) -join ", " } else { "-" }
			$providerText = if (@($config.ConfiguredModelProviders).Count -gt 0) { @($config.ConfiguredModelProviders) -join ", " } else { "-" }
			$reasoningText = if (@($config.ConfiguredReasoningEfforts).Count -gt 0) { @($config.ConfiguredReasoningEfforts) -join ", " } else { "-" }
			$instructionText = if (@($config.InstructionSignals).Count -gt 0) { @($config.InstructionSignals) -join ", " } else { "-" }
			$missingAgentText = if (@($config.MissingRequiredAgentFields).Count -gt 0) { @($config.MissingRequiredAgentFields) -join ", " } else { "-" }
			$keyText = if (@($config.EnvKeys).Count -gt 0) { @($config.EnvKeys | ForEach-Object { if ($_.Present) { "$($_.Name):present" } else { "$($_.Name):missing" } }) -join ", " } else { "-" }
			$lines.Add(('| `{0}` | `{1}` | {2} | `{3}` | `{4}` | `{5}` | `{6}` | `{7}` | `{8}` | `{9}` |' -f $config.Path, $config.Kind, $config.Exists, $endpointText, $modelText, $providerText, $reasoningText, $instructionText, $missingAgentText, $keyText))
		}
	} else {
		$lines.Add("Config evidence omitted by -SummaryOnly; rerun without -SummaryOnly for per-file details.")
	}
	$lines.Add("")
	if ($Result.PSObject.Properties["Endpoints"]) {
		$lines.Add("## Endpoint Evidence")
		$lines.Add("")
		$lines.Add("| Base URL | Reachable | Models |")
		$lines.Add("| --- | --- | ---: |")
		foreach ($endpoint in @($Result.Endpoints)) {
			$lines.Add(('| `{0}` | {1} | {2} |' -f $endpoint.BaseUrl, $endpoint.Reachable, $endpoint.ModelCount))
		}
	} else {
		$lines.Add("Endpoint evidence omitted by -SummaryOnly; rerun without -SummaryOnly for per-endpoint details.")
	}
	$lines.Add("")
	$lines.Add("## Llama-Owned Evidence")
	$lines.Add("")
	if ($Result.LlamaCodexPlanEvidence -and $Result.LlamaCodexPlanEvidence.Invoked) {
		$served = if ($Result.LlamaCodexPlanEvidence.ServedModels -and @($Result.LlamaCodexPlanEvidence.ServedModels.Models).Count -gt 0) {
			@($Result.LlamaCodexPlanEvidence.ServedModels.Models) -join ", "
		} else {
			"-"
		}
		$processes = if ($Result.LlamaCodexPlanEvidence.LocalLlamaServer) {
			@($Result.LlamaCodexPlanEvidence.LocalLlamaServer.Processes)
		} else {
			@()
		}
		$inspection = if ($Result.LlamaCodexPlanEvidence.LocalLlamaServer) {
			if ($Result.LlamaCodexPlanEvidence.LocalLlamaServer.Available) {
				"available"
			} else {
				"unavailable: $($Result.LlamaCodexPlanEvidence.LocalLlamaServer.Error)"
			}
		} else {
			"not-reported"
		}
		$lines.Add("| Endpoint | Model source | Ready | Served models | Process inspection | Local model files | Alias mismatches |")
		$lines.Add("| --- | --- | --- | --- | --- | --- | ---: |")
		$modelFiles = if (@($processes).Count -gt 0) {
			@($processes | ForEach-Object { if (![string]::IsNullOrWhiteSpace($_.ModelFile)) { $_.ModelFile } }) -join ", "
		} else {
			"-"
		}
		$mismatchCount = @($processes | Where-Object { $_.ModelAliasFamilyMismatch }).Count
		$lines.Add(('| `{0}` | `{1}` | {2} | `{3}` | `{4}` | `{5}` | {6} |' -f $Result.LlamaCodexPlanEvidence.Endpoint, $Result.LlamaCodexPlanEvidence.ModelSource, $Result.LlamaCodexPlanEvidence.Ready, $served, $inspection, $modelFiles, $mismatchCount))
	} else {
		$errorText = if ($Result.LlamaCodexPlanEvidence) { $Result.LlamaCodexPlanEvidence.Error } else { "No Llama planner evidence available." }
		$lines.Add("Llama-owned local Codex evidence was not available: $errorText")
	}
	$lines.Add("")
	$lines.Add("## Recommended Actions")
	$lines.Add("")
	$lines.Add("| Priority | State | Action | Command |")
	$lines.Add("| --- | --- | --- | --- |")
	foreach ($action in @($Result.RecommendedActions)) {
		$command = if ([string]::IsNullOrWhiteSpace($action.Command)) { "-" } else { $action.Command }
		$lines.Add(('| {0} | `{1}` | {2} | `{3}` |' -f $action.Priority, $action.State, $action.Action, $command))
	}
	$lines.Add("")
	$lines.Add("## Next Commands")
	$lines.Add("")
	foreach ($command in @($Result.NextCommands)) {
		$lines.Add(('- `{0}`' -f $command))
	}

	return $lines -join [Environment]::NewLine
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot

$configPaths = if ($ConfigPath.Count -gt 0) {
	Get-UniqueFullPath -Paths $ConfigPath
} else {
	Get-DefaultCodexConfigPaths -ProjectRoot $addonRoot
}
$configEvidence = Get-CodexConfigEvidence -Paths $configPaths
$endpointCandidates = Get-EndpointCandidates -ExplicitEndpoints $Endpoint -ConfigEvidence $configEvidence -SkipDefault:$SkipDefaultEndpoints
$endpointEvidence = @($endpointCandidates | ForEach-Object { Test-LocalCodexEndpoint -BaseUrl $_ })
$envKeyRecords = @($configEvidence | ForEach-Object { @($_.EnvKeys) })
$configuredModelRecords = @($configEvidence | ForEach-Object { @($_.ConfiguredModels) })
$configuredModelProviderRecords = @($configEvidence | ForEach-Object { @($_.ConfiguredModelProviders) })
$configuredReasoningEffortRecords = @($configEvidence | ForEach-Object { @($_.ConfiguredReasoningEfforts) })
$instructionSignalRecords = @($configEvidence | ForEach-Object { @($_.InstructionSignals) })
$agentConfigsMissingRequiredFields = @($configEvidence | Where-Object { $_.IsAgentConfig -and @($_.MissingRequiredAgentFields).Count -gt 0 })
$llamaCodex = Get-LlamaLocalCodexMetadata -CoreRoot $addonRoot
$llamaCodexPlanEvidence = Invoke-LlamaLocalCodexPlan -LlamaCodex $llamaCodex -Endpoints $endpointEvidence -Configs $configEvidence
$llamaProcessInspection = if ($llamaCodexPlanEvidence.LocalLlamaServer) {
	if ($llamaCodexPlanEvidence.LocalLlamaServer.Available) { "available" } else { "unavailable" }
} else {
	"not-reported"
}

$summary = [pscustomobject]@{
	ReadinessState = Get-ReadinessState -Configs $configEvidence -Endpoints $endpointEvidence
	ConfigFilesChecked = @($configEvidence).Count
	ConfigFilesFound = @($configEvidence | Where-Object { $_.Exists }).Count
	AgentConfigFilesFound = @($configEvidence | Where-Object { $_.Exists -and $_.IsAgentConfig }).Count
	ConfigFilesWithLocalEndpoints = @($configEvidence | Where-Object { @($_.LocalEndpoints).Count -gt 0 }).Count
	LocalEndpointCandidates = @($endpointCandidates).Count
	ReachableEndpoints = @($endpointEvidence | Where-Object { $_.Reachable }).Count
	ModelsReported = (@($endpointEvidence | Measure-Object -Property ModelCount -Sum).Sum + 0)
	ConfigModelsDeclared = @($configuredModelRecords).Count
	ConfigModelProvidersDeclared = @($configuredModelProviderRecords).Count
	ConfigReasoningEffortsDeclared = @($configuredReasoningEffortRecords).Count
	AgentInstructionSignalsDeclared = @($instructionSignalRecords).Count
	AgentConfigsMissingRequiredFields = @($agentConfigsMissingRequiredFields).Count
	EnvKeysDeclared = @($envKeyRecords).Count
	EnvKeysPresent = @($envKeyRecords | Where-Object { $_.Present }).Count
	LlamaCodexModelSource = [string]$llamaCodexPlanEvidence.ModelSource
	LlamaCodexPlanEntrypoint = [bool]$llamaCodex.CodexLocalPlanPresent
	LlamaCodexSmokeEntrypoint = [bool]$llamaCodex.CodexLocalSmokePresent
	LlamaCodexPlanInvoked = [bool]$llamaCodexPlanEvidence.Invoked
	LlamaCodexPlanSucceeded = [bool]$llamaCodexPlanEvidence.Succeeded
	LlamaCodexPlanReady = [bool]$llamaCodexPlanEvidence.Ready
	LlamaLocalServerInspection = $llamaProcessInspection
	LlamaServedModelsReported = if ($llamaCodexPlanEvidence.ServedModels) { @($llamaCodexPlanEvidence.ServedModels.Models).Count } else { 0 }
	LlamaLocalServerProcesses = if ($llamaCodexPlanEvidence.LocalLlamaServer) { @($llamaCodexPlanEvidence.LocalLlamaServer.Processes).Count } else { 0 }
	LlamaModelAliasMismatchCount = if ($llamaCodexPlanEvidence.LocalLlamaServer) { @($llamaCodexPlanEvidence.LocalLlamaServer.Processes | Where-Object { $_.ModelAliasFamilyMismatch }).Count } else { 0 }
}
$recommendedActions = Get-RecommendedActions -ReadinessState $summary.ReadinessState -Configs $configEvidence -Endpoints $endpointEvidence

$result = [ordered]@{
	Root = $addonRoot
	SummaryOnly = [bool]$SummaryOnly
	SkipDefaultEndpoints = [bool]$SkipDefaultEndpoints
	Summary = $summary
	LlamaCodex = $llamaCodex
	LlamaCodexPlanEvidence = $llamaCodexPlanEvidence
	RecommendedActions = @($recommendedActions)
	NextCommands = @(Get-NextCommands -LlamaCodex $llamaCodex)
}
if (!$SummaryOnly) {
	$result.Configs = @($configEvidence)
	$result.Endpoints = @($endpointEvidence)
}

if ($Json) {
	$content = ([pscustomobject]$result | ConvertTo-Json -Depth 6)
} else {
	$content = ConvertTo-LocalCodexMarkdown -Result ([pscustomobject]$result)
}

if (![string]::IsNullOrWhiteSpace($OutputPath)) {
	$target = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
		$OutputPath
	} else {
		Join-Path $addonRoot $OutputPath
	}
	$directory = Split-Path -Parent $target
	if (!(Test-Path -LiteralPath $directory -PathType Container)) {
		New-Item -ItemType Directory -Path $directory -Force | Out-Null
	}
	Set-Content -LiteralPath $target -Value $content
	Write-Host "Wrote $target"
} else {
	Write-Output $content
}
