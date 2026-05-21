param(
	[string]$Repository = "",
	[string]$Category = "",
	[string]$OutputPath = "docs\HERMES_HANDOFF.md",
	[switch]$RunOnce,
	[switch]$Tui,
	[switch]$Gateway,
	[switch]$InstallScheduledTask,
	[switch]$Worktree,
	[switch]$AcceptHooks,
	[string]$Model = "",
	[string]$Provider = "",
	[string]$Toolsets = ""
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Add-OptionalArgument {
	param(
		[System.Collections.Generic.List[string]]$Arguments,
		[string]$Name,
		[string]$Value
	)
	if (![string]::IsNullOrWhiteSpace($Value)) {
		$Arguments.Add($Name)
		$Arguments.Add($Value)
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$handoffScript = Join-Path $scriptRoot "plan-hermes-handoff.ps1"

if (!(Get-Command "hermes" -ErrorAction SilentlyContinue)) {
	throw "Hermes was not found on PATH. Run the installed Hermes setup first, then retry from ofxGgmlCore."
}

$handoffParams = @{}
if (![string]::IsNullOrWhiteSpace($Repository)) {
	$handoffParams.Repository = $Repository
}
if (![string]::IsNullOrWhiteSpace($Category)) {
	$handoffParams.Category = $Category
}

Write-Step "Generating Hermes handoff"
& $handoffScript @handoffParams -OutputPath $OutputPath
if ($LASTEXITCODE -ne 0) {
	throw "plan-hermes-handoff.ps1 failed."
}

$jsonText = & $handoffScript @handoffParams -Json -SummaryOnly
if ($LASTEXITCODE -ne 0) {
	throw "plan-hermes-handoff.ps1 JSON handoff failed."
}
$handoff = $jsonText | ConvertFrom-Json

$targetPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
	$OutputPath
} else {
	Join-Path $repoRoot $OutputPath
}

Write-Step "Handoff ready: $targetPath"
Write-Host ""
Write-Host "Selected task:"
Write-Host "  $($handoff.SelectedTask.Repository) / $($handoff.SelectedTask.Category): $($handoff.SelectedTask.Task)"
Write-Host ""

if ($InstallScheduledTask) {
	Write-Step "Installing Hermes gateway Windows Scheduled Task"
	& hermes gateway install
	exit $LASTEXITCODE
}

if ($Gateway) {
	Write-Step "Starting Hermes gateway"
	$gatewayArgs = @("gateway", "run")
	if ($AcceptHooks) {
		$gatewayArgs += "--accept-hooks"
	}
	& hermes @gatewayArgs
	exit $LASTEXITCODE
}

$hermesArgs = [System.Collections.Generic.List[string]]::new()
$hermesArgs.Add("chat")
Add-OptionalArgument -Arguments $hermesArgs -Name "--model" -Value $Model
Add-OptionalArgument -Arguments $hermesArgs -Name "--provider" -Value $Provider
Add-OptionalArgument -Arguments $hermesArgs -Name "--toolsets" -Value $Toolsets
if ($Worktree) {
	$hermesArgs.Add("--worktree")
}
if ($AcceptHooks) {
	$hermesArgs.Add("--accept-hooks")
}

if ($RunOnce) {
	$prompt = @"
Use this ofxGgml Hermes handoff:
$targetPath

$($handoff.Prompt)
"@
	$hermesArgs.Add("--query")
	$hermesArgs.Add($prompt.Trim())
	Write-Step "Running Hermes once"
	& hermes @hermesArgs
	exit $LASTEXITCODE
}

if ($Tui) {
	$hermesArgs.Add("--tui")
	Write-Step "Starting Hermes TUI"
	& hermes @hermesArgs
	exit $LASTEXITCODE
}

Write-Host "Launch Hermes with:"
Write-Host "  hermes chat"
Write-Host ""
Write-Host "Or run the selected handoff once with:"
Write-Host "  scripts\start-hermes-agent.bat -RunOnce"
Write-Host ""
Write-Host "Optional gateway modes:"
Write-Host "  scripts\start-hermes-agent.bat -Gateway -AcceptHooks"
Write-Host "  scripts\start-hermes-agent.bat -InstallScheduledTask"
