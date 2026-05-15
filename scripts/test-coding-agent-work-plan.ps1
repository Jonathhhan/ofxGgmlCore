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
foreach ($property in @("Summary", "Guardrails", "Tasks")) {
	if (!$parsed.PSObject.Properties[$property]) {
		throw "coding agent work plan JSON did not include $property."
	}
}
foreach ($property in @(
	"ManagedRepositories",
	"ReadyManagedRepositories",
	"WorkflowGuidesDetected",
	"DetectedReferenceRepositories",
	"ProposedTasks"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "coding agent work plan JSON summary did not include $property."
	}
}
if ($parsed.Summary.ProposedTasks -ne @($parsed.Tasks).Count) {
	throw "coding agent work plan JSON summary task count did not match tasks."
}
if (@($parsed.Guardrails) -notcontains "Do not edit addon runtime/source behavior unless the user explicitly asks for that repository and behavior.") {
	throw "coding agent work plan JSON output did not include the runtime-edit guardrail."
}
if (($jsonOutput -join "`n") -notmatch '"Guardrails":\s+\[') {
	throw "coding agent work plan JSON output did not preserve Guardrails as an array."
}

$firstTask = @($parsed.Tasks)[0]
foreach ($property in @("Priority", "Repository", "Category", "Task", "Validation", "SuggestedFileList", "ValidationCommands")) {
	if (!$firstTask.PSObject.Properties[$property]) {
		throw "coding agent work plan task did not include property: $property"
	}
}
if (@($firstTask.SuggestedFileList).Count -eq 0) {
	throw "coding agent work plan task did not include structured suggested files."
}
if (@($firstTask.ValidationCommands).Count -eq 0) {
	throw "coding agent work plan task did not include structured validation commands."
}
if (($jsonOutput -join "`n") -notmatch '"ValidationCommands":\s+\[') {
	throw "coding agent work plan JSON output did not preserve ValidationCommands as an array."
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

$snapshotPath = Join-Path (Split-Path -Parent $scriptRoot) "docs\CODING_AGENT_WORK.md"
if (Test-Path -LiteralPath $snapshotPath -PathType Leaf) {
	$snapshot = Get-Content -LiteralPath $snapshotPath -Raw
	if ($snapshot -notmatch [regex]::Escape("plan-release-readiness.ps1")) {
		throw "committed coding agent work snapshot did not reference plan-release-readiness.ps1."
	}
	if ($snapshot -notmatch [regex]::Escape("fetch-workflow-status.py")) {
		throw "committed coding agent work snapshot did not reference fetch-workflow-status.py."
	}
	if ($snapshot -notmatch [regex]::Escape("generate-release-readiness-score.py")) {
		throw "committed coding agent work snapshot did not reference generate-release-readiness-score.py."
	}
	if ($snapshot -notmatch [regex]::Escape("test-release-readiness-plan.ps1")) {
		throw "committed coding agent work snapshot did not reference test-release-readiness-plan.ps1."
	}
	if ($snapshot -notmatch [regex]::Escape("plan-of-smoke-build.ps1")) {
		throw "committed coding agent work snapshot did not reference plan-of-smoke-build.ps1."
	}
	foreach ($expected in @(
		"select-smoke-build-target.ps1",
		"plan-smoke-build-target-handoff.ps1",
		"check-smoke-build-target-preflight.ps1",
		"check-smoke-build-target-postflight.ps1",
		"run-smoke-build-ci.ps1",
		"smoke-build-ci-report.ps1",
		"test-smoke-build-ci-report.ps1"
	)) {
		if ($snapshot -notmatch [regex]::Escape($expected)) {
			throw "committed coding agent work snapshot did not reference $expected."
		}
	}
}
