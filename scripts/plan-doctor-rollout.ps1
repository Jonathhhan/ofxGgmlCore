param(
	[string]$OutputPath = "",
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-ScriptNames {
	param(
		[string]$Repository,
		[string]$Pattern
	)

	$scriptsRoot = Join-Path $Repository "scripts"
	if (!(Test-Path -LiteralPath $scriptsRoot -PathType Container)) {
		return @()
	}

	return @(
		Get-ChildItem -LiteralPath $scriptsRoot -Filter $Pattern -File -ErrorAction SilentlyContinue |
			Sort-Object Name |
			Select-Object -ExpandProperty Name
	)
}

function Test-ValidateMentionsDoctor {
	param([string]$Repository)

	$validate = Join-Path $Repository "scripts\validate-local.ps1"
	if (!(Test-Path -LiteralPath $validate -PathType Leaf)) {
		return $false
	}

	$content = Get-Content -LiteralPath $validate -Raw
	return $content -match "doctor"
}

function New-DoctorRolloutEntry {
	param([object]$Status)

	$doctorPs1 = @(Get-ScriptNames -Repository $Status.Path -Pattern "doctor*.ps1")
	$doctorBat = @(Get-ScriptNames -Repository $Status.Path -Pattern "doctor*.bat")
	$doctorSh = @(Get-ScriptNames -Repository $Status.Path -Pattern "doctor*.sh")
	$testDoctor = @(
		Get-ScriptNames -Repository $Status.Path -Pattern "test-doctor*.ps1" |
			Where-Object { $_ -ne "test-doctor-rollout-plan.ps1" }
	)
	$validateMentionsDoctor = Test-ValidateMentionsDoctor -Repository $Status.Path
	$hasDoctor = $doctorPs1.Count -gt 0
	$hasWrappers = $doctorBat.Count -gt 0 -and $doctorSh.Count -gt 0
	$hasTest = $testDoctor.Count -gt 0

	$coverage = if ($Status.Name -eq "ofxGgmlWorkflows") {
		"not-applicable"
	} elseif (!$Status.Present) {
		"missing-repository"
	} elseif ($hasDoctor -and $hasWrappers -and $hasTest -and $validateMentionsDoctor) {
		"complete"
	} elseif ($hasDoctor -and $hasWrappers) {
		"needs-test-or-validation-hook"
	} elseif ($hasDoctor) {
		"needs-wrappers"
	} elseif ($hasTest) {
		"test-only"
	} else {
		"missing"
	}

	$action = switch ($coverage) {
		"not-applicable" { "skip workflow-only repository" }
		"missing-repository" { "restore or remove from manifest before doctor rollout" }
		"complete" { "keep doctor coverage current" }
		"needs-test-or-validation-hook" { "add doctor smoke test and validate-local hook" }
		"needs-wrappers" { "add bat/sh wrappers, smoke test, and validate-local hook" }
		"test-only" { "add user-facing doctor entry point before broadening tests" }
		default { "add doctor entry point, wrappers, smoke test, and validate-local hook" }
	}

	$priority = switch ($Status.Name) {
		"ofxGgmlCore" { 0 }
		"ofxGgmlLlama" { 1 }
		"ofxGgmlSam" { 2 }
		"ofxGgmlAudio" { 3 }
		"ofxGgmlDiffusion" { 4 }
		"ofxGgmlVision" { 5 }
		"ofxGgmlVideo" { 6 }
		"ofxGgmlRag" { 7 }
		"ofxGgmlAgents" { 8 }
		"ofxGgmlMusic" { 9 }
		default { 99 }
	}

	[pscustomobject]@{
		Repository = [string]$Status.Name
		Lane = [string]$Status.Lane
		Present = [bool]$Status.Present
		Priority = [int]$priority
		Coverage = $coverage
		DoctorScripts = $doctorPs1
		Wrappers = @($doctorBat + $doctorSh)
		TestScripts = $testDoctor
		ValidateHook = [bool]$validateMentionsDoctor
		Action = $action
	}
}

function Join-OrDash {
	param([array]$Values)
	if (!$Values -or $Values.Count -eq 0) {
		return "-"
	}
	return (@($Values) -join ", ")
}

function ConvertTo-MarkdownDoctorPlan {
	param(
		[array]$Entries,
		[string]$Root
	)

	$summary = Get-DoctorRolloutSummary -Entries $Entries
	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# ofxGgml Doctor Rollout Plan")
	$lines.Add("")
	$lines.Add("Dry-run plan for adding consistent local diagnostic entry points across managed addon repositories.")
	$lines.Add("")
	$lines.Add("Root: $Root")
	$lines.Add("")
	$lines.Add("## Summary")
	$lines.Add("")
	$lines.Add("| Metric | Count |")
	$lines.Add("| --- | --- |")
	$lines.Add("| Managed repositories | $($summary.ManagedRepositories) |")
	$lines.Add("| Complete doctor coverage | $($summary.CompleteCoverage) |")
	$lines.Add("| Missing or incomplete doctor coverage | $($summary.IncompleteCoverage) |")
	$lines.Add("| Workflow-only repositories | $($summary.NotApplicable) |")
	$lines.Add("")
	$lines.Add("| Repository | Lane | Coverage | Doctor | Test | Validate hook | Action |")
	$lines.Add("| --- | --- | --- | --- | --- | --- | --- |")
	foreach ($entry in @($Entries | Sort-Object Priority, Repository)) {
		$doctor = Join-OrDash -Values $entry.DoctorScripts
		$test = Join-OrDash -Values $entry.TestScripts
		$validate = if ($entry.ValidateHook) { "yes" } else { "missing" }
		$lines.Add("| $($entry.Repository) | $($entry.Lane) | $($entry.Coverage) | $doctor | $test | $validate | $($entry.Action) |")
	}

	$blocking = @($Entries | Where-Object {
		$_.Coverage -ne "complete" -and
		$_.Coverage -ne "not-applicable"
	})
	$lines.Add("")
	$lines.Add("## Recommended Order")
	$lines.Add("")
	if ($blocking.Count -eq 0) {
		$lines.Add("- Doctor coverage is complete across managed addon repositories.")
	} else {
		foreach ($entry in @($blocking | Sort-Object Priority, Repository)) {
			$lines.Add("- $($entry.Repository): $($entry.Action).")
		}
	}

	$lines.Add("")
	$lines.Add("## Guardrails")
	$lines.Add("")
	$lines.Add("- Keep this as a planning handoff until a repo is selected for a focused doctor PR.")
	$lines.Add("- Doctor scripts should report local prerequisites and generated artifact state, not modify addon behavior.")
	$lines.Add("- Do not operate on classified legacy/reference siblings unless they are intentionally promoted.")

	return $lines -join [Environment]::NewLine
}

function Get-DoctorRolloutSummary {
	param([array]$Entries)

	$blocking = @($Entries | Where-Object {
		$_.Coverage -ne "complete" -and
		$_.Coverage -ne "not-applicable"
	})

	return [pscustomobject]@{
		ManagedRepositories = @($Entries).Count
		CompleteCoverage = @($Entries | Where-Object { $_.Coverage -eq "complete" }).Count
		IncompleteCoverage = $blocking.Count
		NotApplicable = @($Entries | Where-Object { $_.Coverage -eq "not-applicable" }).Count
		MissingRepository = @($Entries | Where-Object { $_.Coverage -eq "missing-repository" }).Count
		MissingDoctor = @($Entries | Where-Object { $_.Coverage -eq "missing" }).Count
		NeedsWrappers = @($Entries | Where-Object { $_.Coverage -eq "needs-wrappers" }).Count
		NeedsTestOrValidationHook = @($Entries | Where-Object { $_.Coverage -eq "needs-test-or-validation-hook" }).Count
		BlockingRepositories = @($blocking | Sort-Object Priority, Repository | ForEach-Object { [string]$_.Repository })
	}
}

function Get-DoctorRolloutNextCommands {
	param([array]$Entries)

	$commands = New-Object System.Collections.Generic.List[string]
	$blocking = @($Entries | Where-Object {
		$_.Coverage -ne "complete" -and
		$_.Coverage -ne "not-applicable"
	} | Sort-Object Priority, Repository)

	if ($blocking.Count -gt 0) {
		$commands.Add("scripts\plan-doctor-rollout.bat")
	} else {
		$commands.Add("scripts\check-ecosystem-readiness.bat -SkipDoctorTests")
	}
	$commands.Add("scripts\plan-doctor-rollout.bat -Json")
	return @($commands.ToArray())
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusJson = & (Join-Path $scriptRoot "status-family.ps1") -Json
if (!$?) {
	throw "status-family.ps1 failed."
}

$status = $statusJson | ConvertFrom-Json
$managed = @($status.Addons | Where-Object { $_.Known })
$entries = @($managed | ForEach-Object { New-DoctorRolloutEntry -Status $_ })
$summary = Get-DoctorRolloutSummary -Entries $entries
$nextCommands = Get-DoctorRolloutNextCommands -Entries $entries

if ($Json) {
	$content = [pscustomobject]@{
		Root = $status.Root
		Summary = $summary
		NextCommands = $nextCommands
		Repositories = $entries
	} | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownDoctorPlan -Entries $entries -Root ([string]$status.Root)
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
