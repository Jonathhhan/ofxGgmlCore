$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$scriptPath = Join-Path $scriptRoot "write-agent-instructions.ps1"
$workflowsRoot = Join-Path (Split-Path -Parent $repoRoot) "ofxGgmlWorkflows"
$workflowsAgentsPath = Join-Path $workflowsRoot "AGENTS.md"
$workflowsAvailable = Test-Path -LiteralPath $workflowsAgentsPath -PathType Leaf
$dryRunAddons = @("ofxGgmlCore", "ofxGgmlAgents")
if ($workflowsAvailable) {
	$dryRunAddons += "ofxGgmlWorkflows"
}

$output = & $scriptPath -DryRun -Addons $dryRunAddons *>&1 |
	ForEach-Object { $_.ToString() }
if (!$?) {
	throw "agent instruction dry-run failed."
}

$generatorSource = Get-Content -LiteralPath $scriptPath -Raw
foreach ($expected in @(
	'New-WorkflowsCodexAuthorityAppendix',
	'Ecosystem Authority',
	'Read `ecosystem.yaml` before proposing changes',
	'repository-local `$recursive-codex`',
	'first demonstrated blocker',
	'speculative preparation',
	'Treat `proof` values in `ecosystem.yaml` as claim identifiers',
	'`verification_required`'
)) {
	if ($generatorSource -notmatch [regex]::Escape($expected)) {
		throw "agent instruction generator did not contain required ecosystem authority source: $expected"
	}
}

if ($workflowsAvailable) {
	& $scriptPath -Check -Addons ofxGgmlWorkflows *> $null
	if (!$?) {
		throw "generated ofxGgmlWorkflows agent instructions are stale."
	}

	$workflowsAgents = Get-Content -LiteralPath $workflowsAgentsPath -Raw
	foreach ($expected in @(
		'Ecosystem Authority',
		'Read `ecosystem.yaml` before proposing changes',
		'repository-local `$recursive-codex`',
		'observable capability',
		'first demonstrated blocker',
		'speculative preparation',
		'Treat `proof` values in `ecosystem.yaml` as claim identifiers',
		'`verification_required`',
		'Do not count documentation',
		'add evidence schemas'
	)) {
		if ($workflowsAgents -notmatch [regex]::Escape($expected)) {
			throw "generated Workflows AGENTS.md did not contain required ecosystem authority text: $expected"
		}
	}
}

$text = $output -join "`n"
foreach ($expected in @("Dry run complete", "file(s)")) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "agent instruction dry-run output did not contain expected text: $expected"
	}
}

foreach ($expectedPath in @(
	"AGENTS.md",
	"HERMES.md",
	".github\copilot-instructions.md",
	".github\instructions\ofxggml-ecosystem.instructions.md"
)) {
	$path = Join-Path $repoRoot $expectedPath
	if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
		throw "expected generated agent instruction file was missing: $expectedPath"
	}
}

foreach ($expectedPath in @(
	"AGENTS.md",
	"HERMES.md",
	".github\copilot-instructions.md",
	".github\instructions\ofxggml-ecosystem.instructions.md"
)) {
	$path = Join-Path $repoRoot $expectedPath
	$content = Get-Content -LiteralPath $path -Raw
	foreach ($expected in @(
		"Smoke-Build Target Lifecycle",
		"select-smoke-build-target.ps1",
		"check-smoke-build-target-preflight.ps1",
		"check-smoke-build-target-postflight.ps1"
	)) {
		if ($content -notmatch [regex]::Escape($expected)) {
			throw "generated Core agent instruction file $expectedPath did not contain expected smoke-build lifecycle text: $expected"
		}
	}
}
