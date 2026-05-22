param(
	[Parameter(Mandatory = $true)]
	[string]$BaselinePath,
	[string]$CurrentPath = "",
	[switch]$Json,
	[switch]$SummaryOnly,
	[switch]$Strict
)

$ErrorActionPreference = "Stop"

function Read-Manifest {
	param([string]$Path)
	if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "Manifest file not found: $Path"
	}
	return (Get-Content -LiteralPath $Path -Raw) | ConvertFrom-Json
}

function Get-CurrentManifest {
	param([string]$ScriptRoot)
	$output = & (Join-Path $ScriptRoot "runtime-provider-manifest.ps1") -Json *>&1 |
		ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "runtime-provider-manifest.ps1 -Json failed."
	}
	return ($output -join "`n") | ConvertFrom-Json
}

function Get-PropertyValue {
	param(
		[object]$Object,
		[string]$Name
	)
	if (!$Object) {
		return $null
	}
	$property = $Object.PSObject.Properties[$Name]
	if (!$property) {
		return $null
	}
	return $property.Value
}

function Get-ObjectNames {
	param([object[]]$Objects)
	$names = New-Object System.Collections.Generic.List[string]
	foreach ($object in $Objects) {
		if (!$object) {
			continue
		}
		foreach ($property in $object.PSObject.Properties) {
			if (!$names.Contains([string]$property.Name)) {
				$names.Add([string]$property.Name)
			}
		}
	}
	return @($names.ToArray() | Sort-Object)
}

function New-BackendChange {
	param(
		[string]$Name,
		[object]$Baseline,
		[object]$Current
	)
	$baselineValue = [bool](Get-PropertyValue -Object $Baseline -Name $Name)
	$currentValue = [bool](Get-PropertyValue -Object $Current -Name $Name)
	if ($baselineValue -eq $currentValue) {
		return $null
	}
	return [pscustomobject]@{
		Name = $Name
		Baseline = $baselineValue
		Current = $currentValue
		Direction = if ($currentValue) { "added" } else { "removed" }
	}
}

function New-PathChange {
	param(
		[string]$Name,
		[string]$Baseline,
		[string]$Current
	)
	if ($Baseline -eq $Current) {
		return $null
	}
	return [pscustomobject]@{
		Name = $Name
		Baseline = $Baseline
		Current = $Current
	}
}

function Get-ReadinessMap {
	param([object[]]$Checks)
	$map = @{}
	foreach ($check in @($Checks)) {
		if (!$check -or [string]::IsNullOrWhiteSpace([string]$check.Name)) {
			continue
		}
		$map[[string]$check.Name] = [bool]$check.Ready
	}
	return $map
}

function Get-BackendReadinessMap {
	param([object[]]$Backends)
	$map = @{}
	foreach ($backend in @($Backends)) {
		if (!$backend -or [string]::IsNullOrWhiteSpace([string]$backend.Name)) {
			continue
		}
		$map[[string]$backend.Name] = [string]$backend.State
	}
	return $map
}

function New-BackendReadinessChange {
	param(
		[string]$Name,
		[hashtable]$Baseline,
		[hashtable]$Current
	)
	$baselineHas = $Baseline.ContainsKey($Name)
	$currentHas = $Current.ContainsKey($Name)
	$baselineValue = if ($baselineHas) { [string]$Baseline[$Name] } else { "" }
	$currentValue = if ($currentHas) { [string]$Current[$Name] } else { "" }
	if ($baselineHas -and $currentHas -and $baselineValue -eq $currentValue) {
		return $null
	}
	$status = if (!$baselineHas) {
		"added"
	} elseif (!$currentHas) {
		"removed"
	} else {
		"changed"
	}
	return [pscustomobject]@{
		Name = $Name
		Baseline = $baselineValue
		Current = $currentValue
		Status = $status
	}
}

