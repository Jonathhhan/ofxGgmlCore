param()

$ErrorActionPreference = "Stop"

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

function Test-WindowsHost {
	return !($IsLinux -or $IsMacOS)
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$output = & (Join-Path $scriptRoot "doctor.ps1") *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "doctor smoke test failed."
}

Assert-Contains $output "ofxGgmlCore doctor" "doctor output"
Assert-Contains $output "addon root" "doctor output"
Assert-Contains $output "ggml runtime" "doctor output"
Assert-Contains $output "ofxGgmlSimpleExample" "doctor output"
Assert-Contains $output "ofxGgmlLlama companion" "doctor output"

if (Test-WindowsHost) {
	Assert-NotContains $output "./scripts/" "Windows doctor output"
} else {
	Assert-NotContains $output "scripts\" "shell doctor output"
}

Write-Host "==> Doctor smoke coverage passed"
