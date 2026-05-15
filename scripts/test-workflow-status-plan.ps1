$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptRoot "generate-workflow-status-plan.py"
$testId = [guid]::NewGuid().ToString("N")
$outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-plan-$testId.md"
$repoOutputPath = Join-Path $scriptRoot "..\docs\workflow-status-plan.md"

if (Test-Path -LiteralPath $outputPath) {
	Remove-Item -LiteralPath $outputPath -Force
}
if (Test-Path -LiteralPath $repoOutputPath) {
	throw "workflow status plan test should not start with generated repo output: $repoOutputPath"
}

python $scriptPath --output $outputPath
if (!$?) {
	throw "generate-workflow-status-plan.py failed."
}

if (!(Test-Path -LiteralPath $outputPath -PathType Leaf)) {
	throw "workflow status plan was not written: $outputPath"
}
if (Test-Path -LiteralPath $repoOutputPath) {
	throw "workflow status plan test unexpectedly wrote repo output: $repoOutputPath"
}

$content = Get-Content -LiteralPath $outputPath -Raw
foreach ($expected in @(
	"Workflow Status Plan",
	"Expected workflow",
	"Scope",
	"Core release control",
	'| `Jonathhhan/ofxGgmlCore` | `core` | `release-gate` | Core release control | GitHub Actions |',
	'| `Jonathhhan/ofxGgmlLlama` | `text-chat-embeddings` | `addon-hygiene` | all managed repositories | GitHub Actions |'
)) {
	if ($content -notmatch [regex]::Escape($expected)) {
		throw "workflow status plan did not contain expected text: $expected"
	}
}

if ($content -match [regex]::Escape('| `Jonathhhan/ofxGgmlLlama` | `text-chat-embeddings` | `release-gate` |')) {
	throw "workflow status plan should not assign Core release-gate workflow to companion addons."
}

Remove-Item -LiteralPath $outputPath -Force
Write-Host "==> Workflow status plan coverage passed"
