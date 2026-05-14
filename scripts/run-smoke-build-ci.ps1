param(
	[switch]$CloneAddonRepos,
	[string]$Configuration = "Release",
	[string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-smoke-build-compile.ps1"

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

function Get-MaybeClonedRepos {
	param([string[]]$Repositories)

	$addonsRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)
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
	$plan = ($planOutput -join [Environment]::NewLine) | ConvertFrom-Json
	return @($plan.AllTargets | Where-Object { $_.Stage -eq $Stage })
}

function Invoke-TargetCommands {
	param(
		[Parameter(Mandatory)] $Target
	)

	$commands = @($Target.NextCommands)
	if ($commands.Count -eq 0) {
		throw "No executable commands found for target $($Target.Repository) / $($Target.Example)"
	}

	foreach ($command in $commands) {
		if ([string]::IsNullOrWhiteSpace([string]$command)) {
			continue
		}
		Write-Host ("==> Running [{0} / {1}]: {2}" -f $Target.Repository, $Target.Example, $command)
		cmd /c $command
		if ($LASTEXITCODE -ne 0) {
			throw "Command failed with exit code $LASTEXITCODE for $($Target.Repository) / $($Target.Example): $command"
		}
	}
}

if ($CloneAddonRepos) {
	Get-MaybeClonedRepos -Repositories $managedAddonRepos
}

$stages = @("generate-project", "repair-generated-project", "compile-example")
foreach ($stage in $stages) {
	$targets = Get-StageTargets -Stage $stage
	if ($targets.Count -eq 0) {
		Write-Host "No targets currently require stage: $stage"
		continue
	}

	Write-Host "==> Stage: $stage"
	$orderedTargets = @($targets | Sort-Object @{Expression = "Order"; Descending = $false }, @{Expression = "Priority"; Descending = $false }, @{Expression = "Repository"; Descending = $false }, @{Expression = "Example"; Descending = $false })
	foreach ($target in $orderedTargets) {
		Invoke-TargetCommands -Target $target
	}
}

