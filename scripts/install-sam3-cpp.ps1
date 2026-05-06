param(
    [string] $Repo = "https://github.com/PABannier/sam3.cpp.git",
    [string] $Ref = "main",
    [switch] $Force
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

function Patch-Sam3CudaSupport {
    param([string] $SourceDir)

    $cmakePath = Join-Path $SourceDir "CMakeLists.txt"
    $cppPath = Join-Path $SourceDir "sam3.cpp"

    $cmake = Get-Content -Raw -LiteralPath $cmakePath
    if ($cmake -notmatch "GGML_USE_CUDA") {
        $cmake = [regex]::Replace(
            $cmake,
            "target_compile_features\(sam3 PUBLIC cxx_std_14\)",
            "target_compile_features(sam3 PUBLIC cxx_std_14)`n`nif(GGML_CUDA)`n    target_compile_definitions(sam3 PUBLIC GGML_USE_CUDA)`nendif()",
            1)
        Set-Content -LiteralPath $cmakePath -Value $cmake -Encoding UTF8
        Write-Host "Patched sam3 CMake CUDA compile definition."
    }

    $cpp = Get-Content -Raw -LiteralPath $cppPath
    if ($cpp -notmatch "ggml-cuda.h") {
        $cpp = [regex]::Replace(
            $cpp,
            "#include `"ggml\.h`"\r?\n\r?\n#ifdef GGML_USE_METAL",
            "#include `"ggml.h`"`n`n#ifdef GGML_USE_CUDA`n#include `"ggml-cuda.h`"`n#endif`n`n#ifdef GGML_USE_METAL",
            1)
    }
    if ($cpp -notmatch "ggml_backend_cuda_init") {
        $cpp = [regex]::Replace(
            $cpp,
            "#ifdef GGML_USE_METAL\r?\n    if \(params\.use_gpu\) \{\r?\n        fprintf\(stderr, `"%s: using Metal backend\\n`", __func__\);\r?\n        model->backend = ggml_backend_metal_init\(\);\r?\n    \}\r?\n#endif",
            "#ifdef GGML_USE_CUDA`n    if (params.use_gpu) {`n        fprintf(stderr, `"%s: using CUDA backend\n`", __func__);`n        model->backend = ggml_backend_cuda_init(0);`n        if (!model->backend) {`n            fprintf(stderr, `"%s: failed to init CUDA backend; falling back to CPU\n`", __func__);`n        }`n    }`n#endif`n#ifdef GGML_USE_METAL`n    if (params.use_gpu) {`n        fprintf(stderr, `"%s: using Metal backend\n`", __func__);`n        model->backend = ggml_backend_metal_init();`n    }`n#endif",
            1)
    }
    Set-Content -LiteralPath $cppPath -Value $cpp -Encoding UTF8
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptDir "..")
$destDir = Join-Path $addonRoot "libs\sam3.cpp"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required to install sam3.cpp."
}

if (Test-Path (Join-Path $destDir ".git")) {
    Invoke-Step "Updating existing sam3.cpp checkout" {
        git -C $destDir fetch --tags origin
    }
} else {
    if (Test-Path $destDir) {
        $children = Get-ChildItem -LiteralPath $destDir -Force
        if ($children.Count -gt 0 -and -not $Force) {
            throw "Refusing to overwrite non-empty directory: $destDir. Re-run with -Force to replace it."
        }
        Remove-Item -LiteralPath $destDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destDir) | Out-Null
    Invoke-Step "Cloning sam3.cpp into $destDir" {
        git clone --recursive $Repo $destDir
    }
}

Invoke-Step "Checking out sam3.cpp ref $Ref" {
    git -C $destDir checkout $Ref
}
Invoke-Step "Updating sam3.cpp submodules" {
    git -C $destDir submodule update --init --recursive
}

Patch-Sam3CudaSupport -SourceDir $destDir

Write-Host "==> sam3.cpp is installed."
Write-Host "Source: $destDir"
Write-Host "Ref:    $Ref"
Write-Host "CUDA:   patched ggml CUDA backend init support for sam3.cpp"
