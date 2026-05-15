param(
	[switch]$Json,
	[switch]$SummaryOnly,
	[switch]$Strict
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")
$addonParent = Split-Path -Parent $addonRoot

function Format-Size {
	param([long]$Bytes)
	if ($Bytes -ge 1GB) {
		return "{0:N2} GB" -f ($Bytes / 1GB)
	}
	if ($Bytes -ge 1MB) {
		return "{0:N1} MB" -f ($Bytes / 1MB)
	}
	if ($Bytes -ge 1KB) {
		return "{0:N1} KB" -f ($Bytes / 1KB)
	}
	return "$Bytes B"
}

function Get-UniqueDirectories {
	param([string[]]$Directories)
	$seen = @{}
	foreach ($directory in $Directories) {
		if ([string]::IsNullOrWhiteSpace($directory)) {
			continue
		}
		$fullPath = [System.IO.Path]::GetFullPath($directory)
		$key = $fullPath.ToLowerInvariant()
		if (!$seen.ContainsKey($key)) {
			$seen[$key] = $true
			$fullPath
		}
	}
}

$directories = Get-UniqueDirectories @(
	(Join-Path $addonRoot "models"),
	(Join-Path $addonParent "models")
)

$models = New-Object System.Collections.Generic.List[object]
foreach ($directory in $directories) {
	if (!(Test-Path -LiteralPath $directory -PathType Container)) {
		continue
	}
	Get-ChildItem -LiteralPath $directory -Filter "*.gguf" -File -ErrorAction SilentlyContinue |
		Sort-Object Name |
		ForEach-Object {
			$models.Add([pscustomobject]@{
				Name = $_.Name
				Path = $_.FullName
				Directory = $directory
				Bytes = [long]$_.Length
				Size = Format-Size $_.Length
			})
		}
}

$existingDirectories = @($directories | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
$totalBytes = [long]0
$modelArray = @($models.ToArray())
foreach ($model in $modelArray) {
	$totalBytes += [long]$model.Bytes
}
$summary = [pscustomobject]@{
	SearchDirectoryCount = @($directories).Count
	ExistingSearchDirectoryCount = $existingDirectories.Count
	ModelCount = $models.Count
	TotalBytes = $totalBytes
	TotalSize = Format-Size $totalBytes
	HasModels = $models.Count -gt 0
	CoreRequiresModel = $false
}
$nextCommands = New-Object System.Collections.Generic.List[string]
$nextCommands.Add("scripts\list-models.bat -Json -SummaryOnly")
$nextCommands.Add("scripts\validate-local.bat")
$nextCommands.Add("cd ..\ofxGgmlLlama && scripts\list-models.bat")

if ($Json) {
	$result = [ordered]@{
		Root = $addonRoot.Path
		SummaryOnly = [bool]$SummaryOnly
		Summary = $summary
		NextCommands = @($nextCommands.ToArray())
	}
	if (!$SummaryOnly) {
		$result.SearchDirectories = @($directories)
		$result.ExistingSearchDirectories = $existingDirectories
		$result.Models = $modelArray
	} else {
		$result.SearchDirectorySummaries = @($directories | ForEach-Object {
			[pscustomobject]@{
				Path = [string]$_
				Exists = Test-Path -LiteralPath $_ -PathType Container
			}
		})
	}
	[pscustomobject]$result | ConvertTo-Json -Depth 4
} else {
	Write-Host "ofxGgmlCore model search"
	Write-Host "Root  $addonRoot"
	Write-Host ""
	Write-Host "Core does not require a model. Text, chat, and embedding model workflows live in ofxGgmlLlama."
	Write-Host ""
	Write-Host "Search directories:"
	foreach ($directory in $directories) {
		$exists = Test-Path -LiteralPath $directory -PathType Container
		Write-Host ("  [{0}] {1}" -f ($(if ($exists) { "x" } else { " " }), $directory))
	}
	Write-Host ""
	if ($models.Count -eq 0) {
		Write-Host "No GGUF models found."
	} else {
		Write-Host "Models:"
		foreach ($model in $models) {
			Write-Host ("  {0}  {1}" -f $model.Size.PadLeft(9), $model.Path)
		}
	}
}

if ($Strict -and $models.Count -eq 0) {
	exit 1
}
