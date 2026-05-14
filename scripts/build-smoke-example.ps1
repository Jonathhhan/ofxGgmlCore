param(
	[string]$Repository,
	[string]$Example,
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$Clean
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Repository)) {
	throw "-Repository is required."
}
if ([string]::IsNullOrWhiteSpace($Example)) {
	throw "-Example is required."
}

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Test-WindowsHost {
	return !($IsLinux -or $IsMacOS)
}

function Normalize-WindowsPathEnvironment {
	if (!(Test-WindowsHost)) {
		return
	}
	$variables = [Environment]::GetEnvironmentVariables("Process")
	$pathNames = New-Object System.Collections.Generic.List[string]
	foreach ($key in $variables.Keys) {
		$name = [string]$key
		if ($name.Equals("Path", [System.StringComparison]::OrdinalIgnoreCase)) {
			$pathNames.Add($name)
		}
	}
	if ($pathNames.Count -le 1) {
		return
	}

	$preferredName = if ($pathNames.Contains("Path")) { "Path" } else { $pathNames[0] }
	$pathValue = [string]$variables[$preferredName]
	if ([string]::IsNullOrWhiteSpace($pathValue)) {
		foreach ($name in $pathNames) {
			$value = [string]$variables[$name]
			if (![string]::IsNullOrWhiteSpace($value)) {
				$pathValue = $value
				break
			}
		}
	}
	foreach ($name in $pathNames) {
		if (!$name.Equals("Path", [System.StringComparison]::Ordinal)) {
			[Environment]::SetEnvironmentVariable($name, $null, "Process")
		}
	}
	[Environment]::SetEnvironmentVariable("Path", $pathValue, "Process")
}

function Get-MsBuild {
	$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
	if (Test-Path -LiteralPath $vswhere) {
		$installPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath 2>$null
		if ($installPath) {
			$candidate = Join-Path $installPath "MSBuild\Current\Bin\MSBuild.exe"
			if (Test-Path -LiteralPath $candidate) {
				return $candidate
			}
		}
	}

	foreach ($version in @("18", "17", "16")) {
		foreach ($edition in @("Community", "Professional", "Enterprise", "BuildTools")) {
			$candidate = "C:\Program Files\Microsoft Visual Studio\$version\$edition\MSBuild\Current\Bin\MSBuild.exe"
			if (Test-Path -LiteralPath $candidate) {
				return $candidate
			}
		}
	}
	return ""
}

function Get-StableNameFragment {
	param([string]$Text)
	$sha1 = [System.Security.Cryptography.SHA1]::Create()
	try {
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
		$hash = $sha1.ComputeHash($bytes)
		return [System.BitConverter]::ToString($hash).Replace("-", "")
	} finally {
		$sha1.Dispose()
	}
}

function Invoke-WithNamedMutex {
	param(
		[string]$Name,
		[scriptblock]$Command
	)
	$mutex = New-Object System.Threading.Mutex($false, $Name)
	$locked = $false
	try {
		$locked = $mutex.WaitOne([TimeSpan]::FromMinutes(30))
		if (!$locked) {
			throw "Timed out waiting for build lock: $Name"
		}
		& $Command
	} finally {
		if ($locked) {
			$mutex.ReleaseMutex()
		}
		$mutex.Dispose()
	}
}

function Invoke-CheckedNative {
	param(
		[string]$Step,
		[scriptblock]$Command
	)
	& $Command
	if ($LASTEXITCODE -ne 0) {
		throw "$Step failed with exit code $LASTEXITCODE"
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreRoot = Resolve-Path (Join-Path $scriptRoot "..")
$addonsRoot = Split-Path -Parent $coreRoot.Path
$repoRoot = Join-Path $addonsRoot $Repository
$exampleDir = Join-Path $repoRoot $Example
$postflightScript = Join-Path $scriptRoot "check-smoke-build-target-postflight.ps1"

if (!(Test-Path -LiteralPath $repoRoot -PathType Container)) {
	throw "Repository directory not found: $repoRoot"
}
if (!(Test-Path -LiteralPath $exampleDir -PathType Container)) {
	throw "Example directory not found: $exampleDir"
}

$postflightJson = & $postflightScript -Stage "verify-generated-project" -Repository $Repository -Example $Example -Json
if (!$?) {
	throw "Generated-project postflight failed for $Repository / $Example."
}
$postflightResult = ($postflightJson -join [Environment]::NewLine) | ConvertFrom-Json
$postflight = @($postflightResult.Postflights | Select-Object -First 1)
if (!$postflight -or !$postflight.Complete) {
	throw "Generated project is not ready for compile validation: $Repository / $Example. Run scripts\plan-smoke-build-project-repair.bat first."
}

Normalize-WindowsPathEnvironment

if (Test-WindowsHost) {
	$project = Join-Path $exampleDir "$Example.vcxproj"
	if (!(Test-Path -LiteralPath $project -PathType Leaf)) {
		throw "Visual Studio project not found: $project"
	}
	$msbuild = Get-MsBuild
	if ([string]::IsNullOrWhiteSpace($msbuild)) {
		throw "MSBuild.exe was not found."
	}

	$target = if ($Clean) { "Rebuild" } else { "Build" }
	Write-Step "Building $Repository / $Example $Configuration $Platform with MSBuild"
	$lockName = "Local\ofxGgml-msbuild-" + (Get-StableNameFragment $repoRoot)
	Invoke-WithNamedMutex -Name $lockName -Command {
		$exitCode = 0
		for ($attempt = 1; $attempt -le 2; $attempt++) {
			& $msbuild $project /t:$target /p:Configuration=$Configuration /p:Platform=$Platform /p:TrackFileAccess=false /p:MultiProcessorCompilation=false /m:1 /nr:false
			$exitCode = $LASTEXITCODE
			if ($exitCode -eq 0) {
				return
			}
			if ($attempt -lt 2) {
				Write-Step "MSBuild failed with exit code $exitCode; retrying once"
			}
		}
		if (!$Clean) {
			Write-Step "MSBuild failed with exit code $exitCode; retrying without rebuilding project references"
			& $msbuild $project /t:$target /p:Configuration=$Configuration /p:Platform=$Platform /p:TrackFileAccess=false /p:MultiProcessorCompilation=false /p:BuildProjectReferences=false /m:1 /nr:false
			$exitCode = $LASTEXITCODE
			if ($exitCode -eq 0) {
				return
			}
		}
		throw "MSBuild $Repository / $Example failed with exit code $exitCode"
	}
	return
}

$makefile = Join-Path $exampleDir "Makefile"
if (Test-Path -LiteralPath $makefile -PathType Leaf) {
	$target = if ($Clean) { "clean Release" } else { "Release" }
	Write-Step "Building $Repository / $Example with make"
	Invoke-CheckedNative "make $Repository / $Example" {
		make -C $exampleDir $target
	}
	return
}

if ($IsMacOS) {
	$xcodeProject = Get-ChildItem -LiteralPath $exampleDir -Filter "*.xcodeproj" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($xcodeProject) {
		Write-Step "Building $Repository / $Example $Configuration with xcodebuild"
		Invoke-CheckedNative "xcodebuild $Repository / $Example" {
			xcodebuild -project $xcodeProject.FullName -configuration $Configuration
		}
		return
	}
}

throw "No supported generated project was found for $Repository / $Example."
