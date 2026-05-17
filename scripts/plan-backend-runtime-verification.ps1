param(
	[string]$OutputPath = "",
	[switch]$SummaryOnly,
	[switch]$Quiet,
	[switch]$Json,
	[int]$InferenceReportMaxAgeHours = 24
)

$ErrorActionPreference = "Stop"

function Get-AddonMetadata {
	param([string]$RepositoryPath)

	$metadataPath = Join-Path $RepositoryPath "ofxggml-addon.json"
	if (!(Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
		return $null
	}

	try {
		return Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
	} catch {
		return $null
	}
}

function Get-ModelEvidence {
	param([object]$Status)

	if (!$Status.Present) {
		return [pscustomobject]@{
			State = "missing-repository"
			Count = 0
			Directories = @()
		}
	}

	$candidates = New-Object System.Collections.Generic.List[string]
	$candidates.Add((Join-Path $Status.Path "models"))
	foreach ($example in @($Status.Examples)) {
		$candidates.Add((Join-Path $Status.Path "$example\bin\data\models"))
	}
	$candidates.Add((Join-Path (Split-Path -Parent $Status.Path) "models"))

	$seen = @{}
	$modelCount = 0
	$directories = New-Object System.Collections.Generic.List[object]
	foreach ($candidate in @($candidates.ToArray())) {
		$fullPath = [System.IO.Path]::GetFullPath($candidate)
		$key = $fullPath.ToLowerInvariant()
		if ($seen.ContainsKey($key)) {
			continue
		}
		$seen[$key] = $true
		if (!(Test-Path -LiteralPath $fullPath -PathType Container)) {
			continue
		}
		$models = @(
			Get-ChildItem -LiteralPath $fullPath -File -ErrorAction SilentlyContinue |
				Where-Object { $_.Extension -in @(".gguf", ".ggml", ".bin", ".safetensors") }
		)
		if ($models.Count -gt 0) {
			$modelCount += $models.Count
			$directories.Add([pscustomobject]@{
				Path = $fullPath
				ModelCount = $models.Count
			})
		}
	}

	$state = if ($modelCount -gt 0) { "available" } else { "missing" }
	return [pscustomobject]@{
		State = $state
		Count = $modelCount
		Directories = @($directories.ToArray())
	}
}

function Get-ExampleBuildEvidence {
	param([object]$Status)

	if (!$Status.Present) {
		return [pscustomobject]@{
			State = "missing-repository"
			BuiltExamples = 0
			ExampleCount = 0
			Examples = @()
		}
	}

	$records = New-Object System.Collections.Generic.List[object]
	foreach ($example in @($Status.Examples)) {
		$binPath = Join-Path $Status.Path "$example\bin"
		$executables = @()
		if (Test-Path -LiteralPath $binPath -PathType Container) {
			$executables = @(
				Get-ChildItem -LiteralPath $binPath -Filter "*.exe" -File -ErrorAction SilentlyContinue |
					Select-Object -ExpandProperty Name
			)
		}
		$records.Add([pscustomobject]@{
			Example = [string]$example
			Built = $executables.Count -gt 0
			Executables = @($executables)
		})
	}

	$built = @($records.ToArray() | Where-Object { $_.Built }).Count
	$state = if (@($Status.Examples).Count -eq 0) {
		"not-applicable"
	} elseif ($built -eq @($Status.Examples).Count) {
		"complete"
	} elseif ($built -gt 0) {
		"partial"
	} else {
		"missing"
	}

	return [pscustomobject]@{
		State = $state
		BuiltExamples = $built
		ExampleCount = @($Status.Examples).Count
		Examples = @($records.ToArray())
	}
}

function Get-RuntimeSmokeEvidence {
	param([object]$Status)

	if (!$Status.Present) {
		return [pscustomobject]@{
			State = "missing-repository"
			Scripts = @()
			ValidationHook = $false
		}
	}

	$scriptsRoot = Join-Path $Status.Path "scripts"
	$scripts = @()
	if (Test-Path -LiteralPath $scriptsRoot -PathType Container) {
		$scripts = @(
			Get-ChildItem -LiteralPath $scriptsRoot -File -ErrorAction SilentlyContinue |
				Where-Object { $_.Name -match "(runtime|inference).*smoke|smoke.*(runtime|inference)|build-runtime-smoke" } |
				Sort-Object Name |
				Select-Object -ExpandProperty Name
		)
	}

	$validationHook = $false
	$validate = Join-Path $Status.Path "scripts\validate-local.ps1"
	if (Test-Path -LiteralPath $validate -PathType Leaf) {
		$content = Get-Content -LiteralPath $validate -Raw
		$validationHook = $content -match "runtime|inference"
	}

	$state = if ($scripts.Count -gt 0 -and $validationHook) {
		"available-and-validated"
	} elseif ($scripts.Count -gt 0) {
		"available"
	} else {
		"missing"
	}

	return [pscustomobject]@{
		State = $state
		Scripts = @($scripts)
		ValidationHook = [bool]$validationHook
	}
}

function Get-InferenceSmokeEvidence {
	param([object]$Status)

	function Get-RequiredSummaryProperty {
		param(
			[object]$Target,
			[string]$Name,
			[string]$Type,
			[bool]$AllowEmpty
		)

		if (-not ($Target -and $Target.PSObject.Properties[$Name])) {
			return [pscustomobject]@{
				Found = $false
				Value = ""
			}
		}

		$value = $Target.$Name
		switch ($Type) {
			"bool" {
				if ($value -is [bool]) {
					return [pscustomobject]@{ Found = $true; Value = [bool]$value }
				}
				return [pscustomobject]@{ Found = $false; Value = "" }
			}
			"string" {
				if ($value -is [string] -and ($AllowEmpty -or -not [string]::IsNullOrWhiteSpace($value))) {
					return [pscustomobject]@{ Found = $true; Value = [string]$value }
				}
				return [pscustomobject]@{ Found = false; Value = "" }
			}
		}

		return [pscustomobject]@{ Found = $false; Value = "" }
	}

	function Assert-InferenceSmokeContract {
		param([object]$Summary)

		$missing = New-Object System.Collections.Generic.List[string]
		$required = @(
			@{ Name = "Passed"; Type = "bool"; AllowEmpty = $true },
			@{ Name = "InferenceChecked"; Type = "bool"; AllowEmpty = $true },
			@{ Name = "SmokeKind"; Type = "string"; AllowEmpty = $false },
			@{ Name = "Backend"; Type = "string"; AllowEmpty = $false },
			@{ Name = "ModelPath"; Type = "string"; AllowEmpty = $false }
		)

		foreach ($field in @($required)) {
			$result = Get-RequiredSummaryProperty -Target $Summary -Name $field.Name -Type $field.Type -AllowEmpty $field.AllowEmpty
			if (-not $result.Found) {
				$missing.Add("$($field.Name) is missing or malformed")
			}
		}

		if ($missing.Count -gt 0) {
			return [pscustomobject]@{
				Valid = $false
				Issues = @($missing.ToArray())
			}
		}

		[pscustomobject]@{
			Valid = $true
			Issues = @()
		}
	}

	if (!$Status.Present) {
		return [pscustomobject]@{
			State = "missing-repository"
			ReportPath = ""
			Passed = $false
			Backend = ""
			ModelPath = ""
			SmokeKind = ""
			ReportAgeHours = 0
			Error = ""
		}
	}

	$reportFile = Get-InferenceSmokeReportFile -Metadata $Status.Metadata
	$reportPath = if (![string]::IsNullOrWhiteSpace($reportFile)) {
		Join-Path $Status.Path $reportFile
	} else {
		""
	}
	if ([string]::IsNullOrWhiteSpace($reportFile)) {
		return [pscustomobject]@{
			State = "missing"
			ReportPath = ""
			Passed = $false
			Backend = ""
			ModelPath = ""
			SmokeKind = ""
			ReportAgeHours = 0
			Error = ""
		}
	}

	if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
		try {
			$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
			$summary = $report.Summary
			$contract = Assert-InferenceSmokeContract -Summary $summary
			if (-not $contract.Valid) {
				return [pscustomobject]@{
					State = "inference-report-invalid"
					ReportPath = $reportPath
					Passed = $false
					Backend = if ($summary) { [string]$summary.Backend } else { "" }
					ModelPath = if ($summary) { [string]$summary.ModelPath } else { "" }
					SmokeKind = if ($summary) { [string]$summary.SmokeKind } else { "" }
					ReportAgeHours = 0
					Error = "smoke report contract violations: {0}" -f (($contract.Issues | Sort-Object) -join "; ")
				}
			}
			$reportFileInfo = Get-Item -LiteralPath $reportPath
			$reportAgeHours = [Math]::Round(((Get-Date) - $reportFileInfo.LastWriteTime).TotalHours, 2)
			$passed = [bool]($summary.Passed -and $summary.InferenceChecked)
			if ($passed -and $reportAgeHours -gt $InferenceReportMaxAgeHours) {
				return [pscustomobject]@{
					State = "inference-smoke-stale"
					ReportPath = $reportPath
					Passed = $false
					Backend = if ($summary) { [string]$summary.Backend } else { "" }
					ModelPath = if ($summary) { [string]$summary.ModelPath } else { "" }
					SmokeKind = if ($summary) { [string]$summary.SmokeKind } else { "" }
					ReportAgeHours = [double]$reportAgeHours
					Error = "inference smoke report is stale (${reportAgeHours}h > ${InferenceReportMaxAgeHours}h)"
				}
			}
			return [pscustomobject]@{
				State = if ($passed) { "inference-checked" } else { "inference-report-failed" }
				ReportPath = $reportPath
				Passed = $passed
				Backend = [string]$summary.Backend
				ModelPath = [string]$summary.ModelPath
				SmokeKind = [string]$summary.SmokeKind
				ReportAgeHours = [double]$reportAgeHours
				Error = if ($summary.Error) { [string]$summary.Error } else { "" }
			}
		} catch {
			return [pscustomobject]@{
				State = "inference-report-invalid"
				ReportPath = $reportPath
				Passed = $false
				Backend = ""
				ModelPath = ""
				SmokeKind = ""
				ReportAgeHours = 0
				Error = $_.Exception.Message
			}
		}
	}

	$scriptsRoot = Join-Path $Status.Path "scripts"
	$scriptNames = @()
	if (Test-Path -LiteralPath $scriptsRoot -PathType Container) {
		$scriptNames = @(
			Get-ChildItem -LiteralPath $scriptsRoot -File -ErrorAction SilentlyContinue |
				Where-Object { $_.Name -match "(runtime|inference).*smoke|smoke.*(runtime|inference)" } |
				Sort-Object Name |
				Select-Object -ExpandProperty Name
		)
	}

	$validationHook = $false
	$validate = Join-Path $Status.Path "scripts\validate-local.ps1"
	if (Test-Path -LiteralPath $validate -PathType Leaf) {
		$content = Get-Content -LiteralPath $validate -Raw
		$validationHook = $content -match "runtime|inference"
	}

	if ($scriptNames.Count -gt 0 -and $validationHook) {
		return [pscustomobject]@{
			State = "inference-smoke-entrypoint-validated"
			ReportPath = $reportPath
			Passed = $false
			Backend = ""
			ModelPath = ""
			SmokeKind = ""
			ReportAgeHours = 0
			Error = "run the lane-owned smoke with -OutputPath to produce local inference evidence"
		}
	}
	if ($scriptNames.Count -gt 0) {
		return [pscustomobject]@{
			State = "inference-smoke-entrypoint-present"
			ReportPath = $reportPath
			Passed = $false
			Backend = ""
			ModelPath = ""
			SmokeKind = ""
			ReportAgeHours = 0
			Error = "runtime smoke script exists but is not part of local validation"
		}
	}

	return [pscustomobject]@{
		State = "missing"
		ReportPath = $reportPath
		Passed = $false
		Backend = ""
		ModelPath = ""
		SmokeKind = ""
		ReportAgeHours = 0
		Error = ""
	}
}

