param(
    [string]$Branch = "master",
    [string]$SourceDir = "",
    [string]$BuildDir = "",
    [string]$InstallDir = "",
    [int]$Jobs = 0,
    [switch]$Cuda,
    [switch]$CpuOnly,
    [switch]$Refetch,
    [switch]$Clean,
    [switch]$KeepArtifacts,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message"
}

function Get-CommandPathOrNull {
    param([string]$Name)
    try {
        return (Get-Command $Name -ErrorAction Stop).Source
    } catch {
        return $null
    }
}

function Invoke-NativeCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$Description
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Find-BuiltExecutable {
    param(
        [string]$BuildDir,
        [string]$FileName
    )

    $preferredPath = Join-Path (Join-Path $BuildDir 'bin\Release') $FileName
    if (Test-Path -LiteralPath $preferredPath) {
        return $preferredPath
    }

    $match = Get-ChildItem -LiteralPath $BuildDir -Recurse -Filter $FileName -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\Release\\' } |
        Select-Object -First 1
    if ($match) {
        return $match.FullName
    }

    $match = Get-ChildItem -LiteralPath $BuildDir -Recurse -Filter $FileName -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($match) {
        return $match.FullName
    }

    return $null
}

function Resolve-VisualStudioAsmCompiler {
    $preferredRoots = @(
        'C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Tools\MSVC',
        'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC',
        'C:\Program Files\Microsoft Visual Studio\17\Professional\VC\Tools\MSVC',
        'C:\Program Files\Microsoft Visual Studio\17\Community\VC\Tools\MSVC'
    )

    foreach ($root in $preferredRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }
        $versions = Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending
        foreach ($version in $versions) {
            $candidate = Join-Path $version.FullName 'bin\Hostx64\x64\ml64.exe'
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }

    return $null
}

function Test-CudaAvailable {
    if ($CpuOnly) {
        return $false
    }
    if ($Cuda) {
        return $true
    }
    if ($env:CUDA_PATH -and (Test-Path -LiteralPath $env:CUDA_PATH)) {
        return $true
    }
    if (Get-CommandPathOrNull 'nvcc.exe') {
        return $true
    }
    if (Get-CommandPathOrNull 'nvidia-smi.exe') {
        return $true
    }
    return $false
}

function Resolve-CudaToolkitRoot {
    if ($env:CUDA_PATH -and (Test-Path -LiteralPath $env:CUDA_PATH)) {
        $nvcc = Join-Path $env:CUDA_PATH 'bin\nvcc.exe'
        $msbuildExtensions = Join-Path $env:CUDA_PATH 'extras\visual_studio_integration\MSBuildExtensions'
        $cudaProps = Get-ChildItem -LiteralPath $msbuildExtensions -Filter 'CUDA *.props' -ErrorAction SilentlyContinue | Select-Object -First 1
        $cudaTargets = Get-ChildItem -LiteralPath $msbuildExtensions -Filter 'CUDA *.targets' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ((Test-Path -LiteralPath $nvcc) -and $cudaProps -and $cudaTargets) {
            return $env:CUDA_PATH
        }
    }

    $nvccCommand = Get-CommandPathOrNull 'nvcc.exe'
    if ($nvccCommand) {
        $candidate = Split-Path -Parent (Split-Path -Parent $nvccCommand)
        $msbuildExtensions = Join-Path $candidate 'extras\visual_studio_integration\MSBuildExtensions'
        $cudaProps = Get-ChildItem -LiteralPath $msbuildExtensions -Filter 'CUDA *.props' -ErrorAction SilentlyContinue | Select-Object -First 1
        $cudaTargets = Get-ChildItem -LiteralPath $msbuildExtensions -Filter 'CUDA *.targets' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cudaProps -and $cudaTargets) {
            return $candidate
        }
    }

    return $null
}

function Get-DefaultRuntimeRoot {
    param([string]$AddonRoot)

    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if (-not [string]::IsNullOrWhiteSpace($localAppData)) {
        return (Join-Path $localAppData 'ofxGgml\llama-runtime')
    }
    return (Join-Path $AddonRoot '.runtime\llama-runtime')
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = (Resolve-Path (Join-Path $scriptRoot '..')).Path
$defaultRuntimeRoot = Get-DefaultRuntimeRoot -AddonRoot $addonRoot

if ([string]::IsNullOrWhiteSpace($SourceDir)) {
    $SourceDir = Join-Path $defaultRuntimeRoot 'source'
}
if ([string]::IsNullOrWhiteSpace($BuildDir)) {
    $BuildDir = Join-Path $defaultRuntimeRoot 'build'
}
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = Join-Path $addonRoot 'libs\llama\bin'
}
if ($Jobs -le 0) {
    $Jobs = [Math]::Max(1, [Environment]::ProcessorCount)
}

