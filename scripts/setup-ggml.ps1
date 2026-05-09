param(
	[string]$Revision = "v0.11.0",
	[string]$Repo = "https://github.com/ggml-org/ggml.git",
	[int]$Jobs = 0,
	# Default behavior when no backend switch is supplied.
	[switch]$Auto,
	[switch]$CpuOnly,
	[switch]$Cuda,
	[switch]$Vulkan,
	[switch]$Metal,
	[switch]$OpenCL,
	[switch]$AllBackends,
	[switch]$Clean,
	[switch]$WithDebug
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$GgmlRoot = Join-Path $Root "libs\ggml"
$Source = Join-Path $GgmlRoot ".source"
$Build = Join-Path $GgmlRoot "build"
$Include = Join-Path $GgmlRoot "include"
$Lib = Join-Path $GgmlRoot "lib"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Test-Command {
	param([string]$Name)
	$null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-CheckedNative {
	param(
		[string]$Step,
		[scriptblock]$Command
	)
	& $Command
	if ($LASTEXITCODE -ne 0) {
		throw "$Step failed with exit code $LASTEXITCODE"
	}
}

function Convert-ToCmdArgument {
	param([string]$Value)
	return '"' + ($Value -replace '"', '""') + '"'
}

function Invoke-CMake {
	param(
		[string]$Step,
		[string[]]$Arguments
	)

	if ($script:VsDevCmd) {
		$quotedArgs = $Arguments | ForEach-Object { Convert-ToCmdArgument $_ }
		$command = "call $(Convert-ToCmdArgument $script:VsDevCmd) -arch=x64 -host_arch=x64 >nul && cmake $($quotedArgs -join ' ')"
		& cmd.exe /d /s /c $command
		if ($LASTEXITCODE -ne 0) {
			throw "$Step failed with exit code $LASTEXITCODE"
		}
		return
	}

	Invoke-CheckedNative $Step { cmake @Arguments }
}

function Clear-DirectoryContents {
	param([string]$Path)
	if (!(Test-Path -LiteralPath $Path)) {
		return
	}
	Get-ChildItem -LiteralPath $Path -Force |
		Where-Object { $_.Name -ne ".gitkeep" } |
		Remove-Item -Recurse -Force
}

function Ensure-GitKeep {
	param([string]$Path)
	if (!(Test-Path -LiteralPath $Path)) {
		Set-Content -LiteralPath $Path -Value ""
	}
}

function Test-CMakeGenerator {
	param([string]$Generator)
	$help = & cmake --help 2>$null
	return ($help -join "`n") -match [regex]::Escape($Generator)
}

function Get-VisualStudioDevCmd {
	$candidates = New-Object System.Collections.Generic.List[string]
	$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
	if (Test-Path -LiteralPath $vswhere) {
		$installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
		if ($installPath) {
			$candidates.Add((Join-Path $installPath "Common7\Tools\VsDevCmd.bat"))
		}
	}

	$editions = @("Community", "Professional", "Enterprise", "BuildTools")
	foreach ($version in @("18", "17", "16")) {
		foreach ($edition in $editions) {
			$candidates.Add("C:\Program Files\Microsoft Visual Studio\$version\$edition\Common7\Tools\VsDevCmd.bat")
			$candidates.Add("C:\Program Files (x86)\Microsoft Visual Studio\$version\$edition\Common7\Tools\VsDevCmd.bat")
		}
	}

	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate) {
			return $candidate
		}
	}
	return $null
}

function Test-NinjaGenerator {
	return (Test-Command "ninja") -and (Test-CMakeGenerator "Ninja")
}

function Get-VisualStudioGenerator {
	$generators = @(
		"Visual Studio 18 2026",
		"Visual Studio 17 2022",
		"Visual Studio 16 2019"
	)
	foreach ($generator in $generators) {
		if (Test-CMakeGenerator $generator) {
			return $generator
		}
	}
	return $null
}

function Get-WindowsNativeCMakeGenerator {
	param([string]$VsDevCmd)
	if (!$VsDevCmd) {
		return $null
	}
	if (Test-NinjaGenerator) {
		return "Ninja"
	}
	if (Test-CMakeGenerator "NMake Makefiles") {
		return "NMake Makefiles"
	}
	return $null
}

