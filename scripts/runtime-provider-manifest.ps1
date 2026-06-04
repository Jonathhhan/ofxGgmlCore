param(
	[switch]$Json,
	[switch]$SummaryOnly,
	[switch]$Strict
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path

function Test-PathExists {
	param(
		[string]$Path,
		[switch]$Directory
	)
	if ($Directory) {
		return Test-Path -LiteralPath $Path -PathType Container
	}
	return Test-Path -LiteralPath $Path -PathType Leaf
}

function Get-VendorPinValue {
	param([string]$Prefix)
	$candidates = @(
		(Join-Path $addonRoot "libs\ggml\OFX_VENDOR_PIN.txt"),
		(Join-Path $addonRoot "libs\ggml\.source\OFX_VENDOR_PIN.txt")
	)
	foreach ($path in $candidates) {
		if (!(Test-PathExists -Path $path)) {
			continue
		}
		$line = Get-Content -LiteralPath $path -ErrorAction SilentlyContinue |
			Where-Object { $_ -like "$Prefix*" } |
			Select-Object -First 1
		if ($line) {
			return $line.Substring($Prefix.Length).Trim()
		}
	}
	return ""
}

function Get-GgmlAceStepOpReadiness {
	param([string]$IncludeDir)
	$ggmlHeader = Join-Path $IncludeDir "ggml.h"
	if (!(Test-PathExists -Path $ggmlHeader)) {
		return [pscustomobject]@{
			Col2Im1DReady = $false
			SnakeFusedReady = $false
		}
	}
	$headerText = Get-Content -LiteralPath $ggmlHeader -Raw
	$snakeFusedReady = $headerText -match "ggml_compute_forward_snake_fused"
	$sourceRoot = Join-Path $addonRoot "libs\ggml\.source"
	if (!$snakeFusedReady -and (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
		foreach ($candidate in @(
			(Join-Path $sourceRoot "src\ggml-cpu\ops.h"),
			(Join-Path $sourceRoot "src\ggml-cuda\snake.cuh"),
			(Join-Path $sourceRoot "src\ggml-vulkan\vulkan-shaders\snake.comp"),
			(Join-Path $sourceRoot "src\ggml-metal\ggml-metal-ops.h")
		)) {
			if ((Test-PathExists -Path $candidate) -and
				((Get-Content -LiteralPath $candidate -Raw) -match "snake")) {
				$snakeFusedReady = $true
				break
			}
		}
	}
	return [pscustomobject]@{
		Col2Im1DReady = [bool]($headerText -match "ggml_col2im_1d")
		SnakeFusedReady = [bool]$snakeFusedReady
	}
}

function New-ReadinessCheck {
	param(
		[string]$Name,
		[bool]$Ready,
		[string]$Detail
	)
	[pscustomobject]@{
		Name = $Name
		Ready = $Ready
		Detail = $Detail
	}
}

function New-BackendReadiness {
	param(
		[string]$Name,
		[bool]$HeadersReady,
		[string]$LibraryPath,
		[bool]$Required
	)
	$libraryReady = Test-PathExists -Path $LibraryPath
	$state = if (!$HeadersReady) {
		"missing-headers"
	} elseif ($libraryReady) {
		"ready"
	} elseif ($Required) {
		"missing-required-lib"
	} else {
		"missing-lib"
	}

	[pscustomobject]@{
		Name = $Name
		State = $state
		Ready = [bool]($HeadersReady -and $libraryReady)
		Required = [bool]$Required
		Detail = $LibraryPath
	}
}

$includeDir = Join-Path $addonRoot "libs\ggml\include"
$libDir = Join-Path $addonRoot "libs\ggml\lib"
$sourceDir = Join-Path $addonRoot "libs\ggml\.source"

$libraries = @{
	Base = Join-Path $libDir "ggml-base.lib"
	Core = Join-Path $libDir "ggml.lib"
	Cpu = Join-Path $libDir "ggml-cpu.lib"
	Cuda = Join-Path $libDir "ggml-cuda.lib"
	Vulkan = Join-Path $libDir "ggml-vulkan.lib"
	Metal = Join-Path $libDir "ggml-metal.lib"
	OpenCL = Join-Path $libDir "ggml-opencl.lib"
}

$headersReady = (Test-PathExists -Path (Join-Path $includeDir "ggml.h"))
$aceStepOpReadiness = Get-GgmlAceStepOpReadiness -IncludeDir $includeDir
$aceStepOpsReady = [bool]($aceStepOpReadiness.Col2Im1DReady -and $aceStepOpReadiness.SnakeFusedReady)
$baseReady = (Test-PathExists -Path $libraries.Core) -and
	(Test-PathExists -Path $libraries.Base) -and
	(Test-PathExists -Path $libraries.Cpu)

$enabledBackends = [ordered]@{
	CPU = [bool](Test-PathExists -Path $libraries.Cpu)
	CUDA = [bool](Test-PathExists -Path $libraries.Cuda)
	Vulkan = [bool](Test-PathExists -Path $libraries.Vulkan)
	Metal = [bool](Test-PathExists -Path $libraries.Metal)
	OpenCL = [bool](Test-PathExists -Path $libraries.OpenCL)
}

$readiness = @(
	New-ReadinessCheck -Name "ggml headers" -Ready $headersReady -Detail $includeDir
	New-ReadinessCheck -Name "ACE-Step col2im_1d op" -Ready $aceStepOpReadiness.Col2Im1DReady -Detail "ggml_col2im_1d"
	New-ReadinessCheck -Name "ACE-Step fused Snake support" -Ready $aceStepOpReadiness.SnakeFusedReady -Detail "mul/sin/sqr/mul/add fusion"
	New-ReadinessCheck -Name "ggml base libraries" -Ready $baseReady -Detail $libDir
	New-ReadinessCheck -Name "CPU backend" -Ready ([bool]$enabledBackends.CPU) -Detail $libraries.Cpu
)
foreach ($backendName in @("CUDA", "Vulkan", "Metal", "OpenCL")) {
	$libraryKey = if ($backendName -eq "CUDA") { "Cuda" } else { $backendName }
	$readiness += New-ReadinessCheck `
		-Name "$backendName backend" `
		-Ready ([bool]$enabledBackends.$backendName) `
		-Detail $libraries.$libraryKey
}

$backendReadiness = @(
	New-BackendReadiness -Name "CPU" -HeadersReady $headersReady -LibraryPath $libraries.Cpu -Required $true
	New-BackendReadiness -Name "CUDA" -HeadersReady $headersReady -LibraryPath $libraries.Cuda -Required $false
	New-BackendReadiness -Name "Vulkan" -HeadersReady $headersReady -LibraryPath $libraries.Vulkan -Required $false
	New-BackendReadiness -Name "Metal" -HeadersReady $headersReady -LibraryPath $libraries.Metal -Required $false
	New-BackendReadiness -Name "OpenCL" -HeadersReady $headersReady -LibraryPath $libraries.OpenCL -Required $false
)

$manifest = [pscustomobject]@{
	SchemaVersion = 1
	Addon = "ofxGgmlCore"
	Provider = "ofxGgmlCore"
	Role = "shared ggml runtime provider"
	Root = $addonRoot
	Ggml = [pscustomobject]@{
		IncludeDir = $includeDir
		LibDir = $libDir
		SourceDir = $sourceDir
		ReleaseTag = Get-VendorPinValue -Prefix "Upstream release tag:"
		Commit = Get-VendorPinValue -Prefix "Upstream commit:"
		AceStepOpsReady = $aceStepOpsReady
		AceStepCol2Im1DReady = $aceStepOpReadiness.Col2Im1DReady
		AceStepSnakeFusedReady = $aceStepOpReadiness.SnakeFusedReady
		Libraries = [pscustomobject]$libraries
	}
	EnabledBackends = [pscustomobject]$enabledBackends
	BackendReadiness = $backendReadiness
	Readiness = $readiness
	ReadyForCompanions = [bool]($headersReady -and $baseReady)
	Notes = @(
		"Core stays model-agnostic; companion addons own model-specific runtime policy.",
		"CPU is the required baseline. GPU backends are available only when their ggml libraries are present."
	)
}

if ($SummaryOnly) {
	$manifest = [pscustomobject]@{
		SchemaVersion = $manifest.SchemaVersion
		Provider = $manifest.Provider
		Root = $manifest.Root
		ReadyForCompanions = $manifest.ReadyForCompanions
		EnabledBackends = $manifest.EnabledBackends
		BackendReadiness = $manifest.BackendReadiness
		GgmlIncludeDir = $manifest.Ggml.IncludeDir
		GgmlLibDir = $manifest.Ggml.LibDir
		AceStepOpsReady = $manifest.Ggml.AceStepOpsReady
		AceStepCol2Im1DReady = $manifest.Ggml.AceStepCol2Im1DReady
		AceStepSnakeFusedReady = $manifest.Ggml.AceStepSnakeFusedReady
	}
}

if ($Json) {
	$manifest | ConvertTo-Json -Depth 8
} else {
	Write-Host "ofxGgmlCore runtime provider manifest"
	Write-Host "Root  $addonRoot"
	Write-Host ""
	Write-Host ("Ready for companions: {0}" -f $manifest.ReadyForCompanions)
	Write-Host ("ggml include: {0}" -f $includeDir)
	Write-Host ("ggml libs:    {0}" -f $libDir)
	Write-Host ("ACE-Step ops: {0}" -f $aceStepOpsReady)
	Write-Host ("  col2im_1d:   {0}" -f $aceStepOpReadiness.Col2Im1DReady)
	Write-Host ("  fused Snake: {0}" -f $aceStepOpReadiness.SnakeFusedReady)
	Write-Host "Backends:"
	foreach ($name in @("CPU", "CUDA", "Vulkan", "Metal", "OpenCL")) {
		Write-Host ("  {0,-6} {1}" -f $name, $enabledBackends.$name)
	}
	Write-Host ""
	Write-Host "Backend readiness:"
	foreach ($backend in $backendReadiness) {
		Write-Host ("{0,-6} {1}" -f $backend.Name, $backend.State)
	}
	Write-Host ""
	Write-Host "Readiness:"
	foreach ($check in $readiness) {
		$state = if ($check.Ready) { "OK" } else { "WARN" }
		Write-Host ("{0,-5} {1} - {2}" -f $state, $check.Name, $check.Detail)
	}
}

if ($Strict -and !$manifest.ReadyForCompanions) {
	exit 1
}
