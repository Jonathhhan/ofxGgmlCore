param(
	[string[]]$Addons = @(),
	[switch]$IncludeDiscovered,
	[switch]$DryRun,
	[switch]$Check
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function ConvertTo-ValidationCommand {
	param([string]$AddonName)
	if ($AddonName -eq "ofxGgmlCore") {
		return "scripts\release-candidate.ps1"
	}
	return "scripts\validate-local.ps1"
}

function New-AgentInstructions {
	param([hashtable]$Addon)

	$name = [string]$Addon["Name"]
	$lane = [string]$Addon["Lane"]
	$scope = [string]$Addon["Scope"]
	$validation = ConvertTo-ValidationCommand $name
	return @"
# Codex Repository Instructions

This repository is part of the ofxGgml openFrameworks addon ecosystem.

## Addon Scope

- Addon: $name
- Lane: $lane
- Role: $scope

## Working Rules

- Read the existing code and docs before changing behavior.
- Keep edits scoped to this addon's lane and preserve the companion-addon split.
- Start with an ecosystem plan when a task asks for cross-repo improvement or planning.
- Keep ofxGgmlCore as the shared base; do not add reverse dependencies from Core to companion addons.
- Do not commit generated project files, binaries, model weights, downloaded runtimes, sample media dumps, memory indexes, or caches.
- Prefer focused tests and local validation over broad refactors.
- Preserve openFrameworks-style public names and document intentional breaking changes.

## Validation

Validation before handoff: $validation.

For ecosystem planning work, run `scripts\plan-ecosystem.ps1` from ofxGgmlCore
before proposing addon-code changes.

## Ecosystem Notes

Model-specific UX belongs in companion addons. Shared code should move down into
ofxGgmlCore only after it is stable, domain-neutral, dependency-light, and
covered by focused tests.
"@
}

function New-CopilotInstructions {
	param([hashtable]$Addon)

	$name = [string]$Addon["Name"]
	$scope = [string]$Addon["Scope"]
	$validation = ConvertTo-ValidationCommand $name
	return @"
# GitHub Copilot Repository Instructions

$name is part of the ofxGgml openFrameworks addon ecosystem.

- Scope: $scope
- Keep changes inside this addon's lane unless a task explicitly asks for a cross-addon update.
- For ecosystem planning tasks, prefer instruction, documentation, workflow, and validation changes before addon source changes.
- Use ofxGgmlCore for shared runtime primitives and keep companion workflows out of Core.
- Avoid committing generated outputs, local models, build directories, IDE metadata, downloaded runtimes, caches, or media dumps.
- Add or update headless tests for public helper behavior.
- Validation before handoff: $validation.
- Keep explanations concise and include the files and checks that matter.
"@
}

function New-HermesInstructions {
	param([hashtable]$Addon)

	$name = [string]$Addon["Name"]
	$lane = [string]$Addon["Lane"]
	$scope = [string]$Addon["Scope"]
	$validation = ConvertTo-ValidationCommand $name
	return @"
# Hermes Project Context

This repository is part of the ofxGgml openFrameworks addon ecosystem.

## Repository

- Addon: $name
- Lane: $lane
- Scope: $scope

## Hermes Agent Rules

- Treat this file as project context for Hermes Agent.
- Read README.md, addon_config.mk, docs, scripts, and tests before changing behavior.
- Keep changes inside this repository's lane unless the task explicitly requires cross-repo coordination.
- For ecosystem improvement work, create or update a plan before touching addon source.
- Keep ofxGgmlCore as the shared base; companion addons may depend on Core, but Core must not depend on companions.
- Do not commit generated binaries, model files, downloaded runtimes, build folders, IDE metadata, memory indexes, caches, or media dumps.
- Prefer small, validated changes over broad refactors.
- Validation before handoff: $validation.

## Planning Workflow

- Use `scripts\status-family.ps1` and `scripts\plan-ecosystem.ps1` from ofxGgmlCore for cross-repo planning.
- Classify each task as documentation, automation, validation, or addon-code work.
- Work in the agent layer first when the goal is better Codex, Copilot, or Hermes planning.
- Touch addon source only when the user explicitly asks for addon behavior.

## Ecosystem Split

Model-specific workflows belong in companion addons. Shared helpers should move
to ofxGgmlCore only when they are stable, domain-neutral, dependency-light, and
covered by focused tests.
"@
}

function New-InstructionWorkflow {
	param([hashtable]$Addon)

	$name = [string]$Addon["Name"]
	$requiresAddonShape = $name -ne "ofxGgmlWorkflows"
	$requiresScripts = $name -ne "ofxGgmlWorkflows"
	$addonValue = if ($requiresAddonShape) { "true" } else { "false" }
	$scriptsValue = if ($requiresScripts) { "true" } else { "false" }
	return @"
name: coding-agent-instructions

on:
  push:
  pull_request:

jobs:
  coding-agent-instructions:
    uses: Jonathhhan/ofxGgmlWorkflows/.github/workflows/coding-agent-instructions.yml@main
    with:
      require_addon_config: $addonValue
      require_scripts: $scriptsValue
"@
}

function Set-TextFile {
	param(
		[string]$Path,
		[string]$Content
	)

	$directory = Split-Path -Parent $Path
	if (!(Test-Path -LiteralPath $directory -PathType Container)) {
		New-Item -ItemType Directory -Path $directory -Force | Out-Null
	}
	Set-Content -LiteralPath $Path -Value $Content
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreRoot = Resolve-Path (Join-Path $scriptRoot "..")
$addonsRoot = Split-Path -Parent $coreRoot

. (Join-Path $scriptRoot "get-ecosystem.ps1")
$family = @(Get-OfxGgmlEcosystem -AddonsRoot $addonsRoot)

if (!$IncludeDiscovered) {
	$family = @($family | Where-Object { $_.Known })
}

if ($Addons.Count -gt 0) {
	$wanted = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
	foreach ($addon in $Addons) {
		[void]$wanted.Add($addon)
	}
	$family = @($family | Where-Object { $wanted.Contains($_.Name) })
}

if ($family.Count -eq 0) {
	throw "No matching ofxGgml addon names were selected."
}

$changed = 0
$missingOrOutdated = New-Object System.Collections.Generic.List[string]

foreach ($addon in $family) {
	$addonRoot = Join-Path $addonsRoot $addon.Name
	if (!(Test-Path -LiteralPath $addonRoot -PathType Container)) {
		Write-Step "Skipping missing addon $($addon.Name)"
		continue
	}

	$files = @(
		@{
			Path = Join-Path $addonRoot "AGENTS.md"
			Content = New-AgentInstructions $addon
		},
		@{
			Path = Join-Path $addonRoot ".github\copilot-instructions.md"
			Content = New-CopilotInstructions $addon
		},
		@{
			Path = Join-Path $addonRoot "HERMES.md"
			Content = New-HermesInstructions $addon
		}
	)

	if ($addon.Name -ne "ofxGgmlWorkflows") {
		$files += @{
			Path = Join-Path $addonRoot ".github\workflows\coding-agent-instructions.yml"
			Content = New-InstructionWorkflow $addon
		}
	}

	foreach ($file in $files) {
		$existing = if (Test-Path -LiteralPath $file.Path -PathType Leaf) {
			Get-Content -LiteralPath $file.Path -Raw
		} else {
			""
		}
		$expected = $file.Content.TrimEnd() + [Environment]::NewLine
		if ($existing -ne $expected) {
			$changed++
			if ($Check) {
				$missingOrOutdated.Add($file.Path)
			} elseif ($DryRun) {
				Write-Step "Would write $($file.Path)"
			} else {
				Write-Step "Writing $($file.Path)"
				Set-TextFile -Path $file.Path -Content $file.Content
			}
		}
	}
}

if ($Check -and $missingOrOutdated.Count -gt 0) {
	throw "Agent instruction files are missing or outdated:`n$($missingOrOutdated -join "`n")"
}

if ($Check) {
	Write-Step "Agent instruction files are current"
} elseif ($DryRun) {
	Write-Step "Dry run complete; $changed file(s) would change"
} else {
	Write-Step "Agent instruction generation complete; $changed file(s) changed"
}
