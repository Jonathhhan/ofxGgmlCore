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

function New-PostflightCheck {
	param(
		[string]$Name,
		[string]$State,
		[string]$Detail
	)

	[pscustomobject]@{
		Name = $Name
		State = $State
		Detail = $Detail
	}
}

function Get-GitStatusLines {
	param([string]$Path)

	if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path -PathType Container)) {
		return @()
	}

	$output = @(git -C $Path status --short 2>$null)
	if ($LASTEXITCODE -ne 0) {
		return @()
	}
	return @($output)
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
		$record = @($Plan.Records | Where-Object { $_.Repository -eq $Repository } | Select-Object -First 1)
		if (!$record) {
			throw "Repository was not found in smoke-build plan: $Repository"
		}
		$exampleMetadata = @($record.ExampleMetadata | Where-Object { $_.Example -eq $Example } | Select-Object -First 1)
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
			Action = "review smoke-build target postflight"
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

$postflights = @($targets | ForEach-Object {
	$target = $_
	$record = @($plan.Records | Where-Object { $_.Repository -eq $target.Repository } | Select-Object -First 1)
	$exampleMetadata = @($record.ExampleMetadata | Where-Object { $_.Example -eq $target.Example } | Select-Object -First 1)
	$examplePath = [string]$exampleMetadata.Path
	$repoPath = if (![string]::IsNullOrWhiteSpace($examplePath)) { Split-Path -Parent $examplePath } else { "" }
	$gitStatus = @(Get-GitStatusLines -Path $repoPath)
	$checks = @()

	$generatedFiles = @($exampleMetadata.GeneratedProjectFiles | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) })
	$generatedState = if ($generatedFiles.Count -gt 0) { "OK" } else { "PENDING" }
	$generatedDetail = if ($generatedFiles.Count -gt 0) { $generatedFiles -join "; " } else { "generated project files are not present yet" }
	$checks += New-PostflightCheck -Name "generated project files" -State $generatedState -Detail $generatedDetail

	$gitState = if ($gitStatus.Count -gt 0) { "REVIEW" } else { "OK" }
	$gitDetail = if ($gitStatus.Count -gt 0) { "$($gitStatus.Count) pending git changes in $repoPath" } else { "0 pending git changes in $repoPath" }
	$checks += New-PostflightCheck -Name "owning repository git impact" -State $gitState -Detail $gitDetail

	$stageComplete = $true
	$stageDetail = "stage does not require generated project files"
	if ($target.Stage -eq "generate-project") {
		$stageComplete = $generatedFiles.Count -gt 0
		$stageDetail = if ($stageComplete) { "project generation appears complete" } else { "project generation still appears pending" }
	} elseif ($target.Stage -eq "verify-generated-project") {
		$stageComplete = $generatedFiles.Count -gt 0
		$stageDetail = if ($stageComplete) { "generated project verification can proceed" } else { "generated project files are missing" }
	}
	$checks += New-PostflightCheck -Name "target stage completion" -State $(if ($stageComplete) { "OK" } else { "PENDING" }) -Detail $stageDetail

	[pscustomobject]@{
		Repository = $target.Repository
		Example = $target.Example
		Stage = $target.Stage
		Complete = $stageComplete
		ExamplePath = $examplePath
		RepositoryPath = $repoPath
		GeneratedProjectFiles = $generatedFiles
		GitStatus = $gitStatus
		Checks = @($checks)
		NextValidation = @(
			"scripts\plan-of-smoke-build.bat",
			"scripts\check-smoke-build-target-postflight.bat -Repository $($target.Repository) -Example $($target.Example)",
			"scripts\test-artifact-hygiene.ps1"
		)
	}
})

if ($Json) {
	[pscustomobject]@{
		Root = $plan.Root
		Stage = $Stage
		Postflights = $postflights
	} | ConvertTo-Json -Depth 8
	return
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Smoke Build Target Postflight")
$lines.Add("")
$lines.Add("Root: $($plan.Root)")
$lines.Add("Stage filter: $Stage")
$lines.Add("")

if ($postflights.Count -eq 0) {
	$lines.Add("No matching smoke-build targets.")
	Write-Output ($lines -join [Environment]::NewLine)
	return
}

foreach ($postflight in $postflights) {
	$completeText = if ($postflight.Complete) { "yes" } else { "no" }
	$lines.Add("## $($postflight.Repository) / $($postflight.Example)")
	$lines.Add("")
	$lines.Add(('Stage: `{0}`' -f $postflight.Stage))
	$lines.Add("Complete: $completeText")
	$lines.Add("")
	$lines.Add("| Check | State | Detail |")
	$lines.Add("| --- | --- | --- |")
	foreach ($check in $postflight.Checks) {
		$lines.Add(('| {0} | `{1}` | {2} |' -f $check.Name, $check.State, $check.Detail))
	}
	if ($postflight.GitStatus.Count -gt 0) {
		$lines.Add("")
		$lines.Add("## Git Impact")
		$lines.Add("")
		foreach ($line in $postflight.GitStatus) {
			$lines.Add(('- `{0}`' -f $line))
		}
	}
	$lines.Add("")
	$lines.Add("## Next Validation")
	$lines.Add("")
	foreach ($command in $postflight.NextValidation) {
		$lines.Add(('- `{0}`' -f $command))
	}
	$lines.Add("")
}

Write-Output ($lines -join [Environment]::NewLine)
