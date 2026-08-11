param(
	[switch]$Json,
	[switch]$SummaryOnly,
	[switch]$Strict
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreRoot = Resolve-Path (Join-Path $scriptRoot "..")
$addonsRoot = Split-Path -Parent $coreRoot

. (Join-Path $scriptRoot "get-ecosystem.ps1")
$family = @(Get-OfxGgmlEcosystem -AddonsRoot $addonsRoot)

function Get-DevelopmentPriorityState {
	param([string]$AddonsRoot)

	$path = Join-Path $AddonsRoot "ofxGgmlWorkflows\ecosystem.yaml"
	$priorities = @{}
	if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
		return [pscustomobject]@{
			Available = $false
			Path = $path
			Priorities = $priorities
		}
	}

	$currentOrder = $null
	foreach ($rawLine in Get-Content -LiteralPath $path) {
		$line = [string]$rawLine
		if ($line -match '^\s*-\s+order:\s*(\d+)\s*(?:#.*)?$') {
			$currentOrder = [int]$matches[1]
			continue
		}
		if ($null -ne $currentOrder -and $line -match '^\s+lane:\s*([^#]+?)\s*(?:#.*)?$') {
			$lane = ([string]$matches[1]).Trim().Trim('"').Trim("'")
			if (![string]::IsNullOrWhiteSpace($lane)) {
				$priorities[$lane] = $currentOrder
			}
			$currentOrder = $null
		}
	}

	return [pscustomobject]@{
		Available = $priorities.Count -gt 0
		Path = $path
		Priorities = $priorities
	}
}

$developmentPriorityState = Get-DevelopmentPriorityState -AddonsRoot $addonsRoot

function Get-DevelopmentPriority {
	param([string]$Name)

	if ($Name -eq "ofxGgmlCore") {
		return 0
	}
	if ($developmentPriorityState.Priorities.ContainsKey($Name)) {
		return [int]$developmentPriorityState.Priorities[$Name]
	}
	return 999
}

