param(
	[int]$Jobs = 0,
	[string]$CudaArchitectures = "",
	[switch]$Auto,
	[switch]$CpuOnly,
	[switch]$Cuda,
	[switch]$Vulkan,
	[switch]$Metal,
	[switch]$OpenCL,
	[switch]$AllBackends,
	[switch]$Clean,
	[switch]$StopRunningRuntime,
	[switch]$SkipGgml,
	[switch]$SkipLlama,
	[switch]$SkipDoctor,
	[switch]$StrictDoctor,
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Invoke-Step {
	param(
		[string]$Label,
		[string]$Script,
		[hashtable]$Parameters
	)
	Write-Step $Label
	& $Script @Parameters
	if (!$?) {
		throw "$Label failed."
	}
}

function Add-CommonBackendParameters {
	param([hashtable]$Parameters)
	if ($Jobs -gt 0) {
		$Parameters.Jobs = $Jobs
	}
	foreach ($name in @("Auto", "CpuOnly", "Cuda", "Vulkan", "Metal", "OpenCL", "Clean", "DryRun")) {
		if ((Get-Variable $name -ValueOnly)) {
			$Parameters[$name] = $true
		}
	}
	return $Parameters
}

if ($AllBackends -and $CpuOnly) {
	throw "-AllBackends cannot be combined with -CpuOnly."
}
if ($AllBackends -and !$SkipLlama) {
	throw "-AllBackends is only supported for ggml setup in first-run. Pass -SkipLlama, or use explicit llama backend switches such as -Cuda, -Vulkan, or -OpenCL."
}

if (!$SkipGgml) {
	$setupParams = Add-CommonBackendParameters @{}
	if ($AllBackends) {
		$setupParams.AllBackends = $true
	}
	Invoke-Step `
		-Label "Setting up ggml" `
		-Script (Join-Path $scriptRoot "setup-ggml.ps1") `
		-Parameters $setupParams
}

if (!$SkipLlama) {
	$llamaParams = Add-CommonBackendParameters @{}
	if (![string]::IsNullOrWhiteSpace($CudaArchitectures)) {
		$llamaParams.CudaArchitectures = $CudaArchitectures
	}
	if ($StopRunningRuntime) {
		$llamaParams.StopRunningRuntime = $true
	}
	Invoke-Step `
		-Label "Building llama.cpp tools" `
		-Script (Join-Path $scriptRoot "build-llama-server.ps1") `
		-Parameters $llamaParams
}

if (!$SkipDoctor) {
	$doctorParams = @{
		NoServerProbe = $DryRun
	}
	if ($StrictDoctor) {
		$doctorParams.Strict = $true
	}
	Invoke-Step `
		-Label "Checking first-run readiness" `
		-Script (Join-Path $scriptRoot "doctor.ps1") `
		-Parameters $doctorParams
}

Write-Step "First-run setup complete"
