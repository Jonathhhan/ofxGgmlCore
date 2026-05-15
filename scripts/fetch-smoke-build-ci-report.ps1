param(
	[string]$Repository = "Jonathhhan/ofxGgmlCore",
	[string]$WorkflowFile = "smoke-build-ci.yml",
	[string]$ArtifactName = "ofx-smoke-build-ci-report",
	[string]$OutputPath = "",
	[string]$Branch = "",
	[string]$RunId = "",
	[string]$Token = $env:GITHUB_TOKEN,
	[switch]$Force,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	if (!$Json) {
		Write-Host "==> $Message"
	}
}

function Invoke-GitHubJson {
	param(
		[string]$Uri,
		[string]$Token
	)

	$headers = @{
		Accept = "application/vnd.github+json"
		"X-GitHub-Api-Version" = "2022-11-28"
	}
	if (![string]::IsNullOrWhiteSpace($Token)) {
		$headers.Authorization = "Bearer $Token"
	}
	Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get
}

function Invoke-GitHubDownload {
	param(
		[string]$Uri,
		[string]$Token,
		[string]$OutFile
	)

	if ([string]::IsNullOrWhiteSpace($Token)) {
		throw "GitHub Actions artifact download requires a token. Set GITHUB_TOKEN or pass -Token."
	}

	$headers = @{
		Accept = "application/vnd.github+json"
		"X-GitHub-Api-Version" = "2022-11-28"
		Authorization = "Bearer $Token"
	}
	Invoke-WebRequest -Uri $Uri -Headers $headers -Method Get -OutFile $OutFile
}

function Get-CurrentGitBranch {
	try {
		$branch = @(git branch --show-current 2>$null)[0]
		if ($LASTEXITCODE -eq 0 -and ![string]::IsNullOrWhiteSpace($branch)) {
			return [string]$branch
		}
	} catch {
	}
	return ""
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$resolvedOutputPath = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	Join-Path $addonRoot ".smoke-build-ci-report.json"
} elseif ([System.IO.Path]::IsPathRooted($OutputPath)) {
	$OutputPath
} else {
	Join-Path $addonRoot $OutputPath
}

if ((Test-Path -LiteralPath $resolvedOutputPath -PathType Leaf) -and !$Force) {
	throw "Output report already exists: $resolvedOutputPath. Pass -Force to overwrite it."
}

if ([string]::IsNullOrWhiteSpace($Branch)) {
	$currentBranch = Get-CurrentGitBranch
	if (![string]::IsNullOrWhiteSpace($currentBranch)) {
		$Branch = $currentBranch
	}
}

$apiRoot = "https://api.github.com/repos/$Repository/actions"
$selectedRun = $null
if (![string]::IsNullOrWhiteSpace($RunId)) {
	Write-Step "Using smoke-build CI workflow run $RunId"
	$selectedRun = [pscustomobject]@{
		id = [int64]$RunId
		name = $WorkflowFile
		head_branch = $Branch
		status = "unknown"
		conclusion = "unknown"
		html_url = "https://github.com/$Repository/actions/runs/$RunId"
	}
} else {
	$query = "status=success&per_page=50"
	if (![string]::IsNullOrWhiteSpace($Branch)) {
		$query = "$query&branch=$([uri]::EscapeDataString($Branch))"
	}
	$runsUri = "$apiRoot/workflows/$([uri]::EscapeDataString($WorkflowFile))/runs?$query"
	Write-Step "Finding latest successful smoke-build CI workflow run"
	$runs = Invoke-GitHubJson -Uri $runsUri -Token $Token
	$workflowRuns = @($runs.workflow_runs)
	if ($workflowRuns.Count -eq 0 -and ![string]::IsNullOrWhiteSpace($Branch)) {
		$runsUri = "$apiRoot/workflows/$([uri]::EscapeDataString($WorkflowFile))/runs?status=success&per_page=50"
		Write-Step "No branch-specific run found; falling back to latest successful workflow run"
		$runs = Invoke-GitHubJson -Uri $runsUri -Token $Token
		$workflowRuns = @($runs.workflow_runs)
	}
	$selectedRun = @($workflowRuns | Where-Object { [string]$_.conclusion -eq "success" } | Select-Object -First 1)[0]
	if (!$selectedRun) {
		throw "No successful $WorkflowFile workflow run with a smoke-build report was found for $Repository."
	}
}

$artifactsUri = "$apiRoot/runs/$($selectedRun.id)/artifacts"
Write-Step "Finding smoke-build CI report artifact"
$artifacts = Invoke-GitHubJson -Uri $artifactsUri -Token $Token
$artifact = @(@($artifacts.artifacts) | Where-Object {
	[string]$_.name -eq $ArtifactName -and ![bool]$_.expired
} | Sort-Object -Property created_at -Descending | Select-Object -First 1)[0]
if (!$artifact) {
	throw "Workflow run $($selectedRun.id) did not expose a non-expired $ArtifactName artifact."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgml-smoke-build-ci-artifact-$([guid]::NewGuid().ToString('N'))"
$zipPath = Join-Path $tempRoot "artifact.zip"
$extractPath = Join-Path $tempRoot "extract"
New-Item -ItemType Directory -Force -Path $tempRoot, $extractPath | Out-Null

try {
	Write-Step "Downloading smoke-build CI report artifact"
	Invoke-GitHubDownload -Uri ([string]$artifact.archive_download_url) -Token $Token -OutFile $zipPath
	Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
	$report = @(Get-ChildItem -LiteralPath $extractPath -Recurse -File -Filter ".smoke-build-ci-report.json" | Select-Object -First 1)[0]
	if (!$report) {
		$report = @(Get-ChildItem -LiteralPath $extractPath -Recurse -File -Filter "*.json" | Select-Object -First 1)[0]
	}
	if (!$report) {
		throw "Artifact $ArtifactName did not contain a JSON smoke-build CI report."
	}

	$outputDirectory = Split-Path -Parent $resolvedOutputPath
	if (![string]::IsNullOrWhiteSpace($outputDirectory)) {
		New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
	}
	Copy-Item -LiteralPath $report.FullName -Destination $resolvedOutputPath -Force
} finally {
	Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$result = [ordered]@{
	Repository = $Repository
	WorkflowFile = $WorkflowFile
	Branch = $Branch
	RunId = [string]$selectedRun.id
	RunUrl = [string]$selectedRun.html_url
	ArtifactName = [string]$artifact.name
	ArtifactId = [string]$artifact.id
	OutputPath = $resolvedOutputPath
	ReportExists = Test-Path -LiteralPath $resolvedOutputPath -PathType Leaf
}

if ($Json) {
	[pscustomobject]$result | ConvertTo-Json -Depth 5
} else {
	Write-Host "Smoke-build CI report: $resolvedOutputPath"
}
