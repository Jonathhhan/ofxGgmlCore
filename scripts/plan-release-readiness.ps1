param(
	[string]$OutputPath = "docs\release-readiness-score.md",
	[string]$WorkflowStatusReport = "",
	[int]$StaleDays = 30,
	[switch]$SkipWorkflowStatus
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

$workflowReport = $WorkflowStatusReport
if ([string]::IsNullOrWhiteSpace($workflowReport) -and !$SkipWorkflowStatus) {
	$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-release-evidence.md"
	Write-Step "Generating workflow status evidence"
	python $workflowScript --output $workflowReport --stale-days $StaleDays
	if (!$?) {
		throw "fetch-workflow-status.py failed."
	}
}

$arguments = @($releaseScript, "--output", $OutputPath)
if (![string]::IsNullOrWhiteSpace($workflowReport)) {
	$arguments += @("--workflow-status-report", $workflowReport)
}

Write-Step "Generating release readiness score"
python @arguments
if (!$?) {
	throw "generate-release-readiness-score.py failed."
}

$target = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
	$OutputPath
} else {
	Join-Path $addonRoot $OutputPath
}
Write-Host "Release readiness plan: $target"
