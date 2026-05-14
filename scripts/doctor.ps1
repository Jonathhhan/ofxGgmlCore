param(
	[switch]$Strict
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")

$script:Warnings = 0

function Write-Check {
	param(
		[string]$State,
		[string]$Name,
		[string]$Detail = ""
	)
	$line = "{0,-5} {1}" -f $State, $Name
	if (![string]::IsNullOrWhiteSpace($Detail)) {
		$line += " - $Detail"
	}
	Write-Host $line
	if ($State -eq "WARN") {
		$script:Warnings++
	}
}

function Test-CommandAvailable {
	param([string]$Name)
	return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-GitStatusLine {
	param([string]$RelativePath)
	if (!(Test-CommandAvailable "git")) {
		return ""
	}
	$output = & git -C $addonRoot status --short -- $RelativePath 2>$null
	if ($LASTEXITCODE -ne 0) {
		return ""
	}
	return (@($output) -join "`n").Trim()
}

function Test-WindowsHost {
	return !($IsLinux -or $IsMacOS)
}

function Get-PlatformScript {
	param([string]$Name)
	if (Test-WindowsHost) {
		return "scripts\$Name.bat"
	}
	return "./scripts/$Name.sh"
}

$isWindowsHost = Test-WindowsHost
$exeSuffix = if ($isWindowsHost) { ".exe" } else { "" }
$addonParent = Split-Path -Parent $addonRoot
$setupCommand = Get-PlatformScript -Name "setup-ggml"
$runSimpleCommand = "$(Get-PlatformScript -Name 'run-simple-example') -Build"

Write-Host "ofxGgmlCore doctor"
Write-Host "Root  $addonRoot"
Write-Host ""

Write-Check "OK" "addon root" $addonRoot

foreach ($tool in @("git", "cmake")) {
	if (Test-CommandAvailable $tool) {
		Write-Check "OK" $tool ((Get-Command $tool).Source)
	} else {
		Write-Check "WARN" $tool "not found in PATH"
	}
}

if ($isWindowsHost) {
	$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
	if (Test-Path -LiteralPath $vswhere -PathType Leaf) {
		Write-Check "OK" "Visual Studio locator" $vswhere
	} else {
		Write-Check "WARN" "Visual Studio locator" "vswhere.exe not found"
	}
} elseif (Test-CommandAvailable "pwsh") {
	Write-Check "OK" "PowerShell 7" ((Get-Command pwsh).Source)
} else {
	Write-Check "WARN" "PowerShell 7" "pwsh not found"
}

$ofxImGui = Join-Path $addonParent "ofxImGui"
if (Test-Path -LiteralPath $ofxImGui -PathType Container) {
	Write-Check "OK" "ofxImGui" $ofxImGui
} else {
	Write-Check "WARN" "ofxImGui" "install beside ofxGgmlCore before building GUI examples"
}

$ggmlInclude = Join-Path $addonRoot "libs\ggml\include"
$ggmlLib = Join-Path $addonRoot "libs\ggml\lib"
if ((Test-Path -LiteralPath $ggmlInclude -PathType Container) -and
	(Test-Path -LiteralPath $ggmlLib -PathType Container)) {
	Write-Check "OK" "ggml runtime" "include/lib are present"
} else {
	Write-Check "WARN" "ggml runtime" "run $setupCommand"
}

$simpleExe = Join-Path $addonRoot "ofxGgmlCoreExample\bin\ofxGgmlCoreExample$exeSuffix"
if (Test-Path -LiteralPath $simpleExe -PathType Leaf) {
	Write-Check "OK" "ofxGgmlCoreExample" "built"
} else {
	Write-Check "WARN" "ofxGgmlCoreExample" "run $runSimpleCommand"
}

$llamaSibling = Join-Path $addonParent "ofxGgmlLlama"
if (Test-Path -LiteralPath $llamaSibling -PathType Container) {
	Write-Check "OK" "ofxGgmlLlama companion" $llamaSibling
} else {
	Write-Check "WARN" "ofxGgmlLlama companion" "clone beside ofxGgmlCore for text, chat, and embedding examples"
}

$addonConfigStatus = Get-GitStatusLine -RelativePath "addon_config.mk"
if (![string]::IsNullOrWhiteSpace($addonConfigStatus)) {
	Write-Check "NOTE" "addon_config.mk" "local backend selection differs from git; this is expected after setup-ggml"
}

Write-Host ""
if ($script:Warnings -eq 0) {
	Write-Host "Doctor passed."
} else {
	Write-Host "Doctor found $script:Warnings warning(s)."
	if ($Strict) {
		exit 1
	}
}