function Test-CommandAvailable {
	param([string]$Name)
	return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-GitMetadataReadable {
	param([string]$Repository)

	$gitMetadata = Join-Path $Repository ".git"
	if (!(Test-Path -LiteralPath $gitMetadata)) {
		return $false
	}

	try {
		$item = Get-Item -LiteralPath $gitMetadata -Force -ErrorAction Stop
		if ($item.PSIsContainer) {
			$headPath = Join-Path $item.FullName "HEAD"
			$stream = [System.IO.File]::Open($headPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
			$stream.Dispose()
		} else {
			$stream = [System.IO.File]::Open($item.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
			$stream.Dispose()
		}
		return $true
	} catch {
		return $false
	}
}

function Invoke-Git {
	param(
		[string]$Repository,
		[string[]]$Arguments
	)
	if (!(Test-CommandAvailable "git")) {
		return ""
	}
	if (!(Test-GitMetadataReadable -Repository $Repository)) {
		return ""
	}
	$previousErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$output = & git -C $Repository @Arguments 2>$null
		if ($LASTEXITCODE -ne 0) {
			return ""
		}
	} finally {
		$ErrorActionPreference = $previousErrorActionPreference
	}
	return (@($output) -join "`n").Trim()
}

function Get-AgentWorkflowGuide {
	param(
		[string]$Repository,
		[string]$Name
	)

	if ($Name -eq "ofxGgmlCore") {
		return "docs\ECOSYSTEM_AGENT.md"
	}

	if ($Name -eq "ofxGgmlWorkflows") {
		$workflowAdoption = Join-Path $Repository "docs\workflow-adoption.md"
		if (Test-Path -LiteralPath $workflowAdoption -PathType Leaf) {
			return "docs\workflow-adoption.md"
		}
		return ""
	}

	$docsRoot = Join-Path $Repository "docs"
	if (!(Test-Path -LiteralPath $docsRoot -PathType Container)) {
		return ""
	}

	$guide = Get-ChildItem -LiteralPath $docsRoot -Filter "*_WORKFLOWS.md" -File -ErrorAction SilentlyContinue |
		Sort-Object Name |
		Select-Object -First 1
	if ($guide) {
		return "docs\$($guide.Name)"
	}

	return ""
}

function Get-AddonFeatures {
	param([string]$Repository)

	$metadataPath = Join-Path $Repository "ofxggml-addon.json"
	if (!(Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
		return @()
	}

	try {
		$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
	} catch {
		return @()
	}

	if (!$metadata.PSObject.Properties["features"]) {
		return @()
	}

	return @($metadata.features | Where-Object {
		![string]::IsNullOrWhiteSpace([string]$_)
	} | ForEach-Object {
		[string]$_
	})
}

function Get-AddonRuntimeProviderMode {
	param(
		[string]$Repository,
		[string]$Name
	)
	switch ($Name) {
		"ofxGgmlCore" { return "core-ggml-provider" }
		"ofxGgmlLlama" { return "external-server-or-core-ggml" }
		"ofxGgmlStableDiffusion" {
			$cachePath = Join-Path $Repository "libs\stable-diffusion\build\CMakeCache.txt"
			if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
				$cache = Get-Content -LiteralPath $cachePath -Raw
				if ($cache -match "(?m)^SD_USE_SYSTEM_GGML:BOOL=ON") {
					return "system-ggml-core"
				}
			}
			return "standalone-native"
		}
		"ofxGgmlAudio" { return "native-runtime" }
		"ofxGgmlMusic" { return "external-server-or-native-runtime" }
		"ofxGgmlVision" { return "core-ggml-or-native-runtime" }
		"ofxGgmlSam" { return "core-ggml-or-native-runtime" }
		"ofxGgmlVideo" { return "core-ggml-or-native-runtime" }
		"ofxGgmlRag" { return "external-index-or-llama-provider" }
		"ofxGgmlAgents" { return "external-tool-runtime" }
		default { return "unknown" }
	}
}

function Get-AddonStatus {
	param([hashtable]$Addon)
	$path = Join-Path $addonsRoot $Addon.Name
	$known = if ($Addon.ContainsKey("Known")) { [bool]$Addon.Known } else { $false }
	$classified = if ($Addon.ContainsKey("Classified")) { [bool]$Addon.Classified } else { $known }
	$present = Test-Path -LiteralPath $path -PathType Container
	$branch = ""
	$head = ""
	$dirty = ""
	$dirtyCount = 0
	$gitStatusAvailable = $false
	$validate = $false
	$doctor = $false
	$agentsInstructions = $false
	$hermesInstructions = $false
	$copilotInstructions = $false
	$copilotEcosystemInstructions = $false
	$agentWorkflowGuidePath = ""
	$runtimeProviderMode = "unknown"
	$examples = @()
	$features = @()

	if ($present) {
		$gitStatusAvailable = (Test-CommandAvailable "git") -and (Test-GitMetadataReadable -Repository $path)
		$branch = Invoke-Git -Repository $path -Arguments @("branch", "--show-current")
		$head = Invoke-Git -Repository $path -Arguments @("rev-parse", "--short", "HEAD")
		$dirty = Invoke-Git -Repository $path -Arguments @("status", "--short")
		if (![string]::IsNullOrWhiteSpace($dirty)) {
			$dirtyCount = @($dirty -split "`n" | Where-Object { $_ }).Count
		}
		$validate = Test-Path -LiteralPath (Join-Path $path "scripts\validate-local.ps1") -PathType Leaf
		$doctor = $null -ne (Get-ChildItem -LiteralPath (Join-Path $path "scripts") -Filter "*doctor*.ps1" -File -ErrorAction SilentlyContinue | Select-Object -First 1)
		$agentsInstructions = Test-Path -LiteralPath (Join-Path $path "AGENTS.md") -PathType Leaf
		$hermesInstructions = Test-Path -LiteralPath (Join-Path $path "HERMES.md") -PathType Leaf
		$copilotInstructions = Test-Path -LiteralPath (Join-Path $path ".github\copilot-instructions.md") -PathType Leaf
		$copilotEcosystemInstructions = Test-Path -LiteralPath (Join-Path $path ".github\instructions\ofxggml-ecosystem.instructions.md") -PathType Leaf
		$agentWorkflowGuidePath = Get-AgentWorkflowGuide -Repository $path -Name $Addon.Name
		$runtimeProviderMode = Get-AddonRuntimeProviderMode -Repository $path -Name $Addon.Name
		$features = @(Get-AddonFeatures -Repository $path)
		$examples = @(
			Get-ChildItem -LiteralPath $path -Directory -ErrorAction SilentlyContinue |
				Where-Object { $_.Name -like "*Example" } |
				Where-Object {
					$sourceRoot = Join-Path $_.FullName "src"
					$sourceFile = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".h", ".hpp", ".c", ".cc", ".cpp", ".mm") } | Select-Object -First 1
					(Test-Path -LiteralPath (Join-Path $_.FullName "addons.make") -PathType Leaf) -or
					$null -ne $sourceFile
				} |
				Sort-Object Name |
				Select-Object -ExpandProperty Name
		)
	}

	[pscustomobject]@{
		Name = $Addon.Name
		Kind = $Addon.Kind
		Lane = $Addon.Lane
		DevelopmentPriority = [int](Get-DevelopmentPriority -Name ([string]$Addon.Name))
		Scope = $Addon.Scope
		Known = $known
		Classified = $classified
		Path = $path
		Present = $present
		GitStatusAvailable = $gitStatusAvailable
		Branch = $branch
		Head = $head
		DirtyCount = $dirtyCount
		ValidateScript = $validate
		DoctorScript = $doctor
		AgentsInstructions = $agentsInstructions
		HermesInstructions = $hermesInstructions
		CopilotInstructions = $copilotInstructions
		CopilotEcosystemInstructions = $copilotEcosystemInstructions
		AgentWorkflowGuide = ![string]::IsNullOrWhiteSpace($agentWorkflowGuidePath)
		AgentWorkflowGuidePath = $agentWorkflowGuidePath
		RuntimeProviderMode = $runtimeProviderMode
		FeatureCount = @($features).Count
		Features = $features
		Examples = $examples
	}
}

