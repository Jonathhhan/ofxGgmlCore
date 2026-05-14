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
	"## Summary",
	"Managed repositories scanned",
	"Delete candidates",
	"Local agent branches",
	"Remote agent branches",
	"Repositories with agent branches",
	"## Branch Inventory",
	"Inventory includes merged and unmerged matching branches.",
	"## Candidates",
	"## Next Commands",
	"scripts\plan-agent-branch-cleanup.bat -Fetch",
	"# No delete commands were generated.",
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
if (!$parsed.Summary) {
	throw "agent branch cleanup JSON output did not include Summary."
}
foreach ($property in @("RepositoriesScanned", "DeleteCandidates", "LocalDeleteCandidates", "RemoteDeleteCandidates", "CurrentBranchesSkipped")) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "agent branch cleanup summary did not include property: $property"
	}
}
foreach ($property in @("LocalAgentBranches", "RemoteAgentBranches", "RepositoriesWithAgentBranches")) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "agent branch cleanup inventory summary did not include property: $property"
	}
}
if (!$parsed.PSObject.Properties["Inventory"]) {
	throw "agent branch cleanup JSON output did not include Inventory."
}
if (!$parsed.NextCommands -or $parsed.NextCommands.Count -eq 0) {
	throw "agent branch cleanup JSON output did not include NextCommands."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-agent-branch-cleanup.bat -Fetch") {
	throw "agent branch cleanup JSON next commands did not include the fetch refresh command."
}
if ([string]::IsNullOrWhiteSpace([string]$parsed.SafetyNote)) {
	throw "agent branch cleanup JSON output did not include SafetyNote."
}
