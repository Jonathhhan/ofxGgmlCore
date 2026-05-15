$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot "smoke-build-ci-report.ps1")

$report = [pscustomobject]@{
	Configuration = "Release"
	Platform = "x64"
	StageCount = 2
	TargetsRun = 2
	Outcome = "passed"
	Stages = @(
		[pscustomobject]@{
			Name = "repair-generated-project"
			Outcome = "passed"
			Targets = @(
				[pscustomobject]@{
					Repository = "ofxGgmlCore"
					Example = "ofxGgmlCoreExample"
					Status = "passed"
					Commands = @(
						[pscustomobject]@{
							Command = "scripts\plan-smoke-build-project-repair.bat"
							Status = "passed"
							ExitCode = 0
						}
					)
				}
			)
		},
		[pscustomobject]@{
			Name = "compile-example"
			Outcome = "passed"
			Targets = @(
				[pscustomobject]@{
					Repository = "ofxGgmlCore"
					Example = "ofxGgmlCoreExample"
					Status = "passed"
					Commands = @(
						[pscustomobject]@{
							Command = "scripts\build-simple-example.bat"
							Status = "passed"
							ExitCode = 0
						}
					)
				}
			)
		}
	)
}

$summary = Get-SmokeBuildCiReportSummary -Report $report
foreach ($property in @(
	"Outcome",
	"Configuration",
	"Platform",
	"StageCount",
	"ReportedStages",
	"TargetsRun",
	"ReportedTargets",
	"FailedTargets",
	"CommandsRun",
	"FailedCommands",
	"StageNames",
	"FailedStageNames",
	"HasFailures"
)) {
	if (!$summary.PSObject.Properties[$property]) {
		throw "smoke-build CI report Summary did not include $property."
	}
}

if ($summary.Outcome -ne "passed" -or $summary.HasFailures) {
	throw "smoke-build CI report Summary did not report a passing synthetic report."
}
if ($summary.ReportedStages -ne 2 -or $summary.ReportedTargets -ne 2 -or $summary.CommandsRun -ne 2) {
	throw "smoke-build CI report Summary did not count stages, targets, and commands."
}
if (@($summary.StageNames) -notcontains "compile-example") {
	throw "smoke-build CI report Summary did not include stage names."
}

$failedReport = $report.PSObject.Copy()
$failedReport.Outcome = "failed"
$failedReport.Stages[1].Outcome = "failed"
$failedReport.Stages[1].Targets[0].Status = "failed"
$failedReport.Stages[1].Targets[0].Commands[0].Status = "failed"
$failedReport.Stages[1].Targets[0].Commands[0].ExitCode = 1

$failedSummary = Get-SmokeBuildCiReportSummary -Report $failedReport
if (!$failedSummary.HasFailures -or $failedSummary.FailedTargets -ne 1 -or $failedSummary.FailedCommands -ne 1) {
	throw "smoke-build CI report Summary did not report failures."
}
if (@($failedSummary.FailedStageNames) -notcontains "compile-example") {
	throw "smoke-build CI report Summary did not include failed stage names."
}

$genericListReport = @{
	Configuration = "Release"
	Platform = "x64"
	StageCount = 1
	TargetsRun = 1
	Outcome = "passed"
	Stages = New-Object System.Collections.Generic.List[object]
}
$genericListStage = @{
	Name = "generate-project"
	Outcome = "passed"
	Targets = New-Object System.Collections.Generic.List[object]
}
$genericListTarget = @{
	Repository = "ofxGgmlCore"
	Example = "ofxGgmlCoreExample"
	Status = "passed"
	Commands = @(
		[pscustomobject]@{
			Command = "scripts\check-smoke-build-target-postflight.bat"
			Status = "passed"
			ExitCode = 0
		}
	)
}
[void]$genericListStage.Targets.Add($genericListTarget)
[void]$genericListReport.Stages.Add($genericListStage)

$genericListSummary = Get-SmokeBuildCiReportSummary -Report $genericListReport
if ($genericListSummary.ReportedStages -ne 1 -or $genericListSummary.ReportedTargets -ne 1 -or $genericListSummary.CommandsRun -ne 1) {
	throw "smoke-build CI report Summary did not count generic-list report entries."
}
if ($genericListSummary.HasFailures) {
	throw "smoke-build CI report Summary reported failures for a passing generic-list report."
}

Write-Host "==> Smoke-build CI report summary coverage passed"
