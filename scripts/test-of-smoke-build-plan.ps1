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
if (!$parsed.Summary) {
	throw "openFrameworks smoke build plan JSON did not include Summary."
}
foreach ($property in @(
	"ManagedRecords",
	"ReadyForProjectGenerationChecks",
	"WorkflowOnlyRecords",
	"MissingLocalValidation",
	"MissingRootExampleInventory",
	"ExamplesWithAddonsMake",
	"ExamplesMissingOwnerAddon",
	"ExamplesMissingCoreAddon",
	"ExamplesWithProjectGeneratorCommands",
	"ExamplesWithGeneratedProjectFiles",
	"GenerateProjectTargets",
	"VerifyGeneratedProjectTargets"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "openFrameworks smoke build plan JSON Summary did not include $property."
	}
}
if ($parsed.Summary.ManagedRecords -lt 11) {
	throw "openFrameworks smoke build plan JSON Summary did not count managed records."
}
if ($parsed.Summary.ReadyForProjectGenerationChecks -eq 0) {
	throw "openFrameworks smoke build plan JSON Summary did not report project-generation candidates."
}
if (!$parsed.NextCommands -or @($parsed.NextCommands).Count -eq 0) {
	throw "openFrameworks smoke build plan JSON did not include NextCommands."
}
if (@($parsed.NextCommands) -notcontains "scripts\plan-smoke-build-target-handoff.bat -Stage generate-project") {
	throw "openFrameworks smoke build plan JSON NextCommands did not include target handoff."
}
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
	$verifyTargets = @($parsed.Targets | Where-Object { $_.Stage -eq "verify-generated-project" })
	if ($generateTargets.Count -eq 0 -and $verifyTargets.Count -eq 0) {
		throw "openFrameworks smoke build plan detected projectGenerator but did not identify project-generation or verification targets."
	}
}

$targetStage = if (@($parsed.Targets | Where-Object { $_.Stage -eq "generate-project" }).Count -gt 0) { "generate-project" } else { "verify-generated-project" }

$targetOutput = & $selectScript -Stage $targetStage -First 1 *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "select-smoke-build-target.ps1 failed."
}

$targetText = $targetOutput -join "`n"
foreach ($expected in @(
	"openFrameworks Smoke Build Target",
	"Stage filter: $targetStage",
	$targetStage,
	"Commands"
)) {
	if ($targetText -notmatch [regex]::Escape($expected)) {
		throw "smoke build target selector output did not contain expected text: $expected"
	}
}

$targetJsonOutput = & $selectScript -Stage $targetStage -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "select-smoke-build-target.ps1 -Json failed."
}

$targetParsed = ($targetJsonOutput -join "`n") | ConvertFrom-Json
if (!$targetParsed.Summary) {
	throw "smoke build target selector JSON did not include Summary."
}
foreach ($property in @(
	"TotalTargets",
	"FilteredTargets",
	"SelectedTargets",
	"StageFilter",
	"SelectedStage",
	"ProjectGeneratorDetected",
	"HasSelection",
	"SelectedTargetsWithCommands"
)) {
	if (!$targetParsed.Summary.PSObject.Properties[$property]) {
		throw "smoke build target selector JSON Summary did not include $property."
	}
}
if ($targetParsed.Summary.SelectedTargets -ne 1 -or !$targetParsed.Summary.HasSelection) {
	throw "smoke build target selector JSON Summary did not report the selected target."
}
if (!$targetParsed.NextCommands -or @($targetParsed.NextCommands).Count -eq 0) {
	throw "smoke build target selector JSON did not include NextCommands."
}
if (@($targetParsed.NextCommands) -notcontains "scripts\plan-smoke-build-target-handoff.bat -Stage $targetStage -First 1") {
	throw "smoke build target selector JSON NextCommands did not include the target handoff command."
}
if (!$targetParsed.Targets -or $targetParsed.Targets.Count -ne 1) {
	throw "smoke build target selector JSON did not include exactly one target."
}
if ($targetParsed.Targets[0].Stage -ne $targetStage) {
	throw "smoke build target selector returned the wrong target stage."
}

