param(
	[string]$OutputPath = "",
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-SmokeBuildPhase {
	param([object]$Status)

	if ($Status.Name -eq "ofxGgmlWorkflows") {
		return "workflow-owner"
	}
	if (!$Status.Present) {
		return "missing-repository"
	}
	if (!$Status.ValidateScript) {
		return "needs-local-validation"
	}
	if (!$Status.Examples -or $Status.Examples.Count -eq 0) {
		return "needs-root-example-inventory"
	}
	return "ready-for-project-generation-check"
}

function Get-SmokeBuildAction {
	param([string]$Phase)

	switch ($Phase) {
		"workflow-owner" { "keep reusable smoke workflow expectations aligned with caller addons" }
		"missing-repository" { "restore checkout before smoke-build planning" }
		"needs-local-validation" { "add local validation before project-generation checks" }
		"needs-root-example-inventory" { "document or add a root-level smoke example before compile validation" }
		"ready-for-project-generation-check" { "plan projectGenerator verification before CI compile gates" }
		default { "review smoke-build readiness" }
	}
}

function ConvertTo-MarkdownSmokeBuildPlan {
	param(
		[array]$Records,
		[string]$Root
	)

	$ready = @($Records | Where-Object { $_.Phase -eq "ready-for-project-generation-check" })
	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# openFrameworks Smoke Build Plan")
	$lines.Add("")
	$lines.Add("Non-mutating rollout plan for moving the managed ofxGgml ecosystem from structural checks toward real openFrameworks project-generation and compile validation.")
	$lines.Add("")
	$lines.Add("Root: $Root")
	$lines.Add("")
	$lines.Add("## Summary")
	$lines.Add("")
	$lines.Add("| Metric | Count |")
	$lines.Add("| --- | ---: |")
	$lines.Add("| Managed records | $($Records.Count) |")
	$lines.Add("| Ready for project-generation checks | $($ready.Count) |")
	$lines.Add("| Workflow-only records | $(@($Records | Where-Object { $_.Phase -eq "workflow-owner" }).Count) |")
	$lines.Add("| Missing local validation | $(@($Records | Where-Object { $_.Phase -eq "needs-local-validation" }).Count) |")
	$lines.Add("| Missing root example inventory | $(@($Records | Where-Object { $_.Phase -eq "needs-root-example-inventory" }).Count) |")
	$lines.Add("")
	$lines.Add("## Repository Plan")
	$lines.Add("")
	$lines.Add("| Repository | Lane | Examples | Phase | Next action |")
	$lines.Add("| --- | --- | --- | --- | --- |")
	foreach ($record in $Records) {
		$examples = if ($record.Examples.Count -gt 0) { $record.Examples -join ", " } else { "-" }
		$lines.Add(('| `{0}` | `{1}` | `{2}` | `{3}` | {4} |' -f $record.Repository, $record.Lane, $examples, $record.Phase, $record.Action))
	}
	$lines.Add("")
	$lines.Add("## Guardrails")
	$lines.Add("")
	$lines.Add("- Start with project-generation verification before adding compile gates.")
	$lines.Add("- Keep generated openFrameworks project files, build output, IDE state, local models, and media out of git.")
	$lines.Add("- Compile only focused root-level smoke examples before broad application-like examples.")
	$lines.Add("- Keep reusable workflow implementation in `ofxGgmlWorkflows`; keep ecosystem rollout planning in Core.")

	return $lines -join [Environment]::NewLine
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusJson = & (Join-Path $scriptRoot "status-family.ps1") -Json
if (!$?) {
	throw "status-family.ps1 failed."
}

$status = $statusJson | ConvertFrom-Json
$managed = @($status.Addons | Where-Object { $_.Known })
$records = @($managed | ForEach-Object {
	$phase = Get-SmokeBuildPhase -Status $_
	[pscustomobject]@{
		Repository = [string]$_.Name
		Lane = [string]$_.Lane
		Examples = @($_.Examples)
		Phase = $phase
		Action = Get-SmokeBuildAction -Phase $phase
	}
})

if ($Json) {
	$content = [pscustomobject]@{
		Root = $status.Root
		Records = $records
	} | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownSmokeBuildPlan -Records $records -Root ([string]$status.Root)
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
