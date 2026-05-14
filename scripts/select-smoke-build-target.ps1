param(
	[string]$Stage = "",
	[int]$First = 1,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

if ($First -lt 1) {
	throw "-First must be at least 1."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-of-smoke-build.ps1"
$planJson = & $planScript -Json
if (!$?) {
	throw "plan-of-smoke-build.ps1 -Json failed."
}

$plan = ($planJson -join [Environment]::NewLine) | ConvertFrom-Json
$targets = @($plan.Targets)
if (![string]::IsNullOrWhiteSpace($Stage)) {
	$targets = @($targets | Where-Object { $_.Stage -eq $Stage })
}
$selected = @($targets | Select-Object -First $First)

if ($Json) {
	[pscustomobject]@{
		Root = $plan.Root
		OfRoot = $plan.OfRoot
		ProjectGeneratorPath = $plan.ProjectGeneratorPath
		Stage = $Stage
		Targets = $selected
	} | ConvertTo-Json -Depth 6
	return
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# openFrameworks Smoke Build Target")
$lines.Add("")
$lines.Add("Root: $($plan.Root)")
$lines.Add("ProjectGenerator: $(if ([string]::IsNullOrWhiteSpace([string]$plan.ProjectGeneratorPath)) { 'not detected' } else { $plan.ProjectGeneratorPath })")
$lines.Add("Stage filter: $(if ([string]::IsNullOrWhiteSpace($Stage)) { 'none' } else { $Stage })")
$lines.Add("")

if ($selected.Count -eq 0) {
	$lines.Add("No matching smoke-build targets.")
	Write-Output ($lines -join [Environment]::NewLine)
	return
}

$lines.Add("| Priority | Repository | Example | Stage | Action |")
$lines.Add("| ---: | --- | --- | --- | --- |")
foreach ($target in $selected) {
	$lines.Add(('| {0} | `{1}` | `{2}` | `{3}` | {4} |' -f $target.Priority, $target.Repository, $target.Example, $target.Stage, $target.Action))
}

$commands = @($selected | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_.Command) })
if ($commands.Count -gt 0) {
	$lines.Add("")
	$lines.Add("## Commands")
	$lines.Add("")
	foreach ($target in $commands) {
		$lines.Add(('- `{0}`' -f $target.Command))
	}
}

Write-Output ($lines -join [Environment]::NewLine)
