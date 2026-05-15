$ErrorActionPreference = "Stop"

function Get-SmokeBuildCiReportValue {
	param(
		[Parameter(Mandatory=$true)] $Object,
		[Parameter(Mandatory=$true)] [string]$Name
	)

	if ($Object -is [System.Collections.IDictionary]) {
		if ($Object.Contains($Name)) {
			return $Object[$Name]
		}
		return $null
	}

	$property = $Object.PSObject.Properties[$Name]
	if ($property) {
		return $property.Value
	}

	return $null
}

function ConvertTo-SmokeBuildCiReportArray {
	param($Value)

	if ($null -eq $Value) {
		return @()
	}
	if ($Value -is [string]) {
		return @($Value)
	}
	if ($Value -is [System.Collections.IEnumerable]) {
		$items = New-Object System.Collections.Generic.List[object]
		foreach ($item in $Value) {
			[void]$items.Add($item)
		}
		return $items.ToArray()
	}

	return @($Value)
}

function Get-SmokeBuildCiReportSummary {
	param([Parameter(Mandatory=$true)] $Report)

	$stages = @(ConvertTo-SmokeBuildCiReportArray -Value (Get-SmokeBuildCiReportValue -Object $Report -Name "Stages"))
	$targets = @($stages | ForEach-Object {
		ConvertTo-SmokeBuildCiReportArray -Value (Get-SmokeBuildCiReportValue -Object $_ -Name "Targets")
	})
	$failedTargets = @($targets | Where-Object { [string](Get-SmokeBuildCiReportValue -Object $_ -Name "Status") -ne "passed" })
	$commands = @($targets | ForEach-Object {
		ConvertTo-SmokeBuildCiReportArray -Value (Get-SmokeBuildCiReportValue -Object $_ -Name "Commands")
	})
	$failedCommands = @($commands | Where-Object {
		$status = [string](Get-SmokeBuildCiReportValue -Object $_ -Name "Status")
		$exitCode = [int](Get-SmokeBuildCiReportValue -Object $_ -Name "ExitCode")
		$exitCode -ne 0 -or $status -ne "passed"
	})
	$stageNames = @($stages |
		ForEach-Object { [string](Get-SmokeBuildCiReportValue -Object $_ -Name "Name") } |
		Where-Object { ![string]::IsNullOrWhiteSpace($_) })
	$failedStageNames = @($stages |
		Where-Object { [string](Get-SmokeBuildCiReportValue -Object $_ -Name "Outcome") -ne "passed" } |
		ForEach-Object { [string](Get-SmokeBuildCiReportValue -Object $_ -Name "Name") } |
		Where-Object { ![string]::IsNullOrWhiteSpace($_) })

	return [pscustomobject]@{
		Outcome = [string](Get-SmokeBuildCiReportValue -Object $Report -Name "Outcome")
		Configuration = [string](Get-SmokeBuildCiReportValue -Object $Report -Name "Configuration")
		Platform = [string](Get-SmokeBuildCiReportValue -Object $Report -Name "Platform")
		StageCount = [int](Get-SmokeBuildCiReportValue -Object $Report -Name "StageCount")
		ReportedStages = $stages.Count
		TargetsRun = [int](Get-SmokeBuildCiReportValue -Object $Report -Name "TargetsRun")
		ReportedTargets = $targets.Count
		FailedTargets = $failedTargets.Count
		CommandsRun = $commands.Count
		FailedCommands = $failedCommands.Count
		StageNames = @($stageNames)
		FailedStageNames = @($failedStageNames)
		HasFailures = ([string](Get-SmokeBuildCiReportValue -Object $Report -Name "Outcome") -ne "passed" -or $failedTargets.Count -gt 0 -or $failedCommands.Count -gt 0)
	}
}