function Get-InferenceSmokeReportFile {
	param(
		[object]$Metadata
	)

	$declared = if ($Metadata -and $Metadata.PSObject.Properties["inferenceSmokeReport"]) {
		$Metadata.inferenceSmokeReport
	} else {
		""
	}
	if ($declared -is [string] -and -not [string]::IsNullOrWhiteSpace($declared)) {
		return [string]$declared.Trim()
	}

	return ""
}

function Get-BackendRuntimePriority {
	param([object]$Status)

	switch ($Status.Name) {
		"ofxGgmlCore" { return 0 }
		"ofxGgmlSam" { return 1 }
		"ofxGgmlLlama" { return 2 }
		"ofxGgmlAudio" { return 3 }
		"ofxGgmlDiffusion" { return 4 }
		"ofxGgmlVision" { return 5 }
		"ofxGgmlVideo" { return 6 }
		"ofxGgmlRag" { return 7 }
		"ofxGgmlAgents" { return 8 }
		"ofxGgmlMusic" { return 9 }
		default { return 99 }
	}
}

function New-BackendRuntimeEntry {
	param([object]$Status)

	$metadata = Get-AddonMetadata -RepositoryPath $Status.Path
	$Status | Add-Member -NotePropertyName Metadata -NotePropertyValue $metadata -Force
	$declaredBackends = @()
	if ($metadata -and $metadata.PSObject.Properties["backends"]) {
		$declaredBackends = @($metadata.backends | ForEach-Object { [string]$_ })
	}
	$modelEvidence = Get-ModelEvidence -Status $Status
	$buildEvidence = Get-ExampleBuildEvidence -Status $Status
	$runtimeEvidence = Get-RuntimeSmokeEvidence -Status $Status
	$inferenceEvidence = Get-InferenceSmokeEvidence -Status $Status
	$priority = Get-BackendRuntimePriority -Status $Status

	$gateState = if ($Status.Name -eq "ofxGgmlWorkflows") {
		"not-applicable"
	} elseif (!$Status.Present) {
		"missing-repository"
	} elseif ($inferenceEvidence.State -eq "inference-checked") {
		"inference-checked"
	} elseif ($Status.Name -eq "ofxGgmlCore" -and $runtimeEvidence.State -ne "missing") {
		"core-runtime-smoke-seeded"
	} elseif ($runtimeEvidence.State -ne "missing") {
		"runtime-smoke-entrypoint-present"
	} elseif ($Status.Name -eq "ofxGgmlSam" -and $modelEvidence.State -eq "available" -and $buildEvidence.BuiltExamples -gt 0) {
		"reference-lane-ready-for-runtime-smoke"
	} else {
		"needs-runtime-smoke-plan"
	}

	$action = switch ($gateState) {
		"not-applicable" { "skip workflow-only repository" }
		"missing-repository" { "restore repository before planning runtime verification" }
		"inference-checked" { "use model-backed inference smoke as release evidence" }
		"core-runtime-smoke-seeded" { "keep Core CPU graph smoke active and require reports as release evidence" }
		"reference-lane-ready-for-runtime-smoke" { "add SAM3 CPU/CUDA runtime-smoke handoff before broadening other lanes" }
		"runtime-smoke-entrypoint-present" { "use runtime smoke as validation and release evidence" }
		default { "add lane-owned runtime-smoke planner after the reference SAM lane is gated" }
	}

	[pscustomobject]@{
		Repository = [string]$Status.Name
		Lane = [string]$Status.Lane
		Present = [bool]$Status.Present
		Priority = [int]$priority
		DeclaredBackends = @($declaredBackends)
		CpuDeclared = @($declaredBackends) -contains "cpu"
		CudaDeclared = @($declaredBackends) -contains "cuda"
		VulkanDeclared = @($declaredBackends) -contains "vulkan"
		MetalDeclared = @($declaredBackends) -contains "metal"
		ModelEvidence = $modelEvidence
		ExampleBuildEvidence = $buildEvidence
		RuntimeSmokeEvidence = $runtimeEvidence
		InferenceSmokeEvidence = $inferenceEvidence
		GateState = $gateState
		Action = $action
	}
}

