param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$Json,
	[switch]$SummaryOnly
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Invoke-GitLines {
	param([string[]]$Arguments)
	$output = & git @Arguments 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "git $($Arguments -join ' ') failed: $($output -join "`n")"
	}
	return @($output | ForEach-Object { $_.ToString() })
}

function Assert-NoMatches {
	param(
		[string[]]$Paths,
		[string[]]$Patterns,
		[string]$Label
	)
	$matchedPaths = New-Object System.Collections.Generic.List[string]
	foreach ($path in $Paths) {
		$normalized = $path -replace "\\", "/"
		foreach ($pattern in $Patterns) {
			if ($normalized -match $pattern) {
				$matchedPaths.Add($path)
				break
			}
		}
	}
	if ($matchedPaths.Count -gt 0) {
		throw "$Label contains generated artifacts:`n$($matchedPaths -join "`n")"
	}
}

function Get-Matches {
	param(
		[string[]]$Paths,
		[string[]]$Patterns
	)
	$matchedPaths = New-Object System.Collections.Generic.List[string]
	foreach ($path in $Paths) {
		$normalized = $path -replace "\\", "/"
		foreach ($pattern in $Patterns) {
			if ($normalized -match $pattern) {
				$matchedPaths.Add($path)
				break
			}
		}
	}
	return @($matchedPaths.ToArray())
}

function Get-IgnoreFailures {
	param([string[]]$Paths)
	$failures = New-Object System.Collections.Generic.List[string]
	foreach ($path in $Paths) {
		$output = & git check-ignore --quiet -- $path
		if ($LASTEXITCODE -ne 0) {
			$failures.Add($path)
		}
	}
	return @($failures.ToArray())
}

function New-HygieneCheck {
	param(
		[string]$Name,
		[bool]$Passed,
		[string[]]$Paths
	)
	[pscustomobject]@{
		Name = $Name
		Passed = $Passed
		Count = @($Paths).Count
		Paths = @($Paths)
	}
}

function ConvertTo-HygieneSummary {
	param([object]$Report)
	[pscustomobject]@{
		SchemaVersion = $Report.SchemaVersion
		Repository = $Report.Repository
		Passed = $Report.Passed
		CheckCount = @($Report.Checks).Count
		FailedCheckCount = @($Report.Checks | Where-Object { !$_.Passed }).Count
		TrackedGeneratedArtifactCount = @($Report.TrackedGeneratedArtifacts).Count
		StagedGeneratedArtifactCount = @($Report.StagedGeneratedArtifacts).Count
		IgnoreFailureCount = @($Report.IgnoreFailures).Count
	}
}

$null = $Configuration
$null = $Platform

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
Push-Location $repoRoot
try {
	$forbiddenPatterns = @(
		"^\.vs/",
		"(^|/)build/",
		"(^|/)obj/",
		"^libs/ggml/\.source/",
		"^libs/ggml/build",
		"^libs/llama\.cpp/",
		"^libs/llama/",
		"(^|/)(models)(/|$)",
		"\.(exe|dll|exp|ilk|lib|pdb|sln|suo|user|vcxproj|vcxproj\.filters|VC\.db|VC\.VC\.opendb)$",
		"\.(gguf|safetensors|onnx|pt|pth|ckpt)$"
	)
	$ignoreProbePaths = @(
		"build/artifact.tmp",
		"libs/ggml/.source/CMakeLists.txt",
		"libs/ggml/build/CMakeCache.txt",
		"libs/ggml/include/ggml.h",
		"libs/ggml/lib/ggml.lib",
		"libs/llama.cpp/CMakeLists.txt",
		"libs/llama/bin/llama-server.exe",
		"models/model.gguf",
		"ofxGgmlCoreExample/ofxGgmlCoreExample.vcxproj",
		"ofxGgmlCoreExample/bin/ofxGgmlCoreExample.exe"
	)

	$tracked = Invoke-GitLines @("ls-files")
	$trackedGeneratedArtifacts = @(Get-Matches -Paths $tracked -Patterns $forbiddenPatterns)

	$staged = Invoke-GitLines @("diff", "--cached", "--name-only", "--diff-filter=ACMRT")
	$stagedGeneratedArtifacts = @(Get-Matches -Paths $staged -Patterns $forbiddenPatterns)

	$ignoreFailures = @(Get-IgnoreFailures -Paths $ignoreProbePaths)
	$checks = @(
		New-HygieneCheck `
			-Name "tracked generated artifacts" `
			-Passed ($trackedGeneratedArtifacts.Count -eq 0) `
			-Paths $trackedGeneratedArtifacts
		New-HygieneCheck `
			-Name "staged generated artifacts" `
			-Passed ($stagedGeneratedArtifacts.Count -eq 0) `
			-Paths $stagedGeneratedArtifacts
		New-HygieneCheck `
			-Name "generated artifact ignore rules" `
			-Passed ($ignoreFailures.Count -eq 0) `
			-Paths $ignoreFailures
	)

	$report = [pscustomobject]@{
		SchemaVersion = 1
		Repository = "ofxGgmlCore"
		Root = [string]$repoRoot
		Passed = @($checks | Where-Object { !$_.Passed }).Count -eq 0
		Configuration = $Configuration
		Platform = $Platform
		ForbiddenPatterns = $forbiddenPatterns
		IgnoreProbePaths = $ignoreProbePaths
		TrackedGeneratedArtifacts = $trackedGeneratedArtifacts
		StagedGeneratedArtifacts = $stagedGeneratedArtifacts
		IgnoreFailures = $ignoreFailures
		Checks = $checks
	}

	if ($SummaryOnly) {
		$report = ConvertTo-HygieneSummary -Report $report
	}

	if ($Json) {
		$report | ConvertTo-Json -Depth 7
	} else {
		Write-Step "Checking tracked generated artifacts"
		Assert-NoMatches -Paths $tracked -Patterns $forbiddenPatterns -Label "Tracked files"

		Write-Step "Checking staged generated artifacts"
		Assert-NoMatches -Paths $staged -Patterns $forbiddenPatterns -Label "Staged files"

		Write-Step "Checking generated artifact ignore rules"
		if ($ignoreFailures.Count -gt 0) {
			throw "Expected generated artifact paths to be ignored:`n$($ignoreFailures -join "`n")"
		}
	}
} finally {
	Pop-Location
}

if (!$Json) {
	Write-Step "Artifact hygiene checks passed"
}

if (!$report.Passed) {
	exit 1
}
