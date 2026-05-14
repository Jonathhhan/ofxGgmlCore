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
	"Workflow guides detected",
	"Auto-Detected Completed Planning Guides",
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

$statusScript = Join-Path $scriptRoot "status-family.ps1"
$statusJson = & $statusScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "status-family.ps1 -Json failed."
}

$status = ($statusJson -join "`n") | ConvertFrom-Json
$vision = @($status.Addons | Where-Object { $_.Name -eq "ofxGgmlVision" } | Select-Object -First 1)
if ($vision.Count -gt 0 -and $vision[0].Present -and $vision[0].AgentWorkflowGuide) {
	$staleVisionTasks = @($parsed.Tasks | Where-Object { $_.Repository -eq "ofxGgmlVision" -and $_.Category -eq "lane-uplift" })
	if ($staleVisionTasks.Count -gt 0) {
		throw "coding agent work plan should not propose stale Vision lane-uplift work after detecting a workflow guide."
	}
}

$managedWithGuides = @($status.Addons | Where-Object { $_.Known -and $_.Present -and $_.AgentWorkflowGuide })
if ($managedWithGuides.Count -gt 0) {
	$guidedLaneNames = @($managedWithGuides |
		Where-Object { $_.Name -ne "ofxGgmlCore" -and $_.Name -ne "ofxGgmlWorkflows" } |
		ForEach-Object { $_.Name })
	$staleLaneTasks = @($parsed.Tasks | Where-Object { $_.Category -eq "lane-uplift" -and $guidedLaneNames -contains $_.Repository })
	if ($staleLaneTasks.Count -gt 0) {
		throw "coding agent work plan proposed stale lane-uplift work for guided repositories: $(@($staleLaneTasks | ForEach-Object { $_.Repository }) -join ', ')"
	}
}
