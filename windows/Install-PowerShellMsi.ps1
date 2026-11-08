[CmdletBinding()]
param(
    # An explicit opt-in is required to uninstall the current-user MSIX variant.
    [switch]$Migrate,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This helper is intended for Windows.'
}

$module = Join-Path $PSScriptRoot 'Dotfiles.WindowsPowerShell.psm1'
Import-Module -Name $module -Force

Invoke-DotfilesPowerShellBootstrap -RepoRoot (Split-Path -Parent $PSScriptRoot) -DryRun:$DryRun -ExplicitMigration:$Migrate
