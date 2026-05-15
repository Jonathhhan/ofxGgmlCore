param(
	[string]$OutputPath = "",
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-SmokeBuildPhase {
	param(
		[object]$Status,
		[array]$ExampleMetadata
	)

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
	if (@($ExampleMetadata | Where-Object { !$_.HasAddonsMake }).Count -gt 0) {
		return "needs-example-addons-metadata"
	}
	if (@($ExampleMetadata | Where-Object { !$_.HasOwnerAddon -or !$_.HasCoreAddon }).Count -gt 0) {
		return "needs-example-addon-references"
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
		"needs-example-addons-metadata" { "add addons.make to every root-level smoke example before project-generation checks" }
		"needs-example-addon-references" { "add owner addon and ofxGgmlCore references to example addons.make files" }
		"ready-for-project-generation-check" { "plan projectGenerator verification before CI compile gates" }
		default { "review smoke-build readiness" }
	}
}

function Format-PowerShellArgument {
	param([string]$Value)

	return "'" + ($Value -replace "'", "''") + "'"
}

function Find-ProjectGenerator {
	param([string]$OfRoot)

	foreach ($candidate in @(
		"projectGenerator\projectGeneratorCmd.exe",
		"projectGenerator\resources\app\app\projectGenerator.exe",
		"projectGenerator\projectGenerator.exe",
		"projectGenerator\projectGenerator",
		"projectGenerator-jan2026\projectGeneratorCmd.exe",
		"projectGenerator-jan2026\resources\app\app\projectGenerator.exe",
		"projectGenerator-jan2026\projectGenerator.exe",
		"projectGenerator-jan2026\projectGenerator"
	)) {
		$path = Join-Path $OfRoot $candidate
		if (Test-Path -LiteralPath $path -PathType Leaf) {
			return $path
		}
	}

	return ""
}

function Get-GeneratedProjectFiles {
	param(
		[string]$ExamplePath,
		[string]$Example
	)

	$files = New-Object System.Collections.Generic.List[string]
	foreach ($path in @(
		(Join-Path $ExamplePath "$Example.vcxproj"),
		(Join-Path $ExamplePath "Makefile")
	)) {
		if (Test-Path -LiteralPath $path -PathType Leaf) {
			$files.Add($path)
		}
	}
	foreach ($path in @(Get-ChildItem -LiteralPath $ExamplePath -Filter "*.xcodeproj" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })) {
		$files.Add($path)
	}

	return @($files)
}

