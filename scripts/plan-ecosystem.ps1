param(
	[string]$OutputPath = "",
	[switch]$SummaryOnly,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-EcosystemPlanBuckets {
	param([array]$Statuses)

	$managedStatuses = @($Statuses | Where-Object { $_.Known })
	$detectedStatuses = @($Statuses | Where-Object { !$_.Known })
	$unclassifiedDetected = @($detectedStatuses | Where-Object { !$_.Classified })
	$classifiedDetected = @($detectedStatuses | Where-Object { $_.Classified })
	$missingRepos = @($managedStatuses | Where-Object { !$_.Present })
	$missingValidation = @($managedStatuses | Where-Object { $_.Present -and !$_.ValidateScript })
	$dirtyRepos = @($managedStatuses | Where-Object { $_.Present -and $_.DirtyCount -gt 0 })
	$missingDoctor = @($managedStatuses | Where-Object { $_.Present -and !$_.DoctorScript -and $_.Name -ne "ofxGgmlWorkflows" })
	$readyManaged = @($managedStatuses | Where-Object {
		$_.Present -and
		$_.DirtyCount -eq 0 -and
		$_.ValidateScript -and
		$_.AgentsInstructions -and
		$_.HermesInstructions -and
		$_.CopilotInstructions -and
		$_.CopilotEcosystemInstructions
	})

	[pscustomobject]@{
		ManagedStatuses = $managedStatuses
		DetectedStatuses = $detectedStatuses
		UnclassifiedDetected = $unclassifiedDetected
		ClassifiedDetected = $classifiedDetected
		MissingRepos = $missingRepos
		MissingValidation = $missingValidation
		DirtyRepos = $dirtyRepos
		MissingDoctor = $missingDoctor
		ReadyManaged = $readyManaged
	}
}

function Get-EcosystemSummary {
	param([pscustomobject]$Buckets)

	[pscustomobject]@{
		ManagedRepositories = @($Buckets.ManagedStatuses).Count
		PresentManagedRepositories = @($Buckets.ManagedStatuses | Where-Object { $_.Present }).Count
		ReadyManagedRepositories = @($Buckets.ReadyManaged).Count
		DetectedReferenceRepositories = @($Buckets.DetectedStatuses).Count
		ClassifiedReferenceRepositories = @($Buckets.ClassifiedDetected).Count
		UnclassifiedDetectedRepositories = @($Buckets.UnclassifiedDetected).Count
		DirtyManagedRepositories = @($Buckets.DirtyRepos).Count
		MissingManagedRepositories = @($Buckets.MissingRepos).Count
		MissingValidationEntrypoints = @($Buckets.MissingValidation).Count
		MissingDoctorEntrypoints = @($Buckets.MissingDoctor).Count
	}
}

function Get-PlanningPriorityLines {
	param([pscustomobject]$Buckets)

	$priorities = New-Object System.Collections.Generic.List[string]
	if (@($Buckets.MissingRepos).Count -gt 0) {
		$priorities.Add("Restore or intentionally remove missing repositories from the family map: $(@($Buckets.MissingRepos | ForEach-Object { $_.Name }) -join ', ').")
	}
	if (@($Buckets.UnclassifiedDetected).Count -gt 0) {
		$priorities.Add("Classify auto-detected repositories before enabling generated instructions: $(@($Buckets.UnclassifiedDetected | ForEach-Object { $_.Name }) -join ', ').")
	}
	if (@($Buckets.ClassifiedDetected).Count -gt 0) {
		$priorities.Add("Keep classified legacy/reference siblings out of managed automation unless explicitly promoted: $(@($Buckets.ClassifiedDetected | ForEach-Object { $_.Name }) -join ', ').")
	}
	if (@($Buckets.MissingValidation).Count -gt 0) {
		$priorities.Add("Add local validation entry points before feature work: $(@($Buckets.MissingValidation | ForEach-Object { $_.Name }) -join ', ').")
	}
	if (@($Buckets.DirtyRepos).Count -gt 0) {
		$dirtyList = @($Buckets.DirtyRepos | ForEach-Object { "$($_.Name) ($($_.DirtyCount))" }) -join ", "
		$priorities.Add("Review dirty repositories before cross-repo edits: $dirtyList.")
	}
	if (@($Buckets.MissingDoctor).Count -gt 0) {
		$priorities.Add("Use ``scripts\plan-doctor-rollout.bat`` for lanes that still lack quick local diagnostics: $(@($Buckets.MissingDoctor | ForEach-Object { $_.Name }) -join ', ').")
	}
	if (@($Buckets.MissingRepos).Count -eq 0 -and @($Buckets.MissingValidation).Count -eq 0) {
		$priorities.Add("Keep agent and validation instructions current before widening any addon runtime behavior.")
	}
	$priorities.Add("Make one backend lane genuinely useful before broadening every companion addon.")

	@($priorities.ToArray())
}

function Get-AgentGuardrailLines {
	@(
		"Start in planning, documentation, workflow, or validation files.",
		"Do not edit addon source unless the user explicitly asks for addon behavior.",
		'Keep `ofxGgmlCore` as the shared base and avoid reverse dependencies from Core to companions.',
		"Preserve generated artifact hygiene across all repositories."
	)
}

function Get-SmokeBuildLifecycleCommands {
	@(
		"scripts\plan-of-smoke-build.bat",
		"scripts\select-smoke-build-target.bat -Stage generate-project",
		"scripts\plan-smoke-build-target-handoff.bat -Stage generate-project",
		"scripts\check-smoke-build-target-preflight.bat -Stage generate-project",
		"scripts\check-smoke-build-target-postflight.bat -Stage generate-project",
		"scripts\plan-smoke-build-project-repair.bat -Stage verify-generated-project",
		"scripts\plan-smoke-build-compile.bat -Stage compile-example",
		"scripts\build-smoke-example.bat -Repository ofxGgmlSam -Example ofxGgmlSamPointExample"
	)
}

function Get-SuggestedValidationCommands {
	@(
		"scripts\write-agent-instructions.bat -Check",
		"scripts\audit-ecosystem.bat -Strict",
		"scripts\audit-ecosystem.bat -Strict -Json -SummaryOnly",
		"scripts\plan-ecosystem.bat",
		"scripts\plan-ecosystem.bat -Json -SummaryOnly",
		"scripts\plan-coding-agent-work.bat",
		"scripts\plan-smoke-build-target-handoff.bat -Stage generate-project",
		"scripts\check-smoke-build-target-preflight.bat -Stage generate-project",
		"scripts\check-smoke-build-target-postflight.bat -Stage generate-project",
		"scripts\plan-smoke-build-project-repair.bat -Stage verify-generated-project",
		"scripts\plan-smoke-build-compile.bat -Stage compile-example",
		"scripts\build-smoke-example.bat -Repository ofxGgmlSam -Example ofxGgmlSamPointExample",
		"scripts\plan-doctor-rollout.bat",
		"scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly",
		"scripts\status-family.bat"
	)
}

function ConvertTo-MarkdownPlan {
	param([array]$Statuses)

	$buckets = Get-EcosystemPlanBuckets -Statuses $Statuses
	$planningPriorities = @(Get-PlanningPriorityLines -Buckets $buckets)
	$agentGuardrails = @(Get-AgentGuardrailLines)
	$smokeBuildLifecycle = @(Get-SmokeBuildLifecycleCommands)
	$suggestedValidation = @(Get-SuggestedValidationCommands)

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# ofxGgml Ecosystem Agent Plan")
	$lines.Add("")
	$lines.Add("Generated from local repository status. Treat this as a planning handoff, not as permission to edit addon source.")
	$lines.Add("")
	$lines.Add("## Snapshot")
	$lines.Add("")
	$lines.Add("| Repository | Lane | Managed | State | Validation | Dirty |")
	$lines.Add("| --- | --- | --- | --- | --- | --- |")
	foreach ($status in $Statuses) {
		$managed = if ($status.Known) { "yes" } else { "detected" }
		$state = if ($status.Present) { "present" } else { "missing" }
		$validation = if ($status.ValidateScript) { "yes" } else { "missing" }
		$dirty = if ($status.DirtyCount -gt 0) { [string]$status.DirtyCount } else { "clean" }
		$lines.Add("| $($status.Name) | $($status.Lane) | $managed | $state | $validation | $dirty |")
	}

	$lines.Add("")
	$lines.Add("## Planning Priorities")
	$lines.Add("")
	foreach ($priority in $planningPriorities) {
		$lines.Add("- $priority")
	}

	$lines.Add("")
	$lines.Add("## Agent Guardrails")
	$lines.Add("")
	foreach ($guardrail in $agentGuardrails) {
		$lines.Add("- $guardrail")
	}
	$lines.Add("")
	$lines.Add("## Smoke-Build Target Lifecycle")
	$lines.Add("")
	$lines.Add("Use the Core smoke-build control plane before any agent runs projectGenerator:")
	$lines.Add("")
	$lines.Add('```powershell')
	foreach ($command in $smokeBuildLifecycle) {
		$lines.Add($command)
	}
	$lines.Add('```')
	$lines.Add("")
	$lines.Add("Run projectGenerator only after preflight reports the selected target is ready, then use postflight to review generated files, addon wiring, and git impact. Use the repair planner when postflight reports missing Visual Studio addon references, then use the compile planner for focused build handoff and the emitted addon-owned or generic build command.")
	$lines.Add("")
	$lines.Add("## Suggested Validation")
	$lines.Add("")
	$lines.Add('```powershell')
	foreach ($command in $suggestedValidation) {
		$lines.Add($command)
	}
	$lines.Add('```')

	return $lines -join [Environment]::NewLine
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusScript = Join-Path $scriptRoot "status-family.ps1"
$statusJson = & $statusScript -Json
if (!$?) {
	throw "status-family.ps1 failed."
}

$status = $statusJson | ConvertFrom-Json
$statuses = @($status.Addons)

if ($Json) {
	$buckets = Get-EcosystemPlanBuckets -Statuses $statuses
	$addonSummaries = @($statuses | ForEach-Object {
		[pscustomobject]@{
			Name = [string]$_.Name
			Known = [bool]$_.Known
			Classified = [bool]$_.Classified
			Present = [bool]$_.Present
			DirtyCount = [int]$_.DirtyCount
			ValidateScript = [bool]$_.ValidateScript
			AgentWorkflowGuide = [bool]$_.AgentWorkflowGuide
		}
	})
	$result = [pscustomobject]@{
		Root = $status.Root
		GeneratedFrom = "scripts/status-family.ps1 -Json"
		SummaryOnly = [bool]$SummaryOnly
		Summary = Get-EcosystemSummary -Buckets $buckets
		PlanningPriorities = @(Get-PlanningPriorityLines -Buckets $buckets)
		AgentGuardrails = @(Get-AgentGuardrailLines)
		SmokeBuildLifecycle = @(Get-SmokeBuildLifecycleCommands)
		SuggestedValidation = @(Get-SuggestedValidationCommands)
		RepositorySummaries = $addonSummaries
	}
	if (!$SummaryOnly) {
		$result | Add-Member -NotePropertyName Addons -NotePropertyValue $statuses
	}
	$content = $result | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownPlan -Statuses $statuses
}

if (![string]::IsNullOrWhiteSpace($OutputPath)) {
	$target = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
		$OutputPath
	} else {
		Join-Path (Split-Path -Parent $scriptRoot) $OutputPath
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
