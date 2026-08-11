param()

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot

function Assert-FileContains {
	param(
		[string]$Path,
		[string]$Pattern,
		[string]$Label
	)
	if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label was not generated: $Path"
	}
	$content = Get-Content -LiteralPath $Path -Raw
	if ($content -notmatch $Pattern) {
		throw "$Label did not contain expected pattern: $Pattern"
	}
}

$temporaryCapabilityReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-capability-$([guid]::NewGuid().ToString('N')).md"
try {
	python (Join-Path $scriptRoot "generate-backend-capability-report.py") --output $temporaryCapabilityReport
	if ($LASTEXITCODE -ne 0) {
		throw "generate-backend-capability-report.py explicit output failed."
	}
	Assert-FileContains `
		-Path $temporaryCapabilityReport `
		-Pattern "phase-1 backend discovery evidence" `
		-Label "explicit backend capability report"
} finally {
	Remove-Item -LiteralPath $temporaryCapabilityReport -Force -ErrorAction SilentlyContinue
}

python (Join-Path $scriptRoot "generate-backend-capability-report.py")
if ($LASTEXITCODE -ne 0) {
	throw "generate-backend-capability-report.py failed."
}

python (Join-Path $scriptRoot "generate-backend-verification-plan.py")
if ($LASTEXITCODE -ne 0) {
	throw "generate-backend-verification-plan.py failed."
}

Assert-FileContains `
	-Path (Join-Path $addonRoot "docs\backend-capability-report.md") `
	-Pattern "phase-1 backend discovery evidence" `
	-Label "backend capability report"

Assert-FileContains `
	-Path (Join-Path $addonRoot "docs\backend-capability-report.md") `
	-Pattern "build-runtime-smoke.ps1" `
	-Label "backend capability report"

Assert-FileContains `
	-Path (Join-Path $addonRoot "docs\backend-verification-plan.md") `
	-Pattern "runtime-checked" `
	-Label "backend verification plan"

Assert-FileContains `
	-Path (Join-Path $addonRoot "docs\backend-verification-plan.md") `
	-Pattern "graph-smoke-checked" `
	-Label "backend verification plan"

Assert-FileContains `
	-Path (Join-Path $addonRoot "docs\backend-verification-plan.md") `
	-Pattern "backend-runtime-check" `
	-Label "backend verification plan"

Assert-FileContains `
	-Path (Join-Path $addonRoot "docs\backend-verification-plan.md") `
	-Pattern "plan-backend-runtime-verification" `
	-Label "backend verification plan"

Assert-FileContains `
	-Path (Join-Path $addonRoot "docs\backend-verification-plan.md") `
	-Pattern "Ecosystem implementation backlog" `
	-Label "backend verification plan"

Assert-FileContains `
	-Path (Join-Path $addonRoot "docs\backend-verification-plan.md") `
	-Pattern "ofxGgmlStableDiffusion" `
	-Label "backend verification plan"

$runtimePlan = Join-Path $scriptRoot "plan-backend-runtime-verification.ps1"
$temporaryCompileReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-smoke-build-compile-$([guid]::NewGuid().ToString('N')).json"
try {
	$fixture = [ordered]@{
		Outcome = "passed"
		Configuration = "Release"
		Platform = "x64"
		CompletedUtc = [DateTime]::UtcNow.ToString("o")
		Stages = @(
			[ordered]@{
				Name = "compile-example"
				Outcome = "passed"
				Targets = @(
					[ordered]@{
						Repository = "ofxGgmlStableDiffusion"
						Example = "ofxGgmlStableDiffusionBasicGenerationExample"
						Status = "passed"
						Commands = @()
					}
				)
			}
		)
	}
	Set-Content -LiteralPath $temporaryCompileReport -Value ($fixture | ConvertTo-Json -Depth 8) -Encoding utf8
	$runtimeJson = & $runtimePlan -SmokeBuildCiReport $temporaryCompileReport -Json
	if (!$?) {
		throw "plan-backend-runtime-verification.ps1 compile evidence fixture failed."
	}
	$runtime = $runtimeJson | ConvertFrom-Json
	if ($runtime.SmokeBuildCiEvidence.State -ne "available" -or $runtime.SmokeBuildCiEvidence.CompileTargetCount -ne 1) {
		throw "runtime planner did not expose the compile-example report evidence."
	}
	$stableDiffusion = @($runtime.Repositories | Where-Object { $_.Repository -eq "ofxGgmlStableDiffusion" } | Select-Object -First 1)
	$basicExample = @($stableDiffusion[0].ExampleBuildEvidence.Examples | Where-Object { $_.Example -eq "ofxGgmlStableDiffusionBasicGenerationExample" } | Select-Object -First 1)
	if (!$basicExample -or !$basicExample[0].CiCompilePassed -or !$basicExample[0].Built) {
		throw "runtime planner did not count passed CI compile evidence for the Stable Diffusion basic example."
	}
} finally {
	Remove-Item -LiteralPath $temporaryCompileReport -Force -ErrorAction SilentlyContinue
}

Write-Host "Backend verification planning coverage passed"
