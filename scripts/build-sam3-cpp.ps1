param(
    [switch] $Cuda,
    [switch] $CpuOnly,
    [string] $Configuration = "Release",
    [string] $CudaArchitectures = "",
    [switch] $SkipExamples
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [string] $Description,
        [scriptblock] $Script
    )
    Write-Host "==> $Description"
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Get-CMakeGenerator {
    $help = & cmake --help
    foreach ($candidate in @("Visual Studio 18 2026", "Visual Studio 17 2022", "Visual Studio 16 2019")) {
        if ($help -match [regex]::Escape($candidate)) {
            return $candidate
        }
    }
    return ""
}

function Get-CudaRoot {
    foreach ($candidate in @($env:CUDA_PATH, $env:CUDAToolkit_ROOT)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and
            (Test-Path (Join-Path $candidate "bin\nvcc.exe"))) {
            return $candidate
        }
    }
    $nvcc = Get-Command nvcc.exe -ErrorAction SilentlyContinue
    if ($nvcc) {
        return (Resolve-Path (Join-Path (Split-Path -Parent $nvcc.Source) "..")).Path
    }
    return ""
}

function Test-CudaVsIntegration {
    param([string] $CudaRoot)
    $msbuildExt = Join-Path $CudaRoot "extras\visual_studio_integration\MSBuildExtensions"
    return (Test-Path (Join-Path $msbuildExt "CUDA *.props")) -and
        (Test-Path (Join-Path $msbuildExt "CUDA *.targets"))
}

if ($Cuda -and $CpuOnly) {
    throw "Use either -Cuda or -CpuOnly, not both."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptDir "..")
$sourceDir = Join-Path $addonRoot "libs\sam3.cpp"

if (-not (Test-Path (Join-Path $sourceDir "sam3.cpp"))) {
    & (Join-Path $scriptDir "install-sam3-cpp.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "install-sam3-cpp.ps1 failed with exit code $LASTEXITCODE."
    }
}

$enableCuda = $Cuda.IsPresent
if (-not $Cuda -and -not $CpuOnly) {
    $enableCuda = -not [string]::IsNullOrWhiteSpace((Get-CudaRoot))
}

$generator = Get-CMakeGenerator
if ([string]::IsNullOrWhiteSpace($generator)) {
    throw "No supported Visual Studio CMake generator was found."
}

$buildDirName = if ($enableCuda) { "build-cuda" } else { "build-cpu" }
$buildDir = Join-Path $sourceDir $buildDirName
$cmakeArgs = @(
    "-S", $sourceDir,
    "-B", $buildDir,
    "-G", $generator,
    "-A", "x64",
    "-DBUILD_SHARED_LIBS=OFF",
    "-DSAM3_BUILD_EXAMPLES=$(-not $SkipExamples)",
    "-DSAM3_BUILD_TESTS=OFF",
    "-DGGML_CUDA=$enableCuda"
)

if ($enableCuda) {
    $cudaRoot = Get-CudaRoot
    if ([string]::IsNullOrWhiteSpace($cudaRoot)) {
        throw "CUDA was requested but nvcc.exe was not found."
    }
    if (-not (Test-CudaVsIntegration -CudaRoot $cudaRoot)) {
        throw "CUDA was requested but Visual Studio CUDA integration files were not found under $cudaRoot."
    }
    $cmakeArgs += @("-T", "host=x64,cuda=$cudaRoot")
    if (-not [string]::IsNullOrWhiteSpace($CudaArchitectures)) {
        $cmakeArgs += "-DCMAKE_CUDA_ARCHITECTURES=$CudaArchitectures"
    }
}

Invoke-Step "Configuring sam3.cpp ($buildDirName)" {
    cmake @cmakeArgs
}
Invoke-Step "Building sam3.cpp ($Configuration)" {
    cmake --build $buildDir --config $Configuration --parallel
}

Write-Host "==> sam3.cpp build complete."
Write-Host "Build: $buildDir"
Write-Host "CUDA:  $enableCuda"
