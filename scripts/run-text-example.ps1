param(
	[string]$LlamaCli = $env:OFXGGML_LLAMA_CLI,
	[string]$Model = $env:OFXGGML_TEXT_MODEL,
	[switch]$Build,
	[string]$Configuration = "Release",
	[string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$exampleRoot = Join-Path $addonRoot "ofxGgmlTextExample"
$exampleExe = Join-Path $exampleRoot "bin\ofxGgmlTextExample.exe"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Normalize-PathText {
	param([string]$PathText)
	if ([string]::IsNullOrWhiteSpace($PathText)) {
		return ""
	}
	return $PathText.Trim().Trim('"')
}

function Find-FirstFile {
	param([string[]]$Candidates)
	foreach ($candidate in $Candidates) {
		if (![string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
			return (Resolve-Path -LiteralPath $candidate).Path
		}
	}
	return ""
}

function Find-FirstModel {
	param([string[]]$Directories)
	foreach ($directory in $Directories) {
		if (!(Test-Path -LiteralPath $directory -PathType Container)) {
			continue
		}
		$model = Get-ChildItem -LiteralPath $directory -Filter "*.gguf" -File -ErrorAction SilentlyContinue |
			Sort-Object Name |
			Select-Object -First 1
		if ($model) {
			return $model.FullName
		}
	}
	return ""
}

if ($Build) {
	& (Join-Path $scriptRoot "build-text-example.ps1") -Configuration $Configuration -Platform $Platform
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}

if (!(Test-Path -LiteralPath $exampleExe -PathType Leaf)) {
	throw "Text example executable was not found: $exampleExe. Build it first with scripts\build-text-example.bat."
}

$LlamaCli = Normalize-PathText $LlamaCli
$Model = Normalize-PathText $Model

$searchRoots = @(
	$addonRoot,
	$exampleRoot,
	(Join-Path $exampleRoot "bin"),
	(Join-Path $exampleRoot "bin\data")
)

if ([string]::IsNullOrWhiteSpace($LlamaCli)) {
	$llamaNames = if ($IsWindows -or $env:OS -eq "Windows_NT") {
		@("llama-cli.exe", "main.exe", "llama.exe")
	} else {
		@("llama-cli", "main", "llama")
	}
	$llamaDirs = @(
		"",
		"bin",
		"data",
		"data\bin",
		"tools",
		"libs\llama.cpp\build\bin",
		"libs\llama.cpp\build\bin\Release",
		"libs\llama.cpp\build\bin\Debug"
	)
	$candidates = foreach ($root in $searchRoots) {
		foreach ($dir in $llamaDirs) {
			foreach ($name in $llamaNames) {
				Join-Path (Join-Path $root $dir) $name
			}
		}
	}
	$LlamaCli = Find-FirstFile $candidates
}

if ([string]::IsNullOrWhiteSpace($Model)) {
	$modelDirs = @(
		(Join-Path $exampleRoot "bin\data"),
		(Join-Path $exampleRoot "bin\data\models"),
		(Join-Path $exampleRoot "models"),
		(Join-Path $addonRoot "models")
	)
	$Model = Find-FirstModel $modelDirs
}

if (![string]::IsNullOrWhiteSpace($LlamaCli)) {
	$env:OFXGGML_LLAMA_CLI = $LlamaCli
	Write-Step "Using llama.cpp CLI: $LlamaCli"
} else {
	Write-Warning "No llama.cpp CLI found. The example will show setup instructions."
}

if (![string]::IsNullOrWhiteSpace($Model)) {
	$env:OFXGGML_TEXT_MODEL = $Model
	Write-Step "Using text model: $Model"
} else {
	Write-Warning "No GGUF model found. The example will show setup instructions."
}

Write-Step "Starting ofxGgmlTextExample"
& $exampleExe
exit $LASTEXITCODE
