[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Minimal,
    [switch]$Elevated,
    [switch]$ChocolateyOnly,
    [switch]$CleanBackups
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Section {
    param([string]$Message)
    Write-Host "`n🪟 $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Gray
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✅ $Message" -ForegroundColor Green
}

function Write-Highlight {
    param([string]$Message)
    Write-Host "  ➜ $Message" -ForegroundColor Magenta
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsWindows {
    return $env:OS -eq 'Windows_NT'
}

function Ensure-ParentDirectory {
    param([string]$Path)

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
    if ($DryRun) {
        Write-Info "Would create $parent"
    } else {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}
}

function Ensure-Directory {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or (Test-Path -LiteralPath $Path)) {
        return
    }

    if ($DryRun) {
        Write-Info "Would create directory $Path"
    } else {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-BackupPath {
    param([string]$Path)

    $timestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmssfff')
    $candidate = "$Path.bak.$timestamp"
    $counter = 0

    while (Test-Path -LiteralPath $candidate) {
        $counter += 1
        $candidate = "$Path.bak.$timestamp.$counter"
    }

    return $candidate
}

function Backup-Path {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $backupPath = Get-BackupPath -Path $Path
    if ($DryRun) {
        Write-Highlight "Would back up $Path -> $backupPath"
    } else {
        Move-Item -LiteralPath $Path -Destination $backupPath
        Write-Success "Backed up $Path -> $backupPath"
    }
}

function Test-FileLikePath {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    return -not (Get-Item -LiteralPath $Path -Force).PSIsContainer
}

function Test-SameFileContent {
    param(
        [string]$Source,
        [string]$Target
    )

    if (-not (Test-FileLikePath $Source) -or -not (Test-FileLikePath $Target)) {
        return $false
    }

    $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash
    return $sourceHash -eq $targetHash
}

function Copy-WithBackup {
    param(
        [string]$Source,
        [string]$Target
    )

    Ensure-ParentDirectory -Path $Target

    if ((Test-Path -LiteralPath $Target) -and (Test-SameFileContent -Source $Source -Target $Target)) {
        Write-Info "Already up to date: $Target"
        return
    }

    if (Test-Path -LiteralPath $Target) {
        Backup-Path -Path $Target
    }

    if ($DryRun) {
        Write-Highlight "Would copy $Source -> $Target"
    } else {
        Copy-Item -LiteralPath $Source -Destination $Target -Force
        Write-Success "Copied $Source -> $Target"
    }
}

function Get-ForwardedArgs {
    $argsOut = @()
    if ($DryRun) { $argsOut += '-DryRun' }
    if ($Force) { $argsOut += '-Force' }
    if ($Minimal) { $argsOut += '-Minimal' }
    if ($Elevated) { $argsOut += '-Elevated' }
    if ($ChocolateyOnly) { $argsOut += '-ChocolateyOnly' }
    if ($CleanBackups) { $argsOut += '-CleanBackups' }
    return $argsOut
}

function Invoke-SelfElevated {
    param([switch]$ChocolateyMode)

    if (Test-Administrator) {
        return
    }

    $scriptArgs = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $PSCommandPath
    ) + (Get-ForwardedArgs)

    if ($ChocolateyMode) {
        if ($scriptArgs -notcontains '-ChocolateyOnly') {
            $scriptArgs += '-ChocolateyOnly'
        }
    }

    Write-Info "Chocolatey requires administrator privileges. Relaunching with UAC..."
    Start-Process -FilePath 'powershell.exe' -ArgumentList $scriptArgs -Verb RunAs -Wait
    exit 0
}

function Install-Profile {
    param(
        [string]$Source,
        [string]$Target
    )

    Copy-WithBackup -Source $Source -Target $Target
}

function Install-GitIgnore {
    param(
        [string]$Source,
        [string]$Target
    )

    Copy-WithBackup -Source $Source -Target $Target

    if ($DryRun) {
        Write-Info "Would configure git core.excludesfile -> $Target"
    } elseif (Test-CommandExists git) {
        git config --global core.excludesfile "$Target"
        Write-Info "Configured git core.excludesfile -> $Target"
    } else {
        Write-Warning "git not found; skipping core.excludesfile configuration."
    }
}

function Get-BackupFiles {
    param([string]$RootPath)

    if ([string]::IsNullOrWhiteSpace($RootPath) -or -not (Test-Path -LiteralPath $RootPath)) {
        return @()
    }

    return @(Get-ChildItem -Path $RootPath -Filter '*.bak.*' -File -Force -ErrorAction SilentlyContinue)
}

function Remove-BackupFiles {
    param([string]$RootPath)

    $backups = @(Get-BackupFiles -RootPath $RootPath)
    if ($backups.Count -eq 0) {
        Write-Info "No backup files found in $RootPath."
        return
    }

    Write-Section "Backup cleanup"
    Write-Info "Found the following backup files:"
    foreach ($backup in $backups) {
        Write-Info " - $($backup.FullName)"
    }

    if ($DryRun) {
        foreach ($backup in $backups) {
            Write-Info "Would remove $($backup.FullName)"
        }
        Write-Info "Dry-run complete. No backup files were removed."
        return
    }

    if ($Force) {
        $confirm = 'y'
    } else {
        $confirm = Read-Host "Delete all of these backup files? [y/N]"
    }

    if ($confirm -match '^[Yy]$') {
        foreach ($backup in $backups) {
            Write-Info "Removing $($backup.FullName)"
            Remove-Item -LiteralPath $backup.FullName -Force
        }
        Write-Info "Done cleaning up backups."
    } else {
        Write-Info "Skipped backup cleanup."
    }
}

function Ensure-Scoop {
    if (Test-CommandExists scoop) {
        Write-Success "Scoop already installed."
        return
    }

    if ($DryRun) {
        Write-Highlight "Would install Scoop."
        return
    }

    Write-Highlight "Installing Scoop..."
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    } catch {
        Write-Warning "Could not update execution policy for Scoop. Continuing with bootstrap."
    }

    Invoke-Expression (Invoke-RestMethod -Uri 'https://get.scoop.sh')
}

function Install-ChocolateyBootstrap {
    if (Test-CommandExists choco) {
        Write-Success "Chocolatey already installed."
        return
    }

    if ($DryRun) {
        Write-Highlight "Would install Chocolatey."
        return
    }

    if (-not (Test-Administrator)) {
        Invoke-SelfElevated -ChocolateyMode
        return
    }

    Write-Highlight "Installing Chocolatey..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $script = Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1'
    Invoke-Expression $script

    $chocoBin = Join-Path $env:ProgramData 'chocolatey\bin'
    if ((Test-Path -LiteralPath $chocoBin) -and ($env:Path -notlike "*$chocoBin*")) {
        $env:Path = "$chocoBin;$env:Path"
    }
}

function Get-WindowsPackageManifestPath {
    param([string]$DefaultPath)

    if (-not [string]::IsNullOrWhiteSpace($env:DOTFILES_WINDOWS_PACKAGE_MANIFEST) -and (Test-Path -LiteralPath $env:DOTFILES_WINDOWS_PACKAGE_MANIFEST)) {
        return $env:DOTFILES_WINDOWS_PACKAGE_MANIFEST
    }

    if (-not [string]::IsNullOrWhiteSpace($DefaultPath) -and (Test-Path -LiteralPath $DefaultPath)) {
        return $DefaultPath
    }

    return $null
}

function Get-WindowsPackageManifest {
    param([string]$ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        return $null
    }

    return Import-PowerShellDataFile -LiteralPath $ManifestPath
}

function Test-WingetPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$PackageId)

    $installedIds = Get-WingetInstalledPackageIds
    if (@($installedIds) -contains $PackageId) {
        return $true
    }

    if (-not (Test-CommandExists winget)) {
        return $false
    }

    & winget list --id $PackageId --exact --source winget --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) {
        $script:WingetInstalledPackageIds = @($installedIds + $PackageId | Sort-Object -Unique)
        return $true
    }

    return $false
}

