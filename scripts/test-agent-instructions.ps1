$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$scriptPath = Join-Path $scriptRoot "write-agent-instructions.ps1"

$output = & $scriptPath -DryRun -Addons ofxGgmlCore,ofxGgmlAgents *>&1 |
	ForEach-Object { $_.ToString() }
if (!$?) {
	throw "agent instruction dry-run failed."
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
	".github\instructions\ofxggml-ecosystem.instructions.md",
	".github\workflows\coding-agent-instructions.yml"
)) {
	$path = Join-Path $repoRoot $expectedPath
	if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
		throw "expected generated agent instruction file was missing: $expectedPath"
	}
}
