$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$manifestPath = Join-Path $repoRoot "docs\ECOSYSTEM_MANIFEST.json"

if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
	throw "ecosystem manifest was missing: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) {
	throw "ecosystem manifest schemaVersion must be 1."
}
if (!$manifest.repositories -or $manifest.repositories.Count -lt 11) {
	throw "ecosystem manifest did not include the managed repository list."
}
if (!$manifest.detectedRepositoryClassifications -or $manifest.detectedRepositoryClassifications.Count -lt 7) {
	throw "ecosystem manifest did not include detected repository classifications."
}

$seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($repo in @($manifest.repositories)) {
	foreach ($required in @("name", "kind", "lane", "scope")) {
		if ([string]::IsNullOrWhiteSpace([string]$repo.$required)) {
			throw "ecosystem manifest repository is missing '$required'."
		}
	}
	if (!$repo.name.StartsWith("ofxGgml", [StringComparison]::Ordinal)) {
		throw "ecosystem manifest repository name must start with ofxGgml: $($repo.name)"
	}
	if (!$seen.Add([string]$repo.name)) {
		throw "ecosystem manifest contained a duplicate repository: $($repo.name)"
	}
}

. (Join-Path $scriptRoot "get-ecosystem.ps1")
$known = @(Get-OfxGgmlKnownMetadata)
if ($known.Count -ne $manifest.repositories.Count) {
	throw "get-ecosystem metadata count did not match the manifest."
}

$core = @($known | Where-Object { $_.Name -eq "ofxGgmlCore" } | Select-Object -First 1)
if (!$core -or $core.Kind -ne "core-addon" -or !$core.Known) {
	throw "get-ecosystem did not load Core metadata from the manifest."
}

$classifications = Get-OfxGgmlDetectedClassifications
if (!$classifications.ContainsKey("ofxGgml_X")) {
	throw "get-ecosystem did not load detected repository classifications."
}
if ($classifications["ofxGgml_X"].Known -or !$classifications["ofxGgml_X"].Classified) {
	throw "detected repository classification had incorrect managed flags."
}
