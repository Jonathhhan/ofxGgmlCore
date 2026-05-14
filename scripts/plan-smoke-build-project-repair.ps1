param(
	[string]$Stage = "verify-generated-project",
	[int]$First = 1,
	[string]$Repository = "",
	[string]$Example = "",
	[switch]$Json
)

$ErrorActionPreference = "Stop"

if ($First -lt 1) {
	throw "-First must be at least 1."
}
if (([string]::IsNullOrWhiteSpace($Repository) -and ![string]::IsNullOrWhiteSpace($Example)) -or
	(![string]::IsNullOrWhiteSpace($Repository) -and [string]::IsNullOrWhiteSpace($Example))) {
	throw "-Repository and -Example must be provided together."
}

function Get-ExpectedAddonReference {
	param(
		[string]$Addon,
		[string]$OwnerAddon
	)

	if ($Addon -eq $OwnerAddon) {
		return "..\src"
	}
	return "..\..\$Addon"
}

function Get-RepairState {
	param([object]$Postflight)

	if (!$Postflight.GeneratedProjectFiles -or @($Postflight.GeneratedProjectFiles).Count -eq 0) {
		return "needs-project-generation"
	}
	if (@($Postflight.MissingProjectAddons).Count -gt 0) {
		return "needs-addon-wiring-repair"
	}
	if ($Postflight.Complete) {
		return "ready-for-compile-validation"
	}
	return "review-generated-project"
}

