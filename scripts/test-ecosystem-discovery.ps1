$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot "get-ecosystem.ps1")

$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$addonsRoot = Split-Path -Parent $repoRoot

$family = @(Get-OfxGgmlEcosystem -AddonsRoot $addonsRoot)
foreach ($expected in @("ofxGgmlCore", "ofxGgmlAgents", "ofxGgmlWorkflows")) {
	if (!@($family | Where-Object { $_.Name -eq $expected })) {
		throw "ecosystem discovery did not include expected repository: $expected"
	}
}

$core = @($family | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
if (!$core -or $core.Scope -notmatch "ecosystem coordination") {
	throw "ecosystem discovery did not attach known Core metadata."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ofxGgmlEcosystemDiscovery-" + [guid]::NewGuid().ToString("N"))
try {
	New-Item -ItemType Directory -Path (Join-Path $tempRoot "ofxGgmlExperimental") -Force | Out-Null
	$discovered = @(Get-OfxGgmlEcosystem -AddonsRoot $tempRoot)
	$experimental = @($discovered | Where-Object { $_.Name -eq "ofxGgmlExperimental" } | Select-Object -First 1)
	if (!$experimental) {
		throw "ecosystem discovery did not include an auto-detected sibling repository."
	}
	if ($experimental.Lane -notmatch "auto-detected") {
		throw "auto-detected repository did not receive fallback metadata."
	}
	if ($experimental.Known) {
		throw "auto-detected repository was marked as known."
	}
} finally {
	$resolvedTemp = Resolve-Path $tempRoot -ErrorAction SilentlyContinue
	$tempBase = [System.IO.Path]::GetTempPath()
	if ($resolvedTemp -and $resolvedTemp.Path.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) {
		Remove-Item -LiteralPath $resolvedTemp.Path -Recurse -Force
	}
}
