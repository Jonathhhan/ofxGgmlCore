param(
	[string]$Backend = $(if ($env:OFXGGML_TEXT_BACKEND) { $env:OFXGGML_TEXT_BACKEND } else { "server" }),
	[string]$ServerUrl = $(if ($env:OFXGGML_TEXT_SERVER_URL) { $env:OFXGGML_TEXT_SERVER_URL } else { "http://127.0.0.1:8080" }),
	[string]$ServerModel = $env:OFXGGML_TEXT_SERVER_MODEL,
	[string]$LlamaCli = $env:OFXGGML_LLAMA_CLI,
	[string]$Model = $env:OFXGGML_TEXT_MODEL,
	[switch]$Build,
	[switch]$NoAutoServer,
	[string]$Configuration = "Release",
	[string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$exampleRoot = Join-Path $addonRoot "ofxGgmlChatExample"
$exampleExe = Join-Path $exampleRoot "bin\ofxGgmlChatExample.exe"

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

function Test-LocalServerUrl {
	param([string]$Url)
	try {
		$uri = [Uri]$Url
		if ($uri.Host -notin @("127.0.0.1", "localhost", "::1")) {
			return $true
		}
		$healthUrl = $Url.TrimEnd("/") + "/health"
		$response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
		return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
	} catch {
		return $false
	}
}

function Start-BundledServerIfNeeded {
	if ($NoAutoServer -or (Test-LocalServerUrl $ServerUrl)) {
		return
	}
	if ([string]::IsNullOrWhiteSpace($Model)) {
		Write-Warning "No GGUF model found. Start llama-server manually or pass -Model."
		return
	}
	$uri = [Uri]$ServerUrl
	$port = if ($uri.IsDefaultPort) {
		if ($uri.Scheme -ieq "https") { 443 } else { 80 }
	} else {
		$uri.Port
	}
	$hostName = if ([string]::IsNullOrWhiteSpace($uri.Host)) { "127.0.0.1" } else { $uri.Host }
	Write-Step "llama-server is not responding; starting bundled server"
	& (Join-Path $scriptRoot "start-llama-server.ps1") `
		-ModelPath $Model `
		-HostName $hostName `
		-Port $port `
		-Detached `
		-LogDir (Join-Path $addonRoot "build\llama-server")
}

if ($Build) {
	& (Join-Path $scriptRoot "build-chat-example.ps1") -Configuration $Configuration -Platform $Platform
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}

if (!(Test-Path -LiteralPath $exampleExe -PathType Leaf)) {
	throw "Chat example executable was not found: $exampleExe. Build it first with scripts\build-chat-example.bat."
}

$LlamaCli = Normalize-PathText $LlamaCli
$Model = Normalize-PathText $Model
$Backend = Normalize-PathText $Backend
$ServerUrl = Normalize-PathText $ServerUrl
$ServerModel = Normalize-PathText $ServerModel
if ([string]::IsNullOrWhiteSpace($Backend)) {
	$Backend = "server"
}

$searchRoots = @(
	$addonRoot,
	$exampleRoot,
	(Join-Path $exampleRoot "bin"),
	(Join-Path $exampleRoot "bin\data")
)

if ($Backend -ieq "cli" -and [string]::IsNullOrWhiteSpace($LlamaCli)) {
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
		"libs\llama\bin",
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
		(Join-Path $addonRoot "models"),
		(Join-Path (Split-Path -Parent $addonRoot) "models")
	)
	$Model = Find-FirstModel $modelDirs
}

if ($Backend -ieq "server") {
	$env:OFXGGML_TEXT_BACKEND = "server"
	$env:OFXGGML_TEXT_SERVER_URL = $ServerUrl
	if (![string]::IsNullOrWhiteSpace($ServerModel)) {
		$env:OFXGGML_TEXT_SERVER_MODEL = $ServerModel
	}
	Write-Step "Using llama-server: $ServerUrl"
	if (![string]::IsNullOrWhiteSpace($ServerModel)) {
		Write-Step "Using server model: $ServerModel"
	}
	Start-BundledServerIfNeeded
} elseif (![string]::IsNullOrWhiteSpace($LlamaCli)) {
	$env:OFXGGML_TEXT_BACKEND = "cli"
	$env:OFXGGML_LLAMA_CLI = $LlamaCli
	Write-Step "Using llama.cpp CLI: $LlamaCli"
} else {
	Write-Warning "No llama.cpp CLI found. The example will show setup instructions."
}

if (![string]::IsNullOrWhiteSpace($Model)) {
	$env:OFXGGML_TEXT_MODEL = $Model
	Write-Step "Using text model: $Model"
} elseif ($Backend -ieq "cli") {
	Write-Warning "No GGUF model found. The example will show setup instructions."
}

Write-Step "Starting ofxGgmlChatExample"
& $exampleExe
exit $LASTEXITCODE
