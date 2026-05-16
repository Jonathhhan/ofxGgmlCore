param(
	[string]$BranchPattern = "codex/*",
	[string]$OutputPath = "",
	[switch]$Fetch,
	[switch]$SummaryOnly,
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
		[string]$Branch,
		[switch]$Force
	)

	if ($Type -eq "local") {
		$flag = if ($Force) { "-D" } else { "-d" }
		return "git -C `"$Repository`" branch $flag $Branch"
	}

	$parts = $Branch -split "/", 2
	if ($parts.Count -lt 2) {
		return ""
	}
	return "git -C `"$Repository`" push $($parts[0]) --delete $($parts[1])"
}

function ConvertTo-ReviewCommand {
	param(
		[string]$Repository,
		[string]$DefaultBranch,
		[string]$Branch
	)

	if ([string]::IsNullOrWhiteSpace($DefaultBranch) -or [string]::IsNullOrWhiteSpace($Branch)) {
		return ""
	}

	return "git -C `"$Repository`" log --oneline --decorate $DefaultBranch..$Branch"
}

function Test-BranchPatchEquivalent {
	param(
		[string]$Repository,
		[string]$Upstream,
		[string]$Branch
	)

	if ([string]::IsNullOrWhiteSpace($Upstream) -or [string]::IsNullOrWhiteSpace($Branch)) {
		return $false
	}

	$cherry = Invoke-Git -Repository $Repository -Arguments @("cherry", $Upstream, $Branch)
	$lines = @($cherry -split "`n" | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
	if ($lines.Count -eq 0) {
		return $false
	}

	$remaining = @($lines | Where-Object { !$_.Trim().StartsWith("-") })
	foreach ($line in $remaining) {
		$parts = @($line.Trim() -split "\s+")
		if ($parts.Count -lt 2) {
			return $false
		}
		$changedPaths = @(
			(Invoke-Git -Repository $Repository -Arguments @("diff-tree", "--no-commit-id", "--name-only", "-r", $parts[1])) -split "`n" |
				Where-Object { ![string]::IsNullOrWhiteSpace($_) }
		)
		if ($changedPaths.Count -gt 0) {
			return $false
		}
	}

	return $true
}

