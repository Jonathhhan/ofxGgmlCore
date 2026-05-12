param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$SkipAddonTests,
	[switch]$SkipSetupDryRun,
	[switch]$SkipProjectRepair,
	[switch]$SkipLaunchDryRun,
	[switch]$SkipFirstRunDryRun,
	[switch]$SkipModelList,
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

function Assert-FileContains {
	param(
		[string]$Path,
		[string]$Pattern,
		[string]$Label
	)
	$content = Get-Content -LiteralPath $Path -Raw
	if ($content -notmatch $Pattern) {
		throw "$Label did not contain expected pattern: $Pattern"
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot

foreach ($shellWrapper in Get-ChildItem -LiteralPath $scriptRoot -Filter "*.sh" -File) {
	$content = Get-Content -LiteralPath $shellWrapper.FullName -Raw
	if ($content -match "exec (pwsh|powershell) -NoProfile -File" -or
		$content -match "(^|`n)\s*(pwsh|powershell) -NoProfile -File") {
		throw "Shell wrapper should use -ExecutionPolicy Bypass when launching PowerShell: $($shellWrapper.Name)"
	}
}

Assert-FileContains (Join-Path $addonRoot "README.md") "./scripts/first-run.sh" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "./scripts/validate-local.sh" "README"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "./scripts/setup-ggml.sh -CpuOnly" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "./scripts/run-simple-example.sh -Build" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\EXAMPLES.md") "./scripts/run-simple-example.sh -Build" "examples docs"

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

if (!$SkipFirstRunDryRun) {
	Invoke-CheckedScript `
		-Label "Checking first-run dry-run" `
		-ScriptPath (Join-Path $scriptRoot "first-run.ps1") `
		-Parameters @{
			DryRun = $true
			CpuOnly = $true
			SkipDoctor = $true
		}
}

if (!$SkipModelList) {
	Invoke-CheckedScript `
		-Label "Checking model discovery" `
		-ScriptPath (Join-Path $scriptRoot "list-models.ps1")
}

if (!$SkipDoctor) {
	Invoke-CheckedScript `
		-Label "Checking local doctor" `
		-ScriptPath (Join-Path $scriptRoot "doctor.ps1")
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
