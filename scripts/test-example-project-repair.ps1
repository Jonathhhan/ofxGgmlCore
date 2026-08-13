param(
	[string]$Example = "ofxGgmlCoreExample"
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$project = Join-Path $addonRoot "$Example\$Example.vcxproj"
$config = Join-Path $addonRoot "addon_config.mk"

& (Join-Path $scriptRoot "build-simple-example.ps1") -Example $Example -RepairOnly
if (!$?) {
	throw "Example project repair failed."
}

[xml]$doc = Get-Content -LiteralPath $project -Raw
$namespace = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
$namespace.AddNamespace("msb", "http://schemas.microsoft.com/developer/msbuild/2003")
$dependencies = @($doc.SelectNodes("//msb:AdditionalDependencies", $namespace))
$options = @($doc.SelectNodes("//msb:ClCompile/msb:AdditionalOptions", $namespace))
$libraryDirectories = @($doc.SelectNodes("//msb:AdditionalLibraryDirectories", $namespace))

$configuredLibraries = New-Object System.Collections.Generic.List[string]
$configuredDefines = New-Object System.Collections.Generic.List[string]
$section = ""
Get-Content -LiteralPath $config | ForEach-Object {
	if ($_ -match '^([A-Za-z0-9_/]+):\s*$') {
		$section = $matches[1]
	}
	if ($section -eq "common" -or $section -eq "vs") {
		if ($_ -match '^\s*ADDON_LIBS\s*(?:\+)?=\s*([^#]+?)\s*$') {
			$configuredLibraries.Add([System.IO.Path]::GetFileName(($matches[1] -replace '"', '').Trim()))
		}
		if ($_ -match 'ADDON_CFLAGS\s*(?:\+)?=\s*-D([A-Za-z0-9_]+(?:=[^\s]+)?)') {
			$configuredDefines.Add($matches[1])
		}
	}
}

foreach ($library in $configuredLibraries) {
	foreach ($node in $dependencies) {
		if (@($node.InnerText -split ";" | Where-Object { $_.Equals($library, [System.StringComparison]::OrdinalIgnoreCase) }).Count -eq 0) {
			throw "Generated project is missing configured library: $library"
		}
	}
}

foreach ($define in $configuredDefines) {
	foreach ($node in $options) {
		if ($node.InnerText -notmatch ('(^|\s)-D' + [regex]::Escape($define) + '(\s|$)')) {
			throw "Generated project is missing configured define: $define"
		}
	}
}

if ($configuredLibraries -contains "ggml-cuda.lib") {
	foreach ($node in $libraryDirectories) {
		if ($node.InnerText -notmatch '\$\(CUDA_PATH\)\\lib\\x64') {
			throw "Generated CUDA project is missing the CUDA library directory."
		}
	}
}

Write-Host "==> Example project repair coverage passed"