function Get-FamilyStatusSummary {
	param([array]$Statuses)

	$managed = @($Statuses | Where-Object { $_.Known })
	$detected = @($Statuses | Where-Object { !$_.Known })
	return [pscustomobject]@{
		Repositories = @($Statuses).Count
		ManagedRepositories = $managed.Count
		PresentManagedRepositories = @($managed | Where-Object { $_.Present }).Count
		ReadyManagedRepositories = @($managed | Where-Object { $_.Present -and $_.ValidateScript }).Count
		DetectedReferenceRepositories = $detected.Count
		ClassifiedReferenceRepositories = @($detected | Where-Object { $_.Classified }).Count
		UnclassifiedDetectedRepositories = @($detected | Where-Object { !$_.Classified }).Count
		DirtyManagedRepositories = @($managed | Where-Object { $_.DirtyCount -gt 0 }).Count
		ManagedGitStatusUnavailableRepositories = @($managed | Where-Object { $_.Present -and !$_.GitStatusAvailable }).Count
		MissingManagedRepositories = @($managed | Where-Object { !$_.Present }).Count
		MissingValidationEntrypoints = @($managed | Where-Object { $_.Present -and !$_.ValidateScript }).Count
		MissingDoctorEntrypoints = @($managed | Where-Object { $_.Present -and !$_.DoctorScript -and $_.Name -ne "ofxGgmlWorkflows" }).Count
		AgentWorkflowGuideCoverage = @($managed | Where-Object { $_.AgentWorkflowGuide }).Count
		FeatureMetadataCoverage = @($managed | Where-Object { $_.Present -and $_.Name -ne "ofxGgmlWorkflows" -and $_.FeatureCount -gt 0 }).Count
	}
}

