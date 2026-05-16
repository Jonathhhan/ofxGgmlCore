param()

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-backend-runtime-verification.ps1"
$workspaceRoot = Split-Path -Parent $scriptRoot
$ecosystemRoot = Split-Path -Parent $workspaceRoot

function Get-InferenceSmokeTargets {
	param([string]$Root)

	$targets = New-Object System.Collections.Generic.List[psobject]
	foreach ($repoDir in Get-ChildItem -Path $Root -Directory -Filter "ofxGgml*") {
		$metaPath = Join-Path $repoDir.FullName "ofxggml-addon.json"
		if (!(Test-Path -LiteralPath $metaPath -PathType Leaf)) {
			continue
		}
		$metadata = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
		if (![string]::IsNullOrWhiteSpace([string]$metadata.inferenceSmokeReport)) {
			$targets.Add([pscustomobject]@{
				Repository = [string]$repoDir.Name
				ReportPath = Join-Path $repoDir.FullName ([string]$metadata.inferenceSmokeReport)
			})
		}
	}

	if ($targets.Count -eq 0) {
		throw "No ofxGgml repositories with inferenceSmokeReport metadata were found."
	}

	return @($targets.ToArray())
}

function New-InferenceSmokeTestContext {
	param([string]$ReportPath)

	$tempDir = [System.IO.Path]::GetTempPath()
	$fileName = ("ofxggml-inference-smoke-contract-{0}-backup.json" -f [System.Guid]::NewGuid().ToString("N"))
	return [pscustomobject]@{
		ReportPath = [string]$ReportPath
		BackupPath = Join-Path $tempDir $fileName
		BackupExists = $false
	}
}

function Invoke-InferenceSmokePlan {
	param([string]$Repository)

	$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "plan-backend-runtime-verification.ps1 -Json failed."
	}
	$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
	if (!$parsed.Repositories -or @($parsed.Repositories).Count -eq 0) {
		throw "plan-backend-runtime-verification.ps1 -Json did not include repositories."
	}
	$repo = @($parsed.Repositories | Where-Object { $_.Repository -eq $Repository } | Select-Object -First 1)
	if (!$repo) {
		throw "plan-backend-runtime-verification output did not include $Repository repository evidence."
	}
	return $repo.InferenceSmokeEvidence
}

function Write-InferenceSmokeReport {
	param(
		[string]$ReportPath,
		[psobject]$Payload
	)
	$report = $Payload | ConvertTo-Json -Depth 6
	Set-Content -LiteralPath $ReportPath -Value $report -Encoding utf8
}

function Restore-InferenceSmokeContext {
	param([pscustomobject]$Context)

	if ($Context.BackupExists -and (Test-Path -LiteralPath $Context.BackupPath -PathType Leaf)) {
		Copy-Item -LiteralPath $Context.BackupPath -Destination $Context.ReportPath -Force
	} elseif (Test-Path -LiteralPath $Context.ReportPath -PathType Leaf) {
		Remove-Item -LiteralPath $Context.ReportPath -Force
	}
	if (Test-Path -LiteralPath $Context.BackupPath -PathType Leaf) {
		Remove-Item -LiteralPath $Context.BackupPath -Force
	}
}

$targets = Get-InferenceSmokeTargets -Root $ecosystemRoot
$contexts = @{}

foreach ($target in @($targets)) {
	$context = New-InferenceSmokeTestContext -ReportPath $target.ReportPath
	if (Test-Path -LiteralPath $target.ReportPath -PathType Leaf) {
		Copy-Item -LiteralPath $target.ReportPath -Destination $context.BackupPath -Force
		$context.BackupExists = $true
	}
	$contexts[$target.Repository] = $context
}

try {
	try {
		foreach ($target in @($targets)) {
			$context = $contexts[$target.Repository]

			Write-InferenceSmokeReport -ReportPath $target.ReportPath ([pscustomobject]@{
				Summary = [pscustomobject]@{
					Passed = $true
					InferenceChecked = $true
				}
			})
			$evidence = Invoke-InferenceSmokePlan -Repository $target.Repository
			if ($evidence.State -ne "inference-report-invalid") {
				throw "Expected invalid inference-smoke contract state for $($target.Repository), got '$($evidence.State)'."
			}
			if ($evidence.Error -notmatch "smoke report contract violations") {
				throw "Invalid report did not expose contract violation diagnostics for $($target.Repository): $($evidence.Error)"
			}
			Write-Host "Contract missing-field case passed for $($target.Repository)."

			Write-InferenceSmokeReport -ReportPath $target.ReportPath ([pscustomobject]@{
				Summary = [pscustomobject]@{
					Passed = $true
					InferenceChecked = $true
					SmokeKind = "model-backed-cli-text"
					Backend = "cpu"
					ModelPath = "C:\\model.gguf"
				}
			})
			$evidence = Invoke-InferenceSmokePlan -Repository $target.Repository
			if ($evidence.State -ne "inference-checked") {
				throw "Expected inference-checked state for $($target.Repository), got '$($evidence.State)'."
			}
			Write-Host "Contract valid-field case passed for $($target.Repository)."
		}
	} finally {
		foreach ($target in @($targets)) {
			Restore-InferenceSmokeContext -Context $contexts[$target.Repository]
		}
	}
} catch {
	foreach ($target in @($targets)) {
		Restore-InferenceSmokeContext -Context $contexts[$target.Repository]
	}
	throw
}