function Test-BranchContentEquivalent {
	param(
		[string]$Repository,
		[string]$Upstream,
		[string]$Branch
	)

	if ([string]::IsNullOrWhiteSpace($Upstream) -or [string]::IsNullOrWhiteSpace($Branch)) {
		return $false
	}

	$mergeBase = Invoke-Git -Repository $Repository -Arguments @("merge-base", $Upstream, $Branch)
	if ([string]::IsNullOrWhiteSpace($mergeBase)) {
		return $false
	}

	$changedPaths = @(
		(Invoke-Git -Repository $Repository -Arguments @("diff", "--name-only", "$mergeBase..$Branch")) -split "`n" |
			Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
			ForEach-Object { $_.Trim() }
	)
	if ($changedPaths.Count -eq 0) {
		return $false
	}

	foreach ($path in $changedPaths) {
		$upstreamObject = Invoke-Git -Repository $Repository -Arguments @("rev-parse", "$Upstream`:$path")
		$branchObject = Invoke-Git -Repository $Repository -Arguments @("rev-parse", "$Branch`:$path")
		if ($upstreamObject -ne $branchObject) {
			return $false
		}
	}

	return $true
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
		$mergedLocalBranches = @(
			(Invoke-Git -Repository $repo -Arguments @("branch", "--format", "%(refname:short)", "--merged", $defaultBranch.Local)) -split "`n" |
				Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
				ForEach-Object { $_.Trim() }
		)
		$localBranches = Invoke-Git -Repository $repo -Arguments @("branch", "--format", "%(refname:short)")
		foreach ($branch in @($localBranches -split "`n" | Where-Object { $_ })) {
			$branch = $branch.Trim()
			if ($branch -eq $defaultBranch.Local -or $branch -notlike $BranchPattern) {
				continue
			}
			$directlyMerged = $mergedLocalBranches -contains $branch
			$patchEquivalent = !$directlyMerged -and (Test-BranchPatchEquivalent -Repository $repo -Upstream $defaultBranch.Local -Branch $branch)
			$contentEquivalent = !$directlyMerged -and !$patchEquivalent -and (Test-BranchContentEquivalent -Repository $repo -Upstream $defaultBranch.Local -Branch $branch)
			if (!$directlyMerged -and !$patchEquivalent -and !$contentEquivalent) {
				continue
			}
			$integration = if ($directlyMerged) { "merged" } elseif ($patchEquivalent) { "patch-equivalent" } else { "content-equivalent" }
			$isCurrent = $branch -eq $current
			$candidates += [pscustomobject]@{
				Repository = [string]$Status.Name
				Path = $repo
				Type = "local"
				Branch = $branch
				DefaultBranch = [string]$defaultBranch.Local
				Integration = $integration
				Current = $isCurrent
				Action = if ($isCurrent) { "skip current local branch" } else { "delete integrated local branch" }
				DeleteCommand = if ($isCurrent) { "" } else { ConvertTo-DeleteCommand -Repository $repo -Type "local" -Branch $branch -Force:(!$directlyMerged) }
			}
		}
	}

	if (![string]::IsNullOrWhiteSpace($defaultBranch.Remote)) {
		$mergedRemoteBranches = @(
			(Invoke-Git -Repository $repo -Arguments @("branch", "-r", "--format", "%(refname:short)", "--merged", $defaultBranch.Remote)) -split "`n" |
				Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
				ForEach-Object { $_.Trim() }
		)
		$remoteBranches = Invoke-Git -Repository $repo -Arguments @("branch", "-r", "--format", "%(refname:short)")
		foreach ($branch in @($remoteBranches -split "`n" | Where-Object { $_ })) {
			$branch = $branch.Trim()
			if ($branch -eq $defaultBranch.Remote -or $branch -eq "origin/HEAD" -or $branch -notlike "*/$BranchPattern") {
				continue
			}
			$directlyMerged = $mergedRemoteBranches -contains $branch
			$patchEquivalent = !$directlyMerged -and (Test-BranchPatchEquivalent -Repository $repo -Upstream $defaultBranch.Remote -Branch $branch)
			$contentEquivalent = !$directlyMerged -and !$patchEquivalent -and (Test-BranchContentEquivalent -Repository $repo -Upstream $defaultBranch.Remote -Branch $branch)
			if (!$directlyMerged -and !$patchEquivalent -and !$contentEquivalent) {
				continue
			}
			$integration = if ($directlyMerged) { "merged" } elseif ($patchEquivalent) { "patch-equivalent" } else { "content-equivalent" }
			$candidates += [pscustomobject]@{
				Repository = [string]$Status.Name
				Path = $repo
				Type = "remote"
				Branch = $branch
				DefaultBranch = [string]$defaultBranch.Remote
				Integration = $integration
				Current = $false
				Action = "delete integrated remote branch"
				DeleteCommand = ConvertTo-DeleteCommand -Repository $repo -Type "remote" -Branch $branch
			}
		}
	}

	return @($candidates)
}

function Get-AgentBranchInventory {
	param([object]$Status)

	$repo = [string]$Status.Path
	$current = Invoke-Git -Repository $repo -Arguments @("branch", "--show-current")
	$branches = @()

	$localBranches = Invoke-Git -Repository $repo -Arguments @("branch", "--format", "%(refname:short)")
	foreach ($branch in @($localBranches -split "`n" | Where-Object { $_ })) {
		$branch = $branch.Trim()
		if ($branch -notlike $BranchPattern) {
			continue
		}
		$branches += [pscustomobject]@{
			Repository = [string]$Status.Name
			Path = $repo
			Type = "local"
			Branch = $branch
			Current = ($branch -eq $current)
		}
	}

	$remoteBranches = Invoke-Git -Repository $repo -Arguments @("branch", "-r", "--format", "%(refname:short)")
	foreach ($branch in @($remoteBranches -split "`n" | Where-Object { $_ })) {
		$branch = $branch.Trim()
		if ($branch -eq "origin/HEAD" -or $branch -notlike "*/$BranchPattern") {
			continue
		}
		$branches += [pscustomobject]@{
			Repository = [string]$Status.Name
			Path = $repo
			Type = "remote"
			Branch = $branch
			Current = $false
		}
	}

	return @($branches)
}