$git = Get-CommandPathOrNull 'git.exe'
$cmake = Get-CommandPathOrNull 'cmake.exe'
if (-not $git) {
    throw "git.exe was not found in PATH."
}
if (-not $cmake) {
    throw "cmake.exe was not found in PATH."
}

$useCuda = Test-CudaAvailable
$cudaToolkitRoot = $null
$asmCompiler = $null
if ($useCuda) {
    $asmCompiler = Resolve-VisualStudioAsmCompiler
    if (-not $asmCompiler) {
        throw "CUDA build requested or detected, but ml64.exe was not found. Open a Visual Studio developer shell or install MSVC build tools."
    }
    $cudaToolkitRoot = Resolve-CudaToolkitRoot
    if (-not $cudaToolkitRoot) {
        if ($Cuda) {
            throw "CUDA build requested, but CUDA Visual Studio integration files were not found. Install CUDA with Visual Studio Integration, or rerun with -CpuOnly."
        }
        Write-Warning "CUDA was detected, but CUDA Visual Studio integration files were not found. Building llama.cpp CPU-only. Rerun with -Cuda to require CUDA."
        $useCuda = $false
        $asmCompiler = $null
    }
}

Write-Step "Preparing llama.cpp source"
if ($Clean) {
    if (Test-Path -LiteralPath $BuildDir) {
        Remove-Item -LiteralPath $BuildDir -Recurse -Force
    }
}

if ($Refetch -and (Test-Path -LiteralPath $SourceDir)) {
    Remove-Item -LiteralPath $SourceDir -Recurse -Force
}

