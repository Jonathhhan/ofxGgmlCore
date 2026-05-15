$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$auditScript = Join-Path $scriptRoot "audit-ecosystem.ps1"

$output = & $auditScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "audit-ecosystem.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"ofxGgml Ecosystem Audit",
	"Summary",
	"Managed Repositories",
	"Copilot Ecosystem",
	"reference only; keep out of managed automation",
	"ready for planning"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "ecosystem audit output did not contain expected text: $expected"
	}
}

$jsonOutput = & $auditScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "audit-ecosystem.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Summary) {
	throw "ecosystem audit JSON output did not include Summary."
}
foreach ($property in @(
	"ManagedRepositories",
	"ReadyManagedRepositories",
	"BlockedManagedRepositories",
	"DetectedReferenceRepositories",
	"DirtyManagedRepositories",
	"DirtyDetectedRepositories",
	"MissingInstructionManagedRepositories",
	"MissingWorkflowManagedRepositories",
	"MissingValidationManagedRepositories",
	"BlockingManagedRepositoryNames"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "ecosystem audit JSON Summary did not include $property."
	}
}
if ($parsed.Summary.ManagedRepositories -lt 11) {
	throw "ecosystem audit JSON Summary did not count managed repositories."
}
if ($parsed.Summary.BlockedManagedRepositories -ne 0 -or @($parsed.Summary.BlockingManagedRepositoryNames).Count -ne 0) {
	throw "ecosystem audit JSON Summary reported managed blockers for a passing strict audit."
}
if (!$parsed.Repositories -or $parsed.Repositories.Count -lt 11) {
	throw "ecosystem audit JSON output did not include repositories."
}

$core = @($parsed.Repositories | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
if (!$core -or $core.Instructions -ne "complete") {
	throw "ecosystem audit did not report complete Core instructions."
}
if ($core.CopilotEcosystemInstructions -ne "yes") {
	throw "ecosystem audit did not report Core Copilot ecosystem instructions."
}

& $auditScript -Strict | Out-Null
if (!$?) {
	throw "audit-ecosystem.ps1 -Strict failed."
}
