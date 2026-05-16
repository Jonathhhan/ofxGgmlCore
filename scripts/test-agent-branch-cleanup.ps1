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
	"Directly merged delete candidates",
	"Patch-equivalent delete candidates",
	"Local agent branches",
	"Remote agent branches",
	"Integrated agent branches",
	"Unintegrated agent branches",
	"Repositories with agent branches",
	"## Branch Inventory",
	"squash-merged branches whose patches are equivalent",
	"## Candidates",
	"Integration",
	"## Unintegrated Branches To Review",
	"## Next Commands",
	"scripts\plan-agent-branch-cleanup.bat -Fetch",
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
foreach ($property in @("RepositoriesScanned", "DeleteCandidates", "LocalDeleteCandidates", "RemoteDeleteCandidates", "MergedDeleteCandidates", "PatchEquivalentDeleteCandidates", "CurrentBranchesSkipped")) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "agent branch cleanup summary did not include property: $property"
	}
}
foreach ($property in @("LocalAgentBranches", "RemoteAgentBranches", "IntegratedAgentBranches", "UnintegratedAgentBranches", "RepositoriesWithAgentBranches")) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "agent branch cleanup inventory summary did not include property: $property"
	}
}
if (($parsed.Summary.MergedDeleteCandidates + $parsed.Summary.PatchEquivalentDeleteCandidates) -ne $parsed.Summary.DeleteCandidates) {
	throw "agent branch cleanup summary did not reconcile merged and patch-equivalent delete candidates."
}
if (($parsed.Summary.IntegratedAgentBranches + $parsed.Summary.UnintegratedAgentBranches) -ne ($parsed.Summary.LocalAgentBranches + $parsed.Summary.RemoteAgentBranches)) {
	throw "agent branch cleanup summary did not reconcile integrated and unintegrated branch inventory."
}
if (!$parsed.PSObject.Properties["Inventory"]) {
	throw "agent branch cleanup JSON output did not include Inventory."
}
if (@($parsed.Candidates).Count -gt 0) {
	$candidate = $parsed.Candidates | Select-Object -First 1
	if (!$candidate.PSObject.Properties["Integration"]) {
		throw "agent branch cleanup candidate did not include Integration."
	}
	$patchEquivalentLocal = @($parsed.Candidates | Where-Object {
			$_.Type -eq "local" -and $_.Integration -eq "patch-equivalent" -and ![string]::IsNullOrWhiteSpace([string]$_.DeleteCommand)
		} | Select-Object -First 1)
	if ($patchEquivalentLocal.Count -gt 0 -and [string]$patchEquivalentLocal[0].DeleteCommand -notmatch [regex]::Escape(" branch -D ")) {
		throw "patch-equivalent local cleanup candidate should use git branch -D."
	}
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
if (!$parsed.PSObject.Properties["UnintegratedBranchReviews"]) {
	throw "agent branch cleanup JSON output did not include UnintegratedBranchReviews."
}
if (@($parsed.UnintegratedBranchReviews).Count -ne $parsed.Summary.UnintegratedAgentBranches) {
	throw "agent branch cleanup JSON output did not reconcile unintegrated branch reviews with the summary count."
}
if (@($parsed.UnintegratedBranchReviews).Count -gt 0) {
	$review = @($parsed.UnintegratedBranchReviews)[0]
	foreach ($property in @("Repository", "Type", "Branch", "DefaultBranch", "ReviewCommand")) {
		if (!$review.PSObject.Properties[$property]) {
			throw "agent branch cleanup unintegrated branch review did not include property: $property"
		}
	}
}

$summaryJsonOutput = & $cleanupScript -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-agent-branch-cleanup.ps1 -Json -SummaryOnly failed."
}
$summaryJsonText = $summaryJsonOutput -join "`n"
$summaryParsed = $summaryJsonText | ConvertFrom-Json
if (!$summaryParsed.SummaryOnly) {
	throw "agent branch cleanup summary JSON did not report SummaryOnly."
}
if (!$summaryParsed.Summary) {
	throw "agent branch cleanup summary JSON did not include Summary."
}
if (!$summaryParsed.PSObject.Properties["RepositorySummaries"]) {
	throw "agent branch cleanup summary JSON did not include RepositorySummaries."
}
if (!$summaryParsed.PSObject.Properties["UnintegratedBranchReviews"]) {
	throw "agent branch cleanup summary JSON did not include UnintegratedBranchReviews."
}
if (@($summaryParsed.UnintegratedBranchReviews).Count -ne $summaryParsed.Summary.UnintegratedAgentBranches) {
	throw "agent branch cleanup summary JSON did not reconcile unintegrated branch reviews with the summary count."
}
if (@($summaryParsed.RepositorySummaries).Count -gt 0) {
	$repositorySummary = @($summaryParsed.RepositorySummaries)[0]
	foreach ($property in @("MergedDeleteCandidates", "PatchEquivalentDeleteCandidates", "IntegratedAgentBranches", "UnintegratedAgentBranches", "UnintegratedBranchReviews")) {
		if (!$repositorySummary.PSObject.Properties[$property]) {
			throw "agent branch cleanup repository summary did not include property: $property"
		}
	}
}
if ($summaryParsed.PSObject.Properties["Inventory"] -or $summaryParsed.PSObject.Properties["Candidates"]) {
	throw "agent branch cleanup summary JSON should omit branch-level Inventory and Candidates."
}
if (@($summaryParsed.NextCommands | Where-Object { [string]$_ -match [regex]::Escape("git -C") }).Count -gt 0) {
	throw "agent branch cleanup summary JSON should omit raw delete commands."
}
if (@($summaryParsed.NextCommands) -notcontains "scripts\plan-agent-branch-cleanup.bat -Fetch -Json -SummaryOnly") {
	throw "agent branch cleanup summary JSON did not include the refreshed summary command."
}
if ($summaryParsed.Summary.DeleteCandidates -gt 0 -and @($summaryParsed.NextCommands) -notcontains "scripts\plan-agent-branch-cleanup.bat -Fetch") {
	throw "agent branch cleanup summary JSON did not include the detailed review command."
}

