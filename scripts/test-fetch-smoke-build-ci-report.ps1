$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptRoot "fetch-smoke-build-ci-report.ps1"
$content = Get-Content -LiteralPath $scriptPath -Raw

foreach ($expected in @(
	"Get-GitHubAccessToken",
	"gh.Source auth token",
	"authenticate gh locally",
	'$resolvedToken = Get-GitHubAccessToken -Token $Token',
	'$candidateRuns = @()',
	'foreach ($candidateRun in @($candidateRuns))',
	"No recent successful `$WorkflowFile workflow run exposed a non-expired `$ArtifactName artifact.",
	"Invoke-GitHubDownload -Uri ([string]`$artifact.archive_download_url) -Token `$resolvedToken"
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "fetch-smoke-build-ci-report.ps1 did not contain expected auth behavior: $expected"
	}
}

$addonRoot = Split-Path -Parent $scriptRoot
$workflowPath = Join-Path $addonRoot ".github\workflows\smoke-build-ci.yml"
$workflowContent = Get-Content -LiteralPath $workflowPath -Raw
foreach ($expected in @(
	"name: ofx-smoke-build-ci-report",
	"path: .smoke-build-ci-report.json",
	"if-no-files-found: error",
	"include-hidden-files: true"
)) {
	if ($workflowContent -notmatch [regex]::Escape($expected)) {
		throw "smoke-build-ci.yml did not preserve required report upload behavior: $expected"
	}
}
if ($workflowContent -match "(?m)^\s*continue-on-error:\s*true\s*$") {
	throw "smoke-build-ci.yml must not hide report upload failures."
}

Write-Host "==> Smoke-build CI artifact fetch auth coverage passed"