function New-ProjectGeneratorCommand {
	param(
		[string]$ProjectGeneratorPath,
		[string]$OfRoot,
		[string]$ExamplePath,
		[array]$Addons
	)

	if ([string]::IsNullOrWhiteSpace($ProjectGeneratorPath)) {
		return ""
	}

	$addonList = $Addons -join ","
	return "& {0} -p{1} -o{2} -a{3} {4}" -f `
		(Format-PowerShellArgument $ProjectGeneratorPath),
		(Format-PowerShellArgument "vs"),
		(Format-PowerShellArgument $OfRoot),
		(Format-PowerShellArgument $addonList),
		(Format-PowerShellArgument $ExamplePath)
}

function Get-ExampleMetadata {
	param(
		[object]$Status,
		[string]$OfRoot,
		[string]$ProjectGeneratorPath
	)

	if (!$Status.Present -or !$Status.Examples -or $Status.Examples.Count -eq 0) {
		return @()
	}

	return @($Status.Examples | ForEach-Object {
		$example = [string]$_
		$examplePath = Join-Path ([string]$Status.Path) $example
		$addonsMakePath = Join-Path $examplePath "addons.make"
		$hasAddonsMake = Test-Path -LiteralPath $addonsMakePath -PathType Leaf
		$addons = @()
		if ($hasAddonsMake) {
			$addons = @(Get-Content -LiteralPath $addonsMakePath | ForEach-Object { $_.Trim() } | Where-Object {
				![string]::IsNullOrWhiteSpace($_) -and !$_.StartsWith("#")
			})
		}
		$missing = New-Object System.Collections.Generic.List[string]
		if (!$hasAddonsMake) {
			$missing.Add("addons.make")
		}
		if (!$addons.Contains([string]$Status.Name)) {
			$missing.Add("owner addon")
		}
		if (!$addons.Contains("ofxGgmlCore")) {
			$missing.Add("ofxGgmlCore")
		}
		$generatedProjectFiles = @(Get-GeneratedProjectFiles -ExamplePath $examplePath -Example $example)

		[pscustomobject]@{
			Example = $example
			Path = $examplePath
			HasAddonsMake = $hasAddonsMake
			HasOwnerAddon = $addons.Contains([string]$Status.Name)
			HasCoreAddon = $addons.Contains("ofxGgmlCore")
			Addons = $addons
			Missing = @($missing)
			HasGeneratedProject = $generatedProjectFiles.Count -gt 0
			GeneratedProjectFiles = $generatedProjectFiles
			ProjectGeneratorCommand = New-ProjectGeneratorCommand `
				-ProjectGeneratorPath $ProjectGeneratorPath `
				-OfRoot $OfRoot `
				-ExamplePath $examplePath `
				-Addons $addons
		}
	})
}

function Format-ExampleMetadataSummary {
	param([object]$Record)

	if (!$Record.ExampleMetadata -or $Record.ExampleMetadata.Count -eq 0) {
		return "-"
	}

	$missing = @($Record.ExampleMetadata | Where-Object { $_.Missing.Count -gt 0 })
	if ($missing.Count -eq 0) {
		return "ok"
	}

	return (($missing | ForEach-Object {
		"$($_.Example): $($_.Missing -join ', ')"
	}) -join "; ")
}

function Get-RepositorySmokeBuildOrder {
	param([string]$Repository)

	switch ($Repository) {
		"ofxGgmlCore" { 10 }
		"ofxGgmlLlama" { 20 }
		"ofxGgmlSam" { 30 }
		"ofxGgmlAudio" { 40 }
		"ofxGgmlVision" { 50 }
		"ofxGgmlRag" { 60 }
		"ofxGgmlVideo" { 70 }
		"ofxGgmlMusic" { 80 }
		"ofxGgmlDiffusion" { 90 }
		"ofxGgmlAgents" { 100 }
		default { 900 }
	}
}

function Get-SmokeBuildTargets {
	param([array]$Records)

	$targets = New-Object System.Collections.Generic.List[object]
	foreach ($record in $Records) {
		foreach ($example in @($record.ExampleMetadata)) {
			$stage = "verify-generated-project"
			$priority = 40
			$action = "verify generated project repair/build readiness before compile gates"
			if ($example.Missing.Count -gt 0) {
				$stage = "repair-example-metadata"
				$priority = 10
				$action = "repair example metadata before project generation"
			} elseif ([string]::IsNullOrWhiteSpace([string]$example.ProjectGeneratorCommand)) {
				$stage = "detect-projectGenerator"
				$priority = 20
				$action = "install or expose projectGenerator before generating projects"
			} elseif (!$example.HasGeneratedProject) {
				$stage = "generate-project"
				$priority = 30
				$action = "run projectGenerator command and keep generated outputs out of commits"
			}

			$targets.Add([pscustomobject]@{
				Priority = $priority
				Order = Get-RepositorySmokeBuildOrder -Repository ([string]$record.Repository)
				Repository = $record.Repository
				Example = $example.Example
				Stage = $stage
				Action = $action
				Command = [string]$example.ProjectGeneratorCommand
			})
		}
	}

	return @($targets | Sort-Object Priority, Order, Example)
}

function Get-SmokeBuildPlanSummary {
	param(
		[array]$Records,
		[array]$Targets
	)

	$exampleMetadata = @($Records | ForEach-Object { $_.ExampleMetadata })
	return [pscustomobject]@{
		ManagedRecords = @($Records).Count
		ReadyForProjectGenerationChecks = @($Records | Where-Object { $_.Phase -eq "ready-for-project-generation-check" }).Count
		WorkflowOnlyRecords = @($Records | Where-Object { $_.Phase -eq "workflow-owner" }).Count
		MissingLocalValidation = @($Records | Where-Object { $_.Phase -eq "needs-local-validation" }).Count
		MissingRootExampleInventory = @($Records | Where-Object { $_.Phase -eq "needs-root-example-inventory" }).Count
		ExamplesWithAddonsMake = @($exampleMetadata | Where-Object { $_.HasAddonsMake }).Count
		ExamplesMissingOwnerAddon = @($exampleMetadata | Where-Object { !$_.HasOwnerAddon }).Count
		ExamplesMissingCoreAddon = @($exampleMetadata | Where-Object { !$_.HasCoreAddon }).Count
		ExamplesWithProjectGeneratorCommands = @($exampleMetadata | Where-Object { ![string]::IsNullOrWhiteSpace($_.ProjectGeneratorCommand) }).Count
		ExamplesWithGeneratedProjectFiles = @($exampleMetadata | Where-Object { $_.HasGeneratedProject }).Count
		GenerateProjectTargets = @($Targets | Where-Object { $_.Stage -eq "generate-project" }).Count
		VerifyGeneratedProjectTargets = @($Targets | Where-Object { $_.Stage -eq "verify-generated-project" }).Count
	}
}

function Get-SmokeBuildPlanNextCommands {
	$commands = New-Object System.Collections.Generic.List[string]
	$commands.Add("scripts\select-smoke-build-target.bat -Stage generate-project")
	$commands.Add("scripts\plan-smoke-build-target-handoff.bat -Stage generate-project")
	$commands.Add("scripts\check-smoke-build-target-preflight.bat -Stage generate-project")
	$commands.Add("scripts\test-of-smoke-build-plan.ps1")
	return @($commands.ToArray())
}

function ConvertTo-MarkdownSmokeBuildPlan {
	param(
		[array]$Records,
		[array]$Targets,
		[string]$Root,
		[string]$ProjectGeneratorPath
	)

	$ready = @($Records | Where-Object { $_.Phase -eq "ready-for-project-generation-check" })
	$exampleMetadata = @($Records | ForEach-Object { $_.ExampleMetadata })
	$projectGeneratorCommands = @($exampleMetadata | Where-Object { ![string]::IsNullOrWhiteSpace($_.ProjectGeneratorCommand) })
	$generatedProjects = @($exampleMetadata | Where-Object { $_.HasGeneratedProject })
	$generateTargets = @($Targets | Where-Object { $_.Stage -eq "generate-project" })
	$verifyTargets = @($Targets | Where-Object { $_.Stage -eq "verify-generated-project" })
	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# openFrameworks Smoke Build Plan")
	$lines.Add("")
	$lines.Add("Non-mutating rollout plan for moving the managed ofxGgml ecosystem from structural checks toward real openFrameworks project-generation and compile validation.")
	$lines.Add("")
	$lines.Add("Root: $Root")
	$lines.Add("ProjectGenerator: $(if ([string]::IsNullOrWhiteSpace($ProjectGeneratorPath)) { 'not detected' } else { $ProjectGeneratorPath })")
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
	$lines.Add("| Examples with addons.make | $(@($exampleMetadata | Where-Object { $_.HasAddonsMake }).Count) |")
	$lines.Add("| Examples missing owner addon | $(@($exampleMetadata | Where-Object { !$_.HasOwnerAddon }).Count) |")
	$lines.Add("| Examples missing ofxGgmlCore | $(@($exampleMetadata | Where-Object { !$_.HasCoreAddon }).Count) |")
	$lines.Add("| Examples with projectGenerator commands | $($projectGeneratorCommands.Count) |")
	$lines.Add("| Examples with generated project files | $($generatedProjects.Count) |")
	$lines.Add("| Generate-project targets | $($generateTargets.Count) |")
	$lines.Add("| Verify-generated-project targets | $($verifyTargets.Count) |")
	$lines.Add("")
	$lines.Add("## Repository Plan")
	$lines.Add("")
	$lines.Add("| Repository | Lane | Examples | Example metadata | Phase | Next action |")
	$lines.Add("| --- | --- | --- | --- | --- | --- |")
	foreach ($record in $Records) {
		$examples = if ($record.Examples.Count -gt 0) { $record.Examples -join ", " } else { "-" }
		$metadata = Format-ExampleMetadataSummary -Record $record
		$lines.Add(('| `{0}` | `{1}` | `{2}` | `{3}` | `{4}` | {5} |' -f $record.Repository, $record.Lane, $examples, $metadata, $record.Phase, $record.Action))
	}
	if ($projectGeneratorCommands.Count -gt 0) {
		$lines.Add("")
		$lines.Add("## ProjectGenerator Command Plan")
		$lines.Add("")
		$lines.Add("These commands are for manual or CI verification planning. Do not commit generated project files unless an addon explicitly owns them.")
		$lines.Add("")
		$lines.Add("| Repository | Example | Generated project | Command |")
		$lines.Add("| --- | --- | --- | --- |")
		foreach ($record in $Records) {
			foreach ($example in @($record.ExampleMetadata | Where-Object { ![string]::IsNullOrWhiteSpace($_.ProjectGeneratorCommand) })) {
				$generatedProject = if ($example.HasGeneratedProject) { "present" } else { "missing" }
				$lines.Add(('| `{0}` | `{1}` | `{2}` | `{3}` |' -f $record.Repository, $example.Example, $generatedProject, $example.ProjectGeneratorCommand))
			}
		}
	}
	if ($Targets.Count -gt 0) {
		$lines.Add("")
		$lines.Add("## Next Targets")
		$lines.Add("")
		$lines.Add("| Priority | Repository | Example | Stage | Action |")
		$lines.Add("| ---: | --- | --- | --- | --- |")
		foreach ($target in $Targets) {
			$lines.Add(('| {0} | `{1}` | `{2}` | `{3}` | {4} |' -f $target.Priority, $target.Repository, $target.Example, $target.Stage, $target.Action))
		}
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
$ofRoot = Split-Path -Parent ([string]$status.Root)
$projectGeneratorPath = Find-ProjectGenerator -OfRoot $ofRoot
$managed = @($status.Addons | Where-Object { $_.Known })
$records = @($managed | ForEach-Object {
	$exampleMetadata = @(Get-ExampleMetadata -Status $_ -OfRoot $ofRoot -ProjectGeneratorPath $projectGeneratorPath)
	$phase = Get-SmokeBuildPhase -Status $_ -ExampleMetadata $exampleMetadata
	[pscustomobject]@{
		Repository = [string]$_.Name
		Lane = [string]$_.Lane
		Examples = @($_.Examples)
		ExampleMetadata = $exampleMetadata
		Phase = $phase
		Action = Get-SmokeBuildAction -Phase $phase
	}
})
$targets = @(Get-SmokeBuildTargets -Records $records)
$summary = Get-SmokeBuildPlanSummary -Records $records -Targets $targets
$nextCommands = Get-SmokeBuildPlanNextCommands

if ($Json) {
	$content = [pscustomobject]@{
		Root = $status.Root
		OfRoot = $ofRoot
		ProjectGeneratorPath = $projectGeneratorPath
		Summary = $summary
		NextCommands = $nextCommands
		Records = $records
		Targets = $targets
	} | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownSmokeBuildPlan -Records $records -Targets $targets -Root ([string]$status.Root) -ProjectGeneratorPath $projectGeneratorPath
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