function Initialize-WindowsBuildEnvironment {
	if ($IsLinux -or $IsMacOS) {
		return
	}

	$script:VsDevCmd = Get-VisualStudioDevCmd
	if (!$script:VsDevCmd) {
		throw "Visual Studio C++ build tools were not found. Install Visual Studio with Desktop development with C++."
	}

	$script:WindowsVisualStudioGenerator = Get-VisualStudioGenerator
	$script:WindowsNativeCMakeGenerator = Get-WindowsNativeCMakeGenerator $script:VsDevCmd
	if (!$script:WindowsVisualStudioGenerator -and !$script:WindowsNativeCMakeGenerator) {
		throw "No supported Windows CMake generator was found."
	}
}

function Test-WindowsNativeCompilerAvailable {
	if ($IsLinux -or $IsMacOS) {
		return $true
	}
	if (!$script:VsDevCmd) {
		return $false
	}
	$command = "call $(Convert-ToCmdArgument $script:VsDevCmd) -arch=x64 -host_arch=x64 >nul && where cl >nul"
	& cmd.exe /d /s /c $command
	return ($LASTEXITCODE -eq 0)
}

function Test-SourceRevisionMatches {
	param(
		[string]$Path,
		[string]$Revision
	)
	if (!(Test-Path -LiteralPath $Path)) {
		return $false
	}

	$tag = git -C $Path describe --tags --exact-match HEAD 2>$null
	if ($LASTEXITCODE -eq 0 -and $tag -eq $Revision) {
		return $true
	}

	$commit = git -C $Path rev-parse HEAD 2>$null
	if ($LASTEXITCODE -eq 0 -and $commit.StartsWith($Revision, [System.StringComparison]::OrdinalIgnoreCase)) {
		return $true
	}

	return $false
}

$script:VsDevCmd = $null
$script:WindowsVisualStudioGenerator = $null
$script:WindowsNativeCMakeGenerator = $null

Initialize-WindowsBuildEnvironment

function Test-CudaAvailable {
	if ($env:CUDA_PATH -and (Test-Path (Join-Path $env:CUDA_PATH "bin\nvcc.exe"))) {
		return $true
	}
	return Test-Command "nvcc"
}

function Test-CudaLinkLibrariesAvailable {
	if (!$env:CUDA_PATH) {
		return $false
	}
	$libDir = Join-Path $env:CUDA_PATH "lib\x64"
	return (Test-Path (Join-Path $libDir "cublas.lib")) -and
		(Test-Path (Join-Path $libDir "cudart.lib")) -and
		(Test-Path (Join-Path $libDir "cuda.lib"))
}

function Test-CudaBuildAvailable {
	if (!(Test-CudaAvailable)) {
		return $false
	}
	if (!$IsLinux -and !$IsMacOS) {
		return Test-CudaLinkLibrariesAvailable
	}
	return $true
}

function Test-VulkanAvailable {
	if ($env:VULKAN_SDK -and (Test-Path (Join-Path $env:VULKAN_SDK "Lib\vulkan-1.lib"))) {
		return $true
	}
	if (!$IsLinux -and !$IsMacOS) {
		return $false
	}
	return (Test-Command "glslc")
}

function Test-OpenCLAvailable {
	$knownRoots = @(
		$env:OPENCL_ROOT,
		$env:OpenCL_ROOT,
		$env:OCL_ROOT,
		$env:INTELOCLSDKROOT,
		$env:AMDAPPSDKROOT,
		$env:CUDA_PATH
	) | Where-Object { $_ }

	foreach ($root in $knownRoots) {
		$includePath = Join-Path $root (Join-Path "include" (Join-Path "CL" "cl.h"))
		$windowsIncludePath = Join-Path $root (Join-Path "Include" (Join-Path "CL" "cl.h"))
		if ((Test-Path $includePath) -or (Test-Path $windowsIncludePath)) {
			return $true
		}
	}

	if (Test-Command "pkg-config") {
		pkg-config --exists OpenCL 2>$null
		return ($LASTEXITCODE -eq 0)
	}

	return $false
}