function Get-BackendRuntimeSummary {
	param([array]$Entries)

	$blocking = @($Entries | Where-Object {
		$_.GateState -ne "not-applicable" -and
		$_.GateState -ne "inference-checked" -and
		$_.GateState -ne "core-runtime-smoke-seeded" -and
		$_.GateState -ne "reference-lane-ready-for-runtime-smoke" -and
		$_.GateState -ne "runtime-smoke-entrypoint-present"
	})
	$exampleBuildEvidenceGaps = @($Entries | Where-Object {
		$_.GateState -ne "not-applicable" -and
		$_.ExampleBuildEvidence.ExampleCount -gt 0 -and
		$_.ExampleBuildEvidence.BuiltExamples -lt $_.ExampleBuildEvidence.ExampleCount
	})
	$exampleBuildGapsCoveredByInference = @($exampleBuildEvidenceGaps | Where-Object {
		$_.InferenceSmokeEvidence.State -eq "inference-checked"
	})
	$actionableExampleBuildGaps = @($exampleBuildEvidenceGaps | Where-Object {
		$_.InferenceSmokeEvidence.State -ne "inference-checked"
	})

	[pscustomobject]@{
		ManagedRepositories = @($Entries).Count
		RuntimeApplicableRepositories = @($Entries | Where-Object { $_.GateState -ne "not-applicable" }).Count
		CoreRuntimeSmokeSeeded = @($Entries | Where-Object { $_.GateState -eq "core-runtime-smoke-seeded" }).Count
		ReferenceLaneReady = @($Entries | Where-Object { $_.GateState -eq "reference-lane-ready-for-runtime-smoke" }).Count
		RuntimeSmokeEntrypoints = @($Entries | Where-Object { $_.RuntimeSmokeEvidence.State -ne "missing" }).Count
		ValidatedRuntimeSmokeEntrypoints = @($Entries | Where-Object { $_.RuntimeSmokeEvidence.State -eq "available-and-validated" }).Count
		InferenceSmokeEntrypoints = @($Entries | Where-Object { $_.InferenceSmokeEvidence.State -ne "missing" -and $_.InferenceSmokeEvidence.State -ne "missing-repository" }).Count
		InferenceCheckedRepositories = @($Entries | Where-Object { $_.InferenceSmokeEvidence.State -eq "inference-checked" }).Count
		RepositoriesWithModels = @($Entries | Where-Object { $_.ModelEvidence.State -eq "available" }).Count
		RepositoriesWithBuiltExamples = @($Entries | Where-Object { $_.ExampleBuildEvidence.BuiltExamples -gt 0 }).Count
		ExampleBuildEvidenceGaps = @($exampleBuildEvidenceGaps).Count
		ExampleBuildGapsCoveredByInference = @($exampleBuildGapsCoveredByInference).Count
		ExampleBuildGaps = @($actionableExampleBuildGaps).Count
		RepositoriesMissingBuiltExamples = @($actionableExampleBuildGaps | Sort-Object Priority, Repository | ForEach-Object { [string]$_.Repository })
		NeedsRuntimeSmokePlan = @($Entries | Where-Object { $_.GateState -eq "needs-runtime-smoke-plan" }).Count
		BlockingRepositories = @($blocking | Sort-Object Priority, Repository | ForEach-Object { [string]$_.Repository })
		ReferenceTarget = "ofxGgmlSam"
	}
}

