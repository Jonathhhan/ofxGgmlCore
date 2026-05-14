param(
	[string]$Stage = "compile-example",
	[int]$First = 1,
	[string]$Repository = "",
	[string]$Example = "",
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
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

function Get-CompileCommand {
	param(
		[string]$Repository,
		[string]$Example,
		[string]$Configuration,
		[string]$Platform
	)

	switch ($Repository) {
		"ofxGgmlCore" {
			if ($Example -eq "ofxGgmlCoreExample") {
				return "scripts\build-simple-example.bat -Example $Example -Configuration $Configuration -Platform $Platform"
			}
		}
		"ofxGgmlAudio" {
			if ($Example -eq "ofxGgmlAudioTranscribeExample") {
				return "..\ofxGgmlAudio\scripts\build-transcribe-example.bat -Configuration $Configuration -Platform $Platform"
			}
		}
		"ofxGgmlLlama" {
			$kind = switch ($Example) {
				"ofxGgmlTextExample" { "text" }
				"ofxGgmlChatExample" { "chat" }
				"ofxGgmlEmbeddingExample" { "embedding" }
				default { "" }
			}
			if (![string]::IsNullOrWhiteSpace($kind)) {
				return "..\ofxGgmlLlama\scripts\build-example.bat $kind -Configuration $Configuration -Platform $Platform"
			}
		}
		"ofxGgmlDiffusion" {
			if ($Example -eq "ofxGgmlDiffusionPromptExample" -or $Example -eq "ofxGgmlDiffusionGanExample") {
				return "..\ofxGgmlDiffusion\scripts\build-diffusion-example.bat -Example $Example -Configuration $Configuration -Platform $Platform"
			}
		}
	}

	return "scripts\build-smoke-example.bat -Repository $Repository -Example $Example -Configuration $Configuration -Platform $Platform"
}

function Get-CompileTargetState {
	param(
		[object]$ExampleMetadata,
		[object]$Postflight,
		[string]$CompileCommand
	)

	if (!$ExampleMetadata.HasGeneratedProject) {
		return "generate-project"
	}
	$complete = if ($Postflight) {
		[bool](Get-ObjectPropertyValue -Object $Postflight -Name "Complete")
	} else {
		$false
	}
	if (!$complete) {
		return "repair-generated-project"
	}
	if ([string]::IsNullOrWhiteSpace($CompileCommand)) {
		return "add-compile-command"
	}
	return "compile-example"
}

function Get-CompileTargetAction {
	param([string]$State)

	switch ($State) {
		"generate-project" { "generate project files before compile planning" }
		"repair-generated-project" { "repair or verify generated project addon wiring before compile" }
		"add-compile-command" { "add a focused compile command mapping before automated build handoff" }
		"compile-example" { "run the focused example compile command and keep generated artifacts out of git" }
		default { "review compile target" }
	}
}

function ConvertTo-StringArray {
	param($Value)

	if ($null -eq $Value) {
		return @()
	}
	if ($Value -is [pscustomobject] -and $Value.PSObject.Properties.Count -eq 0) {
		return @()
	}
	return @($Value | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
}

function Get-ObjectPropertyValue {
	param(
		[object]$Object,
		[string]$Name
	)

	if ($null -eq $Object) {
		return $null
	}
	$property = $Object.PSObject.Properties[$Name]
	if (!$property) {
		return $null
	}
	return $property.Value
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-of-smoke-build.ps1"
$postflightScript = Join-Path $scriptRoot "check-smoke-build-target-postflight.ps1"

$planJson = & $planScript -Json
if (!$?) {
	throw "plan-of-smoke-build.ps1 -Json failed."
}
$plan = ($planJson -join [Environment]::NewLine) | ConvertFrom-Json

$targets = New-Object System.Collections.Generic.List[object]
foreach ($record in @($plan.Records)) {
	if (![string]::IsNullOrWhiteSpace($Repository) -and $record.Repository -ne $Repository) {
		continue
	}
	foreach ($exampleMetadata in @($record.ExampleMetadata)) {
		if (![string]::IsNullOrWhiteSpace($Example) -and $exampleMetadata.Example -ne $Example) {
			continue
		}

		$postflight = $null
		if ($exampleMetadata.HasGeneratedProject) {
			$postflightJson = & $postflightScript -Stage "verify-generated-project" -Repository ([string]$record.Repository) -Example ([string]$exampleMetadata.Example) -Json
			if (!$?) {
				throw "check-smoke-build-target-postflight.ps1 -Json failed for $($record.Repository) / $($exampleMetadata.Example)."
			}
			$postflightResult = ($postflightJson -join [Environment]::NewLine) | ConvertFrom-Json
			$postflight = $postflightResult.Postflights | Select-Object -First 1
		}

		$compileCommand = Get-CompileCommand `
			-Repository ([string]$record.Repository) `
			-Example ([string]$exampleMetadata.Example) `
			-Configuration $Configuration `
			-Platform $Platform
		$state = Get-CompileTargetState -ExampleMetadata $exampleMetadata -Postflight $postflight -CompileCommand $compileCommand
		$nextCommands = New-Object System.Collections.Generic.List[string]
		if ($state -eq "generate-project") {
			if (![string]::IsNullOrWhiteSpace([string]$exampleMetadata.ProjectGeneratorCommand)) {
				$nextCommands.Add([string]$exampleMetadata.ProjectGeneratorCommand)
			}
			$nextCommands.Add("scripts\check-smoke-build-target-postflight.bat -Stage verify-generated-project -Repository $($record.Repository) -Example $($exampleMetadata.Example)")
		} elseif ($state -eq "repair-generated-project") {
			$nextCommands.Add("scripts\plan-smoke-build-project-repair.bat -Stage verify-generated-project -Repository $($record.Repository) -Example $($exampleMetadata.Example)")
			$nextCommands.Add("scripts\check-smoke-build-target-postflight.bat -Stage verify-generated-project -Repository $($record.Repository) -Example $($exampleMetadata.Example)")
		} elseif ($state -eq "compile-example") {
			$nextCommands.Add("scripts\check-smoke-build-target-postflight.bat -Stage verify-generated-project -Repository $($record.Repository) -Example $($exampleMetadata.Example)")
			$nextCommands.Add($compileCommand)
			$nextCommands.Add("scripts\test-artifact-hygiene.ps1")
		} else {
			$nextCommands.Add("scripts\plan-smoke-build-compile.bat -Repository $($record.Repository) -Example $($exampleMetadata.Example)")
		}
		$missingProjectAddons = New-Object System.Collections.Generic.List[string]
		if ($postflight) {
			foreach ($missingAddon in @(ConvertTo-StringArray -Value (Get-ObjectPropertyValue -Object $postflight -Name "MissingProjectAddons"))) {
				$missingProjectAddons.Add($missingAddon)
			}
		}
		$completeGeneratedProject = if ($postflight) {
			[bool](Get-ObjectPropertyValue -Object $postflight -Name "Complete")
		} else {
			$false
		}

		$targets.Add([pscustomobject]@{
			Priority = switch ($state) {
				"generate-project" { 30 }
				"repair-generated-project" { 40 }
				"add-compile-command" { 45 }
				"compile-example" { 50 }
				default { 90 }
			}
			Order = Get-RepositorySmokeBuildOrder -Repository ([string]$record.Repository)
			Repository = [string]$record.Repository
			Example = [string]$exampleMetadata.Example
			Stage = $state
			Action = Get-CompileTargetAction -State $state
			CompleteGeneratedProject = $completeGeneratedProject
			GeneratedProjectFiles = @(Get-ObjectPropertyValue -Object $exampleMetadata -Name "GeneratedProjectFiles")
			MissingProjectAddons = $missingProjectAddons
			CompileCommand = $compileCommand
			NextCommands = @($nextCommands.ToArray())
		})
	}
}

$orderedTargets = @($targets | Sort-Object Priority, Order, Example)
$selectedTargets = @($orderedTargets | Where-Object { $_.Stage -eq $Stage } | Select-Object -First $First)
if (![string]::IsNullOrWhiteSpace($Repository)) {
	$selectedTargets = @($orderedTargets | Select-Object -First $First)
}
$nextCommandList = New-Object System.Collections.Generic.List[string]
foreach ($target in @($selectedTargets)) {
	foreach ($command in @($target.NextCommands)) {
		if (!$nextCommandList.Contains($command)) {
			$nextCommandList.Add($command)
		}
	}
}
$nextCommands = @($nextCommandList.ToArray())
$compileReady = @($orderedTargets | Where-Object { $_.Stage -eq "compile-example" })
$needsRepair = @($orderedTargets | Where-Object { $_.Stage -eq "repair-generated-project" })
$needsCommand = @($orderedTargets | Where-Object { $_.Stage -eq "add-compile-command" })
$safetyNote = "This compile plan is non-mutating. Run focused build commands only after generated-project postflight is OK, and keep generated outputs out of git."

if ($Json) {
	[pscustomobject]@{
		Root = $plan.Root
		Stage = $Stage
		Configuration = $Configuration
		Platform = $Platform
		Targets = $selectedTargets
		AllTargets = $orderedTargets
		CompileReadyTargets = $compileReady.Count
		RepairTargets = $needsRepair.Count
		MissingCommandTargets = $needsCommand.Count
		NextCommands = $nextCommands
		SafetyNote = $safetyNote
	} | ConvertTo-Json -Depth 8
	return
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Smoke Build Compile Plan")
$lines.Add("")
$lines.Add("Root: $($plan.Root)")
$lines.Add("Stage filter: $Stage")
$lines.Add("Configuration: $Configuration")
$lines.Add("Platform: $Platform")
$lines.Add("")
$lines.Add("## Summary")
$lines.Add("")
$lines.Add("| Metric | Count |")
$lines.Add("| --- | ---: |")
$lines.Add("| Compile-ready targets | $($compileReady.Count) |")
$lines.Add("| Generated-project repair targets | $($needsRepair.Count) |")
$lines.Add("| Missing compile-command targets | $($needsCommand.Count) |")
$lines.Add("")

if ($selectedTargets.Count -eq 0) {
	$lines.Add("No matching compile targets.")
	Write-Output ($lines -join [Environment]::NewLine)
	return
}

$lines.Add("## Targets")
$lines.Add("")
$lines.Add("| Priority | Repository | Example | Stage | Action |")
$lines.Add("| ---: | --- | --- | --- | --- |")
foreach ($target in @($selectedTargets)) {
	$lines.Add(('| {0} | `{1}` | `{2}` | `{3}` | {4} |' -f $target.Priority, $target.Repository, $target.Example, $target.Stage, $target.Action))
}

$commands = @($selectedTargets | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_.CompileCommand) })
if ($commands.Count -gt 0) {
	$lines.Add("")
	$lines.Add("## Compile Commands")
	$lines.Add("")
	foreach ($target in $commands) {
		$lines.Add(('- `{0}`' -f $target.CompileCommand))
	}
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
