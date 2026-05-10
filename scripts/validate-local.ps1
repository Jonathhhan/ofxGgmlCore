param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$SkipAddonTests,
	[switch]$SkipSetupDryRun,
	[switch]$SkipProjectRepair,
	[switch]$SkipLaunchDryRun,
	[switch]$SkipDoctor,
	[switch]$SkipArtifactHygiene
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

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (!$SkipAddonTests) {
	Invoke-CheckedScript `
		-Label "Running headless addon tests" `
		-ScriptPath (Join-Path $scriptRoot "test-addon.ps1") `
		-Parameters @{
			Configuration = $Configuration
		}
}

if (!$SkipSetupDryRun) {
	Invoke-CheckedScript `
		-Label "Checking setup dry-run plan" `
		-ScriptPath (Join-Path $scriptRoot "test-setup-dry-run.ps1") `
		-Parameters @{
			Configuration = $Configuration
			Platform = $Platform
		}
}

if (!$SkipProjectRepair) {
	Invoke-CheckedScript `
		-Label "Checking generated project repair" `
		-ScriptPath (Join-Path $scriptRoot "test-example-project-repair.ps1") `
		-Parameters @{
			Configuration = $Configuration
			Platform = $Platform
		}
}

if (!$SkipLaunchDryRun) {
	Invoke-CheckedScript `
		-Label "Checking launch dry-runs" `
		-ScriptPath (Join-Path $scriptRoot "test-launch-dry-run.ps1") `
		-Parameters @{
			Configuration = $Configuration
			Platform = $Platform
		}
}

if (!$SkipDoctor) {
	Invoke-CheckedScript `
		-Label "Checking local doctor" `
		-ScriptPath (Join-Path $scriptRoot "doctor.ps1") `
		-Parameters @{
			NoServerProbe = $true
		}
}

if (!$SkipArtifactHygiene) {
	Invoke-CheckedScript `
		-Label "Checking generated artifact hygiene" `
		-ScriptPath (Join-Path $scriptRoot "test-artifact-hygiene.ps1") `
		-Parameters @{
			Configuration = $Configuration
			Platform = $Platform
		}
}

Write-Step "Local validation passed"
