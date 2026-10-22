[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Name (Join-Path $repoRoot 'windows/Dotfiles.WindowsPowerShell.psm1') -Force

function New-FakePwshState {
    param(
        [switch]$Msi,
        [switch]$BrokenMsi,
        [switch]$Msix,
        [switch]$RunningMsix,
        [switch]$QueryFailed,
        [string[]]$OtherPaths = @()
    )

    [pscustomobject]@{
        FixedPath          = 'C:\Program Files\PowerShell\7\pwsh.exe'
        MsiPresent         = [bool]$Msi
        MsiFilePresent     = [bool]($Msi -or $BrokenMsi)
        MsixPackages       = if ($Msix) { @([pscustomobject]@{ Name = 'Microsoft.PowerShell'; PackageFullName = 'Microsoft.PowerShell_7.6.7.0_test' }) } else { @() }
        MsixQuerySucceeded = -not [bool]$QueryFailed
        RunningMsix        = [bool]$RunningMsix
        OtherPwshPaths     = @($OtherPaths)
    }
}

function Assert-PwshPlan {
    param(
        [Parameter(Mandatory = $true)][psobject]$State,
        [Parameter(Mandatory = $true)][string]$Expected,
        [switch]$Migrate
    )
    $plan = Get-DotfilesPowerShellPlan -State $State -ExplicitMigration:$Migrate
    if ($plan -ne $Expected) {
        throw "Expected PowerShell plan '$Expected', got '$plan'."
    }
}

Assert-PwshPlan -State (New-FakePwshState) -Expected Install
Assert-PwshPlan -State (New-FakePwshState -Msi) -Expected Existing
Assert-PwshPlan -State (New-FakePwshState -Msix) -Expected Prompt
Assert-PwshPlan -State (New-FakePwshState -Msix) -Migrate -Expected Migrate
Assert-PwshPlan -State (New-FakePwshState -Msix -Msi) -Expected Prompt
Assert-PwshPlan -State (New-FakePwshState -Msix -Msi) -Migrate -Expected Migrate
Assert-PwshPlan -State (New-FakePwshState -Msix -RunningMsix) -Expected Prompt
Assert-PwshPlan -State (New-FakePwshState -Msix -RunningMsix) -Migrate -Expected Relaunch
Assert-PwshPlan -State (New-FakePwshState -QueryFailed) -Expected UnknownAppx
Assert-PwshPlan -State (New-FakePwshState -QueryFailed -RunningMsix) -Migrate -Expected Relaunch
Assert-PwshPlan -State (New-FakePwshState -BrokenMsi) -Expected BrokenMsi
Assert-PwshPlan -State (New-FakePwshState -BrokenMsi -Msix) -Migrate -Expected BrokenMsi
Assert-PwshPlan -State (New-FakePwshState -OtherPaths @('D:\Tools\pwsh.exe')) -Expected OtherPwsh
Assert-PwshPlan -State (New-FakePwshState -OtherPaths @('D:\Tools\pwsh.exe')) -Migrate -Expected OtherPwsh

Write-Host 'PowerShell MSI migration planning tests passed.'
