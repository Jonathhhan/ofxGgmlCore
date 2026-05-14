$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-of-smoke-build.ps1"
$selectScript = Join-Path $scriptRoot "select-smoke-build-target.ps1"
$handoffScript = Join-Path $scriptRoot "plan-smoke-build-target-handoff.ps1"
$preflightScript = Join-Path $scriptRoot "check-smoke-build-target-preflight.ps1"
$postflightScript = Join-Path $scriptRoot "check-smoke-build-target-postflight.ps1"
$repairPlanScript = Join-Path $scriptRoot "plan-smoke-build-project-repair.ps1"
$compilePlanScript = Join-Path $scriptRoot "plan-smoke-build-compile.ps1"

$output = & $planScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-of-smoke-build.ps1 failed."
}

$text = $output -join "`n"
foreach ($expected in @(
	"openFrameworks Smoke Build Plan",
	"ProjectGenerator:",
	"Repository Plan",
	"Ready for project-generation checks",
	"Examples with addons.make",
	"Examples missing owner addon",
	"Examples with projectGenerator commands",
	"Generate-project targets",
	"Next Targets",
	"Example metadata",
	"ready-for-project-generation-check",
	"ofxGgmlCore",
	"ofxGgmlWorkflows",
	"Keep generated openFrameworks project files"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "openFrameworks smoke build plan output did not contain expected text: $expected"
	}
}

$jsonOutput = & $planScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-of-smoke-build.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Records -or $parsed.Records.Count -eq 0) {
	throw "openFrameworks smoke build plan JSON did not include records."
}

if ($null -eq $parsed.ProjectGeneratorPath) {
	throw "openFrameworks smoke build plan JSON did not include projectGenerator detection state."
}
$ofRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptRoot))
if (![string]::IsNullOrWhiteSpace([string]$parsed.ProjectGeneratorPath) -and
	(Test-Path -LiteralPath (Join-Path $ofRoot "projectGenerator\resources\app\app\projectGenerator.exe") -PathType Leaf) -and
	([string]$parsed.ProjectGeneratorPath -notmatch [regex]::Escape("projectGenerator\resources\app\app\projectGenerator.exe"))) {
	throw "openFrameworks smoke build plan did not prefer the command-line projectGenerator executable."
}

if (!$parsed.Targets -or $parsed.Targets.Count -eq 0) {
	throw "openFrameworks smoke build plan JSON did not include a target queue."
}

$ready = @($parsed.Records | Where-Object { $_.Phase -eq "ready-for-project-generation-check" })
if ($ready.Count -eq 0) {
	throw "openFrameworks smoke build plan did not find any project-generation candidates."
}

$examplesWithMetadata = @($parsed.Records | ForEach-Object { $_.ExampleMetadata } | Where-Object { $_.HasAddonsMake })
if ($examplesWithMetadata.Count -eq 0) {
	throw "openFrameworks smoke build plan did not report example addons.make metadata."
}

$missingMetadata = @($parsed.Records | ForEach-Object { $_.ExampleMetadata } | Where-Object {
	!$_.HasAddonsMake -or !$_.HasOwnerAddon -or !$_.HasCoreAddon
})
if ($missingMetadata.Count -gt 0) {
	throw "openFrameworks smoke build plan found examples missing addons.make, owner addon, or ofxGgmlCore references."
}

$examples = @($parsed.Records | ForEach-Object { $_.ExampleMetadata })
if ($examples.Count -eq 0) {
	throw "openFrameworks smoke build plan JSON did not include example metadata."
}

$missingGeneratedProjectState = @($examples | Where-Object { $null -eq $_.HasGeneratedProject })
if ($missingGeneratedProjectState.Count -gt 0) {
	throw "openFrameworks smoke build plan JSON did not include generated project state for every example."
}

if (![string]::IsNullOrWhiteSpace([string]$parsed.ProjectGeneratorPath)) {
	$commands = @($examples | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_.ProjectGeneratorCommand) })
	if ($commands.Count -eq 0) {
		throw "openFrameworks smoke build plan detected projectGenerator but did not emit example commands."
	}
	$missingVsPlatform = @($commands | Where-Object { [string]$_.ProjectGeneratorCommand -notmatch [regex]::Escape("-p'vs'") })
	if ($missingVsPlatform.Count -gt 0) {
		throw "openFrameworks smoke build plan emitted projectGenerator commands without the Visual Studio platform."
	}
	$generateTargets = @($parsed.Targets | Where-Object { $_.Stage -eq "generate-project" })
	if ($generateTargets.Count -eq 0) {
		throw "openFrameworks smoke build plan detected projectGenerator but did not identify project-generation targets."
	}
}