function Get-BackendRuntimeNextCommands {
	param([array]$Entries)

	$commands = New-Object System.Collections.Generic.List[string]
	$commands.Add("scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly")
	$llama = @($Entries | Where-Object { $_.Repository -eq "ofxGgmlLlama" } | Select-Object -First 1)
	if ($llama.Count -gt 0) {
		$commands.Add("cd ..\ofxGgmlLlama && scripts\list-models.bat -Json -SummaryOnly")
		$commands.Add("cd ..\ofxGgmlLlama && scripts\run-llama-runtime-smoke.bat -Backend cpu -Json -SummaryOnly -OutputPath .llama-runtime-smoke.json")
	}
	$reference = @($Entries | Where-Object { $_.Repository -eq "ofxGgmlSam" } | Select-Object -First 1)
	if ($reference.Count -gt 0) {
		$commands.Add("cd ..\ofxGgmlSam && scripts\doctor-sam.bat")
		$commands.Add("cd ..\ofxGgmlSam && scripts\run-sam3-runtime-smoke.bat -DryRun")
		$commands.Add("cd ..\ofxGgmlSam && scripts\run-sam3-runtime-smoke.bat -Backend cuda -Json -SummaryOnly -OutputPath .sam3-runtime-smoke.json")
		$commands.Add("cd ..\ofxGgmlSam && scripts\validate-local.bat")
	}
	$audio = @($Entries | Where-Object { $_.Repository -eq "ofxGgmlAudio" } | Select-Object -First 1)
	if ($audio.Count -gt 0) {
		$commands.Add("cd ..\ofxGgmlAudio && scripts\run-audio-runtime-smoke.bat -DryRun")
		$commands.Add("cd ..\ofxGgmlAudio && scripts\run-audio-runtime-smoke.bat -Mode simple -Json -SummaryOnly -OutputPath .audio-runtime-smoke.json")
	}
	$agents = @($Entries | Where-Object { $_.Repository -eq "ofxGgmlAgents" } | Select-Object -First 1)
	if ($agents.Count -gt 0) {
		$commands.Add("cd ..\ofxGgmlAgents && scripts\run-agents-runtime-smoke.bat -Json -SummaryOnly -OutputPath .agents-runtime-smoke.json")
	}
	$commands.Add("scripts\plan-release-readiness.bat -Json -SummaryOnly")
	return @($commands.ToArray())
}