function Get-WingetInstalledPackageIds {
    if (-not (Test-CommandExists winget)) {
        return @()
    }

    if (Get-Variable -Scope Script -Name WingetInstalledPackageIds -ErrorAction SilentlyContinue) {
        return $script:WingetInstalledPackageIds
    }

    $tempFile = Join-Path $env:TEMP "dotfiles-winget-export-$PID.json"
    if (Test-Path -LiteralPath $tempFile) {
        Remove-Item -LiteralPath $tempFile -Force
    }

    & winget export -o $tempFile --source winget --include-versions --accept-source-agreements *> $null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tempFile)) {
        $script:WingetInstalledPackageIds = @()
        return @()
    }

    try {
        $export = Get-Content -LiteralPath $tempFile -Raw | ConvertFrom-Json
        $ids = $export.Sources.Packages.PackageIdentifier | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $script:WingetInstalledPackageIds = @($ids | Sort-Object -Unique)
    } catch {
        $script:WingetInstalledPackageIds = @()
    } finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }

    return $script:WingetInstalledPackageIds
}

function Get-ScoopAppRoots {
    $roots = @()

    foreach ($root in @(
        $env:SCOOP
        $env:SCOOP_GLOBAL
        (Join-Path $HOME 'scoop')
        (Join-Path $env:ProgramData 'scoop')
    )) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        $appsRoot = Join-Path $root 'apps'
        if (Test-Path -LiteralPath $appsRoot) {
            $roots += $appsRoot
        }
    }

    return @($roots | Sort-Object -Unique)
}