$targetOutput = & $selectScript -Stage "generate-project" -First 1 *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "select-smoke-build-target.ps1 failed."
}

$targetText = $targetOutput -join "`n"
foreach ($expected in @(
	"openFrameworks Smoke Build Target",
	"Stage filter: generate-project",
	"generate-project",
	"Commands"
)) {
	if ($targetText -notmatch [regex]::Escape($expected)) {
		throw "smoke build target selector output did not contain expected text: $expected"
	}
}

$targetJsonOutput = & $selectScript -Stage "generate-project" -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "select-smoke-build-target.ps1 -Json failed."
}

$targetParsed = ($targetJsonOutput -join "`n") | ConvertFrom-Json
if (!$targetParsed.Targets -or $targetParsed.Targets.Count -ne 1) {
	throw "smoke build target selector JSON did not include exactly one target."
}
if ($targetParsed.Targets[0].Stage -ne "generate-project") {
	throw "smoke build target selector returned the wrong target stage."
}

$handoffOutput = & $handoffScript -Stage "generate-project" -First 1 *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-target-handoff.ps1 failed."
}

$handoffText = $handoffOutput -join "`n"
foreach ($expected in @(
	"Smoke Build Target Handoff",
	"Targets",
	"Validation",
	"Guardrails",
	"Next Commands",
	"test-artifact-hygiene.ps1",
	"Do not commit generated openFrameworks project files"
)) {
	if ($handoffText -notmatch [regex]::Escape($expected)) {
		throw "smoke build target handoff output did not contain expected text: $expected"
	}
}

$handoffJsonOutput = & $handoffScript -Stage "generate-project" -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-target-handoff.ps1 -Json failed."
}

$handoffParsed = ($handoffJsonOutput -join "`n") | ConvertFrom-Json
if (!$handoffParsed.Targets -or $handoffParsed.Targets.Count -ne 1) {
	throw "smoke build target handoff JSON did not include exactly one target."
}
if (!$handoffParsed.Validation -or $handoffParsed.Validation.Count -eq 0) {
	throw "smoke build target handoff JSON did not include validation commands."
}
if (!$handoffParsed.NextCommands -or $handoffParsed.NextCommands.Count -eq 0) {
	throw "smoke build target handoff JSON did not include next commands."
}
if ([string]@($handoffParsed.NextCommands)[0] -ne "scripts\check-smoke-build-target-preflight.bat -Stage generate-project -First 1") {
	throw "smoke build target handoff JSON next commands did not start with preflight."
}
if (@($handoffParsed.NextCommands) -notcontains "scripts\test-of-smoke-build-plan.ps1") {
	throw "smoke build target handoff JSON next commands did not include smoke-build plan validation."
}
if (!$handoffParsed.TargetCommands -or $handoffParsed.TargetCommands.Count -eq 0) {
	throw "smoke build target handoff JSON did not include target commands."
}
if (!$handoffParsed.PostflightCommands -or $handoffParsed.PostflightCommands.Count -eq 0) {
	throw "smoke build target handoff JSON did not include postflight commands."
}
if (!$handoffParsed.RepairPlanCommands -or $handoffParsed.RepairPlanCommands.Count -eq 0) {
	throw "smoke build target handoff JSON did not include repair plan commands."
}
if ([string]::IsNullOrWhiteSpace([string]$handoffParsed.SafetyNote)) {
	throw "smoke build target handoff JSON did not include SafetyNote."
}

$preflightOutput = & $preflightScript -Stage "generate-project" -First 1 *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-preflight.ps1 failed."
}

$preflightText = $preflightOutput -join "`n"
foreach ($expected in @(
	"Smoke Build Target Preflight",
	"projectGenerator detected",
	"owning repository clean",
	"target stage matches filesystem",
	"Next Commands",
	"Ready:"
)) {
	if ($preflightText -notmatch [regex]::Escape($expected)) {
		throw "smoke build target preflight output did not contain expected text: $expected"
	}
}