function ConvertTo-BackendRuntimeRepositorySummary {
	param([object]$Entry)

	[pscustomobject]@{
		Repository = [string]$Entry.Repository
		Lane = [string]$Entry.Lane
		Priority = [int]$Entry.Priority
		DeclaredBackends = @($Entry.DeclaredBackends)
		CpuDeclared = [bool]$Entry.CpuDeclared
		CudaDeclared = [bool]$Entry.CudaDeclared
		VulkanDeclared = [bool]$Entry.VulkanDeclared
		MetalDeclared = [bool]$Entry.MetalDeclared
		ModelEvidence = [string]$Entry.ModelEvidence.State
		ModelCount = [int]$Entry.ModelEvidence.Count
		ExampleBuildEvidence = [string]$Entry.ExampleBuildEvidence.State
		BuiltExamples = [int]$Entry.ExampleBuildEvidence.BuiltExamples
		RuntimeSmokeEvidence = [string]$Entry.RuntimeSmokeEvidence.State
		InferenceSmokeEvidence = [string]$Entry.InferenceSmokeEvidence.State
		InferenceBackend = [string]$Entry.InferenceSmokeEvidence.Backend
		GateState = [string]$Entry.GateState
		Action = [string]$Entry.Action
	}
}

function Join-OrDash {
	param([array]$Values)
	if (!$Values -or $Values.Count -eq 0) {
		return "-"
	}
	return (@($Values) -join ", ")
}

