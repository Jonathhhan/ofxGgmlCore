param(
	[switch]$Cuda,
	[switch]$Vulkan,
	[switch]$CudaVulkan,
	[switch]$OpenCL,
	[switch]$AllBackends
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Invoke-SetupDryRun {
	param([hashtable]$Parameters)
	$scriptPath = Join-Path $PSScriptRoot "setup-ggml.ps1"
	$powershell = Get-Command pwsh.exe -ErrorAction SilentlyContinue
	if (!$powershell) {
		$powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
	}
	if (!$powershell) {
		throw "Could not find pwsh.exe or powershell.exe."
	}

	$arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath, "-DryRun")
	foreach ($key in ($Parameters.Keys | Sort-Object)) {
		if ($Parameters[$key]) {
			$arguments += "-$key"
		}
	}

	$output = & $powershell.Source @arguments 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "setup-ggml backend dry-run failed: $($output -join "`n")"
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

function Test-Plan {
	param(
		[string]$Label,
		[hashtable]$Parameters,
		[string[]]$Needles
	)
	Write-Step $Label
	$output = Invoke-SetupDryRun $Parameters
	Assert-Contains $output "Dry run: ggml setup plan" $Label
	Assert-Contains $output "Dry run complete; no files were changed" $Label
	foreach ($needle in $Needles) {
		Assert-Contains $output $needle $Label
	}
}

if (!$Cuda -and !$Vulkan -and !$CudaVulkan -and !$OpenCL -and !$AllBackends) {
	throw "Choose at least one explicit backend smoke: -Cuda, -Vulkan, -CudaVulkan, -OpenCL, or -AllBackends."
}

if ($Cuda) {
	Test-Plan `
		-Label "setup-ggml CUDA dry-run" `
		-Parameters @{ Cuda = $true } `
		-Needles @("mode: Explicit", "CUDA=ON")
}

if ($Vulkan) {
	Test-Plan `
		-Label "setup-ggml Vulkan dry-run" `
		-Parameters @{ Vulkan = $true } `
		-Needles @("mode: Explicit", "Vulkan=ON")
}

if ($CudaVulkan) {
	Test-Plan `
		-Label "setup-ggml CUDA+Vulkan dry-run" `
		-Parameters @{ Cuda = $true; Vulkan = $true } `
		-Needles @("mode: Explicit", "CUDA=ON", "Vulkan=ON")
}

if ($OpenCL) {
	Test-Plan `
		-Label "setup-ggml OpenCL dry-run" `
		-Parameters @{ OpenCL = $true } `
		-Needles @("mode: Explicit", "OpenCL=ON")
}

if ($AllBackends) {
	Test-Plan `
		-Label "setup-ggml AllBackends dry-run" `
		-Parameters @{ AllBackends = $true } `
		-Needles @("mode: AllBackends", "CUDA=ON", "Vulkan=ON", "OpenCL=ON")
}

Write-Step "Backend setup dry-run smoke coverage passed"
