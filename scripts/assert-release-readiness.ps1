param(
	[string]$OutputPath = "",
	[string]$WorkflowStatusReport = "",
	[string]$BackendCapabilityReport = "",
	[string]$BackendRuntimePlan = "",
	[string]$SmokeBuildCiReport = "",
	[int]$StaleDays = 30,
	[switch]$FetchSmokeBuildCiReport,
	[switch]$AllowDefaultBackendCapability,
	[switch]$AllowDefaultSmokeBuildCi,
	[switch]$AllowBackendRuntimeEvidenceGaps,
	[switch]$AllowMissingSmokeBuildCi,
	[switch]$SkipManagedGitStatus,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Add-Blocker {
	param(
		[System.Collections.Generic.List[string]]$Blockers,
		[string]$Message
	)
	if ([string]::IsNullOrWhiteSpace($Message)) {
		return
	}
	if ($Blockers.Contains($Message)) {
		return
	}
	$Blockers.Add($Message) | Out-Null
}

function Get-MarkdownSectionLines {
	param(
		[string[]]$Lines,
		[string]$Heading
	)

	$section = New-Object System.Collections.Generic.List[string]
	$inside = $false
	foreach ($line in $Lines) {
		if ($line -eq $Heading) {
			$inside = $true
			continue
		}
		if ($inside -and $line.StartsWith("#### ")) {
			break
		}
		if ($inside) {
			$section.Add($line) | Out-Null
		}
	}
	return @($section.ToArray())
}

function Test-SectionHasEntries {
	param([string[]]$Lines)

	$entries = @($Lines | Where-Object {
		$trimmed = $_.Trim()
		$trimmed.StartsWith("- ") -and $trimmed -ne "- None."
	})
	return ($entries.Count -gt 0)
}

function Test-SmokeBuildReportPassed {
	param(
		[string]$Path,
		[System.Collections.Generic.List[string]]$Blockers
	)

	if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path -PathType Leaf)) {
		Add-Blocker -Blockers $Blockers -Message "smoke-build CI evidence is missing"
		return
	}

	$report = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
	$summary = $report.Summary
	if (!$summary) {
		Add-Blocker -Blockers $Blockers -Message "smoke-build CI report is missing Summary"
		return
	}

	$outcome = [string]$summary.Outcome
	$hasFailures = [bool]$summary.HasFailures
	$failedTargets = 0
	if ($summary.PSObject.Properties["FailedTargets"] -and $null -ne $summary.FailedTargets) {
		$failedTargets = [int]$summary.FailedTargets
	}
	$failedCommands = 0
	if ($summary.PSObject.Properties["FailedCommands"] -and $null -ne $summary.FailedCommands) {
		$failedCommands = [int]$summary.FailedCommands
	}
	if ($outcome -ne "passed" -or $hasFailures -or $failedTargets -gt 0 -or $failedCommands -gt 0) {
		Add-Blocker -Blockers $Blockers -Message "smoke-build CI evidence is not passing"
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$planScript = Join-Path $scriptRoot "plan-release-readiness.ps1"
$testId = [guid]::NewGuid().ToString("N")
$resolvedOutputPath = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-gate-$testId.md"
} elseif ([System.IO.Path]::IsPathRooted($OutputPath)) {
	$OutputPath
} else {
	Join-Path $addonRoot $OutputPath
}

$planParams = @{
	OutputPath = $resolvedOutputPath
	StaleDays = $StaleDays
	Json = $true
}
if (![string]::IsNullOrWhiteSpace($WorkflowStatusReport)) {
	$planParams.WorkflowStatusReport = $WorkflowStatusReport
}
if (![string]::IsNullOrWhiteSpace($BackendCapabilityReport)) {
	$planParams.BackendCapabilityReport = $BackendCapabilityReport
}
if (![string]::IsNullOrWhiteSpace($BackendRuntimePlan)) {
	$planParams.BackendRuntimePlan = $BackendRuntimePlan
}
if (![string]::IsNullOrWhiteSpace($SmokeBuildCiReport)) {
	$planParams.SmokeBuildCiReport = $SmokeBuildCiReport
}
if ($FetchSmokeBuildCiReport) {
	$planParams.FetchSmokeBuildCiReport = $true
}
if ($AllowDefaultBackendCapability) {
	$planParams.AllowDefaultBackendCapability = $true
}
if ($AllowDefaultSmokeBuildCi) {
	$planParams.AllowDefaultSmokeBuildCi = $true
}
if ($AllowBackendRuntimeEvidenceGaps) {
	$planParams.AllowBackendRuntimeEvidenceGaps = $true
}
if ($SkipManagedGitStatus) {
	$planParams.SkipManagedGitStatus = $true
}

$planOutput = @(& $planScript @planParams 2>&1)
if (!$?) {
	if ($planOutput.Count -gt 0) {
		$planOutput | Write-Host
	}
	throw "plan-release-readiness.ps1 failed."
}

$plan = ($planOutput -join "`n") | ConvertFrom-Json
$blockers = New-Object System.Collections.Generic.List[string]
$summary = $plan.Summary
if (!$summary.ReleaseReportExists) {
	Add-Blocker -Blockers $blockers -Message "release-readiness report was not generated"
}
if (!$summary.WorkflowStatusEvidenceExists) {
	Add-Blocker -Blockers $blockers -Message "workflow status evidence is missing"
}
if (!$summary.BackendCapabilityEvidenceExists) {
	Add-Blocker -Blockers $blockers -Message "backend capability evidence is missing"
}
if (!$summary.BackendRuntimePlanEvidenceExists) {
	Add-Blocker -Blockers $blockers -Message "backend runtime verification evidence is missing"
}
foreach ($gap in @($plan.EvidenceGaps)) {
	$gapText = [string]$gap
	if (![string]::IsNullOrWhiteSpace($gapText)) {
		Add-Blocker -Blockers $blockers -Message "release readiness evidence gap: $gapText"
	}
}
if (!$AllowMissingSmokeBuildCi) {
	Test-SmokeBuildReportPassed -Path ([string]$plan.SmokeBuildCiReport) -Blockers $blockers
}

if (Test-Path -LiteralPath $resolvedOutputPath -PathType Leaf) {
	$lines = @(Get-Content -LiteralPath $resolvedOutputPath)
	$workflowBlockerLines = Get-MarkdownSectionLines -Lines $lines -Heading "#### Required workflow blockers"
	if (Test-SectionHasEntries -Lines $workflowBlockerLines) {
		Add-Blocker -Blockers $blockers -Message "workflow status evidence reports required blockers"
	}
}

$ready = ($blockers.Count -eq 0)
$result = [ordered]@{
	Ready = $ready
	BlockerCount = $blockers.Count
	Blockers = @($blockers.ToArray())
	ReleaseReadinessPlan = $resolvedOutputPath
	SmokeBuildCiReport = [string]$plan.SmokeBuildCiReport
	Summary = $summary
}

if ($Json) {
	[pscustomobject]$result | ConvertTo-Json -Depth 6
} elseif ($ready) {
	Write-Host "Release gate passed: $outputPath"
} else {
	Write-Host "Release gate blocked:"
	foreach ($blocker in $blockers) {
		Write-Host "- $blocker"
	}
}

if (!$ready) {
	exit 1
}
