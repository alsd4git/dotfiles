[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sources = @(
    'install.ps1'
    'windows/profile.ps1'
    'windows/Dotfiles.WindowsPackages.psm1'
    'windows/start-menu-shortcuts.ps1'
)

foreach ($source in $sources) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $repoRoot $source),
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count -gt 0) {
        throw "PowerShell parse errors in ${source}: $($errors | Out-String)"
    }
}

Import-PowerShellDataFile -Path (Join-Path $repoRoot 'windows/packages.psd1') | Out-Null
Import-Module (Join-Path $repoRoot 'windows/Dotfiles.WindowsPackages.psm1') -Force

$entry = Resolve-WindowsPackageEntry -PackageEntry 'eza-community.eza' -Manager Winget
if ($entry.Source -ne 'winget' -or $entry.Id -ne 'eza-community.eza') {
    throw 'Shared package entry normalization failed.'
}

if (-not $IsWindows) {
    Write-Host 'PowerShell parsing and shared module checks passed; Windows lifecycle skipped on this platform.'
    return
}

$originalHome = $env:HOME
$originalGitConfig = $env:GIT_CONFIG_GLOBAL
$testHome = Join-Path ([System.IO.Path]::GetTempPath()) "dotfiles-windows-lifecycle-$PID"

try {
    New-Item -ItemType Directory -Path $testHome -Force | Out-Null
    $env:HOME = $testHome
    $env:GIT_CONFIG_GLOBAL = Join-Path $testHome 'gitconfig'

    & (Join-Path $repoRoot 'install.ps1') -DryRun -Minimal
    git config --global diff.colorMoved zebra

    & (Join-Path $repoRoot 'install.ps1') -Sync
    if ((git config --global --get diff.colorMoved) -ne 'plain') {
        throw 'Sync did not apply the shared Git defaults.'
    }

    & (Join-Path $repoRoot 'install.ps1') -RestoreGitDefaults
    if ((git config --global --get diff.colorMoved) -ne 'zebra') {
        throw 'RestoreGitDefaults did not restore the previous Git setting.'
    }
} finally {
    $env:HOME = $originalHome
    $env:GIT_CONFIG_GLOBAL = $originalGitConfig
    Remove-Item -LiteralPath $testHome -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Windows smoke tests passed.'
