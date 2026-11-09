[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sources = @(
    'install.ps1'
    'windows/profile.ps1'
    'windows/Dotfiles.WindowsPackages.psm1'
    'windows/Dotfiles.WindowsPowerShell.psm1'
    'windows/Install-PowerShellMsi.ps1'
    'tests/windows-powershell-msi-tests.ps1'
    'windows/Dotfiles.WindowsNode.psm1'
    'tests/windows-node-tests.ps1'
    'scripts/import-ssh-keys.ps1'
    'tests/windows-ssh-key-tests.ps1'
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

$profileTokens = $null
$profileErrors = $null
$profileAst = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $repoRoot 'windows/profile.ps1'),
    [ref]$profileTokens,
    [ref]$profileErrors
)
$profileFunctions = @(
    $profileAst.FindAll(
        { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $true
    ) | ForEach-Object Name
)
foreach ($commandName in @('rld', 'npmupg')) {
    if ($profileFunctions -notcontains $commandName) {
        throw "Missing shared PowerShell helper: $commandName"
    }
}

Import-PowerShellDataFile -Path (Join-Path $repoRoot 'windows/packages.psd1') | Out-Null
Import-Module (Join-Path $repoRoot 'windows/Dotfiles.WindowsPackages.psm1') -Force
& (Join-Path $repoRoot 'tests/windows-powershell-msi-tests.ps1')

$coreManifest = Import-PowerShellDataFile -Path (Join-Path $repoRoot 'windows/packages.psd1')
if (@($coreManifest.Winget) -notcontains 'Microsoft.PowerShell') {
    throw 'The Windows core manifest must include Microsoft.PowerShell.'
}

& (Join-Path $repoRoot 'tests/windows-node-tests.ps1')

if (@($coreManifest.Winget) -notcontains 'AuthorSoftware.NVMWindows' -or @($coreManifest.Winget) -contains 'OpenJS.NodeJS.LTS') {
    throw 'Windows core manifest must use NVM v2 rather than standalone Node LTS.'
}

$entry = Resolve-WindowsPackageEntry -PackageEntry 'eza-community.eza' -Manager Winget
if ($entry.Source -ne 'winget' -or $entry.Id -ne 'eza-community.eza') {
    throw 'Shared package entry normalization failed.'
}

if ($env:OS -ne 'Windows_NT') {
    Write-Host 'PowerShell parsing and shared module checks passed; Windows lifecycle skipped on this platform.'
    return
}

& (Join-Path $repoRoot 'tests/windows-ssh-key-tests.ps1')

# PowerShell's $HOME and Windows profile paths do not follow $env:HOME.
# The lifecycle below invokes the installer and must only run on a disposable VM.
if ($env:DOTFILES_DISPOSABLE_WINDOWS -ne '1') {
    Write-Host 'Windows installer lifecycle skipped: use a disposable Windows environment and set DOTFILES_DISPOSABLE_WINDOWS=1.'
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
