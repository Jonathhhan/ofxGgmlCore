param(
	[int]$Jobs = 0,
	[switch]$Auto,
	[switch]$CpuOnly,
	[switch]$Cuda,
	[switch]$Vulkan,
	[switch]$Metal,
	[switch]$OpenCL,
	[switch]$AllBackends,
	[switch]$Clean,
	[switch]$SkipGgml,
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

if (!$SkipDoctor) {
	$doctorParams = @{}
	if ($StrictDoctor) {
		$doctorParams.Strict = $true
	}
	Invoke-Step `
		-Label "Checking first-run readiness" `
		-Script (Join-Path $scriptRoot "doctor.ps1") `
		-Parameters $doctorParams
}

Write-Step "First-run setup complete"