function Assert-RequestedBackendsAvailable {
	param(
		[bool]$RequireCuda,
		[bool]$RequireVulkan,
		[bool]$RequireMetal,
		[bool]$RequireOpenCL
	)

	if ($RequireCuda -and !(Test-CudaAvailable)) {
		throw "CUDA was requested, but CUDA was not found. Install the NVIDIA CUDA Toolkit or use -Auto/-CpuOnly."
	}
	if (($RequireCuda -or $RequireVulkan -or $RequireOpenCL) -and !(Test-WindowsNativeCompilerAvailable)) {
		throw "A native Visual Studio compiler environment is required for requested Windows backends."
	}
	if ($RequireCuda -and !$IsLinux -and !$IsMacOS -and !(Test-CudaLinkLibrariesAvailable)) {
		throw "CUDA was requested, but CUDA link libraries were not found under CUDA_PATH. Install the NVIDIA CUDA Toolkit or use -Auto/-CpuOnly."
	}
	if ($RequireVulkan -and !(Test-VulkanAvailable)) {
		throw "Vulkan was requested, but Vulkan SDK/tools were not found. Install the Vulkan SDK or use -Auto/-CpuOnly."
	}
	if ($RequireMetal -and !$IsMacOS) {
		throw "Metal was requested, but Metal builds are only supported on macOS."
	}
	if ($RequireOpenCL -and !(Test-OpenCLAvailable)) {
		throw "OpenCL was requested, but OpenCL headers/tools were not found. Install an OpenCL SDK or use -Auto/-CpuOnly."
	}
}

function Get-PlatformSection {
	if ($IsMacOS) {
		return @{ Section = "osx"; Extension = ".a" }
	}
	if ($IsLinux) {
		return @{ Section = "linux64"; Extension = ".a" }
	}
	return @{ Section = "vs"; Extension = ".lib" }
}

function Convert-ToAddonPath {
	param([string]$Path)
	$relative = Resolve-Path -LiteralPath $Path -Relative
	if ($relative.StartsWith(".\")) {
		$relative = $relative.Substring(2)
	}
	return ($relative -replace "\\", "/")
}

function Update-AddonConfig {
	$configPath = Join-Path $Root "addon_config.mk"
	if (!(Test-Path -LiteralPath $configPath)) {
		Write-Step "addon_config.mk not found; skipping library update"
		return
	}

	$platform = Get-PlatformSection
	$section = $platform.Section
	$extension = $platform.Extension
	$startMarker = "# @OFXGGML_LIBS_START $section"
	$endMarker = "# @OFXGGML_LIBS_END $section"

	$order = @(
		"ggml$extension",
		"libggml$extension",
		"ggml-base$extension",
		"libggml-base$extension",
		"ggml-cpu$extension",
		"libggml-cpu$extension",
		"ggml-cuda$extension",
		"libggml-cuda$extension",
		"ggml-vulkan$extension",
		"libggml-vulkan$extension",
		"ggml-metal$extension",
		"libggml-metal$extension",
		"ggml-opencl$extension",
		"libggml-opencl$extension",
		"ggml-sycl$extension",
		"libggml-sycl$extension"
	)

	$found = @{}
	Get-ChildItem -LiteralPath $Lib -Recurse -File -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -like "ggml*$extension" -or $_.Name -like "libggml*$extension" } |
		ForEach-Object {
			if (!$found.ContainsKey($_.Name)) {
				$found[$_.Name] = $_.FullName
			}
		}

	$orderedPaths = New-Object System.Collections.Generic.List[string]
	foreach ($name in $order) {
		if ($found.ContainsKey($name)) {
			$orderedPaths.Add($found[$name])
			$found.Remove($name)
		}
	}
	foreach ($name in ($found.Keys | Sort-Object)) {
		$orderedPaths.Add($found[$name])
	}

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("`t$startMarker")
	foreach ($path in $orderedPaths) {
		$lines.Add("`tADDON_LIBS += $(Convert-ToAddonPath $path)")
	}

	if ($section -eq "vs") {
		if (($orderedPaths | Where-Object { (Split-Path $_ -Leaf) -eq "ggml-cuda.lib" }) -and $env:CUDA_PATH) {
			$lines.Add("`tADDON_LIBS += `$`(CUDA_PATH`)/lib/x64/cublas.lib")
			$lines.Add("`tADDON_LIBS += `$`(CUDA_PATH`)/lib/x64/cudart.lib")
			$lines.Add("`tADDON_LIBS += `$`(CUDA_PATH`)/lib/x64/cuda.lib")
		}
		if (($orderedPaths | Where-Object { (Split-Path $_ -Leaf) -eq "ggml-vulkan.lib" }) -and $env:VULKAN_SDK) {
			$lines.Add("`tADDON_LIBS += `$`(VULKAN_SDK`)/Lib/vulkan-1.lib")
		}
	}

	$lines.Add("`t$endMarker")

	$content = Get-Content -LiteralPath $configPath
	$output = New-Object System.Collections.Generic.List[string]
	$inside = $false
	$replaced = $false
	foreach ($line in $content) {
		if ($line.Contains($startMarker)) {
			foreach ($replacement in $lines) {
				$output.Add($replacement)
			}
			$inside = $true
			$replaced = $true
			continue
		}
		if ($inside -and $line.Contains($endMarker)) {
			$inside = $false
			continue
		}
		if (!$inside) {
			$output.Add($line)
		}
	}

	if (!$replaced) {
		Write-Step "Markers for $section were not found in addon_config.mk"
		return
	}

	Set-Content -LiteralPath $configPath -Value $output
	Write-Step "Updated addon_config.mk [$section] with $($orderedPaths.Count) ggml libraries"
}

