param(
	[string]$Stage = "generate-project",
	[int]$First = 1,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

if ($First -lt 1) {
	throw "-First must be at least 1."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$selectScript = Join-Path $scriptRoot "select-smoke-build-target.ps1"
$selectionJson = & $selectScript -Stage $Stage -First $First -Json
if (!$?) {
	throw "select-smoke-build-target.ps1 -Json failed."
}

$selection = ($selectionJson -join [Environment]::NewLine) | ConvertFrom-Json
$targets = @($selection.Targets)
$validationCommands = @(
	"scripts\plan-of-smoke-build.bat",
	"scripts\select-smoke-build-target.bat -Stage $Stage -First $First",
	"scripts\test-of-smoke-build-plan.ps1",
	"scripts\test-artifact-hygiene.ps1"
)
$guardrails = @(
	"Do not commit generated openFrameworks project files unless the owning addon explicitly tracks them.",
	"Keep model files, build output, IDE state, caches, and downloaded runtimes out of git.",
	"Work one selected example at a time and re-run the smoke-build planner afterward."
)
$targetCommands = @($targets |
	Where-Object { ![string]::IsNullOrWhiteSpace([string]$_.Command) } |
	ForEach-Object { [string]$_.Command })
$preflightCommand = "scripts\check-smoke-build-target-preflight.bat -Stage $Stage -First $First"
$postflightCommands = @($targets |
	Where-Object {
		![string]::IsNullOrWhiteSpace([string]$_.Repository) -and
		![string]::IsNullOrWhiteSpace([string]$_.Example)
	} |
	ForEach-Object { "scripts\check-smoke-build-target-postflight.bat -Stage $Stage -Repository $($_.Repository) -Example $($_.Example)" })
$nextCommands = @($preflightCommand) + $targetCommands + $postflightCommands + $validationCommands
$safetyNote = "This handoff is non-mutating. Run projectGenerator only after preflight reports the selected target is ready, then use postflight to review generated files and git impact."

if ($Json) {
	[pscustomobject]@{
		Root = $selection.Root
		OfRoot = $selection.OfRoot
		ProjectGeneratorPath = $selection.ProjectGeneratorPath
		Stage = $Stage
		Targets = $targets
		TargetCommands = $targetCommands
		PostflightCommands = $postflightCommands
		Validation = $validationCommands
		Guardrails = $guardrails
		NextCommands = $nextCommands
		SafetyNote = $safetyNote
	} | ConvertTo-Json -Depth 6
	return
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Smoke Build Target Handoff")
$lines.Add("")
$lines.Add("Root: $($selection.Root)")
$lines.Add("ProjectGenerator: $(if ([string]::IsNullOrWhiteSpace([string]$selection.ProjectGeneratorPath)) { 'not detected' } else { $selection.ProjectGeneratorPath })")
$lines.Add("Stage filter: $Stage")
$lines.Add("")

if ($targets.Count -eq 0) {
	$lines.Add("No matching smoke-build targets.")
	Write-Output ($lines -join [Environment]::NewLine)
	return
}

$lines.Add("## Targets")
$lines.Add("")
$lines.Add("| Priority | Repository | Example | Stage | Action |")
$lines.Add("| ---: | --- | --- | --- | --- |")
foreach ($target in $targets) {
	$lines.Add(('| {0} | `{1}` | `{2}` | `{3}` | {4} |' -f $target.Priority, $target.Repository, $target.Example, $target.Stage, $target.Action))
}

$commands = @($targets | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_.Command) })
if ($commands.Count -gt 0) {
	$lines.Add("")
	$lines.Add("## Commands")
	$lines.Add("")
	foreach ($target in $commands) {
		$lines.Add(('- `{0}`' -f $target.Command))
	}
}

$lines.Add("")
$lines.Add("## Validation")
$lines.Add("")
foreach ($command in $validationCommands) {
	$lines.Add(('- `{0}`' -f $command))
}
$lines.Add("")
$lines.Add("## Guardrails")
$lines.Add("")
foreach ($guardrail in $guardrails) {
	$lines.Add(("- $guardrail"))
}
$lines.Add("")
$lines.Add("## Next Commands")
$lines.Add("")
$lines.Add('```powershell')
foreach ($command in $nextCommands) {
	$lines.Add($command)
}
$lines.Add('```')
$lines.Add("")
$lines.Add($safetyNote)

Write-Output ($lines -join [Environment]::NewLine)
