param(
	[string]$OutputPath = "",
	[switch]$SummaryOnly,
	[switch]$Json
)

$ErrorActionPreference = "Stop"

function Test-ReadmeFeatureSection {
	param([object]$Status)

	$readme = Join-Path ([string]$Status.Path) "README.md"
	if (!(Test-Path -LiteralPath $readme -PathType Leaf)) {
		return $false
	}

	$content = Get-Content -LiteralPath $readme -Raw
	return $content -match "(?m)^## Features\s*$"
}

function Get-FeatureState {
	param([object]$Status)

	if (!$Status.Present) {
		return "missing-repository"
	}
	if ($Status.Name -eq "ofxGgmlWorkflows") {
		return "not-applicable"
	}
	if ([int]$Status.FeatureCount -le 0) {
		return "missing-metadata"
	}
	if (Test-ReadmeFeatureSection -Status $Status) {
		return "documented"
	}
	return "metadata-only"
}

function Get-FeatureAction {
	param([string]$State)

	switch ($State) {
		"missing-repository" { return "restore repository before feature planning" }
		"not-applicable" { return "skip workflow-only repository" }
		"missing-metadata" { return "add feature metadata to ofxggml-addon.json" }
		"documented" { return "keep README features aligned with metadata and examples" }
		default { return "add a README Features section from metadata before widening behavior" }
	}
}

function New-FeatureEntry {
	param([object]$Status)

	$features = @($Status.Features | Where-Object {
		![string]::IsNullOrWhiteSpace([string]$_)
	} | ForEach-Object {
		[string]$_
	})
	$state = Get-FeatureState -Status $Status

	[pscustomobject]@{
		Repository = [string]$Status.Name
		Lane = [string]$Status.Lane
		Present = [bool]$Status.Present
		Priority = [int]$Status.DevelopmentPriority
		State = [string]$state
		FeatureCount = @($features).Count
		Features = @($features)
		ReadmeFeatures = [bool](Test-ReadmeFeatureSection -Status $Status)
		Action = [string](Get-FeatureAction -State $state)
	}
}

function Join-OrDash {
	param([array]$Values)
	if (!$Values -or $Values.Count -eq 0) {
		return "-"
	}
	return (@($Values) -join ", ")
}

function Get-FeatureSummary {
	param([array]$Entries)

	$applicable = @($Entries | Where-Object { $_.State -ne "not-applicable" })
	$needsReadme = @($Entries | Where-Object { $_.State -eq "metadata-only" })
	$missingMetadata = @($Entries | Where-Object { $_.State -eq "missing-metadata" })
	$blocking = @($missingMetadata)

	[pscustomobject]@{
		ManagedRepositories = @($Entries).Count
		FeatureApplicableRepositories = @($applicable).Count
		FeatureMetadataCoverage = @($applicable | Where-Object { $_.FeatureCount -gt 0 }).Count
		ReadmeFeatureCoverage = @($applicable | Where-Object { $_.ReadmeFeatures }).Count
		MetadataOnlyRepositories = @($needsReadme).Count
		MissingMetadataRepositories = @($missingMetadata).Count
		BlockingRepositories = @($blocking | Sort-Object Priority, Repository | ForEach-Object { [string]$_.Repository })
		RecommendedReadmeOrder = @($needsReadme | Sort-Object Priority, Repository | ForEach-Object { [string]$_.Repository })
	}
}

function Get-FeatureNextCommands {
	param([array]$Entries)

	$summary = Get-FeatureSummary -Entries $Entries
	$commands = New-Object System.Collections.Generic.List[string]
	if (@($summary.BlockingRepositories).Count -gt 0) {
		$commands.Add("scripts\plan-addon-features.bat")
	} elseif (@($summary.RecommendedReadmeOrder).Count -gt 0) {
		$commands.Add("scripts\plan-addon-features.bat")
		$commands.Add("scripts\status-family.bat -Json -SummaryOnly")
	} else {
		$commands.Add("scripts\status-family.bat -Json -SummaryOnly")
	}
	$commands.Add("scripts\plan-addon-features.bat -Json -SummaryOnly")
	return @($commands.ToArray())
}