function Test-ScoopPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$PackageName)

    foreach ($appsRoot in Get-ScoopAppRoots) {
        if (Test-Path -LiteralPath (Join-Path $appsRoot $PackageName)) {
            return $true
        }
    }

    return $false
}

function Test-ChocolateyPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$PackageName)

    if (-not (Test-CommandExists choco)) {
        return $false
    }

    $lines = & choco list --local-only --limit-output --exact $PackageName 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $lines) {
        return $false
    }

    return [bool]($lines | Where-Object { $_ -like "$PackageName|*" } | Select-Object -First 1)
}

function Get-NpmGlobalRoot {
    if (-not (Test-CommandExists npm)) {
        return $null
    }

    $root = & npm root -g 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        return $null
    }

    return $root.Trim()
}

function Test-NpmGlobalPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$PackageName)

    $root = Get-NpmGlobalRoot
    if ([string]::IsNullOrWhiteSpace($root)) {
        return $false
    }

    $packagePath = if ($PackageName -like '@*/*') {
        Join-Path $root ($PackageName -replace '/', '\')
    } else {
        Join-Path $root $PackageName
    }

    return Test-Path -LiteralPath $packagePath
}

function Get-WindowsPackageComparison {
    param([hashtable]$Manifest)

    if (-not $Manifest) {
        return @()
    }

    $comparison = @()

    foreach ($section in @(
        [pscustomobject]@{ Manager = 'Winget'; Packages = @($Manifest.Winget) }
        [pscustomobject]@{ Manager = 'Scoop'; Packages = @($Manifest.Scoop) }
        [pscustomobject]@{ Manager = 'Chocolatey'; Packages = @($Manifest.Chocolatey) }
        [pscustomobject]@{ Manager = 'NpmGlobal'; Packages = @($Manifest.NpmGlobal) }
    )) {
        foreach ($packageName in $section.Packages) {
            $installed = $false

            switch ($section.Manager) {
                'Winget' { $installed = Test-WingetPackageInstalled -PackageId $packageName }
                'Scoop' { $installed = Test-ScoopPackageInstalled -PackageName $packageName }
                'Chocolatey' { $installed = Test-ChocolateyPackageInstalled -PackageName $packageName }
                'NpmGlobal' { $installed = Test-NpmGlobalPackageInstalled -PackageName $packageName }
            }

            $comparison += [pscustomobject]@{
                Manager   = $section.Manager
                Package   = $packageName
                Installed = [bool]$installed
            }
        }
    }

    return $comparison
}

