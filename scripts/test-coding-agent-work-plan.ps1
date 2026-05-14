$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-coding-agent-work.ps1"

$output = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-coding-agent-work.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml Coding Agent Work Queue",
	"Generated from local ecosystem status",
	"Snapshot",
	"Queue",
	"Guardrails",
	"Do not edit addon runtime/source behavior"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "coding agent work plan output did not contain expected text: $expected"
	}
}
if ($text -match "\$\(") {
	throw "coding agent work plan output contained an unresolved interpolation token."
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-coding-agent-work.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Tasks -or $parsed.Tasks.Count -eq 0) {
	throw "coding agent work plan JSON did not include tasks."
}

$firstTask = @($parsed.Tasks)[0]
foreach ($property in @("Priority", "Repository", "Category", "Task", "Validation")) {
	if (!$firstTask.PSObject.Properties[$property]) {
		throw "coding agent work plan task did not include property: $property"
	}
}
