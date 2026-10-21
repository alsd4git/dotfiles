# Pure plan regression tests. No real package install/uninstall is performed.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoRoot 'windows/Dotfiles.WindowsNode.psm1') -Force

function New-TestNodeState {
    param(
        [string]$NvmExecutable,
        [switch]$Legacy,
        [string[]]$StandaloneIds = @(),
        [string[]]$StandalonePaths = @(),
        [string[]]$OtherNodePaths = @()
    )

    [pscustomobject]@{
        NvmExecutable     = $NvmExecutable
        HasLegacyNvm      = [bool]$Legacy
        StandaloneIds     = @($StandaloneIds)
        StandalonePaths   = @($StandalonePaths)
        OtherNodePaths    = @($OtherNodePaths)
        HasStandaloneNode = (@($StandaloneIds).Count -gt 0 -or @($StandalonePaths).Count -gt 0)
    }
}

function Assert-NodePlan {
    param(
        [Parameter(Mandatory = $true)][psobject]$State,
        [Parameter(Mandatory = $true)][string]$Expected,
        [switch]$ExplicitMigration
    )

    $actual = Get-DotfilesNodePlan -State $State -ExplicitMigration:$ExplicitMigration
    if ($actual -ne $Expected) {
        throw "Node plan expected '$Expected' but got '$actual'."
    }
}

$fresh = New-TestNodeState
Assert-NodePlan -State $fresh -Expected 'Install'
Assert-NodePlan -State $fresh -Expected 'Install' -ExplicitMigration

$existing = New-TestNodeState -NvmExecutable 'C:\users\example\AppData\Local\Author Software\nvm\nvm.exe'
Assert-NodePlan -State $existing -Expected 'Existing'

$official = New-TestNodeState -StandaloneIds @('OpenJS.NodeJS.LTS') -StandalonePaths @('C:\Program Files\nodejs\node.exe')
Assert-NodePlan -State $official -Expected 'Prompt'
Assert-NodePlan -State $official -Expected 'Migrate' -ExplicitMigration

$both = New-TestNodeState -NvmExecutable 'C:\nvm\nvm.exe' -StandaloneIds @('OpenJS.NodeJS.LTS')
Assert-NodePlan -State $both -Expected 'Prompt'
Assert-NodePlan -State $both -Expected 'Migrate' -ExplicitMigration

$unmanaged = New-TestNodeState -StandalonePaths @('C:\Program Files\nodejs\node.exe')
Assert-NodePlan -State $unmanaged -Expected 'ManualNode'
Assert-NodePlan -State $unmanaged -Expected 'ManualNode' -ExplicitMigration

$otherManager = New-TestNodeState -OtherNodePaths @('C:\Tools\volta\node.exe')
Assert-NodePlan -State $otherManager -Expected 'OtherNode'
Assert-NodePlan -State $otherManager -Expected 'OtherNode' -ExplicitMigration

$legacy = New-TestNodeState -Legacy -StandaloneIds @('OpenJS.NodeJS.LTS')
Assert-NodePlan -State $legacy -Expected 'LegacyNvm'
Assert-NodePlan -State $legacy -Expected 'LegacyNvm' -ExplicitMigration

$ambiguous = New-TestNodeState -StandaloneIds @('OpenJS.NodeJS.LTS') -OtherNodePaths @('C:\tools\node.exe')
Assert-NodePlan -State $ambiguous -Expected 'OtherNode' -ExplicitMigration

Write-Host 'NVM migration decision tests passed.'
