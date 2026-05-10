param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Invoke-DryRun {
	param([hashtable]$Parameters)
	$scriptRoot = $PSScriptRoot
	$scriptPath = Join-Path $scriptRoot "setup-ggml.ps1"
	$powershell = Get-Command pwsh.exe -ErrorAction SilentlyContinue
	if (!$powershell) {
		$powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
	}
	if (!$powershell) {
		throw "Could not find pwsh.exe or powershell.exe."
	}

	$arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath)
	foreach ($key in ($Parameters.Keys | Sort-Object)) {
		$value = $Parameters[$key]
		if ($value -is [bool]) {
			if ($value) {
				$arguments += "-$key"
			}
		} else {
			$arguments += "-$key"
			$arguments += [string]$value
		}
	}

	$output = & $powershell.Source @arguments 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "setup-ggml dry-run failed: $($output -join "`n")"
	}
	return $output -join "`n"
}

function Assert-Contains {
	param(
		[string]$Text,
		[string]$Needle,
		[string]$Label
	)
	if (!$Text.Contains($Needle)) {
		throw "$Label did not contain expected text: $Needle`n$Text"
	}
}

$null = $Configuration
$null = $Platform

Write-Step "setup-ggml default dry-run"
$autoOutput = Invoke-DryRun @{
	DryRun = $true
}
Assert-Contains $autoOutput "Dry run: ggml setup plan" "Auto setup dry-run"
Assert-Contains $autoOutput "mode: Auto" "Auto setup dry-run"
Assert-Contains $autoOutput "enabled backends:" "Auto setup dry-run"
Assert-Contains $autoOutput "Dry run complete; no files were changed" "Auto setup dry-run"

Write-Step "setup-ggml CPU-only dry-run"
$cpuOutput = Invoke-DryRun @{
	DryRun = $true
	CpuOnly = $true
}
Assert-Contains $cpuOutput "mode: CpuOnly" "CPU-only setup dry-run"
Assert-Contains $cpuOutput "enabled backends: CPU=ON CUDA=OFF Vulkan=OFF Metal=OFF OpenCL=OFF" "CPU-only setup dry-run"

Write-Step "Setup dry-run smoke coverage passed"