function ConvertTo-FeatureRepositorySummary {
	param([object]$Entry)

	[pscustomobject]@{
		Repository = [string]$Entry.Repository
		Lane = [string]$Entry.Lane
		Priority = [int]$Entry.Priority
		State = [string]$Entry.State
		FeatureCount = [int]$Entry.FeatureCount
		ReadmeFeatures = [bool]$Entry.ReadmeFeatures
		Action = [string]$Entry.Action
	}
}

function ConvertTo-MarkdownFeaturePlan {
	param(
		[array]$Entries,
		[string]$Root,
		[array]$NextCommands
	)

	$summary = Get-FeatureSummary -Entries $Entries
	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("# ofxGgml Addon Feature Plan")
	$lines.Add("")
	$lines.Add("Feature inventory for managed addon repositories. Keep this as metadata and documentation planning until a lane is selected for runtime behavior.")
	$lines.Add("")
	$lines.Add("Root: $Root")
	$lines.Add("")
	$lines.Add("## Summary")
	$lines.Add("")
	$lines.Add("| Metric | Count |")
	$lines.Add("| --- | ---: |")
	$lines.Add("| Managed repositories | $($summary.ManagedRepositories) |")
	$lines.Add("| Feature-applicable repositories | $($summary.FeatureApplicableRepositories) |")
	$lines.Add("| Feature metadata coverage | $($summary.FeatureMetadataCoverage) |")
	$lines.Add("| README feature coverage | $($summary.ReadmeFeatureCoverage) |")
	$lines.Add("| Metadata-only repositories | $($summary.MetadataOnlyRepositories) |")
	$lines.Add("| Missing metadata repositories | $($summary.MissingMetadataRepositories) |")
	$lines.Add("")
	$lines.Add("## Repository Features")
	$lines.Add("")
	$lines.Add("| Repository | Lane | State | Features | README | Action |")
	$lines.Add("| --- | --- | --- | --- | --- | --- |")
	foreach ($entry in @($Entries | Sort-Object Priority, Repository)) {
		$features = Join-OrDash -Values $entry.Features
		$readme = if ($entry.ReadmeFeatures) { "yes" } else { "-" }
		$lines.Add("| $($entry.Repository) | $($entry.Lane) | $($entry.State) | $features | $readme | $($entry.Action) |")
	}
	$lines.Add("")
	$lines.Add("## Recommended README Order")
	$lines.Add("")
	if (@($summary.RecommendedReadmeOrder).Count -eq 0) {
		$lines.Add("- README feature sections are complete for feature-applicable addons.")
	} else {
		foreach ($repo in @($summary.RecommendedReadmeOrder)) {
			$lines.Add("- $repo")
		}
	}
	$lines.Add("")
	$lines.Add("## Next Commands")
	$lines.Add("")
	foreach ($command in @($NextCommands)) {
		$lines.Add("- ``$command``")
	}
	$lines.Add("")
	$lines.Add("## Guardrails")
	$lines.Add("")
	$lines.Add("- Keep ofxGgmlCore as the control plane; do not move model-specific workflows into Core.")
	$lines.Add("- Treat metadata features as a promise to document and validate, not as proof of complete runtime behavior.")
	$lines.Add("- Leave classified reference repositories out of managed feature rollout until explicitly promoted.")

	return $lines -join [Environment]::NewLine
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusJson = & (Join-Path $scriptRoot "status-family.ps1") -Json
if (!$?) {
	throw "status-family.ps1 failed."
}

$status = $statusJson | ConvertFrom-Json
$managed = @($status.Addons | Where-Object { $_.Known })
$entries = @($managed | ForEach-Object { New-FeatureEntry -Status $_ })
$summary = Get-FeatureSummary -Entries $entries
$nextCommands = Get-FeatureNextCommands -Entries $entries

if ($Json) {
	$result = [pscustomobject]@{
		Root = [string]$status.Root
		SummaryOnly = [bool]$SummaryOnly
		Summary = $summary
		NextCommands = @($nextCommands)
		RepositorySummaries = @($entries | ForEach-Object { ConvertTo-FeatureRepositorySummary -Entry $_ })
	}
	if (!$SummaryOnly) {
		$result | Add-Member -NotePropertyName Repositories -NotePropertyValue $entries
	}
	$content = $result | ConvertTo-Json -Depth 7
} else {
	$content = ConvertTo-MarkdownFeaturePlan -Entries $entries -Root ([string]$status.Root) -NextCommands $nextCommands
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