$targetSummaryJsonOutput = & $selectScript -Stage $targetStage -First 1 -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "select-smoke-build-target.ps1 -Json -SummaryOnly failed."
}
$targetSummaryParsed = ($targetSummaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$targetSummaryParsed.SummaryOnly -or !$targetSummaryParsed.TargetSummaries) {
	throw "smoke build target selector summary JSON did not report compact target summaries."
}
if ($targetSummaryParsed.PSObject.Properties["Targets"]) {
	throw "smoke build target selector summary JSON should omit full Targets."
}

$handoffOutput = & $handoffScript -Stage $targetStage -First 1 *>&1 | ForEach-Object { $_.ToString() }
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

$handoffJsonOutput = & $handoffScript -Stage $targetStage -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-target-handoff.ps1 -Json failed."
}

$handoffParsed = ($handoffJsonOutput -join "`n") | ConvertFrom-Json
if (!$handoffParsed.Summary) {
	throw "smoke build target handoff JSON did not include Summary."
}
foreach ($property in @(
	"Stage",
	"RequestedTargets",
	"SelectedTargets",
	"TargetCommands",
	"PostflightCommands",
	"RepairPlanCommands",
	"ValidationCommands",
	"Guardrails",
	"NextCommands",
	"HasSelection",
	"ProjectGeneratorDetected"
)) {
	if (!$handoffParsed.Summary.PSObject.Properties[$property]) {
		throw "smoke build target handoff JSON Summary did not include $property."
	}
}
if ($handoffParsed.Summary.SelectedTargets -ne 1 -or !$handoffParsed.Summary.HasSelection) {
	throw "smoke build target handoff JSON Summary did not report the selected target."
}
if ($handoffParsed.Summary.NextCommands -eq 0 -or $handoffParsed.Summary.ValidationCommands -eq 0) {
	throw "smoke build target handoff JSON Summary did not count commands."
}
if (!$handoffParsed.Targets -or $handoffParsed.Targets.Count -ne 1) {
	throw "smoke build target handoff JSON did not include exactly one target."
}
if (!$handoffParsed.Validation -or $handoffParsed.Validation.Count -eq 0) {
	throw "smoke build target handoff JSON did not include validation commands."
}
if (!$handoffParsed.NextCommands -or $handoffParsed.NextCommands.Count -eq 0) {
	throw "smoke build target handoff JSON did not include next commands."
}
if ([string]@($handoffParsed.NextCommands)[0] -ne "scripts\check-smoke-build-target-preflight.bat -Stage $targetStage -First 1") {
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

$handoffSummaryJsonOutput = & $handoffScript -Stage $targetStage -First 1 -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-target-handoff.ps1 -Json -SummaryOnly failed."
}
$handoffSummaryParsed = ($handoffSummaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$handoffSummaryParsed.SummaryOnly -or !$handoffSummaryParsed.TargetSummaries) {
	throw "smoke build target handoff summary JSON did not report compact target summaries."
}
foreach ($omitted in @("Targets", "TargetCommands", "PostflightCommands", "RepairPlanCommands", "Validation", "Guardrails")) {
	if ($handoffSummaryParsed.PSObject.Properties[$omitted]) {
		throw "smoke build target handoff summary JSON should omit $omitted."
	}
}
if (!$handoffSummaryParsed.NextCommands -or [string]::IsNullOrWhiteSpace([string]$handoffSummaryParsed.SafetyNote)) {
	throw "smoke build target handoff summary JSON did not retain next commands and safety note."
}

$preflightOutput = & $preflightScript -Stage $targetStage -First 1 *>&1 | ForEach-Object { $_.ToString() }
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

$preflightJsonOutput = & $preflightScript -Stage $targetStage -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-preflight.ps1 -Json failed."
}

