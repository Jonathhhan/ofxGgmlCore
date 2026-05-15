$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptRoot "fetch-smoke-build-ci-report.ps1"
$content = Get-Content -LiteralPath $scriptPath -Raw

foreach ($expected in @(
	"Get-GitHubAccessToken",
	"gh.Source auth token",
	"authenticate gh locally",
	'$resolvedToken = Get-GitHubAccessToken -Token $Token',
	"Invoke-GitHubDownload -Uri ([string]`$artifact.archive_download_url) -Token `$resolvedToken"
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "fetch-smoke-build-ci-report.ps1 did not contain expected auth behavior: $expected"
	}
}

Write-Host "==> Smoke-build CI artifact fetch auth coverage passed"
