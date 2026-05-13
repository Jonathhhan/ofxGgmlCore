param(
	[string]$BranchPattern = "codex/*",
	[string]$OutputPath = "",
	[switch]$Fetch,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

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

function Get-DefaultBranch {
	param([string]$Repository)

	$remoteHead = Invoke-Git -Repository $Repository -Arguments @("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
	if (![string]::IsNullOrWhiteSpace($remoteHead) -and $remoteHead -like "origin/*") {
		return @{
			Local = $remoteHead.Substring("origin/".Length)
			Remote = $remoteHead
		}
	}

	$main = Invoke-Git -Repository $Repository -Arguments @("rev-parse", "--verify", "--quiet", "main")
	if (![string]::IsNullOrWhiteSpace($main)) {
		return @{
			Local = "main"
			Remote = "origin/main"
		}
	}

	$master = Invoke-Git -Repository $Repository -Arguments @("rev-parse", "--verify", "--quiet", "master")
	if (![string]::IsNullOrWhiteSpace($master)) {
		return @{
			Local = "master"
			Remote = "origin/master"
		}
	}

	return @{
		Local = ""
		Remote = ""
	}
}

function ConvertTo-DeleteCommand {
	param(
		[string]$Repository,
		[string]$Type,
		[string]$Branch
	)

	if ($Type -eq "local") {
		return "git -C `"$Repository`" branch -d $Branch"
	}

	$parts = $Branch -split "/", 2
	if ($parts.Count -lt 2) {
		return ""
	}
	return "git -C `"$Repository`" push $($parts[0]) --delete $($parts[1])"
}

function Get-MergedBranches {
	param([object]$Status)

	$repo = [string]$Status.Path
	if ($Fetch) {
		& git -C $repo fetch --prune --quiet 2>$null
		if ($LASTEXITCODE -ne 0) {
			throw "Failed to fetch $($Status.Name)."
		}
	}

	$defaultBranch = Get-DefaultBranch -Repository $repo
	$current = Invoke-Git -Repository $repo -Arguments @("branch", "--show-current")
	$candidates = @()

	if (![string]::IsNullOrWhiteSpace($defaultBranch.Local)) {
		$localBranches = Invoke-Git -Repository $repo -Arguments @("branch", "--format", "%(refname:short)", "--merged", $defaultBranch.Local)
		foreach ($branch in @($localBranches -split "`n" | Where-Object { $_ })) {
			$branch = $branch.Trim()
			if ($branch -eq $defaultBranch.Local -or $branch -notlike $BranchPattern) {
				continue
			}
			$isCurrent = $branch -eq $current
			$candidates += [pscustomobject]@{
				Repository = [string]$Status.Name
				Path = $repo
				Type = "local"
				Branch = $branch
				DefaultBranch = [string]$defaultBranch.Local
				Current = $isCurrent
				Action = if ($isCurrent) { "skip current local branch" } else { "delete merged local branch" }
				DeleteCommand = if ($isCurrent) { "" } else { ConvertTo-DeleteCommand -Repository $repo -Type "local" -Branch $branch }
			}
		}
	}

	if (![string]::IsNullOrWhiteSpace($defaultBranch.Remote)) {
		$remoteBranches = Invoke-Git -Repository $repo -Arguments @("branch", "-r", "--format", "%(refname:short)", "--merged", $defaultBranch.Remote)
		foreach ($branch in @($remoteBranches -split "`n" | Where-Object { $_ })) {
			$branch = $branch.Trim()
			if ($branch -eq $defaultBranch.Remote -or $branch -eq "origin/HEAD" -or $branch -notlike "*/$BranchPattern") {
				continue
			}
			$candidates += [pscustomobject]@{
				Repository = [string]$Status.Name
				Path = $repo
				Type = "remote"
				Branch = $branch
				DefaultBranch = [string]$defaultBranch.Remote
				Current = $false
				Action = "delete merged remote branch"
				DeleteCommand = ConvertTo-DeleteCommand -Repository $repo -Type "remote" -Branch $branch
			}
		}
	}

	return @($candidates)
}

function ConvertTo-MarkdownCleanupPlan {
	param(
		[array]$Candidates,
		[string]$Root
	)

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# ofxGgml Agent Branch Cleanup Plan")
	$lines.Add("")
	$lines.Add("Dry-run cleanup plan for merged Codex/Copilot/Hermes agent branches in managed repositories.")
	$lines.Add("")
	$lines.Add("Root: $Root")
	$lines.Add("Branch pattern: ``$BranchPattern``")
	if ($Fetch) {
		$lines.Add("Remote refs were fetched with prune before planning.")
	} else {
		$lines.Add("Remote refs were not fetched. Use ``-Fetch`` to refresh before acting.")
	}
	$lines.Add("")
	if ($Candidates.Count -eq 0) {
		$lines.Add("No merged agent branches were found.")
	} else {
		$lines.Add("| Repository | Type | Branch | Default | Action | Delete command |")
		$lines.Add("| --- | --- | --- | --- | --- | --- |")
		foreach ($candidate in $Candidates) {
			$command = if ([string]::IsNullOrWhiteSpace($candidate.DeleteCommand)) { "" } else { $candidate.DeleteCommand.Replace("|", "\|") }
			$lines.Add(("| {0} | {1} | ``{2}`` | ``{3}`` | {4} | ``{5}`` |" -f $candidate.Repository, $candidate.Type, $candidate.Branch, $candidate.DefaultBranch, $candidate.Action, $command))
		}
	}
	$lines.Add("")
	$lines.Add("This script only writes a plan. Review the commands before deleting branches.")

	return $lines -join [Environment]::NewLine
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusJson = & (Join-Path $scriptRoot "status-family.ps1") -Json
if (!$?) {
	throw "status-family.ps1 failed."
}

$status = $statusJson | ConvertFrom-Json
$repositories = @($status.Addons | Where-Object { $_.Known -and $_.Present })
$candidates = @($repositories | ForEach-Object { Get-MergedBranches -Status $_ })

if ($Json) {
	$content = [pscustomobject]@{
		Root = $status.Root
		BranchPattern = $BranchPattern
		Fetched = [bool]$Fetch
		Candidates = $candidates
	} | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownCleanupPlan -Candidates $candidates -Root ([string]$status.Root)
}

if (![string]::IsNullOrWhiteSpace($OutputPath)) {
	$target = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
		$OutputPath
	} else {
		Join-Path (Split-Path -Parent $scriptRoot) $OutputPath
	}
	$directory = Split-Path -Parent $target
	if (!(Test-Path -LiteralPath $directory -PathType Container)) {
		New-Item -ItemType Directory -Path $directory -Force | Out-Null
	}
	Set-Content -LiteralPath $target -Value $content
	Write-Host "Wrote $target"
} else {
	Write-Output $content
}
