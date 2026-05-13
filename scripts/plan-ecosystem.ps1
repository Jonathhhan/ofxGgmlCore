param(
	[string]$OutputPath = "",
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function ConvertTo-MarkdownPlan {
	param([array]$Statuses)

	$managedStatuses = @($Statuses | Where-Object { $_.Known })
	$detectedStatuses = @($Statuses | Where-Object { !$_.Known })
	$unclassifiedDetected = @($detectedStatuses | Where-Object { !$_.Classified })
	$classifiedDetected = @($detectedStatuses | Where-Object { $_.Classified })
	$missingRepos = @($managedStatuses | Where-Object { !$_.Present })
	$missingValidation = @($managedStatuses | Where-Object { $_.Present -and !$_.ValidateScript })
	$dirtyRepos = @($managedStatuses | Where-Object { $_.Present -and $_.DirtyCount -gt 0 })
	$missingDoctor = @($managedStatuses | Where-Object { $_.Present -and !$_.DoctorScript -and $_.Name -ne "ofxGgmlWorkflows" })

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
	if ($missingRepos.Count -gt 0) {
		$lines.Add("- Restore or intentionally remove missing repositories from the family map: $(@($missingRepos | ForEach-Object { $_.Name }) -join ', ').")
	}
	if ($unclassifiedDetected.Count -gt 0) {
		$lines.Add("- Classify auto-detected repositories before enabling generated instructions: $(@($unclassifiedDetected | ForEach-Object { $_.Name }) -join ', ').")
	}
	if ($classifiedDetected.Count -gt 0) {
		$lines.Add("- Keep classified legacy/reference siblings out of managed automation unless explicitly promoted: $(@($classifiedDetected | ForEach-Object { $_.Name }) -join ', ').")
	}
	if ($missingValidation.Count -gt 0) {
		$lines.Add("- Add local validation entry points before feature work: $(@($missingValidation | ForEach-Object { $_.Name }) -join ', ').")
	}
	if ($dirtyRepos.Count -gt 0) {
		$dirtyList = @($dirtyRepos | ForEach-Object { "$($_.Name) ($($_.DirtyCount))" }) -join ", "
		$lines.Add("- Review dirty repositories before cross-repo edits: $dirtyList.")
	}
	if ($missingDoctor.Count -gt 0) {
		$lines.Add("- Consider doctor scripts for lanes that still lack quick local diagnostics: $(@($missingDoctor | ForEach-Object { $_.Name }) -join ', ').")
	}
	if ($missingRepos.Count -eq 0 -and $missingValidation.Count -eq 0) {
		$lines.Add("- Keep agent and validation instructions current before widening any addon runtime behavior.")
	}
	$lines.Add("- Make one backend lane genuinely useful before broadening every companion addon.")

	$lines.Add("")
	$lines.Add("## Agent Guardrails")
	$lines.Add("")
	$lines.Add("- Start in planning, documentation, workflow, or validation files.")
	$lines.Add("- Do not edit addon source unless the user explicitly asks for addon behavior.")
	$lines.Add('- Keep `ofxGgmlCore` as the shared base and avoid reverse dependencies from Core to companions.')
	$lines.Add("- Preserve generated artifact hygiene across all repositories.")
	$lines.Add("")
	$lines.Add("## Suggested Validation")
	$lines.Add("")
	$lines.Add('```powershell')
	$lines.Add("scripts\write-agent-instructions.bat -Check")
	$lines.Add("scripts\audit-ecosystem.bat -Strict")
	$lines.Add("scripts\plan-ecosystem.bat")
	$lines.Add("scripts\status-family.bat")
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

if ($Json) {
	$result = [pscustomobject]@{
		Root = $status.Root
		Addons = $status.Addons
	}
	$content = $result | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownPlan -Statuses @($status.Addons)
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
