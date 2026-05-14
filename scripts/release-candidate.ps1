param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$SkipExampleBuild,
	[switch]$AllowGpuAddonConfig
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Invoke-CheckedScript {
	param(
		[string]$Label,
		[string]$ScriptPath,
		[hashtable]$Parameters = @{}
	)
	Write-Step $Label
	& $ScriptPath @Parameters
	if (!$?) {
		throw "$Label failed."
	}
}

function Invoke-GitCheck {
	param([string[]]$Arguments)
	$output = & git @Arguments 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "git $($Arguments -join ' ') failed: $($output -join "`n")"
	}
	return @($output | ForEach-Object { $_.ToString() })
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")

Push-Location $addonRoot
try {
	Invoke-CheckedScript `
		-Label "Checking addon_config.mk CPU release baseline" `
		-ScriptPath (Join-Path $scriptRoot "test-addon-config-baseline.ps1") `
		-Parameters @{
			AllowGpuBackends = $AllowGpuAddonConfig
		}

	Invoke-CheckedScript `
		-Label "Checking Hermes/Codex/Copilot instruction files" `
		-ScriptPath (Join-Path $scriptRoot "write-agent-instructions.ps1") `
		-Parameters @{
			Check = $true
		}

	Invoke-CheckedScript `
		-Label "Running local validation" `
		-ScriptPath (Join-Path $scriptRoot "validate-local.ps1") `
		-Parameters @{
			Configuration = $Configuration
			Platform = $Platform
		}

	if (!$SkipExampleBuild) {
		Invoke-CheckedScript `
			-Label "Building Core example" `
			-ScriptPath (Join-Path $scriptRoot "build-simple-example.ps1") `
			-Parameters @{
				Configuration = $Configuration
				Platform = $Platform
			}
	}

	Invoke-CheckedScript `
		-Label "Checking family status output" `
		-ScriptPath (Join-Path $scriptRoot "status-family.ps1")

	Write-Step "Checking ignored/generated artifact view"
	$null = Invoke-GitCheck @("status", "--short", "--ignored")

	Write-Step "Release candidate checks passed"
} finally {
	Pop-Location
}
