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

# Exercise the existing-manager path without installing or changing Node.
$nodeModule = Get-Module Dotfiles.WindowsNode
& $nodeModule {
    function script:dotfilesFakeDefault { $global:LASTEXITCODE = 0; return $script:testDefaultOutput }
    $script:testDefaultOutput = "Default  : none`nLast     : v24.22.1"
    if (Test-DotfilesNvmDefault -NvmExecutable 'dotfilesFakeDefault') { throw 'Previous Node version must not be mistaken for the default.' }
    $script:testDefaultOutput = "Default  : v26.13.0`nLast     : v24.22.1"
    if (-not (Test-DotfilesNvmDefault -NvmExecutable 'dotfilesFakeDefault')) { throw 'Valid default was not detected.' }
    $script:testDefault = $true
    $script:testInstallCount = 0
    function script:Get-DotfilesNodeState {
        [pscustomobject]@{ NvmExecutable = 'dotfilesFakeNvm'; HasLegacyNvm = $false; OtherNodePaths = @(); HasStandaloneNode = $false; StandaloneIds = @() }
    }
    function script:Test-DotfilesNvmDefault { param($NvmExecutable) return $script:testDefault }
    function script:Install-DotfilesNodeLts { param($NvmExecutable) $script:testInstallCount++ }
    function script:dotfilesFakeNvm { $global:LASTEXITCODE = 0; return '[]' }
    Invoke-DotfilesNvmBootstrap
    if ($script:testInstallCount -ne 0) { throw 'A valid NVM default must not be changed.' }
    $script:testDefault = $false
    Invoke-DotfilesNvmBootstrap -DryRun
    if ($script:testInstallCount -ne 0) { throw 'Dry-run must not install Node.' }
    Invoke-DotfilesNvmBootstrap
    if ($script:testInstallCount -ne 1) { throw 'NVM without a default must install Node LTS.' }
}
Import-Module (Join-Path $repoRoot 'windows/Dotfiles.WindowsNode.psm1') -Force

# Use a disposable npm command and profile directory; never inspect real globals.
$inventoryRoot = Join-Path ([IO.Path]::GetTempPath()) ("dotfiles-node-inventory-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $inventoryRoot | Out-Null
$originalLocalAppData = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = $inventoryRoot
    $fakeNode = Join-Path $inventoryRoot 'node.exe'
    $fakeNpm = Join-Path $inventoryRoot 'npm.cmd'
    $state = [pscustomobject]@{ StandalonePaths = @($fakeNode); StandaloneIds = @('OpenJS.NodeJS.LTS') }
    $nodeModule = Get-Module Dotfiles.WindowsNode
    Set-Content -LiteralPath $fakeNpm -Value '@echo {"dependencies":{"example":{"version":"1.2.3"}}}'
    $savedPath = & $nodeModule { param($testState) Save-DotfilesNodeInventory -State $testState } $state
    $inventory = Get-Content -LiteralPath $savedPath -Raw | ConvertFrom-Json
    if (@($inventory.GlobalPackages) -notcontains 'example@1.2.3') { throw 'Expected npm package inventory.' }
    Set-Content -LiteralPath $fakeNpm -Value @('@echo {"dependencies":{}}', '@exit /b 1')
    $failed = $false
    try { & $nodeModule { param($testState) Save-DotfilesNodeInventory -State $testState } $state } catch { $failed = $true }
    if (-not $failed) { throw 'Failed npm inventory must stop migration.' }
    Set-Content -LiteralPath $fakeNpm -Value '@echo {"dependencies":{"example":{}}}'
    $failed = $false
    try { & $nodeModule { param($testState) Save-DotfilesNodeInventory -State $testState } $state } catch { $failed = $true }
    if (-not $failed) { throw 'Missing npm package version must stop migration.' }
} finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    Remove-Item -LiteralPath $inventoryRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$saved = [pscustomobject]@{ GlobalPackages = @('@scope/tool@1.2.3', 'example@4.5.6') }
$adopted = '{"dependencies":{"@scope/tool":{"version":"1.2.3"},"example":{"version":"4.5.6"}}}' | ConvertFrom-Json
Assert-DotfilesNpmInventory -Saved $saved -Adopted $adopted
foreach ($badJson in @('{"dependencies":{"example":{"version":"4.5.6"}}}', '{"dependencies":{"@scope/tool":{"version":"1.2.4"},"example":{"version":"4.5.6"}}}')) {
    $failed = $false
    try { Assert-DotfilesNpmInventory -Saved $saved -Adopted ($badJson | ConvertFrom-Json) } catch { $failed = $true }
    if (-not $failed) { throw 'Inventory verification accepted a missing or changed package.' }
}

Import-Module (Join-Path $repoRoot 'windows/Dotfiles.WindowsPackages.psm1') -Force
$global:dotfilesTestWingetIds = @('OpenJS.NodeJS.LTS')
$global:dotfilesTestWingetExports = 0
function global:winget {
    $global:dotfilesTestWingetExports++
    $outputIndex = [array]::IndexOf($args, '-o') + 1
    $packages = @($global:dotfilesTestWingetIds | ForEach-Object { @{ PackageIdentifier = $_ } })
    @{ Sources = @(@{ Packages = $packages }) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $args[$outputIndex]
    $global:LASTEXITCODE = 0
}
try {
    if (@(Get-WingetInstalledPackageIds) -notcontains 'OpenJS.NodeJS.LTS') { throw 'Expected initial package in export.' }
    $global:dotfilesTestWingetIds = @('AuthorSoftware.NVMWindows')
    if (@(Get-WingetInstalledPackageIds) -notcontains 'OpenJS.NodeJS.LTS') { throw 'Expected cached export before refresh.' }
    $refreshed = @(Get-WingetInstalledPackageIds -Refresh)
    if ($refreshed -contains 'OpenJS.NodeJS.LTS' -or $refreshed -notcontains 'AuthorSoftware.NVMWindows') { throw 'Refresh returned stale package IDs.' }
    if ($global:dotfilesTestWingetExports -ne 2) { throw 'Unexpected WinGet export count.' }
} finally {
    Remove-Item Function:\global:winget -ErrorAction SilentlyContinue
    Remove-Variable dotfilesTestWingetIds, dotfilesTestWingetExports -Scope Global -ErrorAction SilentlyContinue
}

Write-Host 'NVM migration decision tests passed.'
