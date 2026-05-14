param(
	[string]$Stage = "generate-project",
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

function New-Check {
	param(
		[string]$Name,
		$Ok,
		[string]$Detail
	)

	[pscustomobject]@{
		Name = $Name
		State = if ([bool]$Ok) { "OK" } else { "BLOCKED" }
		Detail = $Detail
	}
}

function Get-GitDirtyCount {
	param([string]$Path)

	if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path -PathType Container)) {
		return -1
	}

	$output = @(git -C $Path status --short 2>$null)
	if ($LASTEXITCODE -ne 0) {
		return -1
	}
	return $output.Count
}

function Get-SelectedTargets {
	param(
		[object]$Plan,
		[string]$Stage,
		[int]$First,
		[string]$Repository,
		[string]$Example,
		[string]$ScriptRoot
	)

	if (![string]::IsNullOrWhiteSpace($Repository)) {
		$record = @($Plan.Records | Where-Object { $_.Repository -eq $Repository } | Select-Object -First 1)[0]
		if (!$record) {
			throw "Repository was not found in smoke-build plan: $Repository"
		}
		$exampleMetadata = @($record.ExampleMetadata | Where-Object { $_.Example -eq $Example } | Select-Object -First 1)[0]
		if (!$exampleMetadata) {
			throw "Example was not found in smoke-build plan: $Repository / $Example"
		}
		$target = @($Plan.Targets | Where-Object { $_.Repository -eq $Repository -and $_.Example -eq $Example } | Select-Object -First 1)
		if ($target) {
			return @($target)
		}
		return @([pscustomobject]@{
			Priority = 0
			Order = 0
			Repository = $Repository
			Example = $Example
			Stage = $Stage
			Action = "review smoke-build target preflight"
			Command = [string]$exampleMetadata.ProjectGeneratorCommand
		})
	}

	$selectScript = Join-Path $ScriptRoot "select-smoke-build-target.ps1"
	$selectionJson = & $selectScript -Stage $Stage -First $First -Json
	if (!$?) {
		throw "select-smoke-build-target.ps1 -Json failed."
	}
	$selection = ($selectionJson -join [Environment]::NewLine) | ConvertFrom-Json
	return @($selection.Targets)
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-of-smoke-build.ps1"

$planJson = & $planScript -Json
if (!$?) {
	throw "plan-of-smoke-build.ps1 -Json failed."
}
$plan = ($planJson -join [Environment]::NewLine) | ConvertFrom-Json

$targets = @(Get-SelectedTargets -Plan $plan -Stage $Stage -First $First -Repository $Repository -Example $Example -ScriptRoot $scriptRoot)

$preflights = @($targets | ForEach-Object {
	$target = $_
	$record = @($plan.Records | Where-Object { $_.Repository -eq $target.Repository } | Select-Object -First 1)[0]
	$exampleMetadata = @($record.ExampleMetadata | Where-Object { $_.Example -eq $target.Example } | Select-Object -First 1)[0]
	$examplePath = [string]$exampleMetadata.Path
	$repoPath = if (![string]::IsNullOrWhiteSpace($examplePath)) { Split-Path -Parent $examplePath } else { "" }
	$dirtyCount = Get-GitDirtyCount -Path $repoPath
	$checks = @()

	$projectGeneratorOk = ![string]::IsNullOrWhiteSpace([string]$plan.ProjectGeneratorPath) -and (Test-Path -LiteralPath ([string]$plan.ProjectGeneratorPath) -PathType Leaf)
	$projectGeneratorDetail = if ($projectGeneratorOk) { [string]$plan.ProjectGeneratorPath } else { "projectGenerator executable was not detected" }
	$checks += New-Check -Name "projectGenerator detected" -Ok $projectGeneratorOk -Detail $projectGeneratorDetail

	$exampleExists = ![string]::IsNullOrWhiteSpace($examplePath) -and (Test-Path -LiteralPath $examplePath -PathType Container)
	$exampleDetail = if ($exampleExists) { $examplePath } else { "example directory was not found" }
	$checks += New-Check -Name "example directory" -Ok $exampleExists -Detail $exampleDetail

	$metadataOk = $exampleMetadata.HasAddonsMake -and $exampleMetadata.HasOwnerAddon -and $exampleMetadata.HasCoreAddon
	$metadataDetail = if ($metadataOk) { "addons.make includes owner addon and ofxGgmlCore" } else { "example metadata is incomplete" }
	$checks += New-Check -Name "example addon metadata" -Ok $metadataOk -Detail $metadataDetail

	$repoClean = $dirtyCount -eq 0
	$repoDetail = if ($dirtyCount -ge 0) { "$dirtyCount pending git changes in $repoPath" } else { "could not inspect git status for $repoPath" }
	$checks += New-Check -Name "owning repository clean" -Ok $repoClean -Detail $repoDetail

	$stageStateOk = $true
	$stageDetail = "stage does not require generated project state"
	if ($target.Stage -eq "generate-project") {
		$stageStateOk = !$exampleMetadata.HasGeneratedProject
		$stageDetail = if ($stageStateOk) { "generated project files are currently missing" } else { "generated project files already exist" }
	} elseif ($target.Stage -eq "verify-generated-project") {
		$stageStateOk = $exampleMetadata.HasGeneratedProject
		$stageDetail = if ($stageStateOk) { "generated project files are present" } else { "generated project files are missing" }
	}
	$checks += New-Check -Name "target stage matches filesystem" -Ok $stageStateOk -Detail $stageDetail

	[pscustomobject]@{
		Repository = $target.Repository
		Example = $target.Example
		Stage = $target.Stage
		Ready = @($checks | Where-Object { $_.State -ne "OK" }).Count -eq 0
		ExamplePath = $examplePath
		RepositoryPath = $repoPath
		Command = [string]$target.Command
		Checks = @($checks)
	}
})
$readyCommands = @($preflights |
	Where-Object { $_.Ready -and ![string]::IsNullOrWhiteSpace([string]$_.Command) } |
	ForEach-Object { [string]$_.Command })
$postflightCommands = @($preflights |
	Where-Object { $_.Ready } |
	ForEach-Object { "scripts\check-smoke-build-target-postflight.bat -Stage $Stage -Repository $($_.Repository) -Example $($_.Example)" })
$nextCommands = @()
if ($readyCommands.Count -gt 0) {
	$nextCommands = @($readyCommands + $postflightCommands + @(
		"scripts\plan-of-smoke-build.bat",
		"scripts\test-artifact-hygiene.ps1"
	))
} else {
	$blockedCommands = if (![string]::IsNullOrWhiteSpace($Repository)) {
		@($preflights | ForEach-Object { "scripts\check-smoke-build-target-preflight.bat -Stage $($_.Stage) -Repository $($_.Repository) -Example $($_.Example)" })
	} else {
		@("scripts\check-smoke-build-target-preflight.bat -Stage $Stage -First $First")
	}
	$nextCommands = @("# Preflight is blocked. Fix BLOCKED checks before running projectGenerator.") + $blockedCommands
}
$safetyNote = "Run projectGenerator commands only when every preflight check is OK. Use postflight immediately after acting on a target."

if ($Json) {
	[pscustomobject]@{
		Root = $plan.Root
		Stage = $Stage
		Preflights = $preflights
		ReadyCommands = $readyCommands
		PostflightCommands = $postflightCommands
		NextCommands = $nextCommands
		SafetyNote = $safetyNote
	} | ConvertTo-Json -Depth 8
	return
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Smoke Build Target Preflight")
$lines.Add("")
$lines.Add("Root: $($plan.Root)")
$lines.Add("Stage filter: $Stage")
$lines.Add("")

if ($preflights.Count -eq 0) {
	$lines.Add("No matching smoke-build targets.")
	Write-Output ($lines -join [Environment]::NewLine)
	return
}

foreach ($preflight in $preflights) {
	$lines.Add("## $($preflight.Repository) / $($preflight.Example)")
	$lines.Add("")
	$lines.Add(('Stage: `{0}`' -f $preflight.Stage))
	$readyText = if ($preflight.Ready) { "yes" } else { "no" }
	$lines.Add("Ready: $readyText")
	$lines.Add("")
	$lines.Add("| Check | State | Detail |")
	$lines.Add("| --- | --- | --- |")
	foreach ($check in $preflight.Checks) {
		$lines.Add(('| {0} | `{1}` | {2} |' -f $check.Name, $check.State, $check.Detail))
	}
	if (![string]::IsNullOrWhiteSpace($preflight.Command)) {
		$lines.Add("")
		$lines.Add("Command:")
		$lines.Add("")
		$lines.Add(('- `{0}`' -f $preflight.Command))
	}
	$lines.Add("")
}

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