if ($Jobs -le 0) {
	$Jobs = [Math]::Max(1, [Environment]::ProcessorCount)
}

if ($CpuOnly -and ($Cuda -or $Vulkan -or $Metal -or $OpenCL -or $AllBackends)) {
	throw "-CpuOnly cannot be combined with backend switches"
}

if ($WithDebug -and !$IsLinux -and !$IsMacOS) {
	throw "-WithDebug is not supported by the Windows single-config setup path yet"
}

$explicitBackendRequested = $CpuOnly -or $Cuda -or $Vulkan -or $Metal -or $OpenCL -or $AllBackends
$autoRequested = $Auto -or !$explicitBackendRequested
$requireCuda = $Cuda -or $AllBackends
$requireVulkan = $Vulkan -or $AllBackends
$requireMetal = $Metal -or ($AllBackends -and $IsMacOS)
$requireOpenCL = $OpenCL -or $AllBackends

if ($AllBackends) {
	$Cuda = $true
	$Vulkan = $true
	$OpenCL = $true
	if ($IsMacOS) {
		$Metal = $true
	}
}

Assert-RequestedBackendsAvailable `
	-RequireCuda $requireCuda `
	-RequireVulkan $requireVulkan `
	-RequireMetal $requireMetal `
	-RequireOpenCL $requireOpenCL

if ($autoRequested -and !$CpuOnly) {
	if (Test-CudaBuildAvailable) {
		$Cuda = $true
	}
	if (Test-VulkanAvailable) {
		$Vulkan = $true
	}
	if ($IsMacOS) {
		$Metal = $true
	}
}

New-Item -ItemType Directory -Path $GgmlRoot,$Include,$Lib -Force | Out-Null

if ($Clean) {
	Write-Step "Cleaning source, build, include, and lib outputs"
	Remove-Item -LiteralPath $Source,$Build -Recurse -Force -ErrorAction SilentlyContinue
	Clear-DirectoryContents $Include
	Clear-DirectoryContents $Lib
}

if (!(Test-Path -LiteralPath $Source)) {
	Write-Step "Cloning ggml $Revision"
	Invoke-CheckedNative "git clone ggml" { git clone --depth 1 --branch $Revision $Repo $Source }
} elseif (Test-SourceRevisionMatches $Source $Revision) {
	Write-Step "ggml source already at $Revision; skipping fetch"
} else {
	Write-Step "Fetching ggml $Revision"
	Invoke-CheckedNative "git fetch ggml" { git -C $Source fetch --depth 1 origin $Revision }
	Invoke-CheckedNative "git checkout ggml" { git -C $Source checkout --detach FETCH_HEAD }
}

$commit = git -C $Source rev-parse --short HEAD
if ($LASTEXITCODE -ne 0) {
	throw "git rev-parse ggml failed with exit code $LASTEXITCODE"
}
Write-Step "Using ggml commit $commit"