if (-not (Test-Path -LiteralPath $SourceDir)) {
    $cloneArgs = @('clone', '--depth', '1', '--branch', $Branch, 'https://github.com/ggml-org/llama.cpp.git', $SourceDir)
    Write-Step "Cloning llama.cpp ($Branch)"
    if ($DryRun) {
        Write-Host "$git $($cloneArgs -join ' ')"
    } else {
        Invoke-NativeCommand $git $cloneArgs "git clone llama.cpp"
    }
} else {
    Write-Step "Using existing llama.cpp source at $SourceDir"
    $fetchArgs = @('-C', $SourceDir, 'fetch', 'origin', $Branch, '--depth', '1')
    $statusArgs = @('-C', $SourceDir, 'status', '--porcelain')
    $checkoutArgs = @('-C', $SourceDir, 'checkout', '--detach', 'FETCH_HEAD')
    if ($DryRun) {
        Write-Host "$git $($fetchArgs -join ' ')"
        Write-Host "$git $($statusArgs -join ' ')"
        Write-Host "$git $($checkoutArgs -join ' ')"
    } else {
        Invoke-NativeCommand $git $fetchArgs "git fetch llama.cpp"
        $sourceStatus = & $git @statusArgs
        if ($LASTEXITCODE -ne 0) {
            throw "git status llama.cpp failed with exit code $LASTEXITCODE."
        }
        if ($sourceStatus) {
            throw "Existing llama.cpp source has local changes at $SourceDir. Commit/stash them, or rerun with -Refetch to discard the cached source."
        }
        Invoke-NativeCommand $git $checkoutArgs "git checkout llama.cpp fetched ref"
    }
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$configureArgs = @(
    '-S', $SourceDir,
    '-B', $BuildDir,
    '-A', 'x64',
    '-DLLAMA_BUILD_SERVER=ON',
    '-DLLAMA_BUILD_TOOLS=ON',
    '-DLLAMA_BUILD_TESTS=OFF',
    '-DLLAMA_BUILD_EXAMPLES=ON',
    '-DLLAMA_CURL=OFF',
    '-DGGML_VULKAN=OFF'
)
if ($useCuda) {
    $configureArgs += @(
        '-T', "host=x64,cuda=$cudaToolkitRoot",
        '-DGGML_CUDA=ON',
        "-DCMAKE_ASM_COMPILER=$asmCompiler"
    )
} else {
    $configureArgs += '-DGGML_CUDA=OFF'
}

Write-Step ("Configuring llama.cpp for " + ($(if ($useCuda) { 'CUDA' } else { 'CPU-only' })) + " text runtime build")
if ($DryRun) {
    Write-Host "$cmake $($configureArgs -join ' ')"
} else {
    Invoke-NativeCommand $cmake $configureArgs "CMake configure"
}

$requiredTargets = @('llama-server', 'llama-completion', 'llama-cli')
$optionalTargets = @('llama-embedding')

foreach ($target in $requiredTargets) {
    $buildArgs = @(
        '--build', $BuildDir,
        '--config', 'Release',
        '--target', $target,
        '--parallel', $Jobs
    )

    Write-Step "Building $target"
    if ($DryRun) {
        Write-Host "$cmake $($buildArgs -join ' ')"
    } else {
        Invoke-NativeCommand $cmake $buildArgs "CMake build $target"
    }
}

foreach ($target in $optionalTargets) {
    $buildArgs = @(
        '--build', $BuildDir,
        '--config', 'Release',
        '--target', $target,
        '--parallel', $Jobs
    )

    Write-Step "Building optional $target"
    if ($DryRun) {
        Write-Host "$cmake $($buildArgs -join ' ')"
    } else {
        try {
            Invoke-NativeCommand $cmake $buildArgs "CMake build optional $target"
        } catch {
            Write-Warning "$target is unavailable in this llama.cpp checkout; continuing without it."
        }
    }
}

$releaseBinDir = Join-Path $BuildDir 'bin\Release'
$serverExe = Find-BuiltExecutable $BuildDir 'llama-server.exe'
$completionExe = Find-BuiltExecutable $BuildDir 'llama-completion.exe'
$cliExe = Find-BuiltExecutable $BuildDir 'llama-cli.exe'
$embeddingExe = Find-BuiltExecutable $BuildDir 'llama-embedding.exe'
if (-not $DryRun) {
    $requiredExecutables = @(
        @{ Name = 'llama-server.exe'; Path = $serverExe },
        @{ Name = 'llama-completion.exe'; Path = $completionExe },
        @{ Name = 'llama-cli.exe'; Path = $cliExe }
    )
    foreach ($exe in $requiredExecutables) {
        if ([string]::IsNullOrWhiteSpace($exe.Path) -or -not (Test-Path -LiteralPath $exe.Path)) {
            throw "Build finished but $($exe.Name) was not found under $BuildDir"
        }
    }
}

Write-Step "Installing llama.cpp runtime into $InstallDir"
if ($DryRun) {
    Write-Host "Copy $serverExe -> $InstallDir"
    Write-Host "Copy $completionExe -> $InstallDir"
    Write-Host "Copy $cliExe -> $InstallDir"
    Write-Host "Copy $embeddingExe -> $InstallDir (if present)"
    Write-Host "Copy DLLs from $releaseBinDir -> $InstallDir"
} else {
    Copy-Item -LiteralPath $serverExe -Destination $InstallDir -Force
    Copy-Item -LiteralPath $completionExe -Destination $InstallDir -Force
    Copy-Item -LiteralPath $cliExe -Destination $InstallDir -Force
    if (-not [string]::IsNullOrWhiteSpace($embeddingExe) -and (Test-Path -LiteralPath $embeddingExe)) {
        Copy-Item -LiteralPath $embeddingExe -Destination $InstallDir -Force
    }
    $dllSearchRoot = if (Test-Path -LiteralPath $releaseBinDir) { $releaseBinDir } else { $BuildDir }
    Get-ChildItem -LiteralPath $dllSearchRoot -Recurse -Filter '*.dll' -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $InstallDir -Force
    }

    if (-not $KeepArtifacts) {
        Write-Step "Pruning llama.cpp source/build artifacts"
        if ((Test-Path -LiteralPath $BuildDir) -and ($BuildDir -ne $InstallDir)) {
            Remove-Item -LiteralPath $BuildDir -Recurse -Force
        }
        if ((Test-Path -LiteralPath $SourceDir) -and ($SourceDir -ne $InstallDir)) {
            Remove-Item -LiteralPath $SourceDir -Recurse -Force
        }
    }
}

Write-Host ""
Write-Host "llama.cpp text runtime build complete."
Write-Host "  source:  $SourceDir"
Write-Host "  build:   $BuildDir"
Write-Host "  install: $InstallDir"
Write-Host "  server:  $(Join-Path $InstallDir 'llama-server.exe')"
Write-Host "  completion: $(Join-Path $InstallDir 'llama-completion.exe')"
Write-Host "  cli:     $(Join-Path $InstallDir 'llama-cli.exe')"
if (-not $DryRun -and (Test-Path -LiteralPath (Join-Path $InstallDir 'llama-embedding.exe'))) {
    Write-Host "  embedding: $(Join-Path $InstallDir 'llama-embedding.exe')"
}
Write-Host "  cuda:    $useCuda"
if (-not $KeepArtifacts) {
    Write-Host "  cache:   pruned after install"
}