function Get-UnintegratedBranchReviews {
	param(
		[array]$Inventory,
		[array]$Candidates
	)

	$candidateKeys = @{}
	foreach ($candidate in @($Candidates)) {
		$candidateKeys["$($candidate.Repository)|$($candidate.Type)|$($candidate.Branch)"] = $true
	}

	$reviews = New-Object System.Collections.Generic.List[object]
	foreach ($branch in @($Inventory)) {
		$key = "$($branch.Repository)|$($branch.Type)|$($branch.Branch)"
		if ($candidateKeys.ContainsKey($key)) {
			continue
		}

		$defaultBranch = Get-DefaultBranch -Repository ([string]$branch.Path)
		$upstream = if ($branch.Type -eq "remote") {
			[string]$defaultBranch.Remote
		} else {
			[string]$defaultBranch.Local
		}

		$reviews.Add([pscustomobject]@{
			Repository = [string]$branch.Repository
			Path = [string]$branch.Path
			Type = [string]$branch.Type
			Branch = [string]$branch.Branch
			DefaultBranch = $upstream
			Current = [bool]$branch.Current
			Action = "review unintegrated branch before cleanup"
			ReviewCommand = ConvertTo-ReviewCommand -Repository ([string]$branch.Path) -DefaultBranch $upstream -Branch ([string]$branch.Branch)
		}) | Out-Null
	}

	return @($reviews.ToArray())
}

function Get-CleanupNextCommands {
	param(
		[array]$Candidates,
		[switch]$SummaryOnly
	)

	$commands = New-Object System.Collections.Generic.List[string]
	$deleteCommands = @($Candidates |
		Where-Object { ![string]::IsNullOrWhiteSpace([string]$_.DeleteCommand) } |
		ForEach-Object { [string]$_.DeleteCommand })

	if ($SummaryOnly) {
		if (!$Fetch) {
			$commands.Add("scripts\plan-agent-branch-cleanup.bat -Fetch -Json -SummaryOnly")
		}
		if ($deleteCommands.Count -gt 0) {
			$commands.Add("scripts\plan-agent-branch-cleanup.bat -Fetch")
		} else {
			$commands.Add("# No delete commands were generated.")
		}
		return @($commands.ToArray())
	}

	if (!$Fetch) {
		$commands.Add("scripts\plan-agent-branch-cleanup.bat -Fetch")
	}
	if ($deleteCommands.Count -gt 0) {
		foreach ($command in $deleteCommands) {
			$commands.Add($command)
		}
	} else {
		$commands.Add("# No delete commands were generated.")
	}

	return @($commands.ToArray())
}