function Get-WindowsNativeGeneratorArgs {
	if ($script:WindowsNativeCMakeGenerator) {
		return @("-G", $script:WindowsNativeCMakeGenerator)
	}
	if ($script:WindowsVisualStudioGenerator) {
		return @("-G", $script:WindowsVisualStudioGenerator, "-A", "x64")
	}
	throw "No Windows CMake generator is available."
}

function Get-WindowsCudaGeneratorArgs {
	if (!$script:WindowsVisualStudioGenerator) {
		throw "CUDA builds on Windows require a Visual Studio CMake generator."
	}
	if (!$env:CUDA_PATH) {
		throw "CUDA builds on Windows require CUDA_PATH."
	}
	return @("-G", $script:WindowsVisualStudioGenerator, "-A", "x64", "-T", "host=x64,cuda=$env:CUDA_PATH")
}

function Get-PreparedBuildDirectory {
	param([string]$PreferredPath)

	if (!(Test-Path -LiteralPath $PreferredPath)) {
		return $PreferredPath
	}

	try {
		Remove-Item -LiteralPath $PreferredPath -Recurse -Force -ErrorAction Stop
		return $PreferredPath
	} catch {
		$fallback = "$PreferredPath-$(Get-Date -Format 'yyyyMMddHHmmss')"
		Write-Step "Build directory is locked; using fresh build directory $fallback"
		return $fallback
	}
}

function New-GgmlConfigureArgs {
	param(
		[string]$BuildDir,
		[bool]$EnableCuda,
		[bool]$EnableVulkan,
		[bool]$EnableMetal,
		[bool]$EnableOpenCL
	)

	$args = @(
		"-S", $Source,
		"-B", $BuildDir,
		"-DBUILD_SHARED_LIBS=OFF",
		"-DGGML_BUILD_TESTS=OFF",
		"-DGGML_BUILD_EXAMPLES=OFF",
		"-DGGML_NATIVE=ON",
		"-DGGML_STATIC=ON",
		"-DGGML_BACKEND_DL=OFF",
		"-DCMAKE_BUILD_TYPE=Release",
		"-DCMAKE_C_FLAGS=-DGGML_MAX_NAME=128",
		"-DCMAKE_CXX_FLAGS=-DGGML_MAX_NAME=128",
		"-DCMAKE_CUDA_FLAGS=-DGGML_MAX_NAME=128",
		"-DGGML_CUDA=$(if ($EnableCuda) { 'ON' } else { 'OFF' })",
		"-DGGML_CUDA_NCCL=OFF",
		"-DGGML_VULKAN=$(if ($EnableVulkan) { 'ON' } else { 'OFF' })",
		"-DGGML_METAL=$(if ($EnableMetal) { 'ON' } else { 'OFF' })",
		"-DGGML_OPENCL=$(if ($EnableOpenCL) { 'ON' } else { 'OFF' })"
	)
	if ($EnableCuda -and $env:CUDA_PATH) {
		$args += "-DCUDAToolkit_ROOT=$env:CUDA_PATH"
	}
	return $args
}

