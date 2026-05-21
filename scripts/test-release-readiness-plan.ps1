$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$json = & (Join-Path $scriptRoot "plan-release-readiness.ps1") -Json -SummaryOnly
if (!$?) {
	throw "plan-release-readiness.ps1 -Json -SummaryOnly failed."
}

$parsed = $json | ConvertFrom-Json
if (!$parsed.SummaryOnly) {
	throw "release readiness plan JSON did not report SummaryOnly."
}
if (!$parsed.Summary) {
	throw "release readiness plan JSON did not include Summary."
}
foreach ($property in @(
	"ReleaseReportExists",
	"WorkflowStatusEvidenceProvided",
	"BackendCapabilityEvidenceProvided",
	"BackendRuntimePlanEvidenceProvided",
	"SmokeBuildCiEvidenceProvided",
	"EvidenceGapCount"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "release readiness plan Summary did not include $property."
	}
}
if (!$parsed.EvidenceSummaries -or @($parsed.EvidenceSummaries).Count -lt 1) {
	throw "release readiness plan JSON did not include compact evidence summaries."
}
if (!$parsed.NextCommands -or @($parsed.NextCommands).Count -lt 1) {
	throw "release readiness plan JSON did not include next commands."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-release-readiness.bat -Json -SummaryOnly") {
	throw "release readiness plan JSON did not include compact self-check command."
}

Write-Host "Release readiness planning coverage passed"