function ConvertTo-MarkdownCleanupPlan {
	param(
		[array]$Candidates,
		[array]$Inventory,
		[array]$UnintegratedReviews,
		[array]$RepositorySummaries,
		[object]$Summary,
		[string]$Root,
		[string[]]$NextCommands,
		[switch]$SummaryOnly
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
	$lines.Add("## Summary")
	$lines.Add("")
	$lines.Add("| Metric | Count |")
	$lines.Add("| --- | ---: |")
	$lines.Add("| Managed repositories scanned | $($Summary.RepositoriesScanned) |")
	$lines.Add("| Delete candidates | $($Summary.DeleteCandidates) |")
	$lines.Add("| Local delete candidates | $($Summary.LocalDeleteCandidates) |")
	$lines.Add("| Remote delete candidates | $($Summary.RemoteDeleteCandidates) |")
	$lines.Add("| Directly merged delete candidates | $($Summary.MergedDeleteCandidates) |")
	$lines.Add("| Patch-equivalent delete candidates | $($Summary.PatchEquivalentDeleteCandidates) |")
	$lines.Add("| Content-equivalent delete candidates | $($Summary.ContentEquivalentDeleteCandidates) |")
	$lines.Add("| Current branches skipped | $($Summary.CurrentBranchesSkipped) |")
	$lines.Add("| Local agent branches | $($Summary.LocalAgentBranches) |")
	$lines.Add("| Remote agent branches | $($Summary.RemoteAgentBranches) |")
	$lines.Add("| Integrated agent branches | $($Summary.IntegratedAgentBranches) |")
	$lines.Add("| Unintegrated agent branches | $($Summary.UnintegratedAgentBranches) |")
	$lines.Add("| Repositories with agent branches | $($Summary.RepositoriesWithAgentBranches) |")
	$lines.Add("")
	if ($SummaryOnly) {
		$lines.Add("## Repository Summary")
		$lines.Add("")
		if ($RepositorySummaries.Count -eq 0) {
			$lines.Add("No matching agent branches are present in managed repositories.")
		} else {
			$lines.Add("| Repository | Local branches | Remote branches | Delete candidates | Merged | Patch-equivalent | Content-equivalent | Unintegrated | Current skipped |")
			$lines.Add("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
			foreach ($repository in $RepositorySummaries) {
				$lines.Add(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |" -f $repository.Repository, $repository.LocalAgentBranches, $repository.RemoteAgentBranches, $repository.DeleteCandidates, $repository.MergedDeleteCandidates, $repository.PatchEquivalentDeleteCandidates, $repository.ContentEquivalentDeleteCandidates, $repository.UnintegratedAgentBranches, $repository.CurrentBranchesSkipped))
			}
		}
		$lines.Add("")
		$lines.Add("Detailed branch inventory, candidates, and delete commands were omitted. Re-run without ``-SummaryOnly`` before deleting branches.")
		$lines.Add("")
	} else {
	$lines.Add("## Branch Inventory")
	$lines.Add("")
	$lines.Add("Inventory includes merged and unmerged matching branches. The candidate table lists branches Git reports as merged into the default branch and squash-merged branches whose patches are equivalent to default.")
	$lines.Add("")
	if ($Inventory.Count -eq 0) {
		$lines.Add("No matching agent branches are present in managed repositories.")
	} else {
		$lines.Add("| Repository | Type | Branch | Current |")
		$lines.Add("| --- | --- | --- | --- |")
		foreach ($branch in $Inventory) {
			$current = if ($branch.Current) { "yes" } else { "no" }
			$lines.Add(("| {0} | {1} | ``{2}`` | {3} |" -f $branch.Repository, $branch.Type, $branch.Branch, $current))
		}
	}
	$lines.Add("")
	$lines.Add("## Candidates")
	$lines.Add("")
	if ($Candidates.Count -eq 0) {
		$lines.Add("No integrated agent branches were found.")
	} else {
		$lines.Add("| Repository | Type | Branch | Default | Integration | Action | Delete command |")
		$lines.Add("| --- | --- | --- | --- | --- | --- | --- |")
		foreach ($candidate in $Candidates) {
			$command = if ([string]::IsNullOrWhiteSpace($candidate.DeleteCommand)) { "" } else { $candidate.DeleteCommand.Replace("|", "\|") }
			$lines.Add(("| {0} | {1} | ``{2}`` | ``{3}`` | {4} | {5} | ``{6}`` |" -f $candidate.Repository, $candidate.Type, $candidate.Branch, $candidate.DefaultBranch, $candidate.Integration, $candidate.Action, $command))
		}
	}
	$lines.Add("")
	}
	$lines.Add("## Unintegrated Branches To Review")
	$lines.Add("")
	if ($UnintegratedReviews.Count -eq 0) {
		$lines.Add("No unintegrated matching branches were found.")
	} else {
		$lines.Add("| Repository | Type | Branch | Default | Current | Review command |")
		$lines.Add("| --- | --- | --- | --- | --- | --- |")
		foreach ($review in $UnintegratedReviews) {
			$current = if ($review.Current) { "yes" } else { "no" }
			$command = if ([string]::IsNullOrWhiteSpace($review.ReviewCommand)) { "" } else { $review.ReviewCommand.Replace("|", "\|") }
			$lines.Add(("| {0} | {1} | ``{2}`` | ``{3}`` | {4} | ``{5}`` |" -f $review.Repository, $review.Type, $review.Branch, $review.DefaultBranch, $current, $command))
		}
	}
	$lines.Add("")
	$lines.Add("## Next Commands")
	$lines.Add("")
	$lines.Add('```powershell')
	foreach ($command in $NextCommands) {
		$lines.Add($command)
	}
	$lines.Add('```')
	$lines.Add("")
	$lines.Add('This script only writes a plan. Refresh refs with `-Fetch` before acting, review every command, and keep deletion as an explicit follow-up.')

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
$inventory = @($repositories | ForEach-Object { Get-AgentBranchInventory -Status $_ })
$unintegratedReviews = @(Get-UnintegratedBranchReviews -Inventory $inventory -Candidates $candidates)
$deleteCandidates = @($candidates | Where-Object { ![string]::IsNullOrWhiteSpace($_.DeleteCommand) })
$summary = [pscustomobject]@{
	RepositoriesScanned = $repositories.Count
	DeleteCandidates = $deleteCandidates.Count
	LocalDeleteCandidates = @($deleteCandidates | Where-Object { $_.Type -eq "local" }).Count
	RemoteDeleteCandidates = @($deleteCandidates | Where-Object { $_.Type -eq "remote" }).Count
	MergedDeleteCandidates = @($deleteCandidates | Where-Object { $_.Integration -eq "merged" }).Count
	PatchEquivalentDeleteCandidates = @($deleteCandidates | Where-Object { $_.Integration -eq "patch-equivalent" }).Count
	ContentEquivalentDeleteCandidates = @($deleteCandidates | Where-Object { $_.Integration -eq "content-equivalent" }).Count
	CurrentBranchesSkipped = @($candidates | Where-Object { $_.Current }).Count
	LocalAgentBranches = @($inventory | Where-Object { $_.Type -eq "local" }).Count
	RemoteAgentBranches = @($inventory | Where-Object { $_.Type -eq "remote" }).Count
	IntegratedAgentBranches = $candidates.Count
	UnintegratedAgentBranches = [Math]::Max(0, $inventory.Count - $candidates.Count)
	RepositoriesWithAgentBranches = @($inventory | ForEach-Object { $_.Repository } | Sort-Object -Unique).Count
}
$repositorySummaries = @(
	foreach ($repository in $repositories) {
		$name = [string]$repository.Name
		$repositoryInventory = @($inventory | Where-Object { $_.Repository -eq $name })
		$repositoryCandidates = @($candidates | Where-Object { $_.Repository -eq $name })
		$repositoryUnintegratedReviews = @($unintegratedReviews | Where-Object { $_.Repository -eq $name })
		$deleteCandidates = @($repositoryCandidates | Where-Object { ![string]::IsNullOrWhiteSpace($_.DeleteCommand) })
		if ($repositoryInventory.Count -eq 0 -and $repositoryCandidates.Count -eq 0) {
			continue
		}
		[pscustomobject]@{
			Repository = $name
			LocalAgentBranches = @($repositoryInventory | Where-Object { $_.Type -eq "local" }).Count
			RemoteAgentBranches = @($repositoryInventory | Where-Object { $_.Type -eq "remote" }).Count
			DeleteCandidates = $deleteCandidates.Count
			LocalDeleteCandidates = @($deleteCandidates | Where-Object { $_.Type -eq "local" }).Count
			RemoteDeleteCandidates = @($deleteCandidates | Where-Object { $_.Type -eq "remote" }).Count
			MergedDeleteCandidates = @($deleteCandidates | Where-Object { $_.Integration -eq "merged" }).Count
			PatchEquivalentDeleteCandidates = @($deleteCandidates | Where-Object { $_.Integration -eq "patch-equivalent" }).Count
			ContentEquivalentDeleteCandidates = @($deleteCandidates | Where-Object { $_.Integration -eq "content-equivalent" }).Count
			IntegratedAgentBranches = $repositoryCandidates.Count
			UnintegratedAgentBranches = [Math]::Max(0, $repositoryInventory.Count - $repositoryCandidates.Count)
			UnintegratedBranchReviews = @($repositoryUnintegratedReviews | ForEach-Object { [string]$_.Branch })
			CurrentBranchesSkipped = @($repositoryCandidates | Where-Object { $_.Current }).Count
		}
	}
)
$nextCommands = Get-CleanupNextCommands -Candidates $candidates -SummaryOnly:$SummaryOnly
$safetyNote = "This script only writes a plan. Refresh refs with -Fetch before acting, review every command, and keep deletion as an explicit follow-up."

if ($Json) {
	$payload = [ordered]@{
		Root = $status.Root
		BranchPattern = $BranchPattern
		Fetched = [bool]$Fetch
		SummaryOnly = [bool]$SummaryOnly
		Summary = $summary
		RepositorySummaries = @($repositorySummaries)
		UnintegratedBranchReviews = @($unintegratedReviews)
		NextCommands = @($nextCommands)
		SafetyNote = $safetyNote
	}
	if (!$SummaryOnly) {
		$payload.Inventory = @($inventory)
		$payload.Candidates = @($candidates)
	}
	$content = [pscustomobject]$payload | ConvertTo-Json -Depth 6
} else {
	$content = ConvertTo-MarkdownCleanupPlan -Candidates $candidates -Inventory $inventory -UnintegratedReviews $unintegratedReviews -RepositorySummaries $repositorySummaries -Summary $summary -Root ([string]$status.Root) -NextCommands $nextCommands -SummaryOnly:$SummaryOnly
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
