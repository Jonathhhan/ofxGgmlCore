param(
	[switch]$AllowGpuBackends
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")
$configPath = Join-Path $addonRoot "addon_config.mk"

if (!(Test-Path -LiteralPath $configPath -PathType Leaf)) {
	throw "addon_config.mk was not found."
}

Write-Step "Checking committed addon_config.mk backend baseline"

if ($AllowGpuBackends) {
	Write-Step "GPU backend baseline check skipped by request"
	return
}

$content = Get-Content -LiteralPath $configPath -Raw
$forbiddenPatterns = @(
	'OFXGGML_WITH_(CUDA|VULKAN|METAL|OPENCL)',
	'ggml-(cuda|vulkan|metal|opencl)\.(lib|a|dylib)',
	'libggml-(cuda|vulkan|metal|opencl)\.(lib|a|dylib)',
	'\$\(CUDA_PATH\)',
	'\$\(VULKAN_SDK\)'
)

foreach ($pattern in $forbiddenPatterns) {
	if ($content -match $pattern) {
		throw "addon_config.mk contains local GPU backend state that should not be committed: $pattern"
	}
}

Write-Step "addon_config.mk uses the portable CPU baseline"
