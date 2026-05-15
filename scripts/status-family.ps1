param(
	[switch]$Json,
	[switch]$Strict
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreRoot = Resolve-Path (Join-Path $scriptRoot "..")
$addonsRoot = Split-Path -Parent $coreRoot

. (Join-Path $scriptRoot "get-ecosystem.ps1")
$family = @(Get-OfxGgmlEcosystem -AddonsRoot $addonsRoot)

function Test-CommandAvailable {
	param([string]$Name)
	return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Git {
	param(
		[string]$Repository,
		[string[]]$Arguments
	)
	if (!(Test-CommandAvailable "git")) {
		return ""
	}
	$output = & git -C $Repository @Arguments 2>$null
	if ($LASTEXITCODE -ne 0) {
		return ""
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
	$validate = $false
	$doctor = $false
	$agentsInstructions = $false
	$hermesInstructions = $false
	$copilotInstructions = $false
	$copilotEcosystemInstructions = $false
	$agentWorkflowGuidePath = ""
	$examples = @()

	if ($present) {
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
		$examples = @(
			Get-ChildItem -LiteralPath $path -Directory -ErrorAction SilentlyContinue |
				Where-Object { $_.Name -like "*Example" } |
				Sort-Object Name |
				Select-Object -ExpandProperty Name
		)
	}

	[pscustomobject]@{
		Name = $Addon.Name
		Kind = $Addon.Kind
		Lane = $Addon.Lane
		Scope = $Addon.Scope
		Known = $known
		Classified = $classified
		Path = $path
		Present = $present
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
		MissingManagedRepositories = @($managed | Where-Object { !$_.Present }).Count
		MissingValidationEntrypoints = @($managed | Where-Object { $_.Present -and !$_.ValidateScript }).Count
		MissingDoctorEntrypoints = @($managed | Where-Object { $_.Present -and !$_.DoctorScript }).Count
		AgentWorkflowGuideCoverage = @($managed | Where-Object { $_.AgentWorkflowGuide }).Count
	}
}

function Get-FamilyStatusNextCommands {
	$commands = New-Object System.Collections.Generic.List[string]
	$commands.Add("scripts\plan-ecosystem.bat -Json")
	$commands.Add("scripts\audit-ecosystem.bat -Strict")
	$commands.Add("scripts\check-ecosystem-readiness.bat -SkipDoctorTests")
	$commands.Add("scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly")
	$commands.Add("scripts\plan-coding-agent-work.bat -Json")
	return @($commands.ToArray())
}

$statuses = @($family | ForEach-Object { Get-AddonStatus -Addon $_ })
$summary = Get-FamilyStatusSummary -Statuses $statuses
$nextCommands = Get-FamilyStatusNextCommands

if ($Json) {
	[pscustomobject]@{
		Root = $addonsRoot
		Summary = $summary
		NextCommands = $nextCommands
		Addons = $statuses
	} | ConvertTo-Json -Depth 5
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
