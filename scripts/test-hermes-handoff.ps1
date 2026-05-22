$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$handoffScript = Join-Path $scriptRoot "plan-hermes-handoff.ps1"

$output = & $handoffScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-hermes-handoff.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"Hermes Agent Handoff",
	"Selected Task",
	"Prompt",
	"Context Files",
	"Required Planning Commands",
	"Validation",
	"Guardrails",
	"ofxGgmlDiffusion"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "Hermes handoff output did not contain expected text: $expected"
	}
}

$jsonOutput = & $handoffScript -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-hermes-handoff.ps1 -Json -SummaryOnly failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
foreach ($property in @(
	"Root",
	"EcosystemSummary",
	"QueueSummary",
	"SelectedTask",
	"DirtyRepositoryDetail",
	"Prompt",
	"ContextFiles",
	"RequiredPlanningCommands",
	"ValidationCommands",
	"Guardrails",
	"ReferenceExclusionNote"
)) {
	if (!$parsed.PSObject.Properties[$property]) {
		throw "Hermes handoff JSON did not include $property."
	}
}

if (!$parsed.SummaryOnly) {
	throw "Hermes handoff JSON summary output did not set SummaryOnly."
}
if ($parsed.PSObject.Properties["CodingAgentTasks"]) {
	throw "Hermes handoff summary JSON should omit the full coding-agent task list."
}
if ([string]::IsNullOrWhiteSpace([string]$parsed.Prompt)) {
	throw "Hermes handoff JSON did not include a prompt."
}
if ([string]::IsNullOrWhiteSpace([string]$parsed.DirtyRepositoryDetail.Repository)) {
	throw "Hermes handoff JSON did not include dirty repository detail."
}
if (!$parsed.DirtyRepositoryDetail.PSObject.Properties["Files"]) {
	throw "Hermes handoff JSON did not include dirty file samples."
}
if (@($parsed.ContextFiles) -notcontains "HERMES.md") {
	throw "Hermes handoff JSON did not include HERMES.md as context."
}
if (@($parsed.RequiredPlanningCommands) -notcontains "scripts\plan-coding-agent-work.ps1 -Json") {
	throw "Hermes handoff JSON did not include the coding-agent work queue command."
}
if (@($parsed.ValidationCommands).Count -eq 0) {
	throw "Hermes handoff JSON did not include validation commands."
}
if ([string]$parsed.ReferenceExclusionNote -notmatch "ofxGgmlDiffusion") {
	throw "Hermes handoff JSON did not preserve the reference-repository exclusion note."
}
