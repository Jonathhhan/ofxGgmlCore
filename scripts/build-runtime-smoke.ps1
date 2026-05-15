param(
	[ValidateSet("cpu", "cuda", "vulkan", "metal", "opencl", "auto")]
	[string[]]$Backend = @("cpu"),
	[switch]$RequireBackend,
	[switch]$SkipBuild,
	[switch]$UpdateCapabilityReport
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptRoot
$buildDir = Join-Path $root "build\runtime-smoke"
$exe = Join-Path $buildDir "runtime_smoke.exe"
$report = Join-Path $buildDir "backend-runtime-smoke.json"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Convert-ToCmdArgument {
	param([string]$Value)
	return '"' + ($Value -replace '"', '""') + '"'
}

function Get-VisualStudioDevCmd {
	$candidates = New-Object System.Collections.Generic.List[string]
	$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
	if (Test-Path -LiteralPath $vswhere) {
		$installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
		if ($installPath) {
			$candidates.Add((Join-Path $installPath "Common7\Tools\VsDevCmd.bat"))
		}
	}
	foreach ($version in @("18", "17", "16")) {
		foreach ($edition in @("Community", "Professional", "Enterprise", "BuildTools")) {
			$candidates.Add("C:\Program Files\Microsoft Visual Studio\$version\$edition\Common7\Tools\VsDevCmd.bat")
			$candidates.Add("C:\Program Files (x86)\Microsoft Visual Studio\$version\$edition\Common7\Tools\VsDevCmd.bat")
		}
	}
	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate) {
			return $candidate
		}
	}
	return $null
}

function Assert-File {
	param(
		[string]$Path,
		[string]$Message
	)
	if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw $Message
	}
}

function Invoke-RuntimeSmoke {
	param([string]$BackendName)

	$arguments = @("--backend", $BackendName)
	if ($RequireBackend) {
		$arguments += "--require-backend"
	}

	$output = @(& $exe @arguments 2>&1)
	$exitCode = $LASTEXITCODE
	[pscustomobject]@{
		backend = $BackendName
		required = [bool]$RequireBackend
		exitCode = $exitCode
		passed = ($exitCode -eq 0)
		output = @($output)
	}
}

Assert-File (Join-Path $root "libs\ggml\include\ggml.h") "Missing ggml headers. Run scripts\setup-ggml.ps1 -CpuOnly first."
foreach ($library in @("ggml.lib", "ggml-base.lib", "ggml-cpu.lib")) {
	Assert-File (Join-Path $root "libs\ggml\lib\$library") "Missing ggml library: libs\ggml\lib\$library. Run scripts\setup-ggml.ps1 -CpuOnly first."
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

if (!$SkipBuild) {
	$vsDevCmd = Get-VisualStudioDevCmd
	if (!$vsDevCmd) {
		throw "Visual Studio C++ build tools were not found. Install Visual Studio with Desktop development with C++."
	}

	$sources = @(
		(Join-Path $root "tools\runtime-smoke\runtime_smoke.cpp"),
		(Join-Path $root "src\core\ofxGgmlRuntime.cpp"),
		(Join-Path $root "src\compute\ofxGgmlGraph.cpp"),
		(Join-Path $root "src\compute\ofxGgmlTensor.cpp")
	)
	$quotedSources = $sources | ForEach-Object { Convert-ToCmdArgument $_ }
	$includeArgs = @(
		"/I" + (Convert-ToCmdArgument (Join-Path $root "src")),
		"/I" + (Convert-ToCmdArgument (Join-Path $root "libs\ggml\include"))
	)
	$libPath = "/LIBPATH:" + (Convert-ToCmdArgument (Join-Path $root "libs\ggml\lib"))
	$compileCommand = @(
		"cl /nologo /std:c++17 /EHsc /O2 /W3 /MD",
		($includeArgs -join " "),
		($quotedSources -join " "),
		"/Fe:$(Convert-ToCmdArgument $exe)",
		"/link",
		$libPath,
		"ggml.lib ggml-base.lib ggml-cpu.lib advapi32.lib"
	) -join " "
	$command = "call $(Convert-ToCmdArgument $vsDevCmd) -arch=x64 -host_arch=x64 >nul && $compileCommand"

	Write-Step "Building runtime smoke executable"
	& cmd.exe /d /s /c $command
	if ($LASTEXITCODE -ne 0) {
		throw "runtime smoke build failed with exit code $LASTEXITCODE"
	}
}

Assert-File $exe "Runtime smoke executable was not built: $exe"

$results = @()
foreach ($backendName in $Backend) {
	Write-Step "Running runtime smoke for backend: $backendName"
	$results += Invoke-RuntimeSmoke $backendName
}

$payload = [pscustomobject]@{
	generatedAt = (Get-Date).ToUniversalTime().ToString("o")
	executable = $exe
	results = @($results)
}
$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $report -Encoding UTF8
Write-Step "Wrote runtime smoke report: $report"

if ($UpdateCapabilityReport -and (Get-Command python -ErrorAction SilentlyContinue)) {
	$generator = Join-Path $scriptRoot "generate-backend-capability-report.py"
	Write-Step "Updating backend capability report with runtime smoke evidence"
	python $generator --runtime-smoke-report $report
	if ($LASTEXITCODE -ne 0) {
		throw "generate-backend-capability-report.py failed with exit code $LASTEXITCODE"
	}
}

$failed = @($results | Where-Object { !$_.passed })
if ($failed.Count -gt 0) {
	throw "One or more runtime smoke checks failed."
}
