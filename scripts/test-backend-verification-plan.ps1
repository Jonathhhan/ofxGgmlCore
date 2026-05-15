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

Write-Host "Backend verification planning coverage passed"
