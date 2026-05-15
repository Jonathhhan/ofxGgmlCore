param(
	[string]$OutputPath = "",
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Split-AgentTaskList {
	param([string]$Value)

	if ([string]::IsNullOrWhiteSpace($Value)) {
		return @()
	}

	@($Value -split ";" |
		ForEach-Object { $_.Trim() } |
		Where-Object { ![string]::IsNullOrWhiteSpace($_) })
}

function New-AgentTask {
	param(
		[string]$Priority,
		[string]$Repository,
		[string]$Lane,
		[string]$Category,
		[string]$Task,
		[string]$Rationale,
		[string]$SuggestedFiles,
		[string]$Validation
	)

	[pscustomobject]@{
		Priority = $Priority
		Repository = $Repository
		Lane = $Lane
		Category = $Category
		Task = $Task
		Rationale = $Rationale
		SuggestedFiles = $SuggestedFiles
		SuggestedFileList = @(Split-AgentTaskList -Value $SuggestedFiles)
		Validation = $Validation
		ValidationCommands = @(Split-AgentTaskList -Value $Validation)
	}
}

function Get-CodingAgentQueueSummary {
	param(
		[array]$Tasks,
		[array]$Statuses
	)

	$managed = @($Statuses | Where-Object { $_.Known })
	$detected = @($Statuses | Where-Object { !$_.Known })
	$workflowGuides = @($managed | Where-Object { $_.AgentWorkflowGuide })
	$readyManaged = @($managed | Where-Object {
		$_.Present -and
		$_.DirtyCount -eq 0 -and
		$_.ValidateScript -and
		$_.AgentsInstructions -and
		$_.HermesInstructions -and
		$_.CopilotInstructions -and
		$_.CopilotEcosystemInstructions
	})

	[pscustomobject]@{
		ManagedRepositories = $managed.Count
		ReadyManagedRepositories = $readyManaged.Count
		WorkflowGuidesDetected = $workflowGuides.Count
		DetectedReferenceRepositories = $detected.Count
		ProposedTasks = @($Tasks).Count
	}
}

function Get-CodingAgentGuardrails {
	@(
		"Work on planning, instructions, workflow, validation, and documentation first.",
		"Do not edit addon runtime/source behavior unless the user explicitly asks for that repository and behavior.",
		"Keep classified reference repositories out of generated automation unless they are intentionally promoted.",
		"Prefer one small repository-scoped pull request over broad cross-repo edits.",
		"Run the suggested validation before pushing."
	)
}

function ConvertTo-MarkdownQueue {
	param(
		[array]$Tasks,
		[array]$Statuses
	)

	$managed = @($Statuses | Where-Object { $_.Known })
	$detected = @($Statuses | Where-Object { !$_.Known })
	$workflowGuides = @($managed | Where-Object { $_.AgentWorkflowGuide })
	$readyManaged = @($managed | Where-Object {
		$_.Present -and
		$_.DirtyCount -eq 0 -and
		$_.ValidateScript -and
		$_.AgentsInstructions -and
		$_.HermesInstructions -and
		$_.CopilotInstructions -and
		$_.CopilotEcosystemInstructions
	})

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# ofxGgml Coding Agent Work Queue")
	$lines.Add("")
	$lines.Add("Generated from local ecosystem status. This queue is intended for Codex, GitHub Copilot, Hermes Agent, and similar coding assistants.")
	$lines.Add("")
	$lines.Add("## Snapshot")
	$lines.Add("")
	$lines.Add("| Metric | Count |")
	$lines.Add("| --- | ---: |")
	$lines.Add("| Managed repositories | $($managed.Count) |")
	$lines.Add("| Ready managed repositories | $($readyManaged.Count) |")
	$lines.Add("| Workflow guides detected | $($workflowGuides.Count) |")
	$lines.Add("| Detected reference repositories | $($detected.Count) |")
	$lines.Add("| Proposed tasks | $($Tasks.Count) |")
	$lines.Add("")
	$lines.Add("## Queue")
	$lines.Add("")
	$lines.Add("| Priority | Repository | Lane | Category | Task | Suggested files | Validation |")
	$lines.Add("| --- | --- | --- | --- | --- | --- | --- |")
	foreach ($task in $Tasks) {
		$lines.Add(('| {0} | `{1}` | `{2}` | {3} | {4} | `{5}` | `{6}` |' -f $task.Priority, $task.Repository, $task.Lane, $task.Category, $task.Task, $task.SuggestedFiles, $task.Validation))
	}
	$lines.Add("")
	if ($workflowGuides.Count -gt 0) {
		$lines.Add("## Auto-Detected Completed Planning Guides")
		$lines.Add("")
		$lines.Add("| Repository | Guide |")
		$lines.Add("| --- | --- |")
		foreach ($repo in @($workflowGuides | Sort-Object Name)) {
			$lines.Add(('| `{0}` | `{1}` |' -f $repo.Name, $repo.AgentWorkflowGuidePath))
		}
		$lines.Add("")
	}
	$lines.Add("## Guardrails")
	$lines.Add("")
	foreach ($guardrail in @(Get-CodingAgentGuardrails)) {
		$lines.Add("- $guardrail")
	}

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
$tasks = New-Object System.Collections.Generic.List[object]

foreach ($repo in $statuses) {
	if ($repo.Known -and !$repo.Present) {
		$tasks.Add((New-AgentTask `
			-Priority "P0" `
			-Repository $repo.Name `
			-Lane $repo.Lane `
			-Category "availability" `
			-Task "Restore the managed repository checkout or remove it from the managed ecosystem map." `
			-Rationale "Managed automation cannot reason about a missing repository." `
			-SuggestedFiles "ecosystem.json; scripts/get-ecosystem.ps1" `
			-Validation "scripts/status-family.bat"))
		continue
	}

	if (!$repo.Known -and !$repo.Classified) {
		$tasks.Add((New-AgentTask `
			-Priority "P0" `
			-Repository $repo.Name `
			-Lane $repo.Lane `
			-Category "classification" `
			-Task "Classify the detected repository before enabling generated agent instructions or workflows." `
			-Rationale "Auto-detected repositories should not enter managed automation by accident." `
			-SuggestedFiles "scripts/get-ecosystem.ps1; docs/ECOSYSTEM_AGENT.md" `
			-Validation "scripts/audit-ecosystem.bat -Strict"))
		continue
	}

	if (!$repo.Known) {
		continue
	}

	if ($repo.DirtyCount -gt 0) {
		$tasks.Add((New-AgentTask `
			-Priority "P1" `
			-Repository $repo.Name `
			-Lane $repo.Lane `
			-Category "hygiene" `
			-Task "Review and either publish or isolate local dirty changes before starting new agent work." `
			-Rationale "Dirty managed repositories can hide unrelated user work and make cross-repo changes unsafe." `
			-SuggestedFiles "repository working tree" `
			-Validation "git status --short"))
	}

	if (!$repo.ValidateScript) {
		$tasks.Add((New-AgentTask `
			-Priority "P1" `
			-Repository $repo.Name `
			-Lane $repo.Lane `
			-Category "validation" `
			-Task "Add or restore a local validation entrypoint for coding agents." `
			-Rationale "Codex and Copilot need a fast local command before they can safely change a repository." `
			-SuggestedFiles "scripts/validate-local.ps1; scripts/validate-local.bat; scripts/validate-local.sh" `
			-Validation "scripts/validate-local.bat"))
	}

	if (!$repo.AgentsInstructions -or !$repo.HermesInstructions -or !$repo.CopilotInstructions -or !$repo.CopilotEcosystemInstructions) {
		$tasks.Add((New-AgentTask `
			-Priority "P1" `
			-Repository $repo.Name `
			-Lane $repo.Lane `
			-Category "agent-instructions" `
			-Task "Regenerate missing Codex, Copilot, and Hermes instruction files." `
			-Rationale "Missing instruction files make agents relearn ecosystem boundaries and increase the chance of addon source edits." `
			-SuggestedFiles "AGENTS.md; HERMES.md; .github/copilot-instructions.md; .github/instructions/ofxggml-ecosystem.instructions.md" `
			-Validation "scripts/write-agent-instructions.bat -Check"))
	}
}

$managedReady = @($statuses | Where-Object {
	$_.Known -and
	$_.Present -and
	$_.DirtyCount -eq 0 -and
	$_.ValidateScript -and
	$_.AgentsInstructions -and
	$_.HermesInstructions -and
	$_.CopilotInstructions -and
	$_.CopilotEcosystemInstructions
})

if ($tasks.Count -eq 0 -and $managedReady.Count -gt 0) {
	$core = @($managedReady | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
	if ($core.Count -gt 0) {
		$tasks.Add((New-AgentTask `
			-Priority "P1" `
			-Repository "ofxGgmlCore" `
			-Lane $core[0].Lane `
			-Category "control-plane" `
			-Task "Keep the ecosystem control plane current by refreshing queue, readiness, smoke-build, workflow action summaries, and release-evidence docs." `
			-Rationale "When every managed repository is instruction-ready, the next safest work is improving shared planning, smoke-build, and release-readiness signals." `
			-SuggestedFiles "docs/CODING_AGENT_WORK.md; docs/CONTROL_PLANE_NEXT_STEPS.md; docs/operational-validation-status.md; docs/of-smoke-build-strategy.md; docs/release-gating-strategy.md; scripts/check-ecosystem-readiness.ps1; scripts/plan-of-smoke-build.ps1; scripts/select-smoke-build-target.ps1; scripts/plan-smoke-build-target-handoff.ps1; scripts/check-smoke-build-target-preflight.ps1; scripts/check-smoke-build-target-postflight.ps1; scripts/plan-smoke-build-project-repair.ps1; scripts/plan-smoke-build-compile.ps1; scripts/build-smoke-example.ps1; scripts/fetch-workflow-status.py; scripts/generate-release-readiness-score.py; scripts/plan-release-readiness.ps1" `
			-Validation "scripts/check-ecosystem-readiness.bat -SkipDoctorTests; scripts/test-workflow-status-report.ps1; scripts/test-release-readiness-score.ps1; scripts/plan-smoke-build-target-handoff.bat -Stage generate-project; scripts/check-smoke-build-target-preflight.bat -Stage generate-project; scripts/check-smoke-build-target-postflight.bat -Stage generate-project; scripts/plan-smoke-build-project-repair.bat -Stage verify-generated-project; scripts/plan-smoke-build-compile.bat -Stage compile-example; scripts/build-smoke-example.bat -Repository ofxGgmlSam -Example ofxGgmlSamPointExample"))
	}

	foreach ($laneRepo in @($managedReady | Where-Object { $_.Name -ne "ofxGgmlCore" -and $_.Name -ne "ofxGgmlWorkflows" -and !$_.AgentWorkflowGuide } | Sort-Object Name)) {
		$tasks.Add((New-AgentTask `
			-Priority "P2" `
			-Repository $laneRepo.Name `
			-Lane $laneRepo.Lane `
			-Category "lane-uplift" `
			-Task "Plan one repository-scoped documentation or validation improvement for this lane without changing addon runtime behavior." `
			-Rationale "The ecosystem is ready for lane-by-lane usefulness work, but each change should remain reviewable." `
			-SuggestedFiles "README.md; docs; scripts/validate-local.ps1; AGENTS.md" `
			-Validation "scripts/validate-local.bat"))
	}

	$workflow = @($managedReady | Where-Object { $_.Name -eq "ofxGgmlWorkflows" } | Select-Object -First 1)
	if ($workflow.Count -gt 0 -and !$workflow[0].AgentWorkflowGuide) {
		$tasks.Add((New-AgentTask `
			-Priority "P2" `
			-Repository "ofxGgmlWorkflows" `
			-Lane $workflow[0].Lane `
			-Category "workflow-reuse" `
			-Task "Document the reusable workflow adoption path and keep caller expectations aligned with Core." `
			-Rationale "Workflow drift should be solved once in the workflow repository, then consumed by addons." `
			-SuggestedFiles "README.md; .github/workflows; AGENTS.md" `
			-Validation "scripts/validate-local.bat"))
	}
}

$taskArray = @($tasks.ToArray())

$result = [pscustomobject]@{
	Root = $status.Root
	GeneratedFrom = "scripts/status-family.ps1 -Json"
	Summary = Get-CodingAgentQueueSummary -Tasks $taskArray -Statuses $statuses
	Guardrails = @(Get-CodingAgentGuardrails)
	Tasks = $taskArray
}

if ($Json) {
	$content = $result | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownQueue -Tasks $taskArray -Statuses $statuses
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
