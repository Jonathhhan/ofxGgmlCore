param()

$ErrorActionPreference = "Stop"

function Write-JsonFile {
	param(
		[string]$Path,
		[object]$Value
	)
	$Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestScript = Join-Path $scriptRoot "runtime-provider-manifest.ps1"
$compareScript = Join-Path $scriptRoot "compare-runtime-provider-manifest.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ofxGgmlCore-manifest-diff-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
	$currentPath = Join-Path $tempRoot "current.json"
	$baselinePath = Join-Path $tempRoot "baseline.json"
	$changedPath = Join-Path $tempRoot "changed.json"

	$currentJson = & $manifestScript -Json *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "runtime-provider-manifest.ps1 -Json failed."
	}
	Set-Content -LiteralPath $currentPath -Value ($currentJson -join "`n")

	$baseline = Get-Content -LiteralPath $currentPath -Raw | ConvertFrom-Json
	Write-JsonFile -Path $baselinePath -Value $baseline

	$sameOutput = & $compareScript -BaselinePath $baselinePath -CurrentPath $currentPath -Json -SummaryOnly *>&1 |
		ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "compare-runtime-provider-manifest.ps1 unchanged comparison failed."
	}
	$same = ($sameOutput -join "`n") | ConvertFrom-Json
	if ($same.HasChanges) {
		throw "runtime provider manifest diff reported changes for identical manifests."
	}

	$changed = Get-Content -LiteralPath $currentPath -Raw | ConvertFrom-Json
	$changed.EnabledBackends.CUDA = -not [bool]$changed.EnabledBackends.CUDA
	$cudaReadiness = @($changed.BackendReadiness | Where-Object { $_.Name -eq "CUDA" } | Select-Object -First 1)
	if ($cudaReadiness) {
		$cudaReadiness | Add-Member -NotePropertyName State -NotePropertyValue "test-changed" -Force
	}
	$changed.ReadyForCompanions = -not [bool]$changed.ReadyForCompanions
	Write-JsonFile -Path $changedPath -Value $changed

	$diffTextOutput = & $compareScript -BaselinePath $baselinePath -CurrentPath $changedPath *>&1 |
		ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "compare-runtime-provider-manifest.ps1 text comparison failed."
	}
	$diffText = $diffTextOutput -join "`n"
	foreach ($expected in @(
		"ofxGgmlCore runtime provider manifest diff",
		"Changes: True",
		"Ready for companions",
		"Backend changes",
		"Backend readiness changes",
		"CUDA"
	)) {
		if ($diffText -notmatch [regex]::Escape($expected)) {
			throw "runtime provider manifest diff output did not contain expected text: $expected"
		}
	}

	$diffJsonOutput = & $compareScript -BaselinePath $baselinePath -CurrentPath $changedPath -Json *>&1 |
		ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "compare-runtime-provider-manifest.ps1 -Json failed."
	}
	$diff = ($diffJsonOutput -join "`n") | ConvertFrom-Json
	if (!$diff.HasChanges) {
		throw "runtime provider manifest diff JSON did not report changes."
	}
	if (!$diff.BackendChanges -or $diff.BackendChanges.Count -eq 0) {
		throw "runtime provider manifest diff JSON did not include backend changes."
	}
	if (!$diff.BackendReadinessChanges -or $diff.BackendReadinessChanges.Count -eq 0) {
		throw "runtime provider manifest diff JSON did not include backend readiness changes."
	}

	$strictOutput = & $compareScript -BaselinePath $baselinePath -CurrentPath $changedPath -Strict *>&1 |
		ForEach-Object { $_.ToString() }
	if ($?) {
		throw "compare-runtime-provider-manifest.ps1 -Strict should fail when changes are present."
	}
	$null = $strictOutput
} finally {
	if (Test-Path -LiteralPath $tempRoot -PathType Container) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}

Write-Host "==> Runtime provider manifest diff coverage passed"