function ConvertTo-MarkdownBackendRuntimePlan {
	param(
		[array]$Entries,
		[string]$Root,
		[array]$NextCommands
	)

	$summary = Get-BackendRuntimeSummary -Entries $Entries
	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# Backend Runtime Verification Plan")
	$lines.Add("")
	$lines.Add("Non-mutating Core control-plane handoff for turning declared backend support into release evidence.")
	$lines.Add("")
	$lines.Add("Root: $Root")
	$lines.Add("")
	$lines.Add("## Summary")
	$lines.Add("")
	$lines.Add("| Metric | Count |")
	$lines.Add("| --- | ---: |")
	$lines.Add("| Managed repositories | $($summary.ManagedRepositories) |")
	$lines.Add("| Runtime-applicable repositories | $($summary.RuntimeApplicableRepositories) |")
	$lines.Add("| Core runtime-smoke seeded | $($summary.CoreRuntimeSmokeSeeded) |")
	$lines.Add("| Reference lanes ready | $($summary.ReferenceLaneReady) |")
	$lines.Add("| Runtime-smoke entrypoints | $($summary.RuntimeSmokeEntrypoints) |")
	$lines.Add("| Validated runtime-smoke entrypoints | $($summary.ValidatedRuntimeSmokeEntrypoints) |")
	$lines.Add("| Inference-smoke entrypoints | $($summary.InferenceSmokeEntrypoints) |")
	$lines.Add("| Inference-checked repositories | $($summary.InferenceCheckedRepositories) |")
	$lines.Add("| Repositories with models | $($summary.RepositoriesWithModels) |")
	$lines.Add("| Repositories with built examples | $($summary.RepositoriesWithBuiltExamples) |")
	$lines.Add("| Example build evidence gaps | $($summary.ExampleBuildEvidenceGaps) |")
	$lines.Add("| Example build gaps covered by inference smoke | $($summary.ExampleBuildGapsCoveredByInference) |")
	$lines.Add("| Actionable repositories missing built examples | $($summary.ExampleBuildGaps) |")
	$lines.Add("| Repositories needing runtime-smoke plans | $($summary.NeedsRuntimeSmokePlan) |")
	$lines.Add("")
	$lines.Add(("Reference target: ``{0}``" -f $summary.ReferenceTarget))
	if (@($summary.RepositoriesMissingBuiltExamples).Count -gt 0) {
		$lines.Add("")
		$lines.Add("Example build evidence gaps: $(@($summary.RepositoriesMissingBuiltExamples) -join ', ')")
	}
	$lines.Add("")
	$lines.Add("## Repository Evidence")
	$lines.Add("")
	$lines.Add("| Repository | Lane | Backends | Models | Built examples | Runtime smoke | Inference smoke | Gate state | Action |")
	$lines.Add("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	foreach ($entry in @($Entries | Sort-Object Priority, Repository)) {
		$backends = Join-OrDash -Values $entry.DeclaredBackends
		$modelText = "$($entry.ModelEvidence.State) ($($entry.ModelEvidence.Count))"
		$buildText = "$($entry.ExampleBuildEvidence.State) ($($entry.ExampleBuildEvidence.BuiltExamples)/$($entry.ExampleBuildEvidence.ExampleCount))"
		$inferenceText = $entry.InferenceSmokeEvidence.State
		if (![string]::IsNullOrWhiteSpace([string]$entry.InferenceSmokeEvidence.Backend)) {
			$inferenceText += " ($($entry.InferenceSmokeEvidence.Backend))"
		}
		$lines.Add("| $($entry.Repository) | $($entry.Lane) | $backends | $modelText | $buildText | $($entry.RuntimeSmokeEvidence.State) | $inferenceText | $($entry.GateState) | $($entry.Action) |")
	}
	$lines.Add("")
	$lines.Add("## Next Commands")
	$lines.Add("")
	foreach ($command in @($NextCommands)) {
		$lines.Add("- ``$command``")
	}
	$lines.Add("")
	$lines.Add("## Guardrails")
	$lines.Add("")
	$lines.Add("- Keep this as planning evidence until a lane-owned runtime-smoke script exists.")
	$lines.Add("- Do not add model-specific code to Core; companion lanes own model loading and inference.")
	$lines.Add("- Treat `inference-checked` as local evidence from an ignored lane-owned smoke report, not as a committed artifact.")
	$lines.Add("- Do not treat missing generated example binaries as actionable when a lane has stronger model-backed inference evidence; generated binaries stay local-only.")
	$lines.Add("- Treat SAM as the first reference lane because local SAM3 CPU/CUDA evidence already exists outside Core.")

	return $lines -join [Environment]::NewLine
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$statusJson = & (Join-Path $scriptRoot "status-family.ps1") -Json
if (!$?) {
	throw "status-family.ps1 failed."
}
$status = $statusJson | ConvertFrom-Json
$managed = @($status.Addons | Where-Object { $_.Known })
$entries = @($managed | ForEach-Object { New-BackendRuntimeEntry -Status $_ })
$summary = Get-BackendRuntimeSummary -Entries $entries
$nextCommands = Get-BackendRuntimeNextCommands -Entries $entries

if ($Json) {
	$result = [ordered]@{
		Root = [string]$status.Root
		SummaryOnly = [bool]$SummaryOnly
		Summary = $summary
		NextCommands = @($nextCommands)
		RepositorySummaries = @($entries | ForEach-Object { ConvertTo-BackendRuntimeRepositorySummary -Entry $_ })
	}
	if (!$SummaryOnly) {
		$result.Repositories = $entries
	}
	$content = [pscustomobject]$result | ConvertTo-Json -Depth 8
} else {
	$content = ConvertTo-MarkdownBackendRuntimePlan -Entries $entries -Root ([string]$status.Root) -NextCommands $nextCommands
}

if (![string]::IsNullOrWhiteSpace($OutputPath)) {
	$target = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
		$OutputPath
	} else {
		Join-Path $addonRoot $OutputPath
	}
	$directory = Split-Path -Parent $target
	if (!(Test-Path -LiteralPath $directory -PathType Container)) {
		New-Item -ItemType Directory -Path $directory -Force | Out-Null
	}
	Set-Content -LiteralPath $target -Value $content
	if (!$Quiet) {
		Write-Host "Wrote $target"
	}
} else {
	Write-Output $content
}
