param(
	[string]$OutputPath = "",
	[string]$WorkflowStatusReport = "",
	[string]$BackendCapabilityReport = "",
	[string]$BackendRuntimePlan = "",
	[string]$SmokeBuildCiReport = "",
	[int]$StaleDays = 30,
	[switch]$AllowDefaultBackendCapability,
	[switch]$AllowDefaultSmokeBuildCi,
	[switch]$AllowBackendRuntimeEvidenceGaps,
	[switch]$SkipManagedGitStatus,
	[switch]$SkipWorkflowStatus,
	[switch]$SkipBackendCapability,
	[switch]$SkipBackendRuntimePlan,
	[switch]$SkipSmokeBuildCi,
	[switch]$FetchSmokeBuildCiReport,
	[switch]$FailOnEvidenceGaps,
	[switch]$SummaryOnly,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	if ($Json) {
		return
	}
	Write-Host "==> $Message"
}

function Get-LlamaCodexSmokeCommand {
	param([string]$CoreRoot)

	$addonsRoot = Split-Path -Parent $CoreRoot
	$llamaRoot = Join-Path $addonsRoot "ofxGgmlLlama"
	$metadataPath = Join-Path $llamaRoot "ofxggml-addon.json"
	if (!(Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
		return ""
	}

	try {
		$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
		if (!$metadata.PSObject.Properties["codexLocalSmoke"]) {
			return ""
		}
		$scriptPath = [string]$metadata.codexLocalSmoke
		if ([string]::IsNullOrWhiteSpace($scriptPath)) {
			return ""
		}
		if (!(Test-Path -LiteralPath (Join-Path $llamaRoot $scriptPath) -PathType Leaf)) {
			return ""
		}
		return "cd ..\ofxGgmlLlama && $scriptPath -Json -SummaryOnly"
	} catch {
		return ""
	}
}

function Get-ReleaseReadinessNextCommands {
	param([string]$CoreRoot)

	$commands = New-Object System.Collections.Generic.List[string]
	$commands.Add("scripts\validate-local.bat")
	$commands.Add("scripts\audit-ecosystem.bat -Strict")
	$commands.Add("scripts\plan-local-codex.bat -Json -SummaryOnly")
	$codexSmokeCommand = Get-LlamaCodexSmokeCommand -CoreRoot $CoreRoot
	if (![string]::IsNullOrWhiteSpace($codexSmokeCommand)) {
		$commands.Add($codexSmokeCommand)
	}
	$commands.Add("scripts\check-ecosystem-readiness.bat -SkipDoctorTests")
	$commands.Add("scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly")
	$commands.Add("scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly")
	$commands.Add("scripts\fetch-smoke-build-ci-report.bat -Force")
	$commands.Add("scripts\run-smoke-build-ci.bat -CloneAddonRepos -TargetsPerStage 0")
	$commands.Add("scripts\plan-release-readiness.bat -Json -SummaryOnly")
	$commands.Add("scripts\release-candidate.bat")
	return @($commands.ToArray())
}

function New-ReleaseEvidenceSummary {
	param(
		[string]$Name,
		[bool]$Provided,
		[bool]$Exists,
		[bool]$Generated = $false,
		[bool]$DefaultUsed = $false,
		[string]$Path = ""
	)

	$result = [ordered]@{
		Name = $Name
		Provided = $Provided
		Exists = $Exists
		Generated = $Generated
		DefaultUsed = $DefaultUsed
	}
	if (!$SummaryOnly) {
		$result.Path = $Path
	}
	[pscustomobject]$result
}

function Get-FamilyGitEvidence {
	param([string]$ScriptsRoot)

	if ($SkipManagedGitStatus) {
		return [pscustomobject]@{
			Checked = $false
			Available = $false
			DirtyManagedRepositories = 0
			DirtyManagedRepositoryNames = @()
			DirtyReferenceRepositories = 0
			DirtyReferenceRepositoryNames = @()
		}
	}

	try {
		$statusOutput = @(& (Join-Path $ScriptsRoot "status-family.ps1") -Json -SummaryOnly 2>&1)
		if (!$?) {
			throw "status-family.ps1 failed: $($statusOutput -join "`n")"
		}
		$status = ($statusOutput -join "`n") | ConvertFrom-Json
		$managedDirty = @(
			$status.RepositorySummaries |
				Where-Object { $_.Known -and [int]$_.DirtyCount -gt 0 } |
				Sort-Object Name
		)
		$referenceDirty = @(
			$status.RepositorySummaries |
				Where-Object { !$_.Known -and [int]$_.DirtyCount -gt 0 } |
				Sort-Object Name
		)
		return [pscustomobject]@{
			Checked = $true
			Available = $true
			DirtyManagedRepositories = @($managedDirty).Count
			DirtyManagedRepositoryNames = @($managedDirty | ForEach-Object { [string]$_.Name })
			DirtyReferenceRepositories = @($referenceDirty).Count
			DirtyReferenceRepositoryNames = @($referenceDirty | ForEach-Object { [string]$_.Name })
		}
	} catch {
		return [pscustomobject]@{
			Checked = $true
			Available = $false
			DirtyManagedRepositories = 0
			DirtyManagedRepositoryNames = @()
			DirtyReferenceRepositories = 0
			DirtyReferenceRepositoryNames = @()
		}
	}
}

function Get-BackendRuntimePlanMetrics {
	param([string]$Path)

	$metrics = @{}
	if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path -PathType Leaf)) {
		return $metrics
	}

	foreach ($line in @(Get-Content -LiteralPath $Path)) {
		$match = [regex]::Match($line, "^\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|$")
		if (!$match.Success) {
			continue
		}
		$name = $match.Groups[1].Value.Trim()
		if ($name -in @("Metric", "---")) {
			continue
		}
		$metrics[$name] = [int]$match.Groups[2].Value
	}
	return $metrics
}

