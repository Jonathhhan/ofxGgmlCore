param(
	[string]$OutputPath = "",
	[switch]$SkipDoctorTests,
	[switch]$SummaryOnly,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function New-StepResult {
	param(
		[string]$Name,
		[string]$State,
		[string]$Detail = "",
		[string[]]$Output = @()
	)
	return [pscustomobject]@{
		Name = $Name
		State = $State
		Detail = $Detail
		Output = @($Output)
	}
}

function Invoke-ReadinessStep {
	param(
		[string]$Name,
		[string]$ScriptPath,
		[hashtable]$Parameters = @{}
	)

	if (!(Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
		return New-StepResult -Name $Name -State "FAIL" -Detail "missing script: $ScriptPath"
	}

	$output = & $ScriptPath @Parameters *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		return New-StepResult -Name $Name -State "FAIL" -Detail "exit code $LASTEXITCODE" -Output $output
	}
	return New-StepResult -Name $Name -State "OK" -Detail $ScriptPath -Output $output
}

function ConvertTo-MarkdownReadiness {
	param(
		[string]$Root,
		[array]$Steps,
		[array]$DoctorTests
	)

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# ofxGgml Ecosystem Readiness Check")
	$lines.Add("")
	$lines.Add("Non-mutating readiness pass for Codex, GitHub Copilot, Hermes Agent, and similar coding assistants.")
	$lines.Add("")
	$lines.Add("Root: $Root")
	$lines.Add("")
	$lines.Add("## Control Plane")
	$lines.Add("")
	$lines.Add("| Check | State | Detail |")
	$lines.Add("| --- | --- | --- |")
	foreach ($step in $Steps) {
		$lines.Add("| $($step.Name) | $($step.State) | $($step.Detail) |")
	}

	$lines.Add("")
	$lines.Add("## Doctor Smoke Tests")
	$lines.Add("")
	if ($SkipDoctorTests) {
		$lines.Add("Doctor smoke tests were skipped.")
	} else {
		$lines.Add("| Repository | State | Detail |")
		$lines.Add("| --- | --- | --- |")
		foreach ($test in $DoctorTests) {
			$lines.Add("| $($test.Name) | $($test.State) | $($test.Detail) |")
		}
	}

	$failed = @(@($Steps + $DoctorTests) | Where-Object { $_.State -ne "OK" })
	$lines.Add("")
	if ($failed.Count -eq 0) {
		$lines.Add("Readiness passed.")
	} else {
		$lines.Add("Readiness failed for: $(@($failed | ForEach-Object { $_.Name }) -join ', ').")
	}

	return $lines -join [Environment]::NewLine
}

function Test-WorkflowGuideCoverage {
	param([array]$Statuses)

	$managed = @($Statuses | Where-Object { $_.Known })
	$missing = @($managed | Where-Object { !$_.Present -or !$_.AgentWorkflowGuide })
	if ($missing.Count -gt 0) {
		return New-StepResult `
			-Name "workflow guide coverage" `
			-State "FAIL" `
			-Detail ("missing guides: {0}" -f (@($missing | ForEach-Object { $_.Name }) -join ", "))
	}

	return New-StepResult `
		-Name "workflow guide coverage" `
		-State "OK" `
		-Detail ("{0} managed workflow guides detected" -f $managed.Count)
}

function New-ReadinessSummary {
	param(
		[array]$Steps,
		[array]$DoctorTests
	)

	$failedSteps = @($Steps | Where-Object { $_.State -ne "OK" })
	$failedDoctorTests = @($DoctorTests | Where-Object { $_.State -ne "OK" })

	return [pscustomobject]@{
		TotalSteps = @($Steps).Count
		PassedSteps = @($Steps | Where-Object { $_.State -eq "OK" }).Count
		FailedSteps = $failedSteps.Count
		TotalDoctorTests = @($DoctorTests).Count
		PassedDoctorTests = @($DoctorTests | Where-Object { $_.State -eq "OK" }).Count
		FailedDoctorTests = $failedDoctorTests.Count
		FailedChecks = @(@($failedSteps + $failedDoctorTests) | ForEach-Object { [string]$_.Name })
	}
}

function ConvertTo-SummaryStepResult {
	param([object]$Step)

	$output = @()
	$outputOmitted = $false
	if ($Step.State -eq "OK" -and @($Step.Output).Count -gt 0) {
		$outputOmitted = $true
	} else {
		$output = @($Step.Output)
	}

	return [pscustomobject]@{
		Name = [string]$Step.Name
		State = [string]$Step.State
		Detail = [string]$Step.Detail
		OutputOmitted = $outputOmitted
		Output = @($output)
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreRoot = Split-Path -Parent $scriptRoot
$statusScript = Join-Path $scriptRoot "status-family.ps1"

$statusJson = & $statusScript -Json
if (!$?) {
	throw "status-family.ps1 failed."
}
$status = $statusJson | ConvertFrom-Json

$managedNames = @($status.Addons | Where-Object { $_.Known } | ForEach-Object { [string]$_.Name })
$releaseReadinessOutput = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-check.md"
$steps = @()
$steps += Test-WorkflowGuideCoverage -Statuses @($status.Addons)
$steps += Invoke-ReadinessStep -Name "agent instructions current" -ScriptPath (Join-Path $scriptRoot "write-agent-instructions.ps1") -Parameters @{
	Check = $true
	Addons = $managedNames
}
$steps += Invoke-ReadinessStep -Name "ecosystem audit strict" -ScriptPath (Join-Path $scriptRoot "audit-ecosystem.ps1") -Parameters @{
	Strict = $true
	Json = $true
	SummaryOnly = $true
}
$steps += Invoke-ReadinessStep -Name "ecosystem plan" -ScriptPath (Join-Path $scriptRoot "plan-ecosystem.ps1")
$steps += Invoke-ReadinessStep -Name "structured ecosystem plan" -ScriptPath (Join-Path $scriptRoot "plan-ecosystem.ps1") -Parameters @{
	Json = $true
	SummaryOnly = $true
}
$steps += Invoke-ReadinessStep -Name "coding agent work queue" -ScriptPath (Join-Path $scriptRoot "plan-coding-agent-work.ps1")
$steps += Invoke-ReadinessStep -Name "structured coding agent work queue" -ScriptPath (Join-Path $scriptRoot "plan-coding-agent-work.ps1") -Parameters @{
	Json = $true
}
$steps += Invoke-ReadinessStep -Name "openFrameworks smoke build plan" -ScriptPath (Join-Path $scriptRoot "plan-of-smoke-build.ps1")
$steps += Invoke-ReadinessStep -Name "openFrameworks smoke build target selection" -ScriptPath (Join-Path $scriptRoot "select-smoke-build-target.ps1") -Parameters @{
	Stage = "generate-project"
	First = 1
}
$steps += Invoke-ReadinessStep -Name "openFrameworks smoke build target handoff" -ScriptPath (Join-Path $scriptRoot "plan-smoke-build-target-handoff.ps1") -Parameters @{
	Stage = "generate-project"
	First = 1
}
$steps += Invoke-ReadinessStep -Name "openFrameworks smoke build target preflight" -ScriptPath (Join-Path $scriptRoot "check-smoke-build-target-preflight.ps1") -Parameters @{
	Stage = "generate-project"
	First = 1
}
$steps += Invoke-ReadinessStep -Name "openFrameworks smoke build target postflight" -ScriptPath (Join-Path $scriptRoot "check-smoke-build-target-postflight.ps1") -Parameters @{
	Stage = "generate-project"
	First = 1
}
$steps += Invoke-ReadinessStep -Name "openFrameworks smoke build project repair plan" -ScriptPath (Join-Path $scriptRoot "plan-smoke-build-project-repair.ps1") -Parameters @{
	Stage = "verify-generated-project"
	Repository = "ofxGgmlCore"
	Example = "ofxGgmlCoreExample"
}
$steps += Invoke-ReadinessStep -Name "openFrameworks smoke build compile plan" -ScriptPath (Join-Path $scriptRoot "plan-smoke-build-compile.ps1") -Parameters @{
	Repository = "ofxGgmlCore"
	Example = "ofxGgmlCoreExample"
}
$steps += Invoke-ReadinessStep -Name "release readiness plan" -ScriptPath (Join-Path $scriptRoot "plan-release-readiness.ps1") -Parameters @{
	OutputPath = $releaseReadinessOutput
	SkipWorkflowStatus = $true
}
$steps += Invoke-ReadinessStep -Name "doctor rollout plan" -ScriptPath (Join-Path $scriptRoot "plan-doctor-rollout.ps1") -Parameters @{
	Json = $true
	SummaryOnly = $true
}
$steps += Invoke-ReadinessStep -Name "agent branch cleanup plan" -ScriptPath (Join-Path $scriptRoot "plan-agent-branch-cleanup.ps1") -Parameters @{
	Json = $true
	SummaryOnly = $true
}

$doctorTests = @()
if (!$SkipDoctorTests) {
	foreach ($repo in @($status.Addons | Where-Object { $_.Known -and $_.Present -and $_.DoctorScript -and $_.Name -ne "ofxGgmlWorkflows" })) {
		$tests = @(
			Get-ChildItem -LiteralPath (Join-Path $repo.Path "scripts") -Filter "test-doctor*.ps1" -File -ErrorAction SilentlyContinue |
				Where-Object { $_.Name -ne "test-doctor-rollout-plan.ps1" } |
				Sort-Object Name
		)
		if ($tests.Count -eq 0) {
			$doctorTests += New-StepResult -Name $repo.Name -State "FAIL" -Detail "missing test-doctor*.ps1"
			continue
		}
		foreach ($test in $tests) {
			$doctorTests += Invoke-ReadinessStep -Name $repo.Name -ScriptPath $test.FullName
		}
	}
}

$failed = @(@($steps + $doctorTests) | Where-Object { $_.State -ne "OK" })
$summary = New-ReadinessSummary -Steps $steps -DoctorTests $doctorTests

if ($Json) {
	$jsonSteps = @($steps)
	$jsonDoctorTests = @($doctorTests)
	if ($SummaryOnly) {
		$jsonSteps = @($steps | ForEach-Object { ConvertTo-SummaryStepResult -Step $_ })
		$jsonDoctorTests = @($doctorTests | ForEach-Object { ConvertTo-SummaryStepResult -Step $_ })
	}

	$content = [pscustomobject]@{
		Root = [string]$status.Root
		SummaryOnly = [bool]$SummaryOnly
		Summary = $summary
		Passed = ($failed.Count -eq 0)
		Steps = $jsonSteps
		DoctorTests = $jsonDoctorTests
	} | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownReadiness -Root ([string]$status.Root) -Steps $steps -DoctorTests $doctorTests
}

if (![string]::IsNullOrWhiteSpace($OutputPath)) {
	$target = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
		$OutputPath
	} else {
		Join-Path $coreRoot $OutputPath
	}
	$directory = Split-Path -Parent $target
	if (!(Test-Path -LiteralPath $directory -PathType Container)) {
		New-Item -ItemType Directory -Path $directory -Force | Out-Null
	}
	Set-Content -LiteralPath $target -Value $content
	Write-Host "Wrote $target"
} else {
	Write-Output $content
}

if ($failed.Count -gt 0) {
	exit 1
}
