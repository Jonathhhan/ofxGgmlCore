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

function Get-DefaultCodexConfigPaths {
	$candidates = New-Object System.Collections.Generic.List[string]
	if (![string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
		$candidates.Add((Join-Path $env:CODEX_HOME "config.toml"))
	}
	if (![string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
		$candidates.Add((Join-Path $env:USERPROFILE ".codex\config.toml"))
	}
	if (![string]::IsNullOrWhiteSpace($HOME)) {
		$candidates.Add((Join-Path $HOME ".codex\config.toml"))
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
		$envKeyRecords = @($envKeys | ForEach-Object {
			[pscustomobject]@{
				Name = $_
				Present = ![string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
			}
		})
		$records.Add([pscustomobject]@{
			Path = $path
			Exists = [bool]$exists
			HasModelProviders = [bool]($exists -and $content -match '\[model_providers\.')
			HasProfiles = [bool]($exists -and $content -match '\[profiles\.')
			LocalEndpoints = @($localEndpoints)
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

function Get-ReadinessState {
	param(
		[array]$Configs,
		[array]$Endpoints
	)

	$configFound = @($Configs | Where-Object { $_.Exists }).Count -gt 0
	$configWithLocalEndpoint = @($Configs | Where-Object { @($_.LocalEndpoints).Count -gt 0 }).Count -gt 0
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
	@(
		"scripts\plan-local-codex.bat -Json -SummaryOnly",
		"scripts\plan-coding-agent-work.bat -Json",
		"scripts\check-ecosystem-readiness.bat -SkipDoctorTests -Json -SummaryOnly",
		"scripts\release-candidate.bat"
	)
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
	$config = @($Configs | Where-Object { $_.Exists } | Select-Object -First 1)

	switch ($ReadinessState) {
		"ready" {
			$actions.Add((New-LocalCodexAction `
				-Priority "P2" `
				-State $ReadinessState `
				-Action "Use the local Codex profile only for bounded planning, documentation, validation, and small repository-scoped patches." `
				-Rationale "The endpoint and config are visible, but release truth still comes from validation and CI." `
				-Command "scripts\plan-coding-agent-work.bat -Json"))
		}
		"local-provider-missing" {
			$endpoint = if ($firstReachable.Count -gt 0) { [string]$firstReachable[0].BaseUrl } else { "http://127.0.0.1:8080/v1" }
			$model = if ($firstReachable.Count -gt 0 -and @($firstReachable[0].Models).Count -gt 0) { [string]@($firstReachable[0].Models)[0] } else { "<model-id-from-v1-models>" }
			$configPath = if ($config.Count -gt 0) { [string]$config[0].Path } else { "%USERPROFILE%\.codex\config.toml" }
			$actions.Add((New-LocalCodexAction `
				-Priority "P1" `
				-State $ReadinessState `
				-Action "Add a local Codex provider/profile that points at the reachable localhost OpenAI-compatible endpoint." `
				-Rationale "A server is reachable, but the checked Codex config does not expose a local provider endpoint." `
				-Command "Edit $configPath and add a provider base_url for $endpoint with wire_api responses and model $model."))
		}
		"server-missing" {
			$endpoint = if (@($Endpoints).Count -gt 0) { [string]@($Endpoints)[0].BaseUrl } else { "http://127.0.0.1:8080/v1" }
			$actions.Add((New-LocalCodexAction `
				-Priority "P1" `
				-State $ReadinessState `
				-Action "Start or repoint the local OpenAI-compatible llama-server endpoint referenced by Codex config." `
				-Rationale "Codex config contains a local provider endpoint, but the planner could not reach `/v1/models`." `
				-Command "Start llama-server on $endpoint, then rerun scripts\plan-local-codex.bat -Json -SummaryOnly."))
		}
		"config-missing" {
			$endpoint = if ($firstReachable.Count -gt 0) { [string]$firstReachable[0].BaseUrl } else { "http://127.0.0.1:8080/v1" }
			$model = if ($firstReachable.Count -gt 0 -and @($firstReachable[0].Models).Count -gt 0) { [string]@($firstReachable[0].Models)[0] } else { "<model-id-from-v1-models>" }
			$actions.Add((New-LocalCodexAction `
				-Priority "P1" `
				-State $ReadinessState `
				-Action "Create a Codex config with a local provider/profile for the reachable endpoint." `
				-Rationale "A localhost model endpoint is reachable, but no Codex config file was found in the checked locations." `
				-Command "Create %USERPROFILE%\.codex\config.toml with a provider base_url for $endpoint, wire_api responses, and model $model."))
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
	$lines.Add("| Local endpoint candidates | $($Result.Summary.LocalEndpointCandidates) |")
	$lines.Add("| Reachable endpoints | $($Result.Summary.ReachableEndpoints) |")
	$lines.Add("| Models reported | $($Result.Summary.ModelsReported) |")
	$lines.Add("| Env keys declared | $($Result.Summary.EnvKeysDeclared) |")
	$lines.Add("| Env keys present | $($Result.Summary.EnvKeysPresent) |")
	$lines.Add("")
	$lines.Add("## Config Evidence")
	$lines.Add("")
	$lines.Add("| Path | Exists | Local endpoints | Env keys |")
	$lines.Add("| --- | --- | --- | --- |")
	foreach ($config in @($Result.Configs)) {
		$endpointText = if (@($config.LocalEndpoints).Count -gt 0) { @($config.LocalEndpoints) -join ", " } else { "-" }
		$keyText = if (@($config.EnvKeys).Count -gt 0) { @($config.EnvKeys | ForEach-Object { if ($_.Present) { "$($_.Name):present" } else { "$($_.Name):missing" } }) -join ", " } else { "-" }
		$lines.Add(('| `{0}` | {1} | `{2}` | `{3}` |' -f $config.Path, $config.Exists, $endpointText, $keyText))
	}
	$lines.Add("")
	$lines.Add("## Endpoint Evidence")
	$lines.Add("")
	$lines.Add("| Base URL | Reachable | Models |")
	$lines.Add("| --- | --- | ---: |")
	foreach ($endpoint in @($Result.Endpoints)) {
		$lines.Add(('| `{0}` | {1} | {2} |' -f $endpoint.BaseUrl, $endpoint.Reachable, $endpoint.ModelCount))
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
	Get-DefaultCodexConfigPaths
}
$configEvidence = Get-CodexConfigEvidence -Paths $configPaths
$endpointCandidates = Get-EndpointCandidates -ExplicitEndpoints $Endpoint -ConfigEvidence $configEvidence -SkipDefault:$SkipDefaultEndpoints
$endpointEvidence = @($endpointCandidates | ForEach-Object { Test-LocalCodexEndpoint -BaseUrl $_ })
$envKeyRecords = @($configEvidence | ForEach-Object { @($_.EnvKeys) })

$summary = [pscustomobject]@{
	ReadinessState = Get-ReadinessState -Configs $configEvidence -Endpoints $endpointEvidence
	ConfigFilesChecked = @($configEvidence).Count
	ConfigFilesFound = @($configEvidence | Where-Object { $_.Exists }).Count
	ConfigFilesWithLocalEndpoints = @($configEvidence | Where-Object { @($_.LocalEndpoints).Count -gt 0 }).Count
	LocalEndpointCandidates = @($endpointCandidates).Count
	ReachableEndpoints = @($endpointEvidence | Where-Object { $_.Reachable }).Count
	ModelsReported = (@($endpointEvidence | Measure-Object -Property ModelCount -Sum).Sum + 0)
	EnvKeysDeclared = @($envKeyRecords).Count
	EnvKeysPresent = @($envKeyRecords | Where-Object { $_.Present }).Count
}
$recommendedActions = Get-RecommendedActions -ReadinessState $summary.ReadinessState -Configs $configEvidence -Endpoints $endpointEvidence

$result = [ordered]@{
	Root = $addonRoot
	SummaryOnly = [bool]$SummaryOnly
	SkipDefaultEndpoints = [bool]$SkipDefaultEndpoints
	Summary = $summary
	RecommendedActions = @($recommendedActions)
	NextCommands = @(Get-NextCommands)
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