$preflightParsed = ($preflightJsonOutput -join "`n") | ConvertFrom-Json
if (!$preflightParsed.Summary) {
	throw "smoke build target preflight JSON did not include Summary."
}
foreach ($property in @(
	"Stage",
	"RequestedTargets",
	"SelectedTargets",
	"ReadyTargets",
	"BlockedTargets",
	"ReadyCommands",
	"PostflightCommands",
	"NextCommands",
	"HasSelection",
	"ProjectGeneratorDetected"
)) {
	if (!$preflightParsed.Summary.PSObject.Properties[$property]) {
		throw "smoke build target preflight JSON Summary did not include $property."
	}
}
if ($preflightParsed.Summary.SelectedTargets -ne 1 -or !$preflightParsed.Summary.HasSelection) {
	throw "smoke build target preflight JSON Summary did not report the selected target."
}
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

$preflightSummaryJsonOutput = & $preflightScript -Stage $targetStage -First 1 -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-preflight.ps1 -Json -SummaryOnly failed."
}
$preflightSummaryParsed = ($preflightSummaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$preflightSummaryParsed.SummaryOnly -or !$preflightSummaryParsed.PreflightSummaries) {
	throw "smoke build target preflight summary JSON did not report compact preflight summaries."
}
if ($preflightSummaryParsed.PSObject.Properties["Preflights"]) {
	throw "smoke build target preflight summary JSON should omit full Preflights."
}

$postflightOutput = & $postflightScript -Stage $targetStage -First 1 *>&1 | ForEach-Object { $_.ToString() }
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

$postflightJsonOutput = & $postflightScript -Stage $targetStage -First 1 -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-postflight.ps1 -Json failed."
}

$postflightParsed = ($postflightJsonOutput -join "`n") | ConvertFrom-Json
if (!$postflightParsed.Summary) {
	throw "smoke build target postflight JSON did not include Summary."
}
foreach ($property in @(
	"Stage",
	"RequestedTargets",
	"SelectedTargets",
	"CompleteTargets",
	"IncompleteTargets",
	"ReviewTargets",
	"GeneratedProjectFiles",
	"MissingProjectAddons",
	"NextCommands",
	"HasSelection"
)) {
	if (!$postflightParsed.Summary.PSObject.Properties[$property]) {
		throw "smoke build target postflight JSON Summary did not include $property."
	}
}
if ($postflightParsed.Summary.SelectedTargets -ne 1 -or !$postflightParsed.Summary.HasSelection) {
	throw "smoke build target postflight JSON Summary did not report the selected target."
}
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

$postflightSummaryJsonOutput = & $postflightScript -Stage $targetStage -First 1 -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "check-smoke-build-target-postflight.ps1 -Json -SummaryOnly failed."
}
$postflightSummaryParsed = ($postflightSummaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$postflightSummaryParsed.SummaryOnly -or !$postflightSummaryParsed.PostflightSummaries) {
	throw "smoke build target postflight summary JSON did not report compact postflight summaries."
}
if ($postflightSummaryParsed.PSObject.Properties["Postflights"]) {
	throw "smoke build target postflight summary JSON should omit full Postflights."
}

$repairPlanOutput = & $repairPlanScript -Stage "verify-generated-project" -Repository "ofxGgmlCore" -Example "ofxGgmlCoreExample" *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-project-repair.ps1 failed."
}
$repairPlanText = $repairPlanOutput -join "`n"
foreach ($expected in @(
	"Smoke Build Project Repair Plan",
	"ready-for-compile-validation",
	"Expected Addon References",
	"Planned libraries",
	"Combined Next Commands",
	"ofxGgmlCore",
	"ofxImGui"
)) {
	if ($repairPlanText -notmatch [regex]::Escape($expected)) {
		throw "smoke build project repair plan output did not contain expected text: $expected"
	}
}

