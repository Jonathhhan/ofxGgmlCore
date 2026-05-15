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
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\audit-ecosystem.bat -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\status-family.bat -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\check-ecosystem-readiness.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-ecosystem.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-ecosystem.bat -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-coding-agent-work.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-coding-agent-work.bat -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-of-smoke-build.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-of-smoke-build.bat -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\select-smoke-build-target.bat -Stage generate-project -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-smoke-build-target-handoff.bat -Stage generate-project -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-agent-branch-cleanup.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-doctor-rollout.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-doctor-rollout.bat -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-release-readiness.bat" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\plan-release-readiness.bat -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\list-models.bat -Json" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "backend capability evidence" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "scripts\\write-agent-instructions.bat" "README"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENT_WORK.md") "Auto-Detected Completed Planning Guides" "coding agent work snapshot"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENT_WORK.md") "Workflow guides detected" "coding agent work snapshot"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENT_WORK.md") "plan-of-smoke-build.ps1" "coding agent work snapshot"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENT_WORK.md") "plan-release-readiness.ps1" "coding agent work snapshot"
Assert-FileContains (Join-Path $addonRoot "docs\RELEASE_READINESS.md") "scripts\\release-candidate.bat" "release readiness docs"
Assert-FileContains (Join-Path $addonRoot "docs\RELEASE_READINESS.md") "scripts\\plan-release-readiness.bat" "release readiness docs"
Assert-FileContains (Join-Path $addonRoot "docs\RELEASE_READINESS.md") "backend capability evidence" "release readiness docs"
Assert-FileContains (Join-Path $addonRoot "docs\addon-family-sync.md") "./scripts/release-candidate.sh" "addon family sync docs"
Assert-FileContains (Join-Path $addonRoot "docs\addon-family-sync.md") "not a companion-addon" "addon family sync docs"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "Workflow Observability" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "scripts\\status-family.bat -Json" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "scripts\\plan-ecosystem.bat -Json" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "scripts\\plan-coding-agent-work.bat -Json" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "scripts\\plan-doctor-rollout.bat -Json" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "scripts\\plan-of-smoke-build.bat -Json" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "scripts\\select-smoke-build-target.bat -Stage generate-project -Json" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "scripts\\plan-smoke-build-target-handoff.bat -Stage generate-project -Json" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "scripts\\plan-release-readiness.bat -Json" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\CONTROL_PLANE_NEXT_STEPS.md") "scripts\\list-models.bat -Json" "control plane next steps"
Assert-FileContains (Join-Path $addonRoot "docs\operational-validation-status.md") "structured JSON handoff" "operational validation status"
Assert-FileContains (Join-Path $addonRoot "docs\portal-index.md") "CODING_AGENT_WORK.md" "portal index"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_MANIFEST.json") "ofxGgmlCore" "ecosystem manifest"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "Do not edit addon source" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "auto-detected" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "status-family.bat -Json" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "audit-ecosystem.bat -Json" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "check-ecosystem-readiness" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "DoctorTests" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "plan-coding-agent-work" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "AgentGuardrails" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "SuggestedFileList" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "ValidationCommands" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "select-smoke-build-target" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "select-smoke-build-target.bat -Stage generate-project -Json" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "plan-smoke-build-target-handoff.bat -Stage generate-project -Json" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "plan-of-smoke-build.bat -Json" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "plan-release-readiness.bat -Json" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "list-models.bat -Json" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "check-smoke-build-target-preflight" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "check-smoke-build-target-postflight" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "plan-agent-branch-cleanup" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "plan-doctor-rollout" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\ECOSYSTEM_AGENT.md") "plan-doctor-rollout.bat -Json" "ecosystem agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENTS.md") "AGENTS.md" "coding agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENTS.md") "HERMES.md" "coding agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENTS.md") "copilot-instructions.md" "coding agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\CODING_AGENTS.md") ".github/instructions" "coding agent docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "./scripts/setup-ggml.sh -CpuOnly" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "addon_config.mk" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "./scripts/run-simple-example.sh -Build" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\EXAMPLES.md") "./scripts/run-simple-example.sh -Build" "examples docs"

foreach ($requiredScript in @(
	"release-candidate.bat",
	"release-candidate.ps1",
	"release-candidate.sh",
	"check-ecosystem-readiness.bat",
	"check-ecosystem-readiness.ps1",
	"check-ecosystem-readiness.sh",
	"audit-ecosystem.bat",
	"audit-ecosystem.ps1",
	"audit-ecosystem.sh",
	"plan-ecosystem.bat",
	"plan-ecosystem.ps1",
	"plan-ecosystem.sh",
	"plan-coding-agent-work.bat",
	"plan-coding-agent-work.ps1",
	"plan-coding-agent-work.sh",
	"plan-of-smoke-build.bat",
	"plan-of-smoke-build.ps1",
	"plan-of-smoke-build.sh",
	"select-smoke-build-target.bat",
	"select-smoke-build-target.ps1",
	"select-smoke-build-target.sh",
	"plan-smoke-build-target-handoff.bat",
	"plan-smoke-build-target-handoff.ps1",
	"plan-smoke-build-target-handoff.sh",
	"check-smoke-build-target-preflight.bat",
	"check-smoke-build-target-preflight.ps1",
	"check-smoke-build-target-preflight.sh",
	"check-smoke-build-target-postflight.bat",
	"check-smoke-build-target-postflight.ps1",
	"check-smoke-build-target-postflight.sh",
	"plan-smoke-build-project-repair.bat",
	"plan-smoke-build-project-repair.ps1",
	"plan-smoke-build-project-repair.sh",
	"plan-smoke-build-compile.bat",
	"plan-smoke-build-compile.ps1",
	"plan-smoke-build-compile.sh",
	"build-smoke-example.bat",
	"build-smoke-example.ps1",
	"build-smoke-example.sh",
	"build-runtime-smoke.bat",
	"build-runtime-smoke.ps1",
	"build-runtime-smoke.sh",
	"plan-agent-branch-cleanup.bat",
	"plan-agent-branch-cleanup.ps1",
	"plan-agent-branch-cleanup.sh",
	"plan-release-readiness.bat",
	"plan-release-readiness.ps1",
	"plan-release-readiness.sh",
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
	-Label "Checking workflow status report" `
	-ScriptPath (Join-Path $scriptRoot "test-workflow-status-report.ps1")

Invoke-CheckedScript `
	-Label "Checking release readiness score" `
	-ScriptPath (Join-Path $scriptRoot "test-release-readiness-score.ps1")

Invoke-CheckedScript `
	-Label "Checking release readiness planner" `
	-ScriptPath (Join-Path $scriptRoot "test-release-readiness-plan.ps1")

Invoke-CheckedScript `
	-Label "Checking backend verification planning" `
	-ScriptPath (Join-Path $scriptRoot "test-backend-verification-plan.ps1")

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
