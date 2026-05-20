param(
	[string]$OutputPath = "",
	[switch]$Json,
	[switch]$SummaryOnly,
	[switch]$Strict
)

$ErrorActionPreference = "Stop"

function Test-RepoPath {
	param(
		[object]$Status,
		[string]$RelativePath,
		[switch]$Directory
	)

	if (!$Status.Present) {
		return $false
	}
	$path = Join-Path $Status.Path $RelativePath
	if ($Directory) {
		return Test-Path -LiteralPath $path -PathType Container
	}
	return Test-Path -LiteralPath $path -PathType Leaf
}

function New-AuditEntry {
	param([object]$Status)

	$hasHermes = Test-RepoPath -Status $Status -RelativePath "HERMES.md"
	$hasAgents = Test-RepoPath -Status $Status -RelativePath "AGENTS.md"
	$hasCopilot = Test-RepoPath -Status $Status -RelativePath ".github\copilot-instructions.md"
	$hasCopilotEcosystem = Test-RepoPath -Status $Status -RelativePath ".github\instructions\ofxggml-ecosystem.instructions.md"
	$hasInstructionWorkflow = Test-RepoPath -Status $Status -RelativePath ".github\workflows\coding-agent-instructions.yml"
	$hasReleaseCandidate = Test-RepoPath -Status $Status -RelativePath "scripts\release-candidate.ps1"
	$hasDocs = Test-RepoPath -Status $Status -RelativePath "docs" -Directory

	$instructionCount = @(@($hasHermes, $hasAgents, $hasCopilot, $hasCopilotEcosystem) | Where-Object { $_ }).Count
	$instructionState = if ($instructionCount -eq 4) { "complete" } elseif ($instructionCount -gt 0) { "partial" } else { "missing" }
	$workflowState = if ($Status.Name -eq "ofxGgmlWorkflows") {
		if (Test-RepoPath -Status $Status -RelativePath ".github\workflows\coding-agent-instructions.yml") { "owner" } else { "missing-owner" }
	} elseif ($hasInstructionWorkflow) {
		"caller"
	} else {
		"missing"
	}
	$validationState = if ($Status.ValidateScript) { "yes" } else { "missing" }
	$releaseState = if ($Status.Name -eq "ofxGgmlWorkflows") {
		"workflow-repo"
	} elseif ($hasReleaseCandidate) {
		"yes"
	} else {
		"missing"
	}
	$action = if (!$Status.Known -and $Status.Classified) {
		"reference only; keep out of managed automation"
	} elseif (!$Status.Known) {
		"classify detected repo before automation"
	} elseif (!$Status.Present) {
		"restore or remove from managed map"
	} elseif ($instructionState -ne "complete") {
		"regenerate agent instructions"
	} elseif ($workflowState -eq "missing" -or $workflowState -eq "missing-owner") {
		"add coding-agent workflow coverage"
	} elseif ($validationState -eq "missing") {
		"add local validation entry point"
	} elseif ($releaseState -eq "missing") {
		"add release-candidate entry point"
	} else {
		"ready for planning"
	}

	[pscustomobject]@{
		Name = $Status.Name
		Known = [bool]$Status.Known
		Lane = $Status.Lane
		Present = [bool]$Status.Present
		Instructions = $instructionState
		AgentsInstructions = if ($hasAgents) { "yes" } else { "missing" }
		HermesInstructions = if ($hasHermes) { "yes" } else { "missing" }
		CopilotInstructions = if ($hasCopilot) { "yes" } else { "missing" }
		CopilotEcosystemInstructions = if ($hasCopilotEcosystem) { "yes" } else { "missing" }
		CodingAgentWorkflow = $workflowState
		Validation = $validationState
		ReleaseCandidate = $releaseState
		Docs = if ($hasDocs) { "yes" } else { "missing" }
		DirtyCount = [int]$Status.DirtyCount
		Action = $action
	}
}

