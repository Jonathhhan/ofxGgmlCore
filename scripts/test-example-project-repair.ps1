param(
	[string[]]$Examples = @(
		"ofxGgmlSimpleExample"
	),
	[string]$Configuration = "Release",
	[string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Test-WindowsHost {
	return !($IsLinux -or $IsMacOS)
}

function Test-ExampleUsesAddon {
	param(
		[string]$ExampleDir,
		[string]$AddonName
	)
	$addonsMake = Join-Path $ExampleDir "addons.make"
	if (!(Test-Path -LiteralPath $addonsMake)) {
		return $false
	}
	return @(
		Get-Content -LiteralPath $addonsMake |
			ForEach-Object { $_.Trim() } |
			Where-Object { $_ -eq $AddonName }
	).Count -gt 0
}

function Test-GeneratedAddonPath {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path)) {
		return $false
	}

	$normalized = $Path -replace "/", "\"
	return ($normalized -match '(^|\\)libs\\ggml\\\.source(\\|$)') -or
		($normalized -match '(^|\\)libs\\ggml\\build[^\\]*(\\|$)') -or
		($normalized -match '(^|\\)libs\\llama(\\|$)') -or
		($normalized -match '(^|\\)libs\\llama\.cpp(\\|$)') -or
		($normalized -match '(^|\\)libs\\llama\.cpp\\\.source(\\|$)') -or
		($normalized -match '(^|\\)libs\\llama\.cpp\\build[^\\]*(\\|$)') -or
		($normalized -match '(^|\\)libs\\sam3(\\|$)') -or
		($normalized -match '(^|\\)libs\\sam3\.cpp(\\|$)') -or
		($normalized -match '(^|\\)libs\\sam3\.cpp\\build[^\\]*(\\|$)') -or
		($normalized -match '(^|\\)libs\\sam3\.cpp\\(ggml|examples|media|scripts|tests)(\\|$)') -or
		($normalized -match '(^|\\)libs\\sam3\.cpp\\sam3\.cpp$')
}

function Test-StaleAddonLibrary {
	param([string]$Library)
	if ([string]::IsNullOrWhiteSpace($Library)) {
		return $false
	}

	$name = [System.IO.Path]::GetFileName(($Library -replace '"', '').Trim())
	return $name -in @(
		"llama.lib",
		"llama-common.lib",
		"llama-common-base.lib",
		"sam3.lib"
	)
}

function New-MsBuildNamespace {
	param([xml]$Doc)
	$namespace = New-Object System.Xml.XmlNamespaceManager -ArgumentList $Doc.NameTable
	[void]$namespace.AddNamespace("msb", "http://schemas.microsoft.com/developer/msbuild/2003")
	return ,$namespace
}

