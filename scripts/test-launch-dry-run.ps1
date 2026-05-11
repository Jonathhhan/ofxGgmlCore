param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Invoke-DryRun {
	param(
		[string]$Label,
		[string]$Script,
		[hashtable]$Parameters
	)
	Write-Step $Label
	$previousDryRunOnly = $env:OFXGGML_LAUNCH_DRY_RUN_ONLY
	$env:OFXGGML_LAUNCH_DRY_RUN_ONLY = "1"
	try {
		$output = & $Script @Parameters *>&1 | ForEach-Object { $_.ToString() }
		if (!$?) {
			throw "$Label failed."
		}
	} finally {
		if ($null -eq $previousDryRunOnly) {
			Remove-Item Env:\OFXGGML_LAUNCH_DRY_RUN_ONLY -ErrorAction SilentlyContinue
		} else {
			$env:OFXGGML_LAUNCH_DRY_RUN_ONLY = $previousDryRunOnly
		}
	}
	return @($output)
}

function Assert-Contains {
	param(
		[string[]]$Output,
		[string]$Needle,
		[string]$Label
	)
	$text = $Output -join "`n"
	if ($text -notlike "*$Needle*") {
		throw "$Label did not contain expected text: $Needle`n$text"
	}
}

function Assert-NotContains {
	param(
		[string[]]$Output,
		[string]$Needle,
		[string]$Label
	)
	$text = $Output -join "`n"
	if ($text -like "*$Needle*") {
		throw "$Label contained unexpected text: $Needle`n$text"
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$simpleOutput = Invoke-DryRun `
	-Label "Simple example dry-run" `
	-Script (Join-Path $scriptRoot "run-simple-example.ps1") `
	-Parameters @{
		DryRun = $true
		Configuration = $Configuration
		Platform = $Platform
	}
Assert-Contains $simpleOutput "Executable:" "Simple dry-run"
Assert-NotContains $simpleOutput "Starting ofxGgmlSimpleExample" "Simple dry-run"

Write-Step "Launch dry-run smoke coverage passed"
