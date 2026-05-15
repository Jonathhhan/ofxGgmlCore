$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$listScript = Join-Path $scriptRoot "list-models.ps1"

$textOutput = & $listScript *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "list-models.ps1 failed."
}
$text = $textOutput -join "`n"
foreach ($expected in @(
	"ofxGgmlCore model search",
	"Core does not require a model",
	"Search directories"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "model discovery output did not contain expected text: $expected"
	}
}

$jsonOutput = & $listScript -Json *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "list-models.ps1 -Json failed."
}

$parsed = ($jsonOutput -join "`n") | ConvertFrom-Json
if (!$parsed.Summary) {
	throw "model discovery JSON did not include Summary."
}
foreach ($property in @(
	"SearchDirectoryCount",
	"ExistingSearchDirectoryCount",
	"ModelCount",
	"TotalBytes",
	"TotalSize",
	"HasModels",
	"CoreRequiresModel"
)) {
	if (!$parsed.Summary.PSObject.Properties[$property]) {
		throw "model discovery JSON Summary did not include $property."
	}
}
if ($parsed.Summary.CoreRequiresModel) {
	throw "model discovery JSON should report that Core does not require a model."
}
if (!$parsed.SearchDirectories -or @($parsed.SearchDirectories).Count -eq 0) {
	throw "model discovery JSON did not include search directories."
}
if (!$parsed.NextCommands -or @($parsed.NextCommands).Count -eq 0) {
	throw "model discovery JSON did not include NextCommands."
}
if (@($parsed.NextCommands) -notcontains "scripts\list-models.bat -Json -SummaryOnly") {
	throw "model discovery JSON NextCommands did not include the compact structured command."
}
if ($parsed.SummaryOnly) {
	throw "model discovery full JSON unexpectedly reported SummaryOnly."
}

$summaryJsonOutput = & $listScript -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "list-models.ps1 -Json -SummaryOnly failed."
}

$summaryParsed = ($summaryJsonOutput -join "`n") | ConvertFrom-Json
if (!$summaryParsed.SummaryOnly) {
	throw "model discovery summary JSON did not report SummaryOnly."
}
if (!$summaryParsed.Summary -or !$summaryParsed.SearchDirectorySummaries) {
	throw "model discovery summary JSON did not retain compact summary evidence."
}
if ($summaryParsed.PSObject.Properties["Models"] -or $summaryParsed.PSObject.Properties["SearchDirectories"]) {
	throw "model discovery summary JSON should omit full models and search directories."
}
