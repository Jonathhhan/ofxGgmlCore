param()

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-backend-runtime-verification.ps1"
$workspaceRoot = Split-Path -Parent $scriptRoot
$ecosystemRoot = Split-Path -Parent $workspaceRoot
$llamaRoot = Join-Path $ecosystemRoot "ofxGgmlLlama"
$llamaReportPath = Join-Path $llamaRoot ".llama-runtime-smoke.json"

$backupPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxggml-llama-runtime-smoke-contract-backup.json"
$backupExists = $false

if (Test-Path -LiteralPath $llamaReportPath -PathType Leaf) {
	$backupExists = $true
	Copy-Item -LiteralPath $llamaReportPath -Destination $backupPath -Force
}

function Invoke-InferenceSmokePlan {
	$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "plan-backend-runtime-verification.ps1 -Json failed."
	}
	$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
	if (!$parsed.Repositories -or @($parsed.Repositories).Count -eq 0) {
		throw "plan-backend-runtime-verification.ps1 -Json did not include repositories."
	}
	$repo = @($parsed.Repositories | Where-Object { $_.Repository -eq "ofxGgmlLlama" } | Select-Object -First 1)
	if (!$repo) {
		throw "plan-backend-runtime-verification output did not include ofxGgmlLlama repository evidence."
	}
	return $repo.InferenceSmokeEvidence
}

function Write-LlamaSmokeReport {
	param([psobject]$Payload)
	$report = $Payload | ConvertTo-Json -Depth 6
	Set-Content -LiteralPath $llamaReportPath -Value $report -Encoding utf8
}

try {
	try {
		Write-LlamaSmokeReport ([pscustomobject]@{
			Summary = [pscustomobject]@{
				Passed = $true
				InferenceChecked = $true
			}
		})
		$evidence = Invoke-InferenceSmokePlan
		if ($evidence.State -ne "inference-report-invalid") {
			throw "Expected invalid inference-smoke contract state, got '$($evidence.State)'."
		}
		if ($evidence.Error -notmatch "smoke report contract violations") {
			throw "Invalid report did not expose contract violation diagnostics: $($evidence.Error)"
		}
		Write-Host "Contract missing-field case passed."

		Write-LlamaSmokeReport ([pscustomobject]@{
			Summary = [pscustomobject]@{
				Passed = $true
				InferenceChecked = $true
				SmokeKind = "model-backed-cli-text"
				Backend = "cpu"
				ModelPath = "C:\model.gguf"
			}
		})
		$evidence = Invoke-InferenceSmokePlan
		if ($evidence.State -ne "inference-checked") {
			throw "Expected inference-checked state after valid contract, got '$($evidence.State)'."
		}
		Write-Host "Contract valid-field case passed."
	} finally {
		if ($backupExists) {
			Copy-Item -LiteralPath $backupPath -Destination $llamaReportPath -Force
		} elseif (Test-Path -LiteralPath $llamaReportPath -PathType Leaf) {
			Remove-Item -LiteralPath $llamaReportPath -Force
		}
		if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
			Remove-Item -LiteralPath $backupPath -Force
		}
	}
} catch {
	if ($backupExists) {
		Copy-Item -LiteralPath $backupPath -Destination $llamaReportPath -Force
	}
	if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
		Remove-Item -LiteralPath $backupPath -Force
	}
	throw
}
