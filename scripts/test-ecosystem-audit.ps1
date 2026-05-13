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
	"Managed Repositories",
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
if (!$parsed.Repositories -or $parsed.Repositories.Count -lt 11) {
	throw "ecosystem audit JSON output did not include repositories."
}

$core = @($parsed.Repositories | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
if (!$core -or $core.Instructions -ne "complete") {
	throw "ecosystem audit did not report complete Core instructions."
}

& $auditScript -Strict | Out-Null
if (!$?) {
	throw "audit-ecosystem.ps1 -Strict failed."
}
