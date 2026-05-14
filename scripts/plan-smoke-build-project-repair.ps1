param(
	[string]$Stage = "verify-generated-project",
	[int]$First = 1,
	[string]$Repository = "",
	[string]$Example = "",
	[switch]$Apply,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

if ($First -lt 1) {
	throw "-First must be at least 1."
}
if (([string]::IsNullOrWhiteSpace($Repository) -and ![string]::IsNullOrWhiteSpace($Example)) -or
	(![string]::IsNullOrWhiteSpace($Repository) -and [string]::IsNullOrWhiteSpace($Example))) {
	throw "-Repository and -Example must be provided together."
}

function Get-ExpectedAddonReference {
	param(
		[string]$Addon,
		[string]$OwnerAddon
	)

	if ($Addon -eq $OwnerAddon) {
		return "..\src"
	}
	return "..\..\$Addon"
}

function Get-RepairState {
	param([object]$Postflight)

	if (!$Postflight.GeneratedProjectFiles -or @($Postflight.GeneratedProjectFiles).Count -eq 0) {
		return "needs-project-generation"
	}
	if (@($Postflight.MissingProjectAddons).Count -gt 0) {
		return "needs-addon-wiring-repair"
	}
	if ($Postflight.Complete) {
		return "ready-for-compile-validation"
	}
	return "review-generated-project"
}

function Get-RepairAction {
	param([string]$State)

	switch ($State) {
		"needs-project-generation" { "run projectGenerator before repair planning can inspect generated metadata" }
		"needs-addon-wiring-repair" { "regenerate or repair the Visual Studio project so expected addons are referenced before compile gates" }
		"ready-for-compile-validation" { "generated project addon wiring is ready for focused compile validation" }
		default { "review generated project state before compile validation" }
	}
}

function Add-MapValue {
	param(
		[hashtable]$Map,
		[string]$Name,
		[string]$Value
	)

	if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
		return
	}
	if (!$Map.ContainsKey($Name)) {
		$Map[$Name] = New-Object System.Collections.Generic.List[string]
	}
	if (!$Map[$Name].Contains($Value)) {
		$Map[$Name].Add($Value)
	}
}

function Get-AddonConfigValues {
	param([string]$AddonRoot)

	$values = @{}
	$configPath = Join-Path $AddonRoot "addon_config.mk"
	if (!(Test-Path -LiteralPath $configPath -PathType Leaf)) {
		return $values
	}

	$section = ""
	Get-Content -LiteralPath $configPath | ForEach-Object {
		$line = ([string]$_ -replace "\s+#.*$", "").Trim()
		if ([string]::IsNullOrWhiteSpace($line)) {
			return
		}
		if ($line -match "^([A-Za-z0-9_/]+):\s*$") {
			$section = $matches[1]
			return
		}
		if ($section -ne "common" -and $section -ne "vs") {
			return
		}
		if ($line -match "^(ADDON_[A-Z_]+)\s*(?:\+)?=\s*(.+?)\s*$") {
			$name = $matches[1]
			foreach ($part in @($matches[2] -split "\s+" | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) })) {
				Add-MapValue -Map $values -Name $name -Value ([string]$part)
			}
		}
	}

	return $values
}

function Test-AddonPathExcluded {
	param(
		[string]$RelativePath,
		[string[]]$ExcludePatterns
	)

	$normalized = ($RelativePath -replace "\\", "/").TrimStart("/")
	foreach ($pattern in @($ExcludePatterns)) {
		$wildcard = (($pattern -replace "\\", "/") -replace "%", "*").TrimStart("/")
		if ($normalized -like $wildcard) {
			return $true
		}
	}
	return $false
}

function Test-GeneratedProjectAddonReference {
	param(
		[string]$ProjectText,
		[string]$Addon,
		[string]$OwnerAddon
	)

	if ([string]::IsNullOrWhiteSpace($ProjectText) -or [string]::IsNullOrWhiteSpace($Addon)) {
		return $false
	}

	$escapedAddon = [regex]::Escape($Addon)
	if ($Addon -eq $OwnerAddon) {
		return $ProjectText -match "\.\.[\\/]+src([\\/;`"'<]|$)" -or
			$ProjectText -match "\.\.[\\/]+$escapedAddon([\\/;`"'<]|$)"
	}

	return $ProjectText -match "\.\.[\\/]+\.\.[\\/]+$escapedAddon([\\/;`"'<]|$)" -or
		$ProjectText -match "\$\(OF_ROOT\)[\\/]+addons[\\/]+$escapedAddon([\\/;`"'<]|$)"
}

