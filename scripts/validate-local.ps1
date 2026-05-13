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
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\release-candidate.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\audit-ecosystem.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-ecosystem.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-agent-branch-cleanup.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-doctor-rollout.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\write-agent-instructions.bat" "README"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_MANIFEST.json") "ofxGgmlCore" "ecosystem manifest"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "Do not edit addon source" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "auto-detected" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "plan-agent-branch-cleanup" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "plan-doctor-rollout" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENTS.md") "AGENTS.md" "coding agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENTS.md") "HERMES.md" "coding agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENTS.md") "copilot-instructions.md" "coding agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "./scripts/setup-ggml.sh -CpuOnly" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "addon_config.mk" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "./scripts/run-simple-example.sh -Build" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\EXAMPLES.md") "./scripts/run-simple-example.sh -Build" "examples docs"

foreach ($requiredScript in @(
	"release-candidate.bat",
	"release-candidate.ps1",
	"release-candidate.sh",
	"audit-ecosystem.bat",
	"audit-ecosystem.ps1",
	"audit-ecosystem.sh",
	"plan-ecosystem.bat",
	"plan-ecosystem.ps1",
	"plan-ecosystem.sh",
	"plan-agent-branch-cleanup.bat",
	"plan-agent-branch-cleanup.ps1",
	"plan-agent-branch-cleanup.sh",
	"plan-doctor-rollout.bat",
	"plan-doctor-rollout.ps1",
	"plan-doctor-rollout.sh",
	"get-ecosystem.ps1",
	"status-family.bat",
	"status-family.ps1",
	"status-family.sh",
	"write-agent-instructions.bat",
	"write-agent-instructions.ps1",
	"write-agent-instructions.sh"
)) {
	if (!(Test-Path -LiteralPath (Join-Path $scriptRoot $requiredScript) -PathType Leaf)) {
		throw "Missing expected script: scripts\$requiredScript"
	}
}

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
		-Label "Checking doctor smoke output" `
		-ScriptPath (Join-Path $scriptRoot "test-doctor.ps1")

	Invoke-CheckedScript `
		-Label "Checking local doctor" `
		-ScriptPath (Join-Path $scriptRoot "doctor.ps1")
}

Invoke-CheckedScript `
	-Label "Checking ecosystem manifest" `
	-ScriptPath (Join-Path $scriptRoot "test-ecosystem-manifest.ps1")

Invoke-CheckedScript `
	-Label "Checking family status smoke output" `
	-ScriptPath (Join-Path $scriptRoot "test-family-status.ps1")

Invoke-CheckedScript `
	-Label "Checking ecosystem auto-discovery" `
	-ScriptPath (Join-Path $scriptRoot "test-ecosystem-discovery.ps1")

Invoke-CheckedScript `
	-Label "Checking ecosystem audit" `
	-ScriptPath (Join-Path $scriptRoot "test-ecosystem-audit.ps1")

Invoke-CheckedScript `
	-Label "Checking ecosystem agent planner" `
	-ScriptPath (Join-Path $scriptRoot "test-ecosystem-agent.ps1")

Invoke-CheckedScript `
	-Label "Checking agent branch cleanup planner" `
	-ScriptPath (Join-Path $scriptRoot "test-agent-branch-cleanup.ps1")

Invoke-CheckedScript `
	-Label "Checking doctor rollout planner" `
	-ScriptPath (Join-Path $scriptRoot "test-doctor-rollout-plan.ps1")

Invoke-CheckedScript `
	-Label "Checking agent instruction generator" `
	-ScriptPath (Join-Path $scriptRoot "test-agent-instructions.ps1")

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
