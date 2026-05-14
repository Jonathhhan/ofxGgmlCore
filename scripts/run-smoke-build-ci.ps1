param(
	[switch]$CloneAddonRepos,
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-smoke-build-compile.ps1"
$addonsRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

$managedAddonRepos = @(
	"ofxGgmlLlama",
	"ofxGgmlSam",
	"ofxGgmlAudio",
	"ofxGgmlVision",
	"ofxGgmlRag",
	"ofxGgmlVideo",
	"ofxGgmlMusic",
	"ofxGgmlDiffusion",
	"ofxGgmlAgents"
)

function Assert-ExistingRepos {
	param([string[]]$Repositories)

	$missing = @()
	foreach ($repo in $Repositories) {
		$target = Join-Path $addonsRoot $repo
		if (!(Test-Path -LiteralPath $target -PathType Container)) {
			$missing += $repo
		}
	}

	if ($missing.Count -gt 0) {
		throw "Required managed addon repositories are missing: $($missing -join ', '). Use -CloneAddonRepos on the first run."
	}
}

function Get-MaybeClonedRepos {
	param([string[]]$Repositories)

	foreach ($repo in $Repositories) {
		$target = Join-Path $addonsRoot $repo
		if (Test-Path -LiteralPath $target -PathType Container) {
			continue
		}

		$repoUrl = "https://github.com/Jonathhhan/$repo.git"
		Write-Host "==> Cloning $repo from $repoUrl"
		git clone --depth 1 $repoUrl $target
	}
}

function Get-StageTargets {
	param([string]$Stage)

	$planOutput = & $planScript -Stage $Stage -Configuration $Configuration -Platform $Platform -Json
	if (!$?) {
		throw "plan-smoke-build-compile.ps1 failed for stage: $Stage"
	}

	$planText = $planOutput -join [Environment]::NewLine
	if ([string]::IsNullOrWhiteSpace($planText)) {
		throw "plan-smoke-build-compile.ps1 returned empty JSON for stage: $Stage"
	}

	$plan = $planText | ConvertFrom-Json
	if (!$plan.AllTargets) {
		throw "plan-smoke-build-compile.ps1 JSON did not include AllTargets for stage: $Stage"
	}

	return @($plan.AllTargets | Where-Object { $_.Stage -eq $Stage })
}

function Get-ExecutableCommands {
	param([object]$Target)

	$commands = @($Target.NextCommands)
	if ($commands.Count -eq 0) {
		throw "No commands found for target $($Target.Repository) / $($Target.Example)."
	}

	$executableCommands = New-Object System.Collections.Generic.List[string]
	$blockedCommands = New-Object System.Collections.Generic.List[string]
	foreach ($command in $commands) {
		if ([string]::IsNullOrWhiteSpace([string]$command)) {
			continue
		}
		$normalized = [string]$command.Trim()
		if ($normalized -match "^#") {
			$blockedCommands.Add($normalized)
			continue
		}
		if ($normalized -match "Preflight is blocked") {
			$blockedCommands.Add($normalized)
			continue
		}
		$executableCommands.Add($normalized)
	}

	if ($executableCommands.Count -eq 0) {
		if ($blockedCommands.Count -gt 0) {
			throw "Target $($Target.Repository) / $($Target.Example) is blocked before execution: $($blockedCommands[0])"
		}
		throw "No executable commands found for target $($Target.Repository) / $($Target.Example)."
	}

	return @($executableCommands.ToArray())
}

function New-CommandResult {
	param(
		[string]$Command,
		[string]$Status,
		[int]$ExitCode,
		[string[]]$Output,
		[string]$StartedUtc,
		[string]$CompletedUtc
	)

	return @{
		Command = $Command
		Status = $Status
		ExitCode = $ExitCode
		Output = [string]::Join([Environment]::NewLine, @($Output))
		StartedUtc = $StartedUtc
		CompletedUtc = $CompletedUtc
	}
}

function Invoke-TargetCommands {
	param(
		[Parameter(Mandatory)] $Target
	)

	$commands = Get-ExecutableCommands -Target $Target
	$commandResults = New-Object System.Collections.Generic.List[object]

	foreach ($command in $commands) {
		if ([string]::IsNullOrWhiteSpace([string]$command)) {
			continue
		}

		Write-Host ("==> Running [{0} / {1}]: {2}" -f $Target.Repository, $Target.Example, $command)
		$commandStartedUtc = (Get-Date).ToUniversalTime().ToString("o")
		$commandOutput = New-Object System.Collections.Generic.List[string]
		cmd /c $command 2>&1 | ForEach-Object {
			$line = [string]$_
			Write-Host $line
			$commandOutput.Add($line)
		}
		$exitCode = [int]$LASTEXITCODE
		$commandCompletedUtc = (Get-Date).ToUniversalTime().ToString("o")
		$commandResults.Add((New-CommandResult `
			-Command ([string]$command) `
			-Status ($(if ($exitCode -eq 0) { "passed" } else { "failed" })) `
			-ExitCode $exitCode `
			-Output @($commandOutput.ToArray()) `
			-StartedUtc $commandStartedUtc `
			-CompletedUtc $commandCompletedUtc))

		if ($exitCode -ne 0) {
			throw "Command failed with exit code $exitCode for $($Target.Repository) / $($Target.Example): $command"
		}
	}

	return @{
		Repository = [string]$Target.Repository
		Example = [string]$Target.Example
		Status = "passed"
		CommandCount = [int]$commandResults.Count
		Commands = @($commandResults.ToArray())
		Error = ""
	}
}

if ($CloneAddonRepos) {
	Get-MaybeClonedRepos -Repositories $managedAddonRepos
} else {
	Assert-ExistingRepos -Repositories $managedAddonRepos
}

$defaultReportPath = if ([string]::IsNullOrWhiteSpace($ReportPath)) {
	if (![string]::IsNullOrWhiteSpace([string]$env:GITHUB_WORKSPACE)) {
		Join-Path $env:GITHUB_WORKSPACE ".smoke-build-ci-report.json"
	} elseif (![string]::IsNullOrWhiteSpace([string]$env:TEMP)) {
		Join-Path $env:TEMP "ofxgml-smoke-build-ci-report.json"
	} else {
		Join-Path (Get-Location).Path "ofxgml-smoke-build-ci-report.json"
	}
} else {
	$ReportPath
}

$report = @{
	Configuration = $Configuration
	Platform = $Platform
	StartedUtc = (Get-Date).ToUniversalTime().ToString("o")
	Stages = New-Object System.Collections.Generic.List[object]
	StageCount = 0
	TargetsRun = 0
	Outcome = "passed"
	Error = ""
}

$stageTargetsToRun = 0
$stages = @("generate-project", "repair-generated-project", "compile-example")

try {
	foreach ($stage in $stages) {
		$targets = Get-StageTargets -Stage $stage
		if ($targets.Count -eq 0) {
			Write-Host "==> No targets currently require stage: $stage"
			continue
		}

		$stageTargetsToRun++
		Write-Host ("==> Stage: {0} ({1} target(s))" -f $stage, $targets.Count)

		$stageEntry = @{
			Name = $stage
			TargetCount = $targets.Count
			Targets = New-Object System.Collections.Generic.List[object]
			StartedUtc = (Get-Date).ToUniversalTime().ToString("o")
			CompletedUtc = ""
			Outcome = "passed"
		}

		$orderedTargets = @($targets | Sort-Object @{Expression = "Order"; Descending = $false }, @{Expression = "Priority"; Descending = $false }, @{Expression = "Repository"; Descending = $false }, @{Expression = "Example"; Descending = $false })
		$index = 0
		foreach ($target in $orderedTargets) {
			$index++
			Write-Host ("==> [{0}/{1}] Target: {2} / {3}" -f $index, $orderedTargets.Count, $target.Repository, $target.Example)

			$targetEntry = @{
				Repository = [string]$target.Repository
				Example = [string]$target.Example
				Status = "passed"
				CommandCount = 0
				Commands = New-Object System.Collections.Generic.List[object]
				Error = ""
			}

			try {
				$targetResult = Invoke-TargetCommands -Target $target
				$targetEntry.Status = $targetResult.Status
				$targetEntry.CommandCount = $targetResult.CommandCount
				$targetEntry.Commands = @($targetResult.Commands)
			}
			catch {
				$targetEntry.Status = "failed"
				$targetEntry.Error = [string]$_.Exception.Message
				$report.Outcome = "failed"
				$report.Error = [string]$_.Exception.Message
				$stageEntry.Outcome = "failed"
				$stageEntry.Targets.Add($targetEntry)
				$report.TargetsRun++
				$stageEntry.CompletedUtc = (Get-Date).ToUniversalTime().ToString("o")
				$report.Stages.Add($stageEntry)
				throw
			}

			$report.TargetsRun++
			$stageEntry.Targets.Add($targetEntry)
		}

		$stageEntry.CompletedUtc = (Get-Date).ToUniversalTime().ToString("o")
		$report.Stages.Add($stageEntry)
	}

} catch {
	$report.Outcome = "failed"
	if ([string]::IsNullOrWhiteSpace($report.Error)) {
		$report.Error = [string]$_.Exception.Message
	}
	throw
} finally {
	$report.CompletedUtc = (Get-Date).ToUniversalTime().ToString("o")
	$report.StageCount = $stageTargetsToRun
	$reportPathDir = Split-Path -Parent $defaultReportPath
	if (![string]::IsNullOrWhiteSpace($reportPathDir)) {
		[void](New-Item -ItemType Directory -Path $reportPathDir -Force -ErrorAction SilentlyContinue)
	}

	[System.IO.File]::WriteAllText($defaultReportPath, ($report | ConvertTo-Json -Depth 10))
	Write-Host "Smoke build report written to: $defaultReportPath"
}
