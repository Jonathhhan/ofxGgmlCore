$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-ecosystem.ps1"

$output = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-ecosystem.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml Ecosystem Agent Plan",
	"Snapshot",
	"classified legacy/reference siblings",
	"Agent Guardrails",
	"Do not edit addon source",
	"plan-coding-agent-work.bat",
	"plan-doctor-rollout.bat",
	"plan-agent-branch-cleanup.bat",
	"Smoke-Build Target Lifecycle",
	"select-smoke-build-target.bat",
	"check-smoke-build-target-preflight.bat",
	"check-smoke-build-target-postflight.bat"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "ecosystem agent plan output did not contain expected text: $expected"
	}
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-ecosystem.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Addons -or $parsed.Addons.Count -eq 0) {
	throw "ecosystem agent JSON output did not include addons."
}
