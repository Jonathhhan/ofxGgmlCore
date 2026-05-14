$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-of-smoke-build.ps1"

$output = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-of-smoke-build.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"openFrameworks Smoke Build Plan",
	"ProjectGenerator:",
	"Repository Plan",
	"Ready for project-generation checks",
	"Examples with addons.make",
	"Examples missing owner addon",
	"Examples with projectGenerator commands",
	"Example metadata",
	"ready-for-project-generation-check",
	"ofxGgmlCore",
	"ofxGgmlWorkflows",
	"Keep generated openFrameworks project files"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "openFrameworks smoke build plan output did not contain expected text: $expected"
	}
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-of-smoke-build.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Records -or $parsed.Records.Count -eq 0) {
	throw "openFrameworks smoke build plan JSON did not include records."
}

if ($null -eq $parsed.ProjectGeneratorPath) {
	throw "openFrameworks smoke build plan JSON did not include projectGenerator detection state."
}

$ready = @($parsed.Records | Where-Object { $_.Phase -eq "ready-for-project-generation-check" })
if ($ready.Count -eq 0) {
	throw "openFrameworks smoke build plan did not find any project-generation candidates."
}

$examplesWithMetadata = @($parsed.Records | ForEach-Object { $_.ExampleMetadata } | Where-Object { $_.HasAddonsMake })
if ($examplesWithMetadata.Count -eq 0) {
	throw "openFrameworks smoke build plan did not report example addons.make metadata."
}

$missingMetadata = @($parsed.Records | ForEach-Object { $_.ExampleMetadata } | Where-Object {
	!$_.HasAddonsMake -or !$_.HasOwnerAddon -or !$_.HasCoreAddon
})
if ($missingMetadata.Count -gt 0) {
	throw "openFrameworks smoke build plan found examples missing addons.make, owner addon, or ofxGgmlCore references."
}

$examples = @($parsed.Records | ForEach-Object { $_.ExampleMetadata })
if ($examples.Count -eq 0) {
	throw "openFrameworks smoke build plan JSON did not include example metadata."
}

$missingGeneratedProjectState = @($examples | Where-Object { $null -eq $_.HasGeneratedProject })
if ($missingGeneratedProjectState.Count -gt 0) {
	throw "openFrameworks smoke build plan JSON did not include generated project state for every example."
}

if (![string]::IsNullOrWhiteSpace([string]$parsed.ProjectGeneratorPath)) {
	$commands = @($examples | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_.ProjectGeneratorCommand) })
	if ($commands.Count -eq 0) {
		throw "openFrameworks smoke build plan detected projectGenerator but did not emit example commands."
	}
}