function Install-WindowsPackageBaseline {
    param([hashtable]$Manifest)

    if (-not $Manifest) {
        Write-Warning 'No curated Windows package manifest found.'
        return
    }

    Write-Section 'Curated package install'

    foreach ($section in @(
        [pscustomobject]@{ Manager = 'Winget'; Command = 'winget'; Packages = @($Manifest.Winget) }
        [pscustomobject]@{ Manager = 'Scoop'; Command = 'scoop'; Packages = @($Manifest.Scoop) }
        [pscustomobject]@{ Manager = 'Chocolatey'; Command = 'choco'; Packages = @($Manifest.Chocolatey) }
        [pscustomobject]@{ Manager = 'NpmGlobal'; Command = 'npm'; Packages = @($Manifest.NpmGlobal) }
    )) {
        if ($section.Packages.Count -eq 0) {
            Write-Info "$($section.Manager): nothing to install."
            continue
        }

        if (-not (Test-CommandExists $section.Command)) {
            Write-Warning "$($section.Manager) not available; skipping."
            continue
        }

        Write-Info "$($section.Manager):"
        foreach ($packageName in $section.Packages) {
            $installed = $false

            switch ($section.Manager) {
                'Winget' { $installed = Test-WingetPackageInstalled -PackageId $packageName }
                'Scoop' { $installed = Test-ScoopPackageInstalled -PackageName $packageName }
                'Chocolatey' { $installed = Test-ChocolateyPackageInstalled -PackageName $packageName }
                'NpmGlobal' { $installed = Test-NpmGlobalPackageInstalled -PackageName $packageName }
            }

            if ($installed) {
                Write-Success "already installed: $packageName"
                continue
            }

            if ($DryRun) {
                Write-Info " - would install: $packageName"
                continue
            }

            switch ($section.Manager) {
                'Winget' {
                    & winget install --id $packageName --exact --silent --accept-package-agreements --accept-source-agreements
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "installed: $packageName"
                    } else {
                        Write-Warning " - failed: $packageName"
                    }
                }
                'Scoop' {
                    & scoop install $packageName
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "installed: $packageName"
                    } else {
                        Write-Warning " - failed: $packageName"
                    }
                }
                'Chocolatey' {
                    if (-not (Invoke-ChocolateyElevated -Arguments @('install', $packageName, '-y'))) {
                        Write-Warning " - failed: $packageName"
                    } else {
                        Write-Success "installed: $packageName"
                    }
                }
                'NpmGlobal' {
                    & npm install -g $packageName
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "installed: $packageName"
                    } else {
                        Write-Warning " - failed: $packageName"
                    }
                }
            }
        }
    }
}

function Write-WindowsPackageManifestSummary {
    param([hashtable]$Manifest)

    if (-not $Manifest) {
        Write-Warning 'No curated Windows package manifest found.'
        return
    }

    Write-Section 'Curated package manifest'
    Write-Info "Public baseline: $($Manifest.Winget.Count + $Manifest.Scoop.Count + $Manifest.Chocolatey.Count + $Manifest.NpmGlobal.Count) entries"

    foreach ($sectionName in @('Winget', 'Scoop', 'Chocolatey', 'NpmGlobal')) {
        $items = @($Manifest.$sectionName)
        Write-Info "$sectionName ($($items.Count))"

        foreach ($item in $items) {
            Write-Info " - $item"
        }
    }
}

function Import-InstalledProfile {
    param([string]$ProfilePath)

    if ($DryRun) {
        Write-Info "Would load the PowerShell profile into this session."
        return
    }

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        Write-Warning "Profile not found at $ProfilePath."
        return
    }

    . $ProfilePath
    Write-Success "Loaded the PowerShell profile into this session."

    if (Test-CommandExists rld) {
        rld
        Write-Success "Refreshed the PowerShell profile with rld."
    }
}

function Write-WindowsAliasSummary {
    $commands = @(
        'pkgmgr'
        'pkgcmp'
        'npmupg'
        'wingup'
        'scoopup'
        'cupa'
        'cinst'
        'rld'
        'rldz'
        'weather'
        'myip'
    )

    Write-Section 'Quick aliases'
    foreach ($commandName in $commands) {
        if (Test-CommandExists $commandName) {
            Write-Success $commandName
        } else {
            Write-Info $commandName
        }
    }
}

if (-not (Test-IsWindows)) {
    throw "install.ps1 is intended for Windows."
}