function Get-ReleaseEvidenceGaps {
	param(
		[pscustomobject]$Summary
	)

	$gaps = New-Object System.Collections.Generic.List[string]
	if (!$Summary.ReleaseReportExists) {
		$gaps.Add("release-readiness report was not generated") | Out-Null
	}
	if (!$SkipWorkflowStatus -and !$Summary.WorkflowStatusEvidenceExists) {
		$gaps.Add("workflow status evidence is missing") | Out-Null
	}
	if (!$SkipBackendCapability -and !$Summary.BackendCapabilityEvidenceExists) {
		$gaps.Add("backend capability evidence is missing") | Out-Null
	}
	if (
		!$SkipBackendCapability -and
		!$AllowDefaultBackendCapability -and
		$Summary.BackendCapabilityDefaultUsed
	) {
		$gaps.Add("backend capability evidence is using the default repository report") | Out-Null
	}
	if (!$SkipBackendRuntimePlan -and !$Summary.BackendRuntimePlanEvidenceExists) {
		$gaps.Add("backend runtime verification evidence is missing") | Out-Null
	}
	if (
		!$SkipBackendRuntimePlan -and
		!$AllowBackendRuntimeEvidenceGaps -and
		$Summary.BackendRuntimePlanEvidenceExists -and
		$Summary.BackendRuntimeInferenceSmokeEntrypoints -gt 0 -and
		$Summary.BackendRuntimeInferenceCheckedRepositories -eq 0
	) {
		$gaps.Add("backend runtime inference evidence is present but no repository is inference-checked") | Out-Null
	}
	if (
		!$SkipBackendRuntimePlan -and
		!$AllowBackendRuntimeEvidenceGaps -and
		$Summary.BackendRuntimePlanEvidenceExists -and
		$Summary.BackendRuntimeExampleBuildGaps -gt 0
	) {
		$gaps.Add("backend runtime example build evidence has actionable gaps") | Out-Null
	}
	if (!$SkipSmokeBuildCi -and !$Summary.SmokeBuildCiEvidenceExists) {
		$gaps.Add("smoke-build CI evidence is missing") | Out-Null
	}
	if (
		!$SkipSmokeBuildCi -and
		!$AllowDefaultSmokeBuildCi -and
		$Summary.SmokeBuildCiDefaultUsed -and
		!$Summary.SmokeBuildCiEvidenceFetched
	) {
		$gaps.Add("smoke-build CI evidence is using the default local report instead of freshly fetched evidence") | Out-Null
	}
	if (!$SkipManagedGitStatus -and !$Summary.ManagedGitStatusAvailable) {
		$gaps.Add("managed repository git status evidence is unavailable") | Out-Null
	}
	if (!$SkipManagedGitStatus -and $Summary.DirtyManagedRepositories -gt 0) {
		$gaps.Add("managed repositories have uncommitted changes: $(@($Summary.DirtyManagedRepositoryNames) -join ', ')") | Out-Null
	}
	return @($gaps.ToArray())
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$releaseScript = Join-Path $scriptRoot "generate-release-readiness-score.py"
$workflowScript = Join-Path $scriptRoot "fetch-workflow-status.py"
$backendRuntimeScript = Join-Path $scriptRoot "plan-backend-runtime-verification.ps1"
$smokeBuildFetchScript = Join-Path $scriptRoot "fetch-smoke-build-ci-report.ps1"

$resolvedOutputPath = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-release-readiness-score.md"
} elseif ([System.IO.Path]::IsPathRooted($OutputPath)) {
	$OutputPath
} else {
	Join-Path $addonRoot $OutputPath
}

