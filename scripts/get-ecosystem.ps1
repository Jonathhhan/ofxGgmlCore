if ([string]::IsNullOrWhiteSpace($script:OfxGgmlEcosystemScriptRoot)) {
	$script:OfxGgmlEcosystemScriptRoot = Split-Path -Parent $PSCommandPath
}

function Get-OfxGgmlKnownMetadata {
	param([string]$ManifestPath = "")

	if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
		$coreRoot = Resolve-Path (Join-Path $script:OfxGgmlEcosystemScriptRoot "..")
		$ManifestPath = Join-Path $coreRoot "docs\ECOSYSTEM_MANIFEST.json"
	}

	if (!(Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
		throw "Ecosystem manifest was not found: $ManifestPath"
	}

	$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
	if (!$manifest.repositories -or $manifest.repositories.Count -eq 0) {
		throw "Ecosystem manifest did not contain repositories: $ManifestPath"
	}

	$known = @()
	foreach ($repo in @($manifest.repositories)) {
		foreach ($required in @("name", "kind", "lane", "scope")) {
			if ([string]::IsNullOrWhiteSpace([string]$repo.$required)) {
				throw "Ecosystem manifest repository is missing '$required': $ManifestPath"
			}
		}
		$known += @{
			Name = [string]$repo.name
			Kind = [string]$repo.kind
			Lane = [string]$repo.lane
			Scope = [string]$repo.scope
			Known = $true
		}
	}
	return $known
}

function Get-OfxGgmlDetectedClassifications {
	param([string]$ManifestPath = "")

	if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
		$coreRoot = Resolve-Path (Join-Path $script:OfxGgmlEcosystemScriptRoot "..")
		$ManifestPath = Join-Path $coreRoot "docs\ECOSYSTEM_MANIFEST.json"
	}

	if (!(Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
		throw "Ecosystem manifest was not found: $ManifestPath"
	}

	$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
	$classifications = @{}
	foreach ($entry in @($manifest.detectedRepositoryClassifications)) {
		foreach ($required in @("name", "kind", "lane", "scope")) {
			if ([string]::IsNullOrWhiteSpace([string]$entry.$required)) {
				throw "Ecosystem manifest detected repository classification is missing '$required': $ManifestPath"
			}
		}
		$classifications[[string]$entry.name] = @{
			Name = [string]$entry.name
			Kind = [string]$entry.kind
			Lane = [string]$entry.lane
			Scope = [string]$entry.scope
			Known = $false
			Classified = $true
		}
	}
	return $classifications
}

function New-OfxGgmlDiscoveredMetadata {
	param([string]$Name)
	return @{
		Name = $Name
		Kind = "detected-repository"
		Lane = "auto-detected ecosystem repository"
		Scope = "auto-detected sibling repository; classify its lane before broad cross-repo automation"
		Known = $false
		Classified = $false
	}
}

function Get-OfxGgmlEcosystem {
	param([string]$AddonsRoot)

	if ([string]::IsNullOrWhiteSpace($AddonsRoot)) {
		$scriptRoot = $script:OfxGgmlEcosystemScriptRoot
		$coreRoot = Resolve-Path (Join-Path $scriptRoot "..")
		$AddonsRoot = Split-Path -Parent $coreRoot
	}

	$known = @(Get-OfxGgmlKnownMetadata)
	$classifications = Get-OfxGgmlDetectedClassifications
	$seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
	$family = New-Object System.Collections.Generic.List[hashtable]

	foreach ($addon in $known) {
		[void]$seen.Add([string]$addon.Name)
		$family.Add($addon)
	}

	if (Test-Path -LiteralPath $AddonsRoot -PathType Container) {
		$discovered = @(
			Get-ChildItem -LiteralPath $AddonsRoot -Directory -Filter "ofxGgml*" -ErrorAction SilentlyContinue |
				Sort-Object Name
		)
		foreach ($directory in $discovered) {
			if (!$seen.Contains($directory.Name)) {
				[void]$seen.Add($directory.Name)
				if ($classifications.ContainsKey($directory.Name)) {
					$family.Add($classifications[$directory.Name])
				} else {
					$family.Add((New-OfxGgmlDiscoveredMetadata -Name $directory.Name))
				}
			}
		}
	}

	return @($family)
}
