param(
	[string]$OutputPath = "",
	[string]$WorkflowStatusReport = "",
	[string]$BackendCapabilityReport = "",
	[int]$StaleDays = 30,
	[switch]$SkipWorkflowStatus,
	[switch]$SkipBackendCapability,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	if ($Json) {
		return
	}
	Write-Host "==> $Message"
}

function Get-ReleaseReadinessNextCommands {
	$commands = New-Object System.Collections.Generic.List[string]
	$commands.Add("scripts\validate-local.bat")
	$commands.Add("scripts\audit-ecosystem.bat -Strict")
	$commands.Add("scripts\check-ecosystem-readiness.bat -SkipDoctorTests")
	$commands.Add("scripts\plan-release-readiness.bat -Json")
	$commands.Add("scripts\release-candidate.ps1")
	return @($commands.ToArray())
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$releaseScript = Join-Path $scriptRoot "generate-release-readiness-score.py"
$workflowScript = Join-Path $scriptRoot "fetch-workflow-status.py"

$resolvedOutputPath = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-score.md"
} elseif ([System.IO.Path]::IsPathRooted($OutputPath)) {
	$OutputPath
} else {
	Join-Path $addonRoot $OutputPath
}

$workflowReport = $WorkflowStatusReport
$generatedWorkflowReport = $false
if ([string]::IsNullOrWhiteSpace($workflowReport) -and !$SkipWorkflowStatus) {
	$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-release-evidence.md"
	$generatedWorkflowReport = $true
	Write-Step "Generating workflow status evidence"
	$workflowOutput = @(python $workflowScript --output $workflowReport --stale-days $StaleDays 2>&1)
	if (!$?) {
		if ($workflowOutput.Count -gt 0) {
			$workflowOutput | Write-Host
		}
		throw "fetch-workflow-status.py failed."
	}
	if (!$Json -and $workflowOutput.Count -gt 0) {
		$workflowOutput | Write-Host
	}
}

$backendReport = $BackendCapabilityReport
$usedDefaultBackendReport = $false
if ([string]::IsNullOrWhiteSpace($backendReport) -and !$SkipBackendCapability) {
	$defaultBackendReport = Join-Path $addonRoot "docs\backend-capability-report.md"
	if (Test-Path -LiteralPath $defaultBackendReport -PathType Leaf) {
		$backendReport = $defaultBackendReport
		$usedDefaultBackendReport = $true
	}
}

$arguments = @($releaseScript, "--output", $resolvedOutputPath)
if (![string]::IsNullOrWhiteSpace($workflowReport)) {
	$arguments += @("--workflow-status-report", $workflowReport)
}
if (![string]::IsNullOrWhiteSpace($backendReport)) {
	$arguments += @("--backend-capability-report", $backendReport)
}

Write-Step "Generating release readiness score"
$releaseOutput = @(python @arguments 2>&1)
if (!$?) {
	if ($releaseOutput.Count -gt 0) {
		$releaseOutput | Write-Host
	}
	throw "generate-release-readiness-score.py failed."
}
if (!$Json -and $releaseOutput.Count -gt 0) {
	$releaseOutput | Write-Host
}

$summary = [pscustomobject]@{
	ReleaseReportExists = Test-Path -LiteralPath $resolvedOutputPath -PathType Leaf
	WorkflowStatusEvidenceProvided = ![string]::IsNullOrWhiteSpace($workflowReport)
	WorkflowStatusEvidenceGenerated = $generatedWorkflowReport
	WorkflowStatusEvidenceExists = (![string]::IsNullOrWhiteSpace($workflowReport) -and (Test-Path -LiteralPath $workflowReport -PathType Leaf))
	BackendCapabilityEvidenceProvided = ![string]::IsNullOrWhiteSpace($backendReport)
	BackendCapabilityDefaultUsed = $usedDefaultBackendReport
	BackendCapabilityEvidenceExists = (![string]::IsNullOrWhiteSpace($backendReport) -and (Test-Path -LiteralPath $backendReport -PathType Leaf))
	OutputPathIsTemporary = [string]::IsNullOrWhiteSpace($OutputPath)
}
$nextCommands = Get-ReleaseReadinessNextCommands

if ($Json) {
	[pscustomobject]@{
		Root = $addonRoot
		OutputPath = $resolvedOutputPath
		WorkflowStatusReport = $workflowReport
		BackendCapabilityReport = $backendReport
		StaleDays = $StaleDays
		SkipWorkflowStatus = [bool]$SkipWorkflowStatus
		SkipBackendCapability = [bool]$SkipBackendCapability
		Summary = $summary
		NextCommands = $nextCommands
	} | ConvertTo-Json -Depth 5
} else {
	Write-Host "Release readiness plan: $resolvedOutputPath"
}
