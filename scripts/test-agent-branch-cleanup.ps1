$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$cleanupScript = Join-Path $scriptRoot "plan-agent-branch-cleanup.ps1"

$output = & $cleanupScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-agent-branch-cleanup.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml Agent Branch Cleanup Plan",
	"Dry-run cleanup plan",
	"Branch pattern",
	"This script only writes a plan"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "agent branch cleanup output did not contain expected text: $expected"
	}
}

$jsonOutput = & $cleanupScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-agent-branch-cleanup.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$parsed.Root)) {
	throw "agent branch cleanup JSON output did not include Root."
}
if ([string]$parsed.BranchPattern -ne "codex/*") {
	throw "agent branch cleanup JSON output did not include the default branch pattern."
}