$RepoRoot = Split-Path -Parent $PSCommandPath
$WindowsProfileSource = Join-Path $RepoRoot 'windows/profile.ps1'
$WindowsPackageManifest = Join-Path $RepoRoot 'windows/packages.psd1'
$GitIgnoreSource = Join-Path $RepoRoot 'git/global.gitignore'
$PowerShellProfileTarget = $PROFILE.CurrentUserAllHosts
$GitIgnoreTarget = Join-Path $HOME '.gitignore_global'
$WindowsConfigRoot = Join-Path $HOME '.config\dotfiles\windows'
$WindowsPackageTarget = Join-Path $WindowsConfigRoot 'packages.psd1'
$WindowsOverlayDir = Join-Path $HOME '.config\dotfiles\windows\profile.d'

Write-Section "Windows dotfiles setup"
Write-Info "Detected PowerShell edition: $($PSVersionTable.PSEdition)"
Write-Info "Detected Windows PowerShell profile: $PowerShellProfileTarget"

if (-not (Test-Path $WindowsProfileSource)) {
    throw "Missing Windows profile template at $WindowsProfileSource."
}

if ($ChocolateyOnly) {
    Install-ChocolateyBootstrap
    exit 0
}

Install-Profile -Source $WindowsProfileSource -Target $PowerShellProfileTarget
Install-GitIgnore -Source $GitIgnoreSource -Target $GitIgnoreTarget
Ensure-Directory -Path $WindowsConfigRoot
Copy-WithBackup -Source $WindowsPackageManifest -Target $WindowsPackageTarget
Ensure-Directory -Path $WindowsOverlayDir
Write-Info "Local overlay example: $($RepoRoot)\windows\profile.local.example.ps1"

if ($CleanBackups) {
    Remove-BackupFiles -RootPath $HOME
}

Write-Section "Package managers"
if (Test-CommandExists winget) { $wingetState = 'available' } else { $wingetState = 'not found' }
if (Test-CommandExists scoop) { $scoopState = 'available' } else { $scoopState = 'not found' }
if (Test-CommandExists choco) { $chocoState = 'available' } else { $chocoState = 'not found' }
Write-Info "winget: $wingetState"
Write-Info "scoop: $scoopState"
Write-Info "choco: $chocoState"
if (Test-CommandExists winget) {
    Write-Info "winget is assumed to come from App Installer; this script does not bootstrap it."
} else {
    Write-Warning "winget not found; install App Installer if you want the Windows Store package manager."
}
if (-not (Test-CommandExists choco)) {
    Write-Info "Chocolatey bootstrap will relaunch elevated when needed."
}
Write-Info "Elevation helper: $(if (Test-CommandExists gsudo) { 'gsudo detected' } elseif (Test-CommandExists sudo) { 'sudo detected' } else { 'UAC runas' })"

$manifest = Get-WindowsPackageManifest -ManifestPath $WindowsPackageManifest
if ($manifest) {
    Write-WindowsPackageManifestSummary -Manifest $manifest
    Write-Info "Manifest file: $WindowsPackageManifest"
} else {
    Write-Warning "Curated package manifest not found at $WindowsPackageManifest."
}

if (-not $Minimal) {
    if ($Force) {
        $installManagers = $true
    } else {
        $reply = Read-Host "Install Scoop and Chocolatey if missing? [y/N]"
        $installManagers = $reply -match '^[Yy]$'
    }

    if ($installManagers) {
        Ensure-Scoop
        Install-ChocolateyBootstrap
    }

    if ($Force) {
        $installPackages = $true
    } else {
        $reply = Read-Host "Install missing packages from the curated manifest now? [y/N]"
        $installPackages = $reply -match '^[Yy]$'
    }

    if ($installPackages) {
        Install-WindowsPackageBaseline -Manifest $manifest
    }
} else {
    Write-Info "Minimal mode: skipping package manager bootstrap."
}

Import-InstalledProfile -ProfilePath $PowerShellProfileTarget
Write-WindowsAliasSummary

Write-Section "Complete"
Write-Info "Open a new PowerShell session, or run rld/rldz if the prompt still looks stale."