$workflowReport = $WorkflowStatusReport
$generatedWorkflowReport = $false
if ([string]::IsNullOrWhiteSpace($workflowReport) -and !$SkipWorkflowStatus) {
	$workflowReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-workflow-status-release-evidence.md"
	$generatedWorkflowReport = $true
	Write-Step "Generating workflow status evidence"
	$workflowOutput = @(python $workflowScript --output $workflowReport --stale-days $StaleDays 2>&1)
	if (!$?) {
		if ($workflowOutput.Count -gt 0) {
			$workflowOutput | Write-Host
		}
		throw "fetch-workflow-status.py failed."
	}
	if (!$Json -and $workflowOutput.Count -gt 0) {
		$workflowOutput | Write-Host
	}
}

$backendReport = $BackendCapabilityReport
$usedDefaultBackendReport = $false
if ([string]::IsNullOrWhiteSpace($backendReport) -and !$SkipBackendCapability) {
	$defaultBackendReport = Join-Path $addonRoot "docs\backend-capability-report.md"
	if (Test-Path -LiteralPath $defaultBackendReport -PathType Leaf) {
		$backendReport = $defaultBackendReport
		$usedDefaultBackendReport = $true
	}
}

$backendRuntimePlan = $BackendRuntimePlan
$generatedBackendRuntimePlan = $false
if ([string]::IsNullOrWhiteSpace($backendRuntimePlan) -and !$SkipBackendRuntimePlan) {
	$backendRuntimePlan = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-backend-runtime-verification-release-evidence.md"
	$generatedBackendRuntimePlan = $true
	Write-Step "Generating backend runtime verification evidence"
	$backendRuntimeOutput = @(& $backendRuntimeScript -OutputPath $backendRuntimePlan -Quiet 2>&1)
	if (!$?) {
		if ($backendRuntimeOutput.Count -gt 0) {
			$backendRuntimeOutput | Write-Host
		}
		throw "plan-backend-runtime-verification.ps1 failed."
	}
	if (!$Json -and $backendRuntimeOutput.Count -gt 0) {
		$backendRuntimeOutput | Write-Host
	}
}

$smokeBuildReport = $SmokeBuildCiReport
$usedDefaultSmokeBuildReport = $false
$fetchedSmokeBuildReport = $false
if ([string]::IsNullOrWhiteSpace($smokeBuildReport) -and !$SkipSmokeBuildCi) {
	$defaultSmokeBuildReport = Join-Path $addonRoot ".smoke-build-ci-report.json"
	if (Test-Path -LiteralPath $defaultSmokeBuildReport -PathType Leaf) {
		$smokeBuildReport = $defaultSmokeBuildReport
		$usedDefaultSmokeBuildReport = $true
	} elseif ($FetchSmokeBuildCiReport) {
		$smokeBuildReport = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-smoke-build-ci-release-evidence.json"
		Write-Step "Fetching smoke-build CI report evidence"
		$fetchOutput = @(& $smokeBuildFetchScript -OutputPath $smokeBuildReport -Force -Json 2>&1)
		if (!$?) {
			if ($fetchOutput.Count -gt 0) {
				$fetchOutput | Write-Host
			}
			throw "fetch-smoke-build-ci-report.ps1 failed."
		}
		$fetchedSmokeBuildReport = $true
		if (!$Json -and $fetchOutput.Count -gt 0) {
			$fetchOutput | Write-Host
		}
	}
}