$repairPlanJsonOutput = & $repairPlanScript -Stage "verify-generated-project" -Repository "ofxGgmlCore" -Example "ofxGgmlCoreExample" -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-project-repair.ps1 -Json failed."
}
$repairPlanParsed = ($repairPlanJsonOutput -join "`n") | ConvertFrom-Json
if (!$repairPlanParsed.Summary) {
	throw "smoke build project repair plan JSON did not include Summary."
}
foreach ($property in @(
	"Stage",
	"RequestedTargets",
	"SelectedTargets",
	"ReadyForCompileValidation",
	"NeedsProjectGeneration",
	"NeedsAddonWiringRepair",
	"ReviewGeneratedProject",
	"NeedsAction",
	"PlannedRepairChanges",
	"MissingProjectAddons",
	"NextCommands",
	"Applied",
	"HasSelection"
)) {
	if (!$repairPlanParsed.Summary.PSObject.Properties[$property]) {
		throw "smoke build project repair plan JSON Summary did not include $property."
	}
}
if ($repairPlanParsed.Summary.SelectedTargets -ne 1 -or !$repairPlanParsed.Summary.HasSelection) {
	throw "smoke build project repair plan JSON Summary did not report the selected target."
}
if ($repairPlanParsed.Summary.ReadyForCompileValidation -ne 1 -or $repairPlanParsed.Summary.NeedsAction -ne 0) {
	throw "Core smoke build project repair plan JSON Summary did not report compile-validation readiness."
}
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

$corePostflightJsonOutput = & $postflightScript -Stage "verify-generated-project" -Repository "ofxGgmlCore" -Example "ofxGgmlCoreExample" -Json *>&1 | ForEach-Object { $_.ToString() }
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

$compilePlanOutput = & $compilePlanScript -Repository "ofxGgmlCore" -Example "ofxGgmlCoreExample" *>&1 | ForEach-Object { $_.ToString() }
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

$compilePlanJsonOutput = & $compilePlanScript -Repository "ofxGgmlCore" -Example "ofxGgmlCoreExample" -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-compile.ps1 -Json failed."
}
$compilePlanParsed = ($compilePlanJsonOutput -join "`n") | ConvertFrom-Json
if (!$compilePlanParsed.Summary) {
	throw "smoke build compile plan JSON did not include Summary."
}
foreach ($property in @(
	"Stage",
	"RequestedTargets",
	"SelectedTargets",
	"AllTargets",
	"CompileReadyTargets",
	"RepairTargets",
	"MissingCommandTargets",
	"NextCommands",
	"HasSelection",
	"Configuration",
	"Platform"
)) {
	if (!$compilePlanParsed.Summary.PSObject.Properties[$property]) {
		throw "smoke build compile plan JSON Summary did not include $property."
	}
}
if ($compilePlanParsed.Summary.SelectedTargets -ne 1 -or !$compilePlanParsed.Summary.HasSelection) {
	throw "smoke build compile plan JSON Summary did not report the selected target."
}
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

$genericCompilePlanJsonOutput = & $compilePlanScript -Repository "ofxGgmlSam" -Example "ofxGgmlSamPointExample" -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "plan-smoke-build-compile.ps1 -Json failed for a generic smoke example target."
}
$genericCompilePlanParsed = ($genericCompilePlanJsonOutput -join "`n") | ConvertFrom-Json
if (!$genericCompilePlanParsed.Targets -or $genericCompilePlanParsed.Targets.Count -ne 1) {
	throw "generic smoke build compile plan JSON did not include exactly one target."
}
if ($genericCompilePlanParsed.Targets[0].CompleteGeneratedProject -and
	$genericCompilePlanParsed.Targets[0].Stage -ne "compile-example") {
	throw "generic smoke build compile plan did not promote a complete generated project to compile-example."
}
if ($genericCompilePlanParsed.Targets[0].CompleteGeneratedProject -and
	[string]$genericCompilePlanParsed.Targets[0].CompileCommand -notmatch [regex]::Escape("build-smoke-example.bat")) {
	throw "generic smoke build compile plan did not include the generic build command."
}
