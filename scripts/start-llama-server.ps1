param(
	[string]$ModelPath = $(if ($env:OFXGGML_TEXT_MODEL) { $env:OFXGGML_TEXT_MODEL } else { "" }),
	[string]$ServerExe = $(if ($env:OFXGGML_LLAMA_SERVER) { $env:OFXGGML_LLAMA_SERVER } else { "" }),
	[string]$HostName = "127.0.0.1",
	[int]$Port = 8080,
	[int]$GpuLayers = 28,
	[int]$ContextSize = 4096,
	[switch]$NoCudaGraphs,
	[switch]$Detached,
	[string]$LogDir = "",
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")

function Resolve-FirstFile {
	param([string[]]$Candidates)
	foreach ($candidate in $Candidates) {
		if (![string]::IsNullOrWhiteSpace($candidate) -and
			(Test-Path -LiteralPath $candidate -PathType Leaf)) {
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

function Join-ProcessArguments {
	param([string[]]$Arguments)
	$quoted = foreach ($argument in $Arguments) {
		if ($null -eq $argument) {
			'""'
		} elseif ($argument -match '[\s"]') {
			'"' + ($argument.Replace('"', '\"')) + '"'
		} else {
			$argument
		}
	}
	return ($quoted -join " ")
}

if ([string]::IsNullOrWhiteSpace($ServerExe)) {
	$serverName = if ($IsLinux -or $IsMacOS) { "llama-server" } else { "llama-server.exe" }
	$ServerExe = Resolve-FirstFile @(
		(Join-Path $addonRoot "libs\llama\bin\$serverName"),
		(Join-Path $addonRoot "libs\llama.cpp\build\bin\Release\$serverName"),
		(Join-Path $addonRoot "libs\llama.cpp\build\bin\$serverName"),
		(Join-Path $addonRoot "libs\llama.cpp\build\$serverName")
	)
}
if ([string]::IsNullOrWhiteSpace($ServerExe)) {
	throw "Could not find llama-server. Build it with scripts\build-llama-server.bat or pass -ServerExe."
}

if ([string]::IsNullOrWhiteSpace($ModelPath)) {
	$ModelPath = Find-FirstModel @(
		(Join-Path $addonRoot "ofxGgmlTextExample\bin\data\models"),
		(Join-Path $addonRoot "ofxGgmlTextExample\bin\data"),
		(Join-Path $addonRoot "ofxGgmlTextExample\models"),
		(Join-Path $addonRoot "models"),
		(Join-Path (Split-Path -Parent $addonRoot) "models")
	)
}
if ([string]::IsNullOrWhiteSpace($ModelPath)) {
	throw "Could not find a GGUF model. Pass -ModelPath or set OFXGGML_TEXT_MODEL."
}
if (!(Test-Path -LiteralPath $ModelPath -PathType Leaf)) {
	throw "Model file was not found: $ModelPath"
}

$arguments = @(
	"-m", $ModelPath,
	"--host", $HostName,
	"--port", $Port.ToString(),
	"-ngl", ([Math]::Max(0, $GpuLayers)).ToString(),
	"-c", ([Math]::Max(512, $ContextSize)).ToString()
)
if ($NoCudaGraphs) {
	$arguments += "--no-cuda-graphs"
}

Write-Host "Starting llama-server"
Write-Host "  exe:    $ServerExe"
Write-Host "  model:  $ModelPath"
Write-Host "  url:    http://$HostName`:$Port"
Write-Host "  ngl:    $GpuLayers"
Write-Host "  ctx:    $ContextSize"
Write-Host "  mode:   $(if ($Detached) { 'detached' } else { 'foreground' })"
if (![string]::IsNullOrWhiteSpace($LogDir)) {
	Write-Host "  logs:   $LogDir"
}
Write-Host ""
Write-Host ("`"$ServerExe`" " + (Join-ProcessArguments $arguments))

if ($DryRun) {
	return
}

$workingDir = Split-Path -Parent $ServerExe
if ($Detached) {
	$startArgs = @{
		FilePath = $ServerExe
		ArgumentList = (Join-ProcessArguments $arguments)
		WorkingDirectory = $workingDir
		WindowStyle = "Hidden"
		PassThru = $true
	}
	if (![string]::IsNullOrWhiteSpace($LogDir)) {
		New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
		$startArgs.RedirectStandardOutput = Join-Path $LogDir "llama-server.out.log"
		$startArgs.RedirectStandardError = Join-Path $LogDir "llama-server.err.log"
	}
	$process = Start-Process @startArgs
	Write-Host ""
	Write-Host "llama-server started in the background (PID $($process.Id))."
	Write-Host "Use OFXGGML_TEXT_SERVER_URL=http://$HostName`:$Port"
	if (![string]::IsNullOrWhiteSpace($LogDir)) {
		Write-Host "Logs are in $LogDir"
	}
	Write-Output "OFXGGML_LLAMA_SERVER_PID=$($process.Id)"
} else {
	Write-Host ""
	Write-Host "llama-server is running in this console. Press Ctrl+C to stop it."
	& $ServerExe @arguments
}