function Get-RelativeProjectPath {
	param(
		[string]$ProjectDir,
		[string]$FilePath
	)
	$projectUri = [System.Uri]((Resolve-Path -LiteralPath $ProjectDir).Path.TrimEnd("\") + "\")
	$fileUri = [System.Uri](Resolve-Path -LiteralPath $FilePath).Path
	return [System.Uri]::UnescapeDataString(
		$projectUri.MakeRelativeUri($fileUri).ToString()).Replace("/", "\")
}

function Get-FirstItemGroup {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$PreferredTag
	)
	$itemGroups = @($Doc.SelectNodes("//msb:ItemGroup", $Namespace))
	foreach ($group in $itemGroups) {
		if ($group.SelectSingleNode("msb:$PreferredTag", $Namespace)) {
			return $group
		}
	}
	if ($itemGroups.Count -gt 0) {
		return $itemGroups[0]
	}
	return $null
}

function Add-VisualStudioProjectItem {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$Tag,
		[string]$Include,
		[string]$Filter = "",
		[switch]$Apply
	)

	if ($Doc.SelectSingleNode("//msb:$Tag[@Include='$Include']", $Namespace)) {
		return $false
	}
	if (!$Apply) {
		return $true
	}
	$itemGroup = Get-FirstItemGroup -Doc $Doc -Namespace $Namespace -PreferredTag $Tag
	if (!$itemGroup) {
		return $false
	}
	$item = $Doc.CreateElement($Tag, $Doc.DocumentElement.NamespaceURI)
	$item.SetAttribute("Include", $Include)
	if (![string]::IsNullOrWhiteSpace($Filter)) {
		$filterNode = $Doc.CreateElement("Filter", $Doc.DocumentElement.NamespaceURI)
		$filterNode.InnerText = $Filter
		[void]$item.AppendChild($filterNode)
	}
	[void]$itemGroup.AppendChild($item)
	return $true
}

function Add-AdditionalIncludeDirectory {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$IncludeDir,
		[switch]$Apply
	)

	$nodes = @($Doc.SelectNodes("//msb:AdditionalIncludeDirectories", $Namespace))
	$changed = $false
	foreach ($node in $nodes) {
		$parts = New-Object System.Collections.Generic.List[string]
		foreach ($part in @($node.InnerText -split ";" | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) })) {
			$parts.Add([string]$part)
		}
		if (!$parts.Contains($IncludeDir)) {
			$changed = $true
			if ($Apply) {
				$parts.Add($IncludeDir)
				$node.InnerText = ($parts.ToArray() -join ";")
			}
		}
	}
	return $changed
}

function Add-SemicolonNodeValue {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$NodeName,
		[string]$Value,
		[switch]$Apply
	)

	if ([string]::IsNullOrWhiteSpace($Value)) {
		return $false
	}
	$nodes = @($Doc.SelectNodes("//msb:$NodeName", $Namespace))
	$changed = $false
	foreach ($node in $nodes) {
		$parts = New-Object System.Collections.Generic.List[string]
		foreach ($part in @($node.InnerText -split ";" | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) })) {
			$parts.Add([string]$part)
		}
		if (!$parts.Contains($Value)) {
			$changed = $true
			if ($Apply) {
				$parts.Add($Value)
				$node.InnerText = ($parts.ToArray() -join ";")
			}
		}
	}
	return $changed
}

function Add-AdditionalOption {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$Option,
		[switch]$Apply
	)

	if ([string]::IsNullOrWhiteSpace($Option)) {
		return $false
	}
	$nodes = @($Doc.SelectNodes("//msb:ClCompile/msb:AdditionalOptions", $Namespace))
	$changed = $false
	foreach ($node in $nodes) {
		$options = New-Object System.Collections.Generic.List[string]
		foreach ($part in @($node.InnerText -split "\s+" | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) })) {
			$options.Add([string]$part)
		}
		if (!$options.Contains($Option)) {
			$changed = $true
			if ($Apply) {
				$options.Add($Option)
				$node.InnerText = ($options.ToArray() -join " ")
			}
		}
	}
	return $changed
}

