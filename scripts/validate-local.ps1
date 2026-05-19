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

# Verify README references key entry points
Assert-FileContains (Join-Path $addonRoot "README.md") "first-run" "README first-run"
Assert-FileEntries (Join-Path $addonRoot "README.md") "doctor" "README doctor"
Assert-FileContains (Join-Path $addonRoot "README.md") "validate-local" "README validate-local"
Assert-FileContains (Join-Path $addonRoot "README.md") "release-candidate" "README release-candidate"
Assert-FileContains (Join-Path $addonRoot "README.md") "ofxGgmlLlama" "README companion addon"
Assert-FileContains (Join-Path $addonRoot "README.md") "Core Contract" "README contract"

# Verify required scripts exist
foreach ($requiredScript in @(
	"setup-ggml.bat",
	"setup-ggml.ps1",
	"first-run.bat",
	"first-run.ps1",
	"doctor.bat",
	"doctor.ps1",
	"build-simple-example.bat",
	"build-simple-example.ps1",
	"run-simple-example.bat",
	"run-simple-example.ps1",
	"list-models.bat",
	"list-models.ps1",
	"validate-local.bat",
	"validate-local.ps1",
	"release-candidate.bat",
	"release-candidate.ps1",
	"check-ecosystem-readiness.bat",
	"check-ecosystem-readiness.ps1",
	"audit-ecosystem.bat",
	"audit-ecosystem.ps1",
	"plan-ecosystem.bat",
	"plan-ecosystem.ps1",
	"plan-coding-agent-work.bat",
	"plan-coding-agent-work.ps1",
	"plan-local-codex.bat",
	"plan-local-codex.ps1",
	"plan-of-smoke-build.bat",
	"plan-of-smoke-build.ps1",
	"select-smoke-build-target.bat",
	"select-smoke-build-target.ps1",
	"plan-smoke-build-target-handoff.bat",
	"plan-smoke-build-target-handoff.ps1",
	"check-smoke-build-target-preflight.bat",
	"check-smoke-build-target-preflight.ps1",
	"check-smoke-build-target-postflight.bat",
	"check-smoke-build-target-postflight.ps1",
	"plan-smoke-build-project-repair.bat",
	"plan-smoke-build-project-repair.ps1",
	"plan-smoke-build-compile.bat",
	"plan-smoke-build-compile.ps1",
	"build-smoke-example.bat",
	"build-smoke-example.ps1",
	"run-smoke-build-ci.bat",
	"run-smoke-build-ci.ps1",
	"build-runtime-smoke.bat",
	"build-runtime-smoke.ps1",
	"build-runtime-smoke.sh",
	"plan-agent-branch-cleanup.bat",
	"plan-agent-branch-cleanup.ps1",
	"plan-release-readiness.bat",
	"plan-release-readiness.ps1",
	"assert-release-readiness.bat",
	"assert-release-readiness.ps1",
	"fetch-smoke-build-ci-report.bat",
	"fetch-smoke-build-ci-report.ps1",
	"fetch-workflow-status.bat",
	"fetch-workflow-status.py",
	"generate-workflow-status-plan.bat",
	"generate-workflow-status-plan.py",
	"plan-doctor-rollout.bat",
	"plan-doctor-rollout.ps1",
	"plan-backend-runtime-verification.bat",
	"plan-backend-runtime-verification.ps1",
	"plan-backend-runtime-verification.sh",
	"get-ecosystem.ps1",
	"status-family.bat",
	"status-family.ps1",
	"write-agent-instructions.bat",
	"write-agent-instructions.ps1"
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

	Invoke-CheckedScript `
		-Label "Checking model discovery JSON" `
		-ScriptPath (Join-Path $scriptRoot "test-model-discovery.ps1")
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
	-Label "Checking release readiness planner" `
	-ScriptPath (Join-Path $scriptRoot "test-release-readiness-plan.ps1")

Invoke-CheckedScript `
	-Label "Checking release readiness gate" `
	-ScriptPath (Join-Path $scriptRoot "test-release-readiness-gate.ps1")

Invoke-CheckedScript `
	-Label "Checking backend verification planning" `
	-ScriptPath (Join-Path $scriptRoot "test-backend-verification-plan.ps1")
Invoke-CheckedScript `
	-Label "Checking inference smoke contract" `
	-ScriptPath (Join-Path $scriptRoot "test-inference-smoke-contract.ps1")

Invoke-CheckedScript `
	-Label "Checking local Codex planner" `
	-ScriptPath (Join-Path $scriptRoot "test-local-codex-plan.ps1")

Invoke-CheckedScript `
	-Label "Checking ecosystem readiness" `
	-ScriptPath (Join-Path $scriptRoot "test-ecosystem-readiness.ps1")

Invoke-CheckedScript `
	-Label "Checking ecosystem agent planner" `
	-ScriptPath (Join-Path $scriptRoot "test-ecosystem-agent.ps1")

Invoke-CheckedScript `
	-Label "Checking coding agent work planner" `
	-ScriptPath (Join-Path $scriptRoot "test-coding-agent-work-plan.ps1")

Invoke-CheckedScript `
	-Label "Checking openFrameworks smoke build planner" `
	-ScriptPath (Join-Path $scriptRoot "test-of-smoke-build-plan.ps1")

Invoke-CheckedScript `
	-Label "Checking smoke-build CI report summary" `
	-ScriptPath (Join-Path $scriptRoot "test-smoke-build-ci-report.ps1")

Invoke-CheckedScript `
	-Label "Checking smoke-build CI artifact fetch auth" `
	-ScriptPath (Join-Path $scriptRoot "test-fetch-smoke-build-ci-report.ps1")

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