function New-ReadinessChange {
	param(
		[string]$Name,
		[hashtable]$Baseline,
		[hashtable]$Current
	)
	$baselineHas = $Baseline.ContainsKey($Name)
	$currentHas = $Current.ContainsKey($Name)
	$baselineValue = if ($baselineHas) { [bool]$Baseline[$Name] } else { $null }
	$currentValue = if ($currentHas) { [bool]$Current[$Name] } else { $null }
	if ($baselineHas -and $currentHas -and $baselineValue -eq $currentValue) {
		return $null
	}
	$status = if (!$baselineHas) {
		"added"
	} elseif (!$currentHas) {
		"removed"
	} elseif ($currentValue) {
		"became-ready"
	} else {
		"became-not-ready"
	}
	return [pscustomobject]@{
		Name = $Name
		Baseline = $baselineValue
		Current = $currentValue
		Status = $status
	}
}

function Compare-Manifests {
	param(
		[object]$Baseline,
		[object]$Current
	)
	$backendNames = Get-ObjectNames @($Baseline.EnabledBackends, $Current.EnabledBackends)
	$backendChanges = @($backendNames | ForEach-Object {
		New-BackendChange -Name $_ -Baseline $Baseline.EnabledBackends -Current $Current.EnabledBackends
	} | Where-Object { $_ })

	$baselineBackendReadiness = Get-BackendReadinessMap -Backends $Baseline.BackendReadiness
	$currentBackendReadiness = Get-BackendReadinessMap -Backends $Current.BackendReadiness
	$backendReadinessNames = @($baselineBackendReadiness.Keys + $currentBackendReadiness.Keys |
		Sort-Object -Unique)
	$backendReadinessChanges = @($backendReadinessNames | ForEach-Object {
		New-BackendReadinessChange `
			-Name $_ `
			-Baseline $baselineBackendReadiness `
			-Current $currentBackendReadiness
	} | Where-Object { $_ })

	$libraryNames = Get-ObjectNames @($Baseline.Ggml.Libraries, $Current.Ggml.Libraries)
	$libraryPathChanges = @($libraryNames | ForEach-Object {
		New-PathChange `
			-Name $_ `
			-Baseline ([string](Get-PropertyValue -Object $Baseline.Ggml.Libraries -Name $_)) `
			-Current ([string](Get-PropertyValue -Object $Current.Ggml.Libraries -Name $_))
	} | Where-Object { $_ })

	$pathChanges = @(
		New-PathChange `
			-Name "IncludeDir" `
			-Baseline ([string]$Baseline.Ggml.IncludeDir) `
			-Current ([string]$Current.Ggml.IncludeDir)
		New-PathChange `
			-Name "LibDir" `
			-Baseline ([string]$Baseline.Ggml.LibDir) `
			-Current ([string]$Current.Ggml.LibDir)
		New-PathChange `
			-Name "SourceDir" `
			-Baseline ([string]$Baseline.Ggml.SourceDir) `
			-Current ([string]$Current.Ggml.SourceDir)
	) | Where-Object { $_ }

	$pinChanges = @(
		New-PathChange `
			-Name "ReleaseTag" `
			-Baseline ([string]$Baseline.Ggml.ReleaseTag) `
			-Current ([string]$Current.Ggml.ReleaseTag)
		New-PathChange `
			-Name "Commit" `
			-Baseline ([string]$Baseline.Ggml.Commit) `
			-Current ([string]$Current.Ggml.Commit)
	) | Where-Object { $_ }

	$baselineReadiness = Get-ReadinessMap -Checks $Baseline.Readiness
	$currentReadiness = Get-ReadinessMap -Checks $Current.Readiness
	$readinessNames = @($baselineReadiness.Keys + $currentReadiness.Keys |
		Sort-Object -Unique)
	$readinessChanges = @($readinessNames | ForEach-Object {
		New-ReadinessChange -Name $_ -Baseline $baselineReadiness -Current $currentReadiness
	} | Where-Object { $_ })

	$readyChanged = [bool]$Baseline.ReadyForCompanions -ne [bool]$Current.ReadyForCompanions
	$hasChanges = ($backendChanges.Count -gt 0) -or
		($backendReadinessChanges.Count -gt 0) -or
		($libraryPathChanges.Count -gt 0) -or
		($pathChanges.Count -gt 0) -or
		($pinChanges.Count -gt 0) -or
		($readinessChanges.Count -gt 0) -or
		$readyChanged

	return [pscustomobject]@{
		SchemaVersion = 1
		Provider = "ofxGgmlCore"
		BaselineRoot = [string]$Baseline.Root
		CurrentRoot = [string]$Current.Root
		HasChanges = [bool]$hasChanges
		ReadyForCompanionsChanged = [bool]$readyChanged
		ReadyForCompanions = [pscustomobject]@{
			Baseline = [bool]$Baseline.ReadyForCompanions
			Current = [bool]$Current.ReadyForCompanions
		}
		BackendChanges = $backendChanges
		BackendReadinessChanges = $backendReadinessChanges
		RuntimePathChanges = $pathChanges
		LibraryPathChanges = $libraryPathChanges
		VendorPinChanges = $pinChanges
		ReadinessChanges = $readinessChanges
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$baseline = Read-Manifest -Path $BaselinePath
$current = if ([string]::IsNullOrWhiteSpace($CurrentPath)) {
	Get-CurrentManifest -ScriptRoot $scriptRoot
} else {
	Read-Manifest -Path $CurrentPath
}

$comparison = Compare-Manifests -Baseline $baseline -Current $current
if ($SummaryOnly) {
	$comparison = [pscustomobject]@{
		SchemaVersion = $comparison.SchemaVersion
		Provider = $comparison.Provider
		HasChanges = $comparison.HasChanges
		ReadyForCompanionsChanged = $comparison.ReadyForCompanionsChanged
		BackendChangeCount = @($comparison.BackendChanges).Count
		BackendReadinessChangeCount = @($comparison.BackendReadinessChanges).Count
		RuntimePathChangeCount = @($comparison.RuntimePathChanges).Count
		LibraryPathChangeCount = @($comparison.LibraryPathChanges).Count
		VendorPinChangeCount = @($comparison.VendorPinChanges).Count
		ReadinessChangeCount = @($comparison.ReadinessChanges).Count
	}
}

if ($Json) {
	$comparison | ConvertTo-Json -Depth 8
} else {
	Write-Host "ofxGgmlCore runtime provider manifest diff"
	Write-Host ("Baseline: {0}" -f $BaselinePath)
	if ([string]::IsNullOrWhiteSpace($CurrentPath)) {
		Write-Host "Current:  live runtime provider manifest"
	} else {
		Write-Host ("Current:  {0}" -f $CurrentPath)
	}
	Write-Host ""
	Write-Host ("Changes: {0}" -f $comparison.HasChanges)
	Write-Host ("Ready for companions: {0} -> {1}" -f `
		$comparison.ReadyForCompanions.Baseline,
		$comparison.ReadyForCompanions.Current)

	if (@($comparison.BackendChanges).Count -gt 0) {
		Write-Host ""
		Write-Host "Backend changes:"
		foreach ($change in $comparison.BackendChanges) {
			Write-Host ("  {0,-6} {1} -> {2} ({3})" -f `
				$change.Name,
				$change.Baseline,
				$change.Current,
				$change.Direction)
		}
	}

	if (@($comparison.BackendReadinessChanges).Count -gt 0) {
		Write-Host ""
		Write-Host "Backend readiness changes:"
		foreach ($change in $comparison.BackendReadinessChanges) {
			Write-Host ("  {0,-6} {1} -> {2} ({3})" -f `
				$change.Name,
				$change.Baseline,
				$change.Current,
				$change.Status)
		}
	}

	if (@($comparison.ReadinessChanges).Count -gt 0) {
		Write-Host ""
		Write-Host "Readiness changes:"
		foreach ($change in $comparison.ReadinessChanges) {
			Write-Host ("  {0}: {1} -> {2} ({3})" -f `
				$change.Name,
				$change.Baseline,
				$change.Current,
				$change.Status)
		}
	}

	if (@($comparison.RuntimePathChanges).Count -gt 0 -or
		@($comparison.LibraryPathChanges).Count -gt 0 -or
		@($comparison.VendorPinChanges).Count -gt 0) {
		Write-Host ""
		Write-Host "Path/pin changes:"
		foreach ($change in @($comparison.RuntimePathChanges +
			$comparison.LibraryPathChanges +
			$comparison.VendorPinChanges)) {
			Write-Host ("  {0}: {1} -> {2}" -f $change.Name, $change.Baseline, $change.Current)
		}
	}
}

if ($Strict -and $comparison.HasChanges) {
	exit 1
}
