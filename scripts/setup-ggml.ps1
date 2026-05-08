param(
	[string]$Revision = "master",
	[switch]$Cuda,
	[switch]$Clean
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$GgmlRoot = Join-Path $Root "libs\ggml"
$Source = Join-Path $GgmlRoot ".source"
$Build = Join-Path $GgmlRoot "build"
$Include = Join-Path $GgmlRoot "include"
$Lib = Join-Path $GgmlRoot "lib"

if ($Clean) {
	Remove-Item -LiteralPath $Source,$Build -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $GgmlRoot,$Include,$Lib -Force | Out-Null

if (!(Test-Path $Source)) {
	git clone https://github.com/ggml-org/ggml.git $Source
}

git -C $Source fetch --all --tags
git -C $Source checkout $Revision

if (Test-Path $Build) {
	Remove-Item -LiteralPath $Build -Recurse -Force
}

$cudaFlag = if ($Cuda) { "ON" } else { "OFF" }
cmake -S $Source -B $Build -DGGML_CUDA=$cudaFlag -DGGML_BUILD_TESTS=OFF -DGGML_BUILD_EXAMPLES=OFF
cmake --build $Build --config Release --target ggml ggml-base ggml-cpu

Copy-Item -Path (Join-Path $Source "include\*.h") -Destination $Include -Force
Copy-Item -Path (Join-Path $Build "src\Release\*.lib") -Destination $Lib -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $Build "src\*.a") -Destination $Lib -Force -ErrorAction SilentlyContinue

Write-Host "ggml headers and libraries installed under $GgmlRoot"