$arguments = @($releaseScript, "--output", $resolvedOutputPath)
if (![string]::IsNullOrWhiteSpace($workflowReport)) {
	$arguments += @("--workflow-status-report", $workflowReport)
}
if (![string]::IsNullOrWhiteSpace($backendReport)) {
	$arguments += @("--backend-capability-report", $backendReport)
}
if (![string]::IsNullOrWhiteSpace($backendRuntimePlan)) {
	$arguments += @("--backend-runtime-plan", $backendRuntimePlan)
}
if (![string]::IsNullOrWhiteSpace($smokeBuildReport)) {
	$arguments += @("--smoke-build-ci-report", $smokeBuildReport)
}

Write-Step "Generating release readiness score"
$releaseOutput = @(python @arguments 2>&1)
if (!$?) {
	if ($releaseOutput.Count -gt 0) {
		$releaseOutput | Write-Host
	}
	throw "generate-release-readiness-score.py failed."
}
if (!$Json -and $releaseOutput.Count -gt 0) {
	$releaseOutput | Write-Host
}

$gitEvidence = Get-FamilyGitEvidence -ScriptsRoot $scriptRoot
$backendRuntimeMetrics = Get-BackendRuntimePlanMetrics -Path $backendRuntimePlan
$backendRuntimeInferenceEntrypoints = if ($backendRuntimeMetrics.ContainsKey("Inference-smoke entrypoints")) {
	[int]$backendRuntimeMetrics["Inference-smoke entrypoints"]
} else {
	-1
}
$backendRuntimeInferenceChecked = if ($backendRuntimeMetrics.ContainsKey("Inference-checked repositories")) {
	[int]$backendRuntimeMetrics["Inference-checked repositories"]
} else {
	-1
}
$backendRuntimeExampleBuildGaps = if ($backendRuntimeMetrics.ContainsKey("Actionable repositories missing built examples")) {
	[int]$backendRuntimeMetrics["Actionable repositories missing built examples"]
} elseif ($backendRuntimeMetrics.ContainsKey("Example build gaps")) {
	[int]$backendRuntimeMetrics["Example build gaps"]
} else {
	-1
}

