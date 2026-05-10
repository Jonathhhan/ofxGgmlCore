param(
	[string]$ServerUrl = $(if ($env:OFXGGML_EMBEDDING_SERVER_URL) { $env:OFXGGML_EMBEDDING_SERVER_URL } else { "http://127.0.0.1:8081" }),
	[string]$ServerModel = $env:OFXGGML_EMBEDDING_SERVER_MODEL,
	[string]$Model = $(if ($env:OFXGGML_EMBEDDING_MODEL) { $env:OFXGGML_EMBEDDING_MODEL } elseif ($env:OFXGGML_TEXT_MODEL) { $env:OFXGGML_TEXT_MODEL } else { "" }),
	[switch]$Build,
	[switch]$NoAutoServer,
	[switch]$DryRun,
	[string]$Configuration = "Release",
	[string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$exampleRoot = Join-Path $addonRoot "ofxGgmlEmbeddingExample"
$exampleExe = Join-Path $exampleRoot "bin\ofxGgmlEmbeddingExample.exe"

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

function Start-BundledEmbeddingServerIfNeeded {
	if ($NoAutoServer -or (Test-LocalServerUrl $ServerUrl)) {
		return
	}
	if ([string]::IsNullOrWhiteSpace($Model)) {
		Write-Warning "No GGUF model found. Start an embedding llama-server manually or pass -Model."
		return
	}
	$uri = [Uri]$ServerUrl
	$port = if ($uri.IsDefaultPort) {
		if ($uri.Scheme -ieq "https") { 443 } else { 80 }
	} else {
		$uri.Port
	}
	$hostName = if ([string]::IsNullOrWhiteSpace($uri.Host)) { "127.0.0.1" } else { $uri.Host }
	Write-Step "embedding llama-server is not responding; starting bundled server"
	& (Join-Path $scriptRoot "start-llama-server.ps1") `
		-ModelPath $Model `
		-HostName $hostName `
		-Port $port `
		-Embeddings `
		-Detached `
		-LogDir (Join-Path $addonRoot "build\llama-embedding-server")
}

if ($Build) {
	& (Join-Path $scriptRoot "build-embedding-example.ps1") -Configuration $Configuration -Platform $Platform
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}

if (!(Test-Path -LiteralPath $exampleExe -PathType Leaf)) {
	throw "Embedding example executable was not found: $exampleExe. Build it first with scripts\build-embedding-example.bat."
}

$Model = Normalize-PathText $Model
$ServerUrl = Normalize-PathText $ServerUrl
$ServerModel = Normalize-PathText $ServerModel
if ([string]::IsNullOrWhiteSpace($ServerUrl)) {
	$ServerUrl = "http://127.0.0.1:8081"
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

$env:OFXGGML_EMBEDDING_SERVER_URL = $ServerUrl
if (![string]::IsNullOrWhiteSpace($ServerModel)) {
	$env:OFXGGML_EMBEDDING_SERVER_MODEL = $ServerModel
}
if (![string]::IsNullOrWhiteSpace($Model)) {
	$env:OFXGGML_EMBEDDING_MODEL = $Model
	Write-Step "Using embedding model: $Model"
} else {
	Write-Warning "No GGUF model found. The example can still connect to an already-running server."
}

Write-Step "Using embedding server: $ServerUrl"
if (![string]::IsNullOrWhiteSpace($ServerModel)) {
	Write-Step "Using server model: $ServerModel"
}
if ($DryRun) {
	Write-Step "Executable: $exampleExe"
	Write-Step "Auto server: $(if ($NoAutoServer) { 'off' } else { 'on' })"
	return
}
Start-BundledEmbeddingServerIfNeeded

Write-Step "Starting ofxGgmlEmbeddingExample"
& $exampleExe
exit $LASTEXITCODE
