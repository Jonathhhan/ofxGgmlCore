$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-doctor-rollout.ps1"

$output = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-doctor-rollout.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml Doctor Rollout Plan",
	"Recommended Order",
	"Guardrails",
	"ofxGgmlLlama",
	"ofxGgmlWorkflows",
	"Do not operate on classified legacy/reference siblings"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "doctor rollout output did not contain expected text: $expected"
	}
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-doctor-rollout.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Repositories -or $parsed.Repositories.Count -lt 11) {
	throw "doctor rollout JSON output did not include managed repositories."
}

$workflows = @($parsed.Repositories | Where-Object { $_.Repository -eq "ofxGgmlWorkflows" } | Select-Object -First 1)
if (!$workflows -or $workflows.Coverage -ne "not-applicable") {
	throw "doctor rollout JSON did not mark ofxGgmlWorkflows as not applicable."
}