$summary = [pscustomobject]@{
	ReleaseReportExists = Test-Path -LiteralPath $resolvedOutputPath -PathType Leaf
	WorkflowStatusEvidenceProvided = ![string]::IsNullOrWhiteSpace($workflowReport)
	WorkflowStatusEvidenceGenerated = $generatedWorkflowReport
	WorkflowStatusEvidenceExists = (![string]::IsNullOrWhiteSpace($workflowReport) -and (Test-Path -LiteralPath $workflowReport -PathType Leaf))
	BackendCapabilityEvidenceProvided = ![string]::IsNullOrWhiteSpace($backendReport)
	BackendCapabilityDefaultUsed = $usedDefaultBackendReport
	BackendCapabilityEvidenceExists = (![string]::IsNullOrWhiteSpace($backendReport) -and (Test-Path -LiteralPath $backendReport -PathType Leaf))
	BackendRuntimePlanEvidenceProvided = ![string]::IsNullOrWhiteSpace($backendRuntimePlan)
	BackendRuntimePlanEvidenceGenerated = $generatedBackendRuntimePlan
	BackendRuntimePlanEvidenceExists = (![string]::IsNullOrWhiteSpace($backendRuntimePlan) -and (Test-Path -LiteralPath $backendRuntimePlan -PathType Leaf))
	BackendRuntimeInferenceSmokeEntrypoints = $backendRuntimeInferenceEntrypoints
	BackendRuntimeInferenceCheckedRepositories = $backendRuntimeInferenceChecked
	BackendRuntimeExampleBuildGaps = $backendRuntimeExampleBuildGaps
	SmokeBuildCiEvidenceProvided = ![string]::IsNullOrWhiteSpace($smokeBuildReport)
	SmokeBuildCiDefaultUsed = $usedDefaultSmokeBuildReport
	SmokeBuildCiEvidenceFetched = $fetchedSmokeBuildReport
	SmokeBuildCiEvidenceExists = (![string]::IsNullOrWhiteSpace($smokeBuildReport) -and (Test-Path -LiteralPath $smokeBuildReport -PathType Leaf))
	ManagedGitStatusChecked = [bool]$gitEvidence.Checked
	ManagedGitStatusAvailable = [bool]$gitEvidence.Available
	DirtyManagedRepositories = [int]$gitEvidence.DirtyManagedRepositories
	DirtyManagedRepositoryNames = @($gitEvidence.DirtyManagedRepositoryNames)
	DirtyReferenceRepositories = [int]$gitEvidence.DirtyReferenceRepositories
	DirtyReferenceRepositoryNames = @($gitEvidence.DirtyReferenceRepositoryNames)
	OutputPathIsTemporary = [string]::IsNullOrWhiteSpace($OutputPath)
}
$evidenceGaps = [string[]](Get-ReleaseEvidenceGaps -Summary $summary)
$summary | Add-Member -NotePropertyName EvidenceGapCount -NotePropertyValue ([int]$evidenceGaps.Count)
$nextCommands = Get-ReleaseReadinessNextCommands -CoreRoot $addonRoot
$evidenceSummaries = @(
	New-ReleaseEvidenceSummary `
		-Name "workflow status" `
		-Provided (![string]::IsNullOrWhiteSpace($workflowReport)) `
		-Exists (![string]::IsNullOrWhiteSpace($workflowReport) -and (Test-Path -LiteralPath $workflowReport -PathType Leaf)) `
		-Generated $generatedWorkflowReport `
		-Path $workflowReport
	New-ReleaseEvidenceSummary `
		-Name "backend capability" `
		-Provided (![string]::IsNullOrWhiteSpace($backendReport)) `
		-Exists (![string]::IsNullOrWhiteSpace($backendReport) -and (Test-Path -LiteralPath $backendReport -PathType Leaf)) `
		-DefaultUsed $usedDefaultBackendReport `
		-Path $backendReport
	New-ReleaseEvidenceSummary `
		-Name "backend runtime verification" `
		-Provided (![string]::IsNullOrWhiteSpace($backendRuntimePlan)) `
		-Exists (![string]::IsNullOrWhiteSpace($backendRuntimePlan) -and (Test-Path -LiteralPath $backendRuntimePlan -PathType Leaf)) `
		-Generated $generatedBackendRuntimePlan `
		-Path $backendRuntimePlan
	New-ReleaseEvidenceSummary `
		-Name "smoke-build CI" `
		-Provided (![string]::IsNullOrWhiteSpace($smokeBuildReport)) `
		-Exists (![string]::IsNullOrWhiteSpace($smokeBuildReport) -and (Test-Path -LiteralPath $smokeBuildReport -PathType Leaf)) `
		-DefaultUsed $usedDefaultSmokeBuildReport `
		-Path $smokeBuildReport
)

if ($Json) {
	$result = [ordered]@{
		Root = $addonRoot
		StaleDays = $StaleDays
		AllowDefaultBackendCapability = [bool]$AllowDefaultBackendCapability
		AllowDefaultSmokeBuildCi = [bool]$AllowDefaultSmokeBuildCi
		AllowBackendRuntimeEvidenceGaps = [bool]$AllowBackendRuntimeEvidenceGaps
		SkipManagedGitStatus = [bool]$SkipManagedGitStatus
		SkipWorkflowStatus = [bool]$SkipWorkflowStatus
		SkipBackendCapability = [bool]$SkipBackendCapability
		SkipBackendRuntimePlan = [bool]$SkipBackendRuntimePlan
		SkipSmokeBuildCi = [bool]$SkipSmokeBuildCi
		FetchSmokeBuildCiReport = [bool]$FetchSmokeBuildCiReport
		FailOnEvidenceGaps = [bool]$FailOnEvidenceGaps
		SummaryOnly = [bool]$SummaryOnly
		Summary = $summary
		EvidenceSummaries = $evidenceSummaries
		EvidenceGaps = [string[]]$evidenceGaps
		NextCommands = $nextCommands
	}
	if (!$SummaryOnly) {
		$result.OutputPath = $resolvedOutputPath
		$result.WorkflowStatusReport = $workflowReport
		$result.BackendCapabilityReport = $backendReport
		$result.BackendRuntimePlan = $backendRuntimePlan
		$result.SmokeBuildCiReport = $smokeBuildReport
	}
	[pscustomobject]$result | ConvertTo-Json -Depth 5
} else {
	Write-Host "Release readiness plan: $resolvedOutputPath"
}

if ($FailOnEvidenceGaps -and $evidenceGaps.Count -gt 0) {
	exit 1
}