function Get-FamilyStatusNextCommands {
	$commands = New-Object System.Collections.Generic.List[string]
	$commands.Add("scripts\plan-ecosystem.bat -Json -SummaryOnly")
	$commands.Add("scripts\plan-addon-features.bat -Json -SummaryOnly")
	$commands.Add("scripts\audit-ecosystem.bat -Strict -Json -SummaryOnly")
	$commands.Add("scripts\check-ecosystem-readiness.bat -SkipDoctorTests -Json -SummaryOnly")
	$commands.Add("scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly")
	$commands.Add("scripts\plan-coding-agent-work.bat -Json")
	return @($commands.ToArray())
}

function ConvertTo-FamilyRepositorySummary {
	param([object]$Status)

	[pscustomobject]@{
		Name = [string]$Status.Name
		Known = [bool]$Status.Known
		Classified = [bool]$Status.Classified
		Present = [bool]$Status.Present
		GitStatusAvailable = [bool]$Status.GitStatusAvailable
		Head = [string]$Status.Head
		DirtyCount = [int]$Status.DirtyCount
		ValidateScript = [bool]$Status.ValidateScript
		DoctorScript = [bool]$Status.DoctorScript
		AgentWorkflowGuide = [bool]$Status.AgentWorkflowGuide
		RuntimeProviderMode = [string]$Status.RuntimeProviderMode
		FeatureCount = [int]$Status.FeatureCount
		DevelopmentPriority = [int]$Status.DevelopmentPriority
	}
}

$statuses = @($family | ForEach-Object { Get-AddonStatus -Addon $_ })
$summary = Get-FamilyStatusSummary -Statuses $statuses
$nextCommands = Get-FamilyStatusNextCommands

if ($Json) {
	$result = [pscustomobject]@{
		Root = $addonsRoot
		DevelopmentPrioritySource = [string]$developmentPriorityState.Path
		DevelopmentPriorityAvailable = [bool]$developmentPriorityState.Available
		SummaryOnly = [bool]$SummaryOnly
		Summary = $summary
		NextCommands = $nextCommands
		RepositorySummaries = @($statuses | ForEach-Object { ConvertTo-FamilyRepositorySummary -Status $_ })
	}
	if (!$SummaryOnly) {
		$result | Add-Member -NotePropertyName Addons -NotePropertyValue $statuses
	}
	$result | ConvertTo-Json -Depth 5
} else {
	Write-Host "ofxGgml family status"
	Write-Host "Root  $addonsRoot"
	Write-Host ""
	Write-Host ("{0,-18} {1,-8} {2,-8} {3,-9} {4,-7} {5,-9} {6,-7} {7}" -f "Addon", "Managed", "Present", "Head", "Dirty", "Validate", "Doctor", "Examples")
	Write-Host ("{0,-18} {1,-8} {2,-8} {3,-9} {4,-7} {5,-9} {6,-7} {7}" -f "-----", "-------", "-------", "----", "-----", "--------", "------", "--------")
	foreach ($status in $statuses) {
		$managed = if ($status.Known) { "yes" } else { "detect" }
		$present = if ($status.Present) { "yes" } else { "missing" }
		$head = if ($status.Head) { $status.Head } else { "-" }
		$dirty = if ($status.DirtyCount -gt 0) { $status.DirtyCount } else { "clean" }
		$validate = if ($status.ValidateScript) { "yes" } else { "missing" }
		$doctor = if ($status.DoctorScript) { "yes" } else { "-" }
		$examples = if ($status.Examples.Count -gt 0) { $status.Examples -join ", " } else { "-" }
		Write-Host ("{0,-18} {1,-8} {2,-8} {3,-9} {4,-7} {5,-9} {6,-7} {7}" -f $status.Name, $managed, $present, $head, $dirty, $validate, $doctor, $examples)
	}
}

if ($Strict) {
	$missingRequired = @($statuses | Where-Object { $_.Known -and (!$_.Present -or !$_.ValidateScript) })
	if ($missingRequired.Count -gt 0) {
		exit 1
	}
}