$preflightJsonOutput = & $preflightScript -Stage "generate-project" -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-preflight.ps1 -Json failed."
}

$preflightParsed = ($preflightJsonOutput -join "`n") | ConvertFrom-Json
if (!$preflightParsed.Preflights -or $preflightParsed.Preflights.Count -ne 1) {
	throw "smoke build target preflight JSON did not include exactly one preflight."
}
if (!$preflightParsed.Preflights[0].Checks -or $preflightParsed.Preflights[0].Checks.Count -eq 0) {
	throw "smoke build target preflight JSON did not include checks."
}
if (!$preflightParsed.NextCommands -or $preflightParsed.NextCommands.Count -eq 0) {
	throw "smoke build target preflight JSON did not include next commands."
}
if ([string]::IsNullOrWhiteSpace([string]$preflightParsed.SafetyNote)) {
	throw "smoke build target preflight JSON did not include SafetyNote."
}
if ($preflightParsed.Preflights[0].Ready) {
	if (!$preflightParsed.ReadyCommands -or $preflightParsed.ReadyCommands.Count -eq 0) {
		throw "ready smoke build target preflight JSON did not include ready commands."
	}
	if (!$preflightParsed.PostflightCommands -or $preflightParsed.PostflightCommands.Count -eq 0) {
		throw "ready smoke build target preflight JSON did not include postflight commands."
	}
} elseif ([string]@($preflightParsed.NextCommands)[0] -notmatch "Preflight is blocked") {
	throw "blocked smoke build target preflight JSON did not start next commands with a blocked note."
}

$postflightOutput = & $postflightScript -Stage "generate-project" -First 1 *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-postflight.ps1 failed."
}

$postflightText = $postflightOutput -join "`n"
foreach ($expected in @(
	"Smoke Build Target Postflight",
	"generated project files",
	"generated project addon wiring",
	"owning repository git impact",
	"target stage completion",
	"Next Validation",
	"Next Commands"
)) {
	if ($postflightText -notmatch [regex]::Escape($expected)) {
		throw "smoke build target postflight output did not contain expected text: $expected"
	}
}

$postflightJsonOutput = & $postflightScript -Stage "generate-project" -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-postflight.ps1 -Json failed."
}

$postflightParsed = ($postflightJsonOutput -join "`n") | ConvertFrom-Json
if (!$postflightParsed.Postflights -or $postflightParsed.Postflights.Count -ne 1) {
	throw "smoke build target postflight JSON did not include exactly one postflight."
}
if (!$postflightParsed.Postflights[0].Checks -or $postflightParsed.Postflights[0].Checks.Count -eq 0) {
	throw "smoke build target postflight JSON did not include checks."
}
$projectWiringCheck = @($postflightParsed.Postflights[0].Checks | Where-Object { $_.Name -eq "generated project addon wiring" } | Select-Object -First 1)
if (!$projectWiringCheck) {
	throw "smoke build target postflight JSON did not include generated project addon wiring."
}
if (!$postflightParsed.NextCommands -or $postflightParsed.NextCommands.Count -eq 0) {
	throw "smoke build target postflight JSON did not include next commands."
}
if ([string]::IsNullOrWhiteSpace([string]$postflightParsed.SafetyNote)) {
	throw "smoke build target postflight JSON did not include SafetyNote."
}
if ($null -eq $postflightParsed.IncompleteTargets) {
	throw "smoke build target postflight JSON did not include IncompleteTargets."
}
if ($null -eq $postflightParsed.ReviewTargets) {
	throw "smoke build target postflight JSON did not include ReviewTargets."
}
if (@($postflightParsed.NextCommands) -notcontains "scripts\plan-of-smoke-build.bat") {
	throw "smoke build target postflight JSON next commands did not include smoke-build planning."
}
$nullGeneratedProjectFiles = @($postflightParsed.Postflights[0].GeneratedProjectFiles | Where-Object { $null -eq $_ -or [string]::IsNullOrWhiteSpace([string]$_) })
if ($nullGeneratedProjectFiles.Count -gt 0) {
	throw "smoke build target postflight JSON included null or empty generated project file entries."
}