function Assert-ProjectMetadata {
	param(
		[string]$Example,
		[string]$Project,
		[string]$Filters
	)

	[xml]$projectDoc = Get-Content -LiteralPath $Project -Raw
	[System.Xml.XmlNamespaceManager]$projectNs = New-MsBuildNamespace -Doc $projectDoc

	foreach ($tag in @("ClCompile", "ClInclude", "None", "CustomBuild", "CudaCompile")) {
		$nodes = @($projectDoc.SelectNodes("//msb:$tag[@Include]", $projectNs))
		foreach ($node in $nodes) {
			$include = [string]$node.Include
			$extension = [System.IO.Path]::GetExtension(($include -replace "/", "\"))
			if (Test-GeneratedAddonPath $include) {
				throw "$Example project still includes generated dependency path: $include"
			}
			if ($tag -eq "ClCompile" -and $extension -in @(".h", ".hpp")) {
				throw "$Example project still compiles header as source: $include"
			}
		}
	}

	$includeDirNodes = @($projectDoc.SelectNodes("//msb:AdditionalIncludeDirectories", $projectNs))
	foreach ($node in $includeDirNodes) {
		$parts = @($node.InnerText -split ";" | Where-Object { $_ })
		foreach ($part in $parts) {
			if (Test-GeneratedAddonPath $part) {
				throw "$Example project still references generated dependency include path: $part"
			}
		}
	}

	$libraryDirNodes = @($projectDoc.SelectNodes("//msb:AdditionalLibraryDirectories", $projectNs))
	foreach ($node in $libraryDirNodes) {
		$parts = @($node.InnerText -split ";" | Where-Object { $_ })
		foreach ($part in $parts) {
			if (Test-GeneratedAddonPath $part) {
				throw "$Example project still references split-addon library path: $part"
			}
		}
	}

	$dependencyNodes = @($projectDoc.SelectNodes("//msb:AdditionalDependencies", $projectNs))
	foreach ($node in $dependencyNodes) {
		$parts = @($node.InnerText -split ";" | Where-Object { $_ })
		foreach ($part in $parts) {
			if (Test-StaleAddonLibrary $part) {
				throw "$Example project still links split-addon library: $part"
			}
		}
	}

	$optionNodes = @($projectDoc.SelectNodes("//msb:ClCompile/msb:AdditionalOptions", $projectNs))
	foreach ($node in $optionNodes) {
		if ($node.InnerText -match '(^|\s)-DOFXGGML_ENABLE_SAM3_ADAPTER(?:\s|$)') {
			throw "$Example project still defines OFXGGML_ENABLE_SAM3_ADAPTER"
		}
	}

	$requiredProjectIncludes = @(
		"..\src\core\ofxGgmlRuntime.cpp",
		"..\src\inference\ofxGgmlTextGeneration.cpp",
		"..\src\ofxGgml.h"
	)
	foreach ($include in $requiredProjectIncludes) {
		$found = $projectDoc.SelectSingleNode("//*[@Include='$include']", $projectNs)
		if (!$found) {
			throw "$Example project is missing repaired addon item: $include"
		}
	}

	$exampleDir = Split-Path -Parent $Project
	if (Test-ExampleUsesAddon -ExampleDir $exampleDir -AddonName "ofxImGui") {
		$imguiInclude = "..\..\ofxImGui\src"
		$includeNodes = @($projectDoc.SelectNodes("//msb:AdditionalIncludeDirectories", $projectNs))
		$hasImguiInclude = $false
		foreach ($node in $includeNodes) {
			$parts = @($node.InnerText -split ";" | Where-Object { $_ })
			if ($parts -contains $imguiInclude) {
				$hasImguiInclude = $true
				break
			}
		}
		if (!$hasImguiInclude) {
			throw "$Example project is missing ofxImGui include directory repair."
		}

		$imguiSource = $projectDoc.SelectSingleNode("//*[@Include='..\..\ofxImGui\src\Gui.cpp']", $projectNs)
		if (!$imguiSource) {
			throw "$Example project is missing repaired ofxImGui source item."
		}
	}

	if (Test-Path -LiteralPath $Filters) {
		[xml]$filtersDoc = Get-Content -LiteralPath $Filters -Raw
		[System.Xml.XmlNamespaceManager]$filtersNs = New-MsBuildNamespace -Doc $filtersDoc
		foreach ($tag in @("ClCompile", "ClInclude", "None", "CustomBuild", "CudaCompile", "Filter")) {
			$nodes = @($filtersDoc.SelectNodes("//msb:$tag[@Include]", $filtersNs))
			foreach ($node in $nodes) {
				$include = [string]$node.Include
				$extension = [System.IO.Path]::GetExtension(($include -replace "/", "\"))
				if (Test-GeneratedAddonPath $include) {
					throw "$Example filters still includes generated dependency path: $include"
				}
				if ($tag -eq "ClCompile" -and $extension -in @(".h", ".hpp")) {
					throw "$Example filters still compiles header as source: $include"
				}
			}
		}
	}
}

if (!(Test-WindowsHost)) {
	throw "Generated Visual Studio project repair tests currently run only on Windows."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")
$buildScript = Join-Path $scriptRoot "build-simple-example.ps1"
$validatedCount = 0
$skippedCount = 0

foreach ($example in $Examples) {
	$exampleDir = Join-Path $addonRoot $example
	$project = Join-Path $exampleDir "$example.vcxproj"
	$filters = "$project.filters"

	if (!(Test-Path -LiteralPath $project -PathType Leaf)) {
		Write-Step "Skipping $example generated metadata; Visual Studio project has not been generated"
		$skippedCount++
		continue
	}

	Write-Step "Repairing $example generated metadata"
	& $buildScript `
		-Configuration $Configuration `
		-Platform $Platform `
		-Example $example `
		-RepairOnly
	if (!$?) {
		throw "Repair failed for $example with exit code $LASTEXITCODE"
	}

	Write-Step "Validating $example generated metadata"
	Assert-ProjectMetadata -Example $example -Project $project -Filters $filters
	$validatedCount++
}

Write-Step "Generated project repair coverage passed ($validatedCount checked, $skippedCount skipped)"