function ConvertTo-ProjectLibraryReference {
	param(
		[string]$AddonRoot,
		[string]$ProjectDir,
		[string]$Library
	)

	$value = ([string]$Library).Trim().Trim('"')
	if ([string]::IsNullOrWhiteSpace($value)) {
		return $null
	}
	$normalized = $value -replace "/", "\"
	$name = [System.IO.Path]::GetFileName($normalized)
	$parent = Split-Path -Parent $normalized
	$directory = ""
	if (![string]::IsNullOrWhiteSpace($parent)) {
		if ($parent -match '^\$\(' -or [System.IO.Path]::IsPathRooted($parent)) {
			$directory = $parent
		} else {
			$path = Join-Path $AddonRoot $parent
			if (Test-Path -LiteralPath $path) {
				$directory = Get-RelativeProjectPath -ProjectDir $ProjectDir -FilePath $path
			} else {
				$directory = $parent
			}
		}
	}
	return [pscustomobject]@{
		Dependency = $name
		Directory = $directory
	}
}

function Get-AddonRepairMetadata {
	param(
		[string]$Addon,
		[string]$OwnerAddon,
		[string]$ExamplePath,
		[string]$AddonsRoot
	)

	$addonRoot = if ($Addon -eq $OwnerAddon) {
		Split-Path -Parent $ExamplePath
	} else {
		Join-Path $AddonsRoot $Addon
	}
	if (!(Test-Path -LiteralPath $addonRoot -PathType Container)) {
		return $null
	}

	$config = Get-AddonConfigValues -AddonRoot $addonRoot
	$includeRoots = New-Object System.Collections.Generic.List[string]
	foreach ($include in @($config["ADDON_INCLUDES"])) {
		if (![string]::IsNullOrWhiteSpace([string]$include) -and [string]$include -ne "." -and !$includeRoots.Contains([string]$include)) {
			$includeRoots.Add([string]$include)
		}
	}
	if ($includeRoots.Count -eq 0 -and (Test-Path -LiteralPath (Join-Path $addonRoot "src") -PathType Container)) {
		$includeRoots.Add("src")
	}
	if ($Addon -eq "ofxImGui") {
		foreach ($include in @("src", "libs/imgui", "libs/imgui/src", "libs/imgui/backends", "libs/imgui/extras")) {
			if (!$includeRoots.Contains($include) -and (Test-Path -LiteralPath (Join-Path $addonRoot $include) -PathType Container)) {
				$includeRoots.Add($include)
			}
		}
	}

	$sourceRoots = New-Object System.Collections.Generic.List[string]
	if ($config.ContainsKey("ADDON_SOURCES") -and $config["ADDON_SOURCES"].Count -gt 0) {
		foreach ($source in @($config["ADDON_SOURCES"])) {
			$sourceParent = Split-Path -Parent ([string]$source)
			if (![string]::IsNullOrWhiteSpace($sourceParent) -and $sourceParent -ne "." -and !$sourceRoots.Contains($sourceParent)) {
				$sourceRoots.Add($sourceParent)
			}
		}
	} else {
		foreach ($root in @("src")) {
			if (!$sourceRoots.Contains($root) -and (Test-Path -LiteralPath (Join-Path $addonRoot $root) -PathType Container)) {
				$sourceRoots.Add($root)
			}
		}
	}
	if ($Addon -eq "ofxImGui") {
		foreach ($root in @("src", "libs/imgui/src", "libs/imgui/backends", "libs/imgui/extras")) {
			if (!$sourceRoots.Contains($root) -and (Test-Path -LiteralPath (Join-Path $addonRoot $root) -PathType Container)) {
				$sourceRoots.Add($root)
			}
		}
	}

	$excludes = @($config["ADDON_SOURCES_EXCLUDE"]) + @($config["ADDON_INCLUDES_EXCLUDE"])
	$sourceFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
	$headerFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]

	if ($config.ContainsKey("ADDON_SOURCES") -and $config["ADDON_SOURCES"].Count -gt 0) {
		foreach ($source in @($config["ADDON_SOURCES"])) {
			$path = Join-Path $addonRoot ([string]$source)
			if ((Test-Path -LiteralPath $path -PathType Leaf) -and !(Test-AddonPathExcluded -RelativePath ([string]$source) -ExcludePatterns $excludes)) {
				$sourceFiles.Add((Get-Item -LiteralPath $path))
			}
		}
	} else {
		foreach ($root in @($sourceRoots)) {
			$path = Join-Path $addonRoot $root
			if (!(Test-Path -LiteralPath $path -PathType Container)) {
				continue
			}
			Get-ChildItem -LiteralPath $path -Recurse -File | Where-Object { $_.Extension -in @(".cpp", ".cxx", ".cc") } | ForEach-Object {
				$relative = Get-RelativeProjectPath -ProjectDir $addonRoot -FilePath $_.FullName
				if (!(Test-AddonPathExcluded -RelativePath $relative -ExcludePatterns $excludes)) {
					$sourceFiles.Add($_)
				}
			}
		}
	}

	foreach ($root in @($includeRoots + $sourceRoots | Select-Object -Unique)) {
		$path = Join-Path $addonRoot $root
		if (!(Test-Path -LiteralPath $path -PathType Container)) {
			continue
		}
		Get-ChildItem -LiteralPath $path -Recurse -File | Where-Object { $_.Extension -in @(".h", ".hpp") } | ForEach-Object {
			$relative = Get-RelativeProjectPath -ProjectDir $addonRoot -FilePath $_.FullName
			if (!(Test-AddonPathExcluded -RelativePath $relative -ExcludePatterns $excludes)) {
				$headerFiles.Add($_)
			}
		}
	}

	return [pscustomobject]@{
		Addon = $Addon
		Root = $addonRoot
		IncludeRoots = @($includeRoots)
		SourceFiles = @($sourceFiles)
		HeaderFiles = @($headerFiles)
		CFlags = @($config["ADDON_CFLAGS"])
		Libs = @($config["ADDON_LIBS"])
	}
}

