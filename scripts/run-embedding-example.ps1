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
. (Join-Path $scriptRoot "ofxGgml-launch-utils.ps1")

if ($Build) {
	& (Join-Path $scriptRoot "build-embedding-example.ps1") -Configuration $Configuration -Platform $Platform
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}

if (!(Test-Path -LiteralPath $exampleExe -PathType Leaf)) {
	throw "Embedding example executable was not found: $exampleExe. Build it first with scripts\build-embedding-example.bat."
}

$Model = Normalize-OfxGgmlPathText $Model
$ServerUrl = Normalize-OfxGgmlPathText $ServerUrl
$ServerModel = Normalize-OfxGgmlPathText $ServerModel
if ([string]::IsNullOrWhiteSpace($ServerUrl)) {
	$ServerUrl = "http://127.0.0.1:8081"
}

if ([string]::IsNullOrWhiteSpace($Model)) {
	$Model = Find-OfxGgmlFirstModel (Get-OfxGgmlModelSearchDirectories `
		-AddonRoot $addonRoot `
		-ExampleRoot $exampleRoot `
		-ExtraExampleNames @("ofxGgmlTextExample", "ofxGgmlChatExample"))
}

$env:OFXGGML_EMBEDDING_SERVER_URL = $ServerUrl
if (![string]::IsNullOrWhiteSpace($ServerModel)) {
	$env:OFXGGML_EMBEDDING_SERVER_MODEL = $ServerModel
}
if (![string]::IsNullOrWhiteSpace($Model)) {
	$env:OFXGGML_EMBEDDING_MODEL = $Model
	Write-OfxGgmlStep "Using embedding model: $Model"
} else {
	Write-Warning "No GGUF model found. The example can still connect to an already-running server."
}

Write-OfxGgmlStep "Using embedding server: $ServerUrl"
if (![string]::IsNullOrWhiteSpace($ServerModel)) {
	Write-OfxGgmlStep "Using server model: $ServerModel"
}
if ($DryRun) {
	Write-OfxGgmlStep "Executable: $exampleExe"
	Write-OfxGgmlStep "Auto server: $(if ($NoAutoServer) { 'off' } else { 'on' })"
	return
}
Start-OfxGgmlBundledLlamaServerIfNeeded `
	-ScriptRoot $scriptRoot `
	-AddonRoot $addonRoot `
	-ServerUrl $ServerUrl `
	-Model $Model `
	-LogDir (Join-Path $addonRoot "build\llama-embedding-server") `
	-MissingModelWarning "No GGUF model found. Start an embedding llama-server manually or pass -Model." `
	-StartMessage "embedding llama-server is not responding; starting bundled server" `
	-NoAutoServer:$NoAutoServer `
	-Embeddings

Write-OfxGgmlStep "Starting ofxGgmlEmbeddingExample"
& $exampleExe
exit $LASTEXITCODE
