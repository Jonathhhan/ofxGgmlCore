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
		Examples = $examples
	}
}

$statuses = @($family | ForEach-Object { Get-AddonStatus -Addon $_ })

if ($Json) {
	[pscustomobject]@{
		Root = $addonsRoot
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