function Invoke-VisualStudioProjectRepair {
	param(
		[string]$ProjectFile,
		[string]$OwnerAddon,
		[string]$ExamplePath,
		[string]$AddonsRoot,
		[array]$ExpectedReferences,
		[switch]$Apply
	)

	if ([string]::IsNullOrWhiteSpace($ProjectFile) -or !(Test-Path -LiteralPath $ProjectFile -PathType Leaf)) {
		return [pscustomobject]@{
			Applied = $false
			Changed = $false
			PlannedIncludeDirectories = @()
			PlannedProjectItems = @()
			Detail = "Visual Studio project file was not found."
		}
	}

	$projectDir = Split-Path -Parent $ProjectFile
	[xml]$projectDoc = Get-Content -LiteralPath $ProjectFile -Raw
	$projectNs = New-Object System.Xml.XmlNamespaceManager($projectDoc.NameTable)
	$projectNs.AddNamespace("msb", "http://schemas.microsoft.com/developer/msbuild/2003")
	$filtersFile = "$ProjectFile.filters"
	$filtersDoc = $null
	$filtersNs = $null
	if (Test-Path -LiteralPath $filtersFile -PathType Leaf) {
		[xml]$filtersDoc = Get-Content -LiteralPath $filtersFile -Raw
		$filtersNs = New-Object System.Xml.XmlNamespaceManager($filtersDoc.NameTable)
		$filtersNs.AddNamespace("msb", "http://schemas.microsoft.com/developer/msbuild/2003")
	}

	$plannedIncludeDirs = New-Object System.Collections.Generic.List[string]
	$plannedItems = New-Object System.Collections.Generic.List[string]
	$plannedLibraries = New-Object System.Collections.Generic.List[string]
	$plannedLibraryDirs = New-Object System.Collections.Generic.List[string]
	$plannedOptions = New-Object System.Collections.Generic.List[string]
	$changed = $false
	foreach ($reference in @($ExpectedReferences)) {
		$metadata = Get-AddonRepairMetadata -Addon ([string]$reference.Addon) -OwnerAddon $OwnerAddon -ExamplePath $ExamplePath -AddonsRoot $AddonsRoot
		if (!$metadata) {
			continue
		}
		foreach ($cflag in @($metadata.CFlags)) {
			$option = [string]$cflag
			if (Add-AdditionalOption -Doc $projectDoc -Namespace $projectNs -Option $option -Apply:$Apply) {
				$changed = $true
				if (!$plannedOptions.Contains($option)) {
					$plannedOptions.Add($option)
				}
			}
		}
		foreach ($library in @($metadata.Libs)) {
			$referenceInfo = ConvertTo-ProjectLibraryReference -AddonRoot ([string]$metadata.Root) -ProjectDir $projectDir -Library ([string]$library)
			if (!$referenceInfo) {
				continue
			}
			if (Add-SemicolonNodeValue -Doc $projectDoc -Namespace $projectNs -NodeName "AdditionalDependencies" -Value ([string]$referenceInfo.Dependency) -Apply:$Apply) {
				$changed = $true
				if (!$plannedLibraries.Contains([string]$referenceInfo.Dependency)) {
					$plannedLibraries.Add([string]$referenceInfo.Dependency)
				}
			}
			if (![string]::IsNullOrWhiteSpace([string]$referenceInfo.Directory) -and
				(Add-SemicolonNodeValue -Doc $projectDoc -Namespace $projectNs -NodeName "AdditionalLibraryDirectories" -Value ([string]$referenceInfo.Directory) -Apply:$Apply)) {
				$changed = $true
				if (!$plannedLibraryDirs.Contains([string]$referenceInfo.Directory)) {
					$plannedLibraryDirs.Add([string]$referenceInfo.Directory)
				}
			}
		}
		foreach ($includeRoot in @($metadata.IncludeRoots)) {
			$includePath = Get-RelativeProjectPath -ProjectDir $projectDir -FilePath (Join-Path $metadata.Root $includeRoot)
			if (Add-AdditionalIncludeDirectory -Doc $projectDoc -Namespace $projectNs -IncludeDir $includePath -Apply:$Apply) {
				$changed = $true
				if (!$plannedIncludeDirs.Contains($includePath)) {
					$plannedIncludeDirs.Add($includePath)
				}
			}
		}
		foreach ($file in @($metadata.SourceFiles)) {
			$include = Get-RelativeProjectPath -ProjectDir $projectDir -FilePath $file.FullName
			$filter = "addons\$($metadata.Addon)\$((Split-Path -Parent $include).TrimStart('.\').Replace('..\', ''))"
			if (Add-VisualStudioProjectItem -Doc $projectDoc -Namespace $projectNs -Tag "ClCompile" -Include $include -Apply:$Apply) {
				$changed = $true
				$plannedItems.Add("ClCompile:$include")
			}
			if ($filtersDoc -and (Add-VisualStudioProjectItem -Doc $filtersDoc -Namespace $filtersNs -Tag "ClCompile" -Include $include -Filter $filter -Apply:$Apply)) {
				$changed = $true
			}
		}
		foreach ($file in @($metadata.HeaderFiles)) {
			$include = Get-RelativeProjectPath -ProjectDir $projectDir -FilePath $file.FullName
			$filter = "addons\$($metadata.Addon)\$((Split-Path -Parent $include).TrimStart('.\').Replace('..\', ''))"
			if (Add-VisualStudioProjectItem -Doc $projectDoc -Namespace $projectNs -Tag "ClInclude" -Include $include -Apply:$Apply) {
				$changed = $true
				$plannedItems.Add("ClInclude:$include")
			}
			if ($filtersDoc -and (Add-VisualStudioProjectItem -Doc $filtersDoc -Namespace $filtersNs -Tag "ClInclude" -Include $include -Filter $filter -Apply:$Apply)) {
				$changed = $true
			}
		}
	}

	if ($Apply -and $changed) {
		$projectDoc.Save($ProjectFile)
		if ($filtersDoc) {
			$filtersDoc.Save($filtersFile)
		}
	}

	return [pscustomobject]@{
		Applied = [bool]$Apply
		Changed = $changed
		PlannedIncludeDirectories = @($plannedIncludeDirs)
		PlannedProjectItems = @($plannedItems)
		PlannedLibraries = @($plannedLibraries)
		PlannedLibraryDirectories = @($plannedLibraryDirs)
		PlannedOptions = @($plannedOptions)
		Detail = if ($Apply) { "generated Visual Studio project repair applied" } else { "generated Visual Studio project repair dry run" }
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$planScript = Join-Path $scriptRoot "plan-of-smoke-build.ps1"
$postflightScript = Join-Path $scriptRoot "check-smoke-build-target-postflight.ps1"

$planJson = & $planScript -Json
if (!$?) {
	throw "plan-of-smoke-build.ps1 -Json failed."
}
$plan = ($planJson -join [Environment]::NewLine) | ConvertFrom-Json

if (![string]::IsNullOrWhiteSpace($Repository)) {
	$postflightJson = & $postflightScript -Stage $Stage -First $First -Repository $Repository -Example $Example -Json
} else {
	$postflightJson = & $postflightScript -Stage $Stage -First $First -Json
}
if (!$?) {
	throw "check-smoke-build-target-postflight.ps1 -Json failed."
}
$postflight = ($postflightJson -join [Environment]::NewLine) | ConvertFrom-Json

$repairs = @($postflight.Postflights | ForEach-Object {
	$targetPostflight = $_
	$record = @($plan.Records | Where-Object { $_.Repository -eq $targetPostflight.Repository } | Select-Object -First 1)
	$exampleMetadata = @($record.ExampleMetadata | Where-Object { $_.Example -eq $targetPostflight.Example } | Select-Object -First 1)
	$addons = @($exampleMetadata.Addons | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
	$missingAddons = @($targetPostflight.MissingProjectAddons | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
	$state = Get-RepairState -Postflight $targetPostflight
	$expectedReferences = @($addons | ForEach-Object {
		[pscustomobject]@{
			Addon = $_
			Reference = Get-ExpectedAddonReference -Addon $_ -OwnerAddon ([string]$targetPostflight.Repository)
			Missing = $missingAddons -contains $_
		}
	})
	$projectGeneratorCommand = [string]$exampleMetadata.ProjectGeneratorCommand
	$repairResult = $null
	if ($state -eq "needs-addon-wiring-repair" -or $state -eq "ready-for-compile-validation") {
		$repairResult = Invoke-VisualStudioProjectRepair `
			-ProjectFile ([string]$targetPostflight.GeneratedProjectFile) `
			-OwnerAddon ([string]$targetPostflight.Repository) `
			-ExamplePath ([string]$targetPostflight.ExamplePath) `
			-AddonsRoot ([string]$plan.Root) `
			-ExpectedReferences $expectedReferences `
			-Apply:$Apply
	}
	if ($Apply -and ![string]::IsNullOrWhiteSpace([string]$targetPostflight.GeneratedProjectFile) -and
		(Test-Path -LiteralPath ([string]$targetPostflight.GeneratedProjectFile) -PathType Leaf)) {
		$projectText = Get-Content -LiteralPath ([string]$targetPostflight.GeneratedProjectFile) -Raw
		$missingAddons = @($addons | Where-Object {
			!(Test-GeneratedProjectAddonReference -ProjectText $projectText -Addon $_ -OwnerAddon ([string]$targetPostflight.Repository))
		})
		$state = if ($missingAddons.Count -eq 0) { "ready-for-compile-validation" } else { "needs-addon-wiring-repair" }
		$expectedReferences = @($addons | ForEach-Object {
			[pscustomobject]@{
				Addon = $_
				Reference = Get-ExpectedAddonReference -Addon $_ -OwnerAddon ([string]$targetPostflight.Repository)
				Missing = $missingAddons -contains $_
			}
		})
	}
	$nextCommands = New-Object System.Collections.Generic.List[string]
	$nextCommands.Add("scripts\check-smoke-build-target-preflight.bat -Stage $($targetPostflight.Stage) -Repository $($targetPostflight.Repository) -Example $($targetPostflight.Example)")
	if (($state -eq "needs-project-generation" -or $state -eq "needs-addon-wiring-repair") -and
		![string]::IsNullOrWhiteSpace($projectGeneratorCommand)) {
		$nextCommands.Add($projectGeneratorCommand)
	}
	if ($state -eq "needs-addon-wiring-repair") {
		$repairCommand = "scripts\plan-smoke-build-project-repair.bat -Stage $($targetPostflight.Stage) -Repository $($targetPostflight.Repository) -Example $($targetPostflight.Example) -Apply"
		if (!$Apply) {
			$nextCommands.Add($repairCommand)
		}
	}
	$nextCommands.Add("scripts\check-smoke-build-target-postflight.bat -Stage $($targetPostflight.Stage) -Repository $($targetPostflight.Repository) -Example $($targetPostflight.Example)")
	$nextCommands.Add("scripts\test-artifact-hygiene.ps1")

	[pscustomobject]@{
		Repository = $targetPostflight.Repository
		Example = $targetPostflight.Example
		Stage = $targetPostflight.Stage
		State = $state
		Action = Get-RepairAction -State $state
		ProjectFile = [string]$targetPostflight.GeneratedProjectFile
		GeneratedProjectFiles = @($targetPostflight.GeneratedProjectFiles)
		ExpectedReferences = @($expectedReferences)
		MissingProjectAddons = @($missingAddons)
		RepairResult = $repairResult
		ProjectGeneratorCommand = $projectGeneratorCommand
		NextCommands = @($nextCommands.ToArray())
	}
})

$needsAction = @($repairs | Where-Object { $_.State -ne "ready-for-compile-validation" })
$nextCommandList = New-Object System.Collections.Generic.List[string]
foreach ($repair in $repairs) {
	foreach ($command in @($repair.NextCommands)) {
		if (!$nextCommandList.Contains($command)) {
			$nextCommandList.Add($command)
		}
	}
}
$nextCommands = @($nextCommandList.ToArray())
$safetyNote = if ($Apply) {
	"This repair applied only to generated project metadata. Keep generated project files ignored unless an owning addon explicitly tracks them."
} else {
	"This repair plan is non-mutating. Re-run with -Apply to update generated Visual Studio project metadata."
}

if ($Json) {
	[pscustomobject]@{
		Root = $plan.Root
		Stage = $Stage
		Repairs = $repairs
		Applied = [bool]$Apply
		NeedsAction = $needsAction.Count
		NextCommands = $nextCommands
		SafetyNote = $safetyNote
	} | ConvertTo-Json -Depth 8
	return
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Smoke Build Project Repair Plan")
$lines.Add("")
$lines.Add("Root: $($plan.Root)")
$lines.Add("Stage filter: $Stage")
$lines.Add("")

if ($repairs.Count -eq 0) {
	$lines.Add("No matching smoke-build project repair targets.")
	Write-Output ($lines -join [Environment]::NewLine)
	return
}

foreach ($repair in $repairs) {
	$lines.Add("## $($repair.Repository) / $($repair.Example)")
	$lines.Add("")
	$lines.Add(('Stage: `{0}`' -f $repair.Stage))
	$lines.Add(('State: `{0}`' -f $repair.State))
	$lines.Add("Action: $($repair.Action)")
	if (![string]::IsNullOrWhiteSpace([string]$repair.ProjectFile)) {
		$lines.Add("Project file: $($repair.ProjectFile)")
	}
	if ($repair.RepairResult) {
		$lines.Add("Repair mode: $(if ($repair.RepairResult.Applied) { 'apply' } else { 'dry-run' })")
		$lines.Add("Planned include directories: $(@($repair.RepairResult.PlannedIncludeDirectories).Count)")
		$lines.Add("Planned project items: $(@($repair.RepairResult.PlannedProjectItems).Count)")
		$lines.Add("Planned libraries: $(@($repair.RepairResult.PlannedLibraries).Count)")
		$lines.Add("Planned library directories: $(@($repair.RepairResult.PlannedLibraryDirectories).Count)")
		$lines.Add("Planned compiler options: $(@($repair.RepairResult.PlannedOptions).Count)")
	}
	$lines.Add("")
	$lines.Add("## Expected Addon References")
	$lines.Add("")
	$lines.Add("| Addon | Expected reference | Missing |")
	$lines.Add("| --- | --- | --- |")
	foreach ($reference in @($repair.ExpectedReferences)) {
		$missing = if ($reference.Missing) { "yes" } else { "no" }
		$lines.Add(('| `{0}` | `{1}` | {2} |' -f $reference.Addon, $reference.Reference, $missing))
	}
	$lines.Add("")
	$lines.Add("## Next Commands")
	$lines.Add("")
	$lines.Add('```powershell')
	foreach ($command in @($repair.NextCommands)) {
		$lines.Add($command)
	}
	$lines.Add('```')
	$lines.Add("")
}

$lines.Add("## Combined Next Commands")
$lines.Add("")
$lines.Add('```powershell')
foreach ($command in $nextCommands) {
	$lines.Add($command)
}
$lines.Add('```')
$lines.Add("")
$lines.Add($safetyNote)

Write-Output ($lines -join [Environment]::NewLine)