function Invoke-GgmlCMakeBuild {
	param(
		[string]$BuildDir,
		[string]$Label,
		[bool]$EnableCuda,
		[bool]$EnableVulkan,
		[bool]$EnableMetal,
		[bool]$EnableOpenCL,
		[string[]]$GeneratorArgs
	)

	$configureArgs = $GeneratorArgs + (New-GgmlConfigureArgs `
		-BuildDir $BuildDir `
		-EnableCuda $EnableCuda `
		-EnableVulkan $EnableVulkan `
		-EnableMetal $EnableMetal `
		-EnableOpenCL $EnableOpenCL)

	if ($GeneratorArgs.Count -gt 0) {
		Write-Step "Using CMake generator args for $($Label): $($GeneratorArgs -join ' ')"
	}
	Write-Step "Configuring $($Label): CPU=ON CUDA=$(if ($EnableCuda) { 'ON' } else { 'OFF' }) Vulkan=$(if ($EnableVulkan) { 'ON' } else { 'OFF' }) Metal=$(if ($EnableMetal) { 'ON' } else { 'OFF' }) OpenCL=$(if ($EnableOpenCL) { 'ON' } else { 'OFF' })"
	Invoke-CMake "cmake configure $Label" $configureArgs

	Write-Step "Building $Label Release with $Jobs jobs"
	$releaseBuildArgs = @("--build", $BuildDir, "--config", "Release", "--parallel", $Jobs.ToString())
	Invoke-CMake "cmake build $Label Release" $releaseBuildArgs

	if ($WithDebug) {
		Write-Step "Building $Label Debug with $Jobs jobs"
		$debugBuildArgs = @("--build", $BuildDir, "--config", "Debug", "--parallel", $Jobs.ToString())
		Invoke-CMake "cmake build $Label Debug" $debugBuildArgs
	}
}

$buildOutputDirs = New-Object System.Collections.Generic.List[string]

if (!$IsLinux -and !$IsMacOS -and $Cuda -and ($Vulkan -or $OpenCL)) {
	$cudaBuild = Get-PreparedBuildDirectory (Join-Path $GgmlRoot "build-cuda")
	$buildOutputDirs.Add($cudaBuild)
	Invoke-GgmlCMakeBuild `
		-BuildDir $cudaBuild `
		-Label "ggml CUDA" `
		-EnableCuda $true `
		-EnableVulkan $false `
		-EnableMetal $false `
		-EnableOpenCL $false `
		-GeneratorArgs (Get-WindowsCudaGeneratorArgs)

	$nativeBuild = Get-PreparedBuildDirectory (Join-Path $GgmlRoot "build-native")
	$buildOutputDirs.Add($nativeBuild)
	Invoke-GgmlCMakeBuild `
		-BuildDir $nativeBuild `
		-Label "ggml native backends" `
		-EnableCuda $false `
		-EnableVulkan $Vulkan `
		-EnableMetal $false `
		-EnableOpenCL $OpenCL `
		-GeneratorArgs (Get-WindowsNativeGeneratorArgs)
} else {
	$generatorArgs = @()
	if (!$IsLinux -and !$IsMacOS) {
		if ($Cuda) {
			$generatorArgs = Get-WindowsCudaGeneratorArgs
		} else {
			$generatorArgs = Get-WindowsNativeGeneratorArgs
		}
	}
	$singleBuild = Get-PreparedBuildDirectory $Build
	$buildOutputDirs.Add($singleBuild)
	Invoke-GgmlCMakeBuild `
		-BuildDir $singleBuild `
		-Label "ggml" `
		-EnableCuda $Cuda `
		-EnableVulkan $Vulkan `
		-EnableMetal $Metal `
		-EnableOpenCL $OpenCL `
		-GeneratorArgs $generatorArgs
}

Write-Step "Exporting headers and libraries"
Clear-DirectoryContents $Include
Clear-DirectoryContents $Lib

Copy-Item -Path (Join-Path $Source "include\*") -Destination $Include -Recurse -Force
Ensure-GitKeep (Join-Path $Include ".gitkeep")

$libraryPatterns = @("ggml*.lib", "libggml*.a", "libggml*.dylib")
foreach ($pattern in $libraryPatterns) {
	foreach ($buildDir in $buildOutputDirs) {
		Get-ChildItem -LiteralPath $buildDir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
			Where-Object { $_.FullName -notmatch "\\Debug\\" } |
			Sort-Object Name |
			ForEach-Object {
				$destination = Join-Path $Lib $_.Name
				if (!(Test-Path -LiteralPath $destination)) {
					Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
				}
			}
	}
}

if ($WithDebug) {
	$releaseDir = Join-Path $Lib "Release"
	$debugDir = Join-Path $Lib "Debug"
	New-Item -ItemType Directory -Path $releaseDir,$debugDir -Force | Out-Null
	Get-ChildItem -LiteralPath $Lib -File |
		Where-Object { $_.Name -like "ggml*.lib" -or $_.Name -like "libggml*.a" } |
		ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $releaseDir $_.Name) -Force }
	foreach ($pattern in $libraryPatterns) {
		foreach ($buildDir in $buildOutputDirs) {
			Get-ChildItem -LiteralPath $buildDir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
				Where-Object { $_.FullName -match "\\Debug\\" } |
				Sort-Object Name |
				ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $debugDir $_.Name) -Force }
		}
	}
}

Ensure-GitKeep (Join-Path $Lib ".gitkeep")

Update-AddonConfig

Write-Step "Done. ggml $Revision installed under $GgmlRoot"