function Get-RepairAction {
	param([string]$State)

	switch ($State) {
		"needs-project-generation" { "run projectGenerator before repair planning can inspect generated metadata" }
		"needs-addon-wiring-repair" { "regenerate or repair the Visual Studio project so expected addons are referenced before compile gates" }
		"ready-for-compile-validation" { "generated project addon wiring is ready for focused compile validation" }
		default { "review generated project state before compile validation" }
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-of-smoke-build.ps1"
$postflightScript = Join-Path $scriptRoot "check-smoke-build-target-postflight.ps1"

$planJson = & $planScript -Json
if (!$?) {
	throw "plan-of-smoke-build.ps1 -Json failed."
}
$plan = ($planJson -join [Environment]::NewLine) | ConvertFrom-Json

if (![string]::IsNullOrWhiteSpace($Repository)) {
	$postflightJson = & $postflightScript -Stage $Stage -First $First -Repository $Repository -Example $Example -Json
} else {
	$postflightJson = & $postflightScript -Stage $Stage -First $First -Json
}
if (!$?) {
	throw "check-smoke-build-target-postflight.ps1 -Json failed."
}
$postflight = ($postflightJson -join [Environment]::NewLine) | ConvertFrom-Json

$repairs = @($postflight.Postflights | ForEach-Object {
	$targetPostflight = $_
	$record = @($plan.Records | Where-Object { $_.Repository -eq $targetPostflight.Repository } | Select-Object -First 1)
	$exampleMetadata = @($record.ExampleMetadata | Where-Object { $_.Example -eq $targetPostflight.Example } | Select-Object -First 1)
	$addons = @($exampleMetadata.Addons | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
	$missingAddons = @($targetPostflight.MissingProjectAddons | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
	$state = Get-RepairState -Postflight $targetPostflight
	$expectedReferences = @($addons | ForEach-Object {
		[pscustomobject]@{
			Addon = $_
			Reference = Get-ExpectedAddonReference -Addon $_ -OwnerAddon ([string]$targetPostflight.Repository)
			Missing = $missingAddons -contains $_
		}
	})
	$projectGeneratorCommand = [string]$exampleMetadata.ProjectGeneratorCommand
	$nextCommands = New-Object System.Collections.Generic.List[string]
	$nextCommands.Add("scripts\check-smoke-build-target-preflight.bat -Stage $($targetPostflight.Stage) -Repository $($targetPostflight.Repository) -Example $($targetPostflight.Example)")
	if (($state -eq "needs-project-generation" -or $state -eq "needs-addon-wiring-repair") -and
		![string]::IsNullOrWhiteSpace($projectGeneratorCommand)) {
		$nextCommands.Add($projectGeneratorCommand)
	}
	if ($state -eq "needs-addon-wiring-repair") {
		$nextCommands.Add("# If projectGenerator still exits during addon processing, repair the generated Visual Studio project so the missing addon references below are present.")
	}
	$nextCommands.Add("scripts\check-smoke-build-target-postflight.bat -Stage $($targetPostflight.Stage) -Repository $($targetPostflight.Repository) -Example $($targetPostflight.Example)")
	$nextCommands.Add("scripts\test-artifact-hygiene.ps1")

	[pscustomobject]@{
		Repository = $targetPostflight.Repository
		Example = $targetPostflight.Example
		Stage = $targetPostflight.Stage
		State = $state
		Action = Get-RepairAction -State $state
		ProjectFile = [string]$targetPostflight.GeneratedProjectFile
		GeneratedProjectFiles = @($targetPostflight.GeneratedProjectFiles)
		ExpectedReferences = @($expectedReferences)
		MissingProjectAddons = @($missingAddons)
		ProjectGeneratorCommand = $projectGeneratorCommand
		NextCommands = @($nextCommands.ToArray())
	}
})

$needsAction = @($repairs | Where-Object { $_.State -ne "ready-for-compile-validation" })
$nextCommandList = New-Object System.Collections.Generic.List[string]
foreach ($repair in $repairs) {
	foreach ($command in @($repair.NextCommands)) {
		if (!$nextCommandList.Contains($command)) {
			$nextCommandList.Add($command)
		}
	}
}
$nextCommands = @($nextCommandList.ToArray())
$safetyNote = "This repair plan is non-mutating. Keep generated project files ignored unless an owning addon explicitly tracks them."

if ($Json) {
	[pscustomobject]@{
		Root = $plan.Root
		Stage = $Stage
		Repairs = $repairs
		NeedsAction = $needsAction.Count
		NextCommands = $nextCommands
		SafetyNote = $safetyNote
	} | ConvertTo-Json -Depth 8
	return
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Smoke Build Project Repair Plan")
$lines.Add("")
$lines.Add("Root: $($plan.Root)")
$lines.Add("Stage filter: $Stage")
$lines.Add("")

if ($repairs.Count -eq 0) {
	$lines.Add("No matching smoke-build project repair targets.")
	Write-Output ($lines -join [Environment]::NewLine)
	return
}

foreach ($repair in $repairs) {
	$lines.Add("## $($repair.Repository) / $($repair.Example)")
	$lines.Add("")
	$lines.Add(('Stage: `{0}`' -f $repair.Stage))
	$lines.Add(('State: `{0}`' -f $repair.State))
	$lines.Add("Action: $($repair.Action)")
	if (![string]::IsNullOrWhiteSpace([string]$repair.ProjectFile)) {
		$lines.Add("Project file: $($repair.ProjectFile)")
	}
	$lines.Add("")
	$lines.Add("## Expected Addon References")
	$lines.Add("")
	$lines.Add("| Addon | Expected reference | Missing |")
	$lines.Add("| --- | --- | --- |")
	foreach ($reference in @($repair.ExpectedReferences)) {
		$missing = if ($reference.Missing) { "yes" } else { "no" }
		$lines.Add(('| `{0}` | `{1}` | {2} |' -f $reference.Addon, $reference.Reference, $missing))
	}
	$lines.Add("")
	$lines.Add("## Next Commands")
	$lines.Add("")
	$lines.Add('```powershell')
	foreach ($command in @($repair.NextCommands)) {
		$lines.Add($command)
	}
	$lines.Add('```')
	$lines.Add("")
}

$lines.Add("## Combined Next Commands")
$lines.Add("")
$lines.Add('```powershell')
foreach ($command in $nextCommands) {
	$lines.Add($command)
}
$lines.Add('```')
$lines.Add("")
$lines.Add($safetyNote)

Write-Output ($lines -join [Environment]::NewLine)