$summaryMarkdownOutput = & $cleanupScript -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-agent-branch-cleanup.ps1 -SummaryOnly failed."
}
$summaryMarkdownText = $summaryMarkdownOutput -join "`n"
foreach ($expected in @(
	"## Repository Summary",
	"Detailed branch inventory, candidates, and delete commands were omitted",
	"## Unintegrated Branches To Review",
	"## Next Commands"
)) {
	if ($summaryMarkdownText -notmatch [regex]::Escape($expected)) {
		throw "agent branch cleanup summary output did not contain expected text: $expected"
	}
}
if ($summaryMarkdownText -match [regex]::Escape("## Branch Inventory") -or $summaryMarkdownText -match [regex]::Escape("## Candidates")) {
	throw "agent branch cleanup summary output should omit branch-level tables."
}
if ($summaryMarkdownText -match [regex]::Escape(" branch -D ") -or $summaryMarkdownText -match [regex]::Escape(" push origin --delete ")) {
	throw "agent branch cleanup summary output should omit raw delete commands."
}

$emptyJsonOutput = & $cleanupScript -BranchPattern "codex/no-cleanup-branch-should-match-*" -Fetch -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-agent-branch-cleanup.ps1 empty -Json failed."
}
$emptyJsonText = $emptyJsonOutput -join "`n"
foreach ($expected in @(
	'"Inventory":  [',
	'"Candidates":  [',
	'"UnintegratedBranchReviews":  [',
	'"NextCommands":  [',
	'# No delete commands were generated.'
)) {
	if ($emptyJsonText -notmatch [regex]::Escape($expected)) {
		throw "agent branch cleanup empty JSON output did not preserve expected array shape/text: $expected"
	}
}
