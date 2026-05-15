param(
	[string]$OutputPath = "",
	[string]$WorkflowStatusReport = "",
	[string]$BackendCapabilityReport = "",
	[int]$StaleDays = 30,
	[switch]$SkipWorkflowStatus,
	[switch]$SkipBackendCapability
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
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
if ([string]::IsNullOrWhiteSpace($workflowReport) -and !$SkipWorkflowStatus) {
	$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-release-evidence.md"
	Write-Step "Generating workflow status evidence"
	python $workflowScript --output $workflowReport --stale-days $StaleDays
	if (!$?) {
		throw "fetch-workflow-status.py failed."
	}
}

$backendReport = $BackendCapabilityReport
if ([string]::IsNullOrWhiteSpace($backendReport) -and !$SkipBackendCapability) {
	$defaultBackendReport = Join-Path $addonRoot "docs\backend-capability-report.md"
	if (Test-Path -LiteralPath $defaultBackendReport -PathType Leaf) {
		$backendReport = $defaultBackendReport
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
python @arguments
if (!$?) {
	throw "generate-release-readiness-score.py failed."
}

Write-Host "Release readiness plan: $resolvedOutputPath"
