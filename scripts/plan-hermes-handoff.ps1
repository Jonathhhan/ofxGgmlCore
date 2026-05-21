param(
	[string]$Repository = "",
	[string]$Category = "",
	[string]$OutputPath = "",
	[switch]$Json,
	[switch]$SummaryOnly
)

$ErrorActionPreference = "Stop"

function Invoke-JsonPlan {
	param(
		[string]$ScriptPath,
		[hashtable]$Parameters
	)

	$output = & $ScriptPath @Parameters *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "$([System.IO.Path]::GetFileName($ScriptPath)) failed."
	}

	$raw = $output -join "`n"
	$start = $raw.IndexOf("{")
	$end = $raw.LastIndexOf("}")
	if ($start -lt 0 -or $end -lt $start) {
		throw "$([System.IO.Path]::GetFileName($ScriptPath)) did not emit JSON."
	}

	return ($raw.Substring($start, $end - $start + 1) | ConvertFrom-Json)
}

function Join-HandoffList {
	param([object[]]$Values)

	return (@($Values) | ForEach-Object { $_.ToString() } | Where-Object {
		![string]::IsNullOrWhiteSpace($_)
	}) -join "; "
}

function ConvertTo-HermesMarkdown {
	param([pscustomobject]$Handoff)

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# Hermes Agent Handoff")
	$lines.Add("")
	$lines.Add("Generated from Core status, ecosystem planning, and the coding-agent work queue.")
	$lines.Add("This is a point-in-time snapshot, not the canonical source of truth; rerun the generator before acting on stale artifacts.")
	$lines.Add("")
	$lines.Add("## Snapshot")
	$lines.Add("")
	$lines.Add("| Metric | Count |")
	$lines.Add("| --- | ---: |")
	$lines.Add("| Managed repositories | $($Handoff.EcosystemSummary.ManagedRepositories) |")
	$lines.Add("| Ready managed repositories | $($Handoff.EcosystemSummary.ReadyManagedRepositories) |")
	$lines.Add("| Dirty managed repositories | $($Handoff.EcosystemSummary.DirtyManagedRepositories) |")
	$lines.Add("| Proposed coding-agent tasks | $($Handoff.QueueSummary.ProposedTasks) |")
	$lines.Add("")
	$lines.Add("## Selected Task")
	$lines.Add("")
	$lines.Add("| Field | Value |")
	$lines.Add("| --- | --- |")
	$lines.Add(('| Priority | `{0}` |' -f $Handoff.SelectedTask.Priority))
	$lines.Add(('| Repository | `{0}` |' -f $Handoff.SelectedTask.Repository))
	$lines.Add(('| Lane | `{0}` |' -f $Handoff.SelectedTask.Lane))
	$lines.Add(('| Category | `{0}` |' -f $Handoff.SelectedTask.Category))
	$lines.Add("| Task | $($Handoff.SelectedTask.Task) |")
	$lines.Add(('| Suggested files | `{0}` |' -f $Handoff.SelectedTask.SuggestedFiles))
	$lines.Add(('| Validation | `{0}` |' -f $Handoff.SelectedTask.Validation))
	$lines.Add("")
	$lines.Add("## Prompt")
	$lines.Add("")
	$lines.Add('```text')
	$lines.Add($Handoff.Prompt)
	$lines.Add('```')
	$lines.Add("")
	$lines.Add("## Context Files")
	$lines.Add("")
	foreach ($path in @($Handoff.ContextFiles)) {
		$lines.Add(('- `{0}`' -f $path))
	}
	$lines.Add("")
	$lines.Add("## Required Planning Commands")
	$lines.Add("")
	foreach ($command in @($Handoff.RequiredPlanningCommands)) {
		$lines.Add(('- `{0}`' -f $command))
	}
	$lines.Add("")
	$lines.Add("## Validation")
	$lines.Add("")
	foreach ($command in @($Handoff.ValidationCommands)) {
		$lines.Add(('- `{0}`' -f $command))
	}
	$lines.Add("")
	$lines.Add("## Guardrails")
	$lines.Add("")
	foreach ($guardrail in @($Handoff.Guardrails)) {
		$lines.Add("- $guardrail")
	}
	$lines.Add("- $($Handoff.ReferenceExclusionNote)")

	return $lines -join [Environment]::NewLine
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot

$statusScript = Join-Path $scriptRoot "status-family.ps1"
$ecosystemScript = Join-Path $scriptRoot "plan-ecosystem.ps1"
$queueScript = Join-Path $scriptRoot "plan-coding-agent-work.ps1"

$status = Invoke-JsonPlan -ScriptPath $statusScript -Parameters @{
	Json = $true
	SummaryOnly = $true
}
$ecosystem = Invoke-JsonPlan -ScriptPath $ecosystemScript -Parameters @{
	Json = $true
	SummaryOnly = $true
}
$queue = Invoke-JsonPlan -ScriptPath $queueScript -Parameters @{
	Json = $true
}

$candidateTasks = @($queue.Tasks)
if (![string]::IsNullOrWhiteSpace($Repository)) {
	$candidateTasks = @($candidateTasks | Where-Object { $_.Repository -eq $Repository })
}
if (![string]::IsNullOrWhiteSpace($Category)) {
	$candidateTasks = @($candidateTasks | Where-Object { $_.Category -eq $Category })
}
if ($candidateTasks.Count -eq 0) {
	throw "No Hermes handoff task matched Repository='$Repository' Category='$Category'."
}

$selectedTask = @($candidateTasks | Select-Object -First 1)[0]
$requiredPlanningCommands = @(
	"scripts\status-family.ps1 -Json -SummaryOnly",
	"scripts\plan-ecosystem.ps1 -Json -SummaryOnly",
	"scripts\plan-coding-agent-work.ps1 -Json"
)
$contextFiles = @(
	"HERMES.md",
	"docs\ECOSYSTEM_AGENT.md",
	"docs\CODING_AGENTS.md",
	"docs\CODING_AGENT_WORK.md"
)
$validationCommands = @($selectedTask.ValidationCommands)
if (@($validationCommands).Count -eq 0) {
	$validationCommands = @($selectedTask.Validation)
}
$validationCommands += "scripts\test-hermes-handoff.ps1"

$referenceExclusionNote = "Keep classified reference repositories, including ofxGgmlDiffusion, out of managed automation unless the user explicitly promotes them. Treat ofxGgmlStableDiffusion as the managed stable-diffusion.cpp lane."
$promptLines = @(
	"Read HERMES.md and docs\ECOSYSTEM_AGENT.md in ofxGgmlCore before changing files.",
	"Use Core status and planning scripts as the source of truth, not ad hoc repository guesses.",
	"Take one repository-scoped task only:",
	"[$($selectedTask.Priority)] $($selectedTask.Repository) / $($selectedTask.Category): $($selectedTask.Task)",
	"Suggested files: $(Join-HandoffList -Values @($selectedTask.SuggestedFileList))",
	"Validation commands: $(Join-HandoffList -Values @($validationCommands))",
	"Work in planning, instructions, workflow, validation, or documentation first.",
	"Do not edit addon runtime/source behavior unless the user explicitly asks for that repository and behavior.",
	$referenceExclusionNote,
	"Report touched repositories, validation run, and any remaining blockers."
)

$handoff = [pscustomobject]@{
	Root = $addonRoot
	GeneratedFrom = @(
		"scripts/status-family.ps1 -Json -SummaryOnly",
		"scripts/plan-ecosystem.ps1 -Json -SummaryOnly",
		"scripts/plan-coding-agent-work.ps1 -Json"
	)
	SummaryOnly = [bool]$SummaryOnly
	EcosystemSummary = $ecosystem.Summary
	QueueSummary = $queue.Summary
	PlanningPriorities = @($ecosystem.PlanningPriorities)
	SelectedTask = $selectedTask
	Prompt = ($promptLines -join [Environment]::NewLine)
	ContextFiles = $contextFiles
	RequiredPlanningCommands = $requiredPlanningCommands
	ValidationCommands = $validationCommands
	Guardrails = @($queue.Guardrails)
	ReferenceExclusionNote = $referenceExclusionNote
}

if (!$SummaryOnly) {
	$handoff | Add-Member -NotePropertyName CodingAgentTasks -NotePropertyValue @($queue.Tasks)
}

if ($Json) {
	$content = $handoff | ConvertTo-Json -Depth 8
} else {
	$content = ConvertTo-HermesMarkdown -Handoff $handoff
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