$repairPlanOutput = & $repairPlanScript -Stage "verify-generated-project" -Repository "ofxGgmlCore" -Example "ofxGgmlSimpleExample" *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-project-repair.ps1 failed."
}
$repairPlanText = $repairPlanOutput -join "`n"
foreach ($expected in @(
	"Smoke Build Project Repair Plan",
	"ready-for-compile-validation",
	"Expected Addon References",
	"Combined Next Commands",
	"ofxGgmlCore",
	"ofxImGui"
)) {
	if ($repairPlanText -notmatch [regex]::Escape($expected)) {
		throw "smoke build project repair plan output did not contain expected text: $expected"
	}
}

$repairPlanJsonOutput = & $repairPlanScript -Stage "verify-generated-project" -Repository "ofxGgmlCore" -Example "ofxGgmlSimpleExample" -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-project-repair.ps1 -Json failed."
}
$repairPlanParsed = ($repairPlanJsonOutput -join "`n") | ConvertFrom-Json
if (!$repairPlanParsed.Repairs -or $repairPlanParsed.Repairs.Count -ne 1) {
	throw "smoke build project repair plan JSON did not include exactly one repair target."
}
if ($repairPlanParsed.Repairs[0].State -ne "ready-for-compile-validation") {
	throw "Core smoke build project repair plan did not report compile-validation readiness."
}
if ($repairPlanParsed.Applied) {
	throw "smoke build project repair plan dry-run JSON incorrectly reported Applied."
}
if (!$repairPlanParsed.Repairs[0].RepairResult) {
	throw "smoke build project repair plan JSON did not include repair result details."
}
if (!$repairPlanParsed.Repairs[0].ExpectedReferences -or $repairPlanParsed.Repairs[0].ExpectedReferences.Count -eq 0) {
	throw "smoke build project repair plan JSON did not include expected addon references."
}
if (!$repairPlanParsed.NextCommands -or $repairPlanParsed.NextCommands.Count -eq 0) {
	throw "smoke build project repair plan JSON did not include next commands."
}

$corePostflightJsonOutput = & $postflightScript -Stage "verify-generated-project" -Repository "ofxGgmlCore" -Example "ofxGgmlSimpleExample" -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-postflight.ps1 -Json failed for the Core generated project."
}
$corePostflightParsed = ($corePostflightJsonOutput -join "`n") | ConvertFrom-Json
$coreWiringCheck = @($corePostflightParsed.Postflights[0].Checks | Where-Object { $_.Name -eq "generated project addon wiring" } | Select-Object -First 1)
if (!$coreWiringCheck -or $coreWiringCheck.State -ne "OK") {
	throw "Core generated project postflight did not verify expected addon wiring."
}
if ($corePostflightParsed.Postflights[0].MissingProjectAddons.Count -gt 0) {
	throw "Core generated project postflight reported missing addon wiring."
}

$compilePlanOutput = & $compilePlanScript -Repository "ofxGgmlCore" -Example "ofxGgmlSimpleExample" *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-compile.ps1 failed."
}
$compilePlanText = $compilePlanOutput -join "`n"
foreach ($expected in @(
	"Smoke Build Compile Plan",
	"compile-example",
	"Compile Commands",
	"build-simple-example.bat",
	"test-artifact-hygiene.ps1"
)) {
	if ($compilePlanText -notmatch [regex]::Escape($expected)) {
		throw "smoke build compile plan output did not contain expected text: $expected"
	}
}

$compilePlanJsonOutput = & $compilePlanScript -Repository "ofxGgmlCore" -Example "ofxGgmlSimpleExample" -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-compile.ps1 -Json failed."
}
$compilePlanParsed = ($compilePlanJsonOutput -join "`n") | ConvertFrom-Json
if (!$compilePlanParsed.Targets -or $compilePlanParsed.Targets.Count -ne 1) {
	throw "smoke build compile plan JSON did not include exactly one target."
}
if ($compilePlanParsed.Targets[0].Stage -ne "compile-example") {
	throw "Core smoke build compile plan did not report compile-example readiness."
}
if ([string]$compilePlanParsed.Targets[0].CompileCommand -notmatch [regex]::Escape("build-simple-example.bat")) {
	throw "Core smoke build compile plan did not include the focused build command."
}
if (!$compilePlanParsed.NextCommands -or $compilePlanParsed.NextCommands.Count -eq 0) {
	throw "smoke build compile plan JSON did not include next commands."
}