function ConvertTo-MarkdownAudit {
	param([array]$Entries)

	$managed = @($Entries | Where-Object { $_.Known })
	$detected = @($Entries | Where-Object { !$_.Known })
	$summary = Get-AuditSummary -Entries $Entries
	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# ofxGgml Ecosystem Audit")
	$lines.Add("")
	$lines.Add("Agent-facing readiness audit for managed repositories and auto-detected siblings.")
	$lines.Add("")
	$lines.Add("## Summary")
	$lines.Add("")
	$lines.Add("| Metric | Count |")
	$lines.Add("| --- | --- |")
	$lines.Add("| Managed repositories | $($summary.ManagedRepositories) |")
	$lines.Add("| Ready managed repositories | $($summary.ReadyManagedRepositories) |")
	$lines.Add("| Managed repositories with blockers | $($summary.BlockedManagedRepositories) |")
	$lines.Add("| Detected reference repositories | $($summary.DetectedReferenceRepositories) |")
	$lines.Add("| Dirty managed repositories | $($summary.DirtyManagedRepositories) |")
	$lines.Add("| Dirty detected repositories | $($summary.DirtyDetectedRepositories) |")
	$lines.Add("")
	$lines.Add("## Managed Repositories")
	$lines.Add("")
	$lines.Add("| Repository | Instructions | AGENTS | HERMES | Copilot | Copilot Ecosystem | Agent Workflow | Validation | Release | Dirty | Action |")
	$lines.Add("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	foreach ($entry in $managed) {
		$lines.Add("| $($entry.Name) | $($entry.Instructions) | $($entry.AgentsInstructions) | $($entry.HermesInstructions) | $($entry.CopilotInstructions) | $($entry.CopilotEcosystemInstructions) | $($entry.CodingAgentWorkflow) | $($entry.Validation) | $($entry.ReleaseCandidate) | $($entry.DirtyCount) | $($entry.Action) |")
	}

	if ($detected.Count -gt 0) {
		$lines.Add("")
		$lines.Add("## Detected Siblings")
		$lines.Add("")
		$lines.Add("Detected repositories are visible to planning but are not updated by instruction generation unless `-IncludeDiscovered` is used. Classified legacy/reference siblings stay out of managed automation unless explicitly promoted.")
		$lines.Add("")
		$lines.Add("| Repository | Instructions | Validation | Dirty | Action |")
		$lines.Add("| --- | --- | --- | --- | --- |")
		foreach ($entry in $detected) {
			$lines.Add("| $($entry.Name) | $($entry.Instructions) | $($entry.Validation) | $($entry.DirtyCount) | $($entry.Action) |")
		}
	}

	return $lines -join [Environment]::NewLine
}

function Get-AuditSummary {
	param([array]$Entries)

	$managed = @($Entries | Where-Object { $_.Known })
	$detected = @($Entries | Where-Object { !$_.Known })
	$blockedManaged = @($managed | Where-Object {
		!$_.Present -or
		$_.Instructions -ne "complete" -or
		$_.CodingAgentWorkflow -eq "missing" -or
		$_.CodingAgentWorkflow -eq "missing-owner" -or
		$_.Validation -eq "missing"
	})

	return [pscustomobject]@{
		ManagedRepositories = $managed.Count
		ReadyManagedRepositories = @($managed | Where-Object { $_.Action -eq "ready for planning" }).Count
		BlockedManagedRepositories = $blockedManaged.Count
		DetectedReferenceRepositories = $detected.Count
		DirtyManagedRepositories = @($managed | Where-Object { $_.DirtyCount -gt 0 }).Count
		DirtyDetectedRepositories = @($detected | Where-Object { $_.DirtyCount -gt 0 }).Count
		MissingInstructionManagedRepositories = @($managed | Where-Object { $_.Instructions -ne "complete" }).Count
		MissingWorkflowManagedRepositories = @($managed | Where-Object { $_.CodingAgentWorkflow -eq "missing" -or $_.CodingAgentWorkflow -eq "missing-owner" }).Count
		MissingValidationManagedRepositories = @($managed | Where-Object { $_.Validation -eq "missing" }).Count
		BlockingManagedRepositoryNames = @($blockedManaged | ForEach-Object { [string]$_.Name })
	}
}

function ConvertTo-AuditRepositorySummary {
	param([object]$Entry)

	[pscustomobject]@{
		Name = [string]$Entry.Name
		Known = [bool]$Entry.Known
		Present = [bool]$Entry.Present
		Instructions = [string]$Entry.Instructions
		CodingAgentWorkflow = [string]$Entry.CodingAgentWorkflow
		Validation = [string]$Entry.Validation
		ReleaseCandidate = [string]$Entry.ReleaseCandidate
		DirtyCount = [int]$Entry.DirtyCount
		Action = [string]$Entry.Action
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusScript = Join-Path $scriptRoot "status-family.ps1"
$statusJson = & $statusScript -Json
if (!$?) {
	throw "status-family.ps1 failed."
}

$status = $statusJson | ConvertFrom-Json
$entries = @($status.Addons | ForEach-Object { New-AuditEntry -Status $_ })

if ($Strict) {
	$blocking = @($entries | Where-Object {
		$_.Known -and (
			!$_.Present -or
			$_.Instructions -ne "complete" -or
			$_.CodingAgentWorkflow -eq "missing" -or
			$_.CodingAgentWorkflow -eq "missing-owner" -or
			$_.Validation -eq "missing"
		)
	})
	if ($blocking.Count -gt 0) {
		throw "Managed ecosystem audit failed: $(@($blocking | ForEach-Object { $_.Name }) -join ', ')"
	}
}

if ($Json) {
	$result = [pscustomobject]@{
		Root = $status.Root
		SummaryOnly = [bool]$SummaryOnly
		Summary = Get-AuditSummary -Entries $entries
		RepositorySummaries = @($entries | ForEach-Object { ConvertTo-AuditRepositorySummary -Entry $_ })
	}
	if (!$SummaryOnly) {
		$result | Add-Member -NotePropertyName Repositories -NotePropertyValue $entries
	}
	$content = $result | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownAudit -Entries $entries
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
