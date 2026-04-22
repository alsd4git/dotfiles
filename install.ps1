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

function Resolve-WindowsPackageEntry {
    param(
        [Parameter(Mandatory = $true)]
        [object]$PackageEntry,
        [Parameter(Mandatory = $true)]
        [string]$Manager
    )

    if ($PackageEntry -is [string]) {
        return [pscustomobject]@{
            Name   = $PackageEntry
            Id     = $PackageEntry
            Source = if ($Manager -eq 'Winget') { 'winget' } else { $null }
        }
    }

    $entry = if ($PackageEntry -is [hashtable]) { [pscustomobject]$PackageEntry } else { $PackageEntry }
    $id = $entry.Id
    if ([string]::IsNullOrWhiteSpace($id)) {
        $id = $entry.PackageId
    }
    if ([string]::IsNullOrWhiteSpace($id)) {
        $id = $entry.Name
    }

    $name = $entry.Name
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = $entry.DisplayName
    }
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = $id
    }

    $source = $entry.Source
    if ($Manager -eq 'Winget' -and [string]::IsNullOrWhiteSpace($source)) {
        $source = 'winget'
    }

    return [pscustomobject]@{
        Name   = $name
        Id     = $id
        Source = $source
    }
}

function Format-WindowsPackageEntry {
    param([object]$Package)

    if ($null -eq $Package) {
        return ''
    }

    if ([string]::IsNullOrWhiteSpace($Package.Source) -or $Package.Source -eq 'winget') {
        return $Package.Name
    }

    return "$($Package.Name) [$($Package.Source):$($Package.Id)]"
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

function Resolve-WindowsPackageManifestPath {
    param(
        [string[]]$EnvironmentVariables,
        [string]$LocalPath,
        [string]$SourcePath
    )

    foreach ($environmentVariable in $EnvironmentVariables) {
        $environmentValue = [Environment]::GetEnvironmentVariable($environmentVariable)
        if (-not [string]::IsNullOrWhiteSpace($environmentValue) -and (Test-Path -LiteralPath $environmentValue)) {
            return $environmentValue
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($SourcePath) -and (Test-Path -LiteralPath $SourcePath)) {
        return $SourcePath
    }

    if (-not [string]::IsNullOrWhiteSpace($LocalPath) -and (Test-Path -LiteralPath $LocalPath)) {
        return $LocalPath
    }

    return $null
}

function Get-WindowsPackageManifestEntries {
    $repoRoot = Split-Path -Parent $PSCommandPath
    $windowsRoot = Join-Path $repoRoot 'windows'
    $localRoot = Join-Path $HOME '.config\dotfiles\windows'

    $manifestSpecs = @(
        [pscustomobject]@{
            Name       = 'Core'
            Env        = @('DOTFILES_WINDOWS_PACKAGE_MANIFEST', 'DOTFILES_WINDOWS_PACKAGE_CORE_MANIFEST')
            LocalPath  = Join-Path $localRoot 'packages.psd1'
            SourcePath = Join-Path $windowsRoot 'packages.psd1'
        }
        [pscustomobject]@{
            Name       = 'Optional'
            Env        = @('DOTFILES_WINDOWS_PACKAGE_OPTIONAL_MANIFEST')
            LocalPath  = Join-Path $localRoot 'packages.optional.psd1'
            SourcePath = Join-Path $windowsRoot 'packages.optional.psd1'
        }
        [pscustomobject]@{
            Name       = 'Private'
            Env        = @('DOTFILES_WINDOWS_PACKAGE_PRIVATE_MANIFEST')
            LocalPath  = Join-Path $localRoot 'packages.private.psd1'
            SourcePath = $null
        }
    )

    $manifests = @()

    foreach ($spec in $manifestSpecs) {
        $resolvedPath = Resolve-WindowsPackageManifestPath -EnvironmentVariables $spec.Env -LocalPath $spec.LocalPath -SourcePath $spec.SourcePath
        if ([string]::IsNullOrWhiteSpace($resolvedPath)) {
            continue
        }

        try {
            $data = Import-PowerShellDataFile -LiteralPath $resolvedPath
        } catch {
            Write-Warning "Unable to load $($spec.Name) package manifest: $resolvedPath"
            continue
        }

        $manifests += [pscustomobject]@{
            Name = $spec.Name
            Path = $resolvedPath
            Data = $data
        }
    }

    return $manifests
}

function Test-WingetPackageInstalled {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [string]$Source = 'winget'
    )

    $sourceName = if ([string]::IsNullOrWhiteSpace($Source)) { 'winget' } else { $Source }

    if ($sourceName -eq 'winget') {
        $installedIds = Get-WingetInstalledPackageIds
        if (@($installedIds) -contains $PackageId) {
            return $true
        }
    }

    if (-not (Test-CommandExists winget)) {
        return $false
    }

    & winget list --id $PackageId --exact --source $sourceName --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) {
        if ($sourceName -eq 'winget') {
            $installedIds = Get-WingetInstalledPackageIds
            $script:WingetInstalledPackageIds = @($installedIds + $PackageId | Sort-Object -Unique)
        }
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
    param([array]$Manifests)

    if (-not $Manifests -or $Manifests.Count -eq 0) {
        return @()
    }

    $comparison = @()

    foreach ($manifest in $Manifests) {
        foreach ($section in @(
            [pscustomobject]@{ Manager = 'Winget'; Packages = @($manifest.Data.Winget) }
            [pscustomobject]@{ Manager = 'Scoop'; Packages = @($manifest.Data.Scoop) }
            [pscustomobject]@{ Manager = 'Chocolatey'; Packages = @($manifest.Data.Chocolatey) }
            [pscustomobject]@{ Manager = 'NpmGlobal'; Packages = @($manifest.Data.NpmGlobal) }
        )) {
            foreach ($packageEntry in $section.Packages) {
                $package = Resolve-WindowsPackageEntry -PackageEntry $packageEntry -Manager $section.Manager
                $installed = $false

                switch ($section.Manager) {
                    'Winget' { $installed = Test-WingetPackageInstalled -PackageId $package.Id -Source $package.Source }
                    'Scoop' { $installed = Test-ScoopPackageInstalled -PackageName $package.Name }
                    'Chocolatey' { $installed = Test-ChocolateyPackageInstalled -PackageName $package.Name }
                    'NpmGlobal' { $installed = Test-NpmGlobalPackageInstalled -PackageName $package.Name }
                }

                $comparison += [pscustomobject]@{
                    Manifest  = $manifest.Name
                    Manager   = $section.Manager
                    Package   = (Format-WindowsPackageEntry -Package $package)
                    Installed = [bool]$installed
                }
            }
        }
    }

    return $comparison
}

function Install-WindowsPackageBaseline {
    param(
        [array]$Manifests,
        [string[]]$ManifestNames
    )

    if (-not $Manifests -or $Manifests.Count -eq 0) {
        Write-Warning 'No curated Windows package manifest found.'
        return
    }

    $selectedManifests = @($Manifests | Where-Object { -not $ManifestNames -or ($ManifestNames -contains $_.Name) })
    if ($selectedManifests.Count -eq 0) {
        Write-Info 'No matching package manifests selected.'
        return
    }

    Write-Section 'Curated package install'

    foreach ($manifest in $selectedManifests) {
        Write-Info "$($manifest.Name):"

        foreach ($section in @(
            [pscustomobject]@{ Manager = 'Winget'; Command = 'winget'; Packages = @($manifest.Data.Winget) }
            [pscustomobject]@{ Manager = 'Scoop'; Command = 'scoop'; Packages = @($manifest.Data.Scoop) }
            [pscustomobject]@{ Manager = 'Chocolatey'; Command = 'choco'; Packages = @($manifest.Data.Chocolatey) }
            [pscustomobject]@{ Manager = 'NpmGlobal'; Command = 'npm'; Packages = @($manifest.Data.NpmGlobal) }
        )) {
            if ($section.Packages.Count -eq 0) {
                Write-Info "  $($section.Manager): nothing to install."
                continue
            }

            if (-not (Test-CommandExists $section.Command)) {
                Write-Warning "  $($section.Manager) not available; skipping."
                continue
            }

            Write-Info "  $($section.Manager):"
            foreach ($packageEntry in $section.Packages) {
                $package = Resolve-WindowsPackageEntry -PackageEntry $packageEntry -Manager $section.Manager
                $installed = $false

                switch ($section.Manager) {
                    'Winget' { $installed = Test-WingetPackageInstalled -PackageId $package.Id -Source $package.Source }
                    'Scoop' { $installed = Test-ScoopPackageInstalled -PackageName $package.Name }
                    'Chocolatey' { $installed = Test-ChocolateyPackageInstalled -PackageName $package.Name }
                    'NpmGlobal' { $installed = Test-NpmGlobalPackageInstalled -PackageName $package.Name }
                }

                if ($installed) {
                    Write-Success "  already installed: $(Format-WindowsPackageEntry -Package $package)"
                    continue
                }

                if ($DryRun) {
                    Write-Info "   would install: $(Format-WindowsPackageEntry -Package $package)"
                    continue
                }

                switch ($section.Manager) {
                    'Winget' {
                        $wingetSource = if ([string]::IsNullOrWhiteSpace($package.Source)) { 'winget' } else { $package.Source }
                        $wingetArgs = @(
                            'install'
                            '--id'
                            $package.Id
                            '--exact'
                            '--accept-package-agreements'
                            '--accept-source-agreements'
                            '--source'
                            $wingetSource
                        )
                        if ($wingetSource -eq 'winget') {
                            $wingetArgs += '--silent'
                        }

                        & winget @wingetArgs
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "  installed: $(Format-WindowsPackageEntry -Package $package)"
                        } else {
                            Write-Warning "  failed: $(Format-WindowsPackageEntry -Package $package)"
                        }
                    }
                    'Scoop' {
                        & scoop install $package.Name
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "  installed: $(Format-WindowsPackageEntry -Package $package)"
                        } else {
                            Write-Warning "  failed: $(Format-WindowsPackageEntry -Package $package)"
                        }
                    }
                    'Chocolatey' {
                        if (-not (Invoke-ChocolateyElevated -Arguments @('install', $package.Name, '-y'))) {
                            Write-Warning "  failed: $(Format-WindowsPackageEntry -Package $package)"
                        } else {
                            Write-Success "  installed: $(Format-WindowsPackageEntry -Package $package)"
                        }
                    }
                    'NpmGlobal' {
                        & npm install -g $package.Name
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "  installed: $(Format-WindowsPackageEntry -Package $package)"
                        } else {
                            Write-Warning "  failed: $(Format-WindowsPackageEntry -Package $package)"
                        }
                    }
                }
            }
        }
    }
}

function Write-WindowsPackageManifestSummary {
    param([array]$Manifests)

    if (-not $Manifests -or $Manifests.Count -eq 0) {
        Write-Warning 'No curated Windows package manifest found.'
        return
    }

    Write-Section 'Curated package manifests'
    foreach ($manifest in $Manifests) {
        $total = @($manifest.Data.Winget).Count + @($manifest.Data.Scoop).Count + @($manifest.Data.Chocolatey).Count + @($manifest.Data.NpmGlobal).Count
        Write-Info "$($manifest.Name) ($total) -> $($manifest.Path)"

        foreach ($sectionName in @('Winget', 'Scoop', 'Chocolatey', 'NpmGlobal')) {
            $items = @($manifest.Data.$sectionName)
            if ($items.Count -eq 0) {
                continue
            }

            Write-Info "  $sectionName ($($items.Count))"
            foreach ($item in $items) {
                if ($sectionName -eq 'Winget') {
                    $label = Format-WindowsPackageEntry -Package (Resolve-WindowsPackageEntry -PackageEntry $item -Manager $sectionName)
                } else {
                    $label = $item
                }

                Write-Info "   - $label"
            }
        }
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
$WindowsCorePackageManifest = Join-Path $RepoRoot 'windows/packages.psd1'
$WindowsOptionalPackageManifest = Join-Path $RepoRoot 'windows/packages.optional.psd1'
$WindowsPrivatePackageExample = Join-Path $RepoRoot 'windows/packages.private.example.psd1'
$GitIgnoreSource = Join-Path $RepoRoot 'git/global.gitignore'
$PowerShellProfileTarget = $PROFILE.CurrentUserAllHosts
$GitIgnoreTarget = Join-Path $HOME '.gitignore_global'
$WindowsConfigRoot = Join-Path $HOME '.config\dotfiles\windows'
$WindowsCorePackageTarget = Join-Path $WindowsConfigRoot 'packages.psd1'
$WindowsOptionalPackageTarget = Join-Path $WindowsConfigRoot 'packages.optional.psd1'
$WindowsPrivatePackageTarget = Join-Path $WindowsConfigRoot 'packages.private.psd1'
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
Copy-WithBackup -Source $WindowsCorePackageManifest -Target $WindowsCorePackageTarget
if (Test-Path -LiteralPath $WindowsOptionalPackageManifest) {
    Copy-WithBackup -Source $WindowsOptionalPackageManifest -Target $WindowsOptionalPackageTarget
}
if (-not (Test-Path -LiteralPath $WindowsPrivatePackageTarget)) {
    if (Test-Path -LiteralPath $WindowsPrivatePackageExample) {
        if ($DryRun) {
            Write-Info "Would create private package scaffold at $WindowsPrivatePackageTarget"
        } else {
            Copy-Item -LiteralPath $WindowsPrivatePackageExample -Destination $WindowsPrivatePackageTarget
            Write-Success "Created private package scaffold at $WindowsPrivatePackageTarget"
        }
    }
}
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
Write-Info "Chocolatey is treated as legacy fallback only, not part of the public bootstrap."
Write-Info "Elevation helper: $(if (Test-CommandExists gsudo) { 'gsudo detected' } elseif (Test-CommandExists sudo) { 'sudo detected' } else { 'UAC runas' })"

$manifests = @(Get-WindowsPackageManifestEntries)
if ($manifests.Count -gt 0) {
    Write-WindowsPackageManifestSummary -Manifests $manifests
} else {
    Write-Warning 'Curated Windows package manifests not found.'
}

if (-not $Minimal) {
    if ($Force) {
        $installScoop = $true
    } else {
        $reply = Read-Host "Install Scoop if missing? [y/N]"
        $installScoop = $reply -match '^[Yy]$'
    }

    if ($installScoop) {
        Ensure-Scoop
    }

    if ($manifests.Count -gt 0) {
        $coreManifests = @($manifests | Where-Object Name -eq 'Core')
        $optionalManifests = @($manifests | Where-Object Name -eq 'Optional')
        $privateManifests = @($manifests | Where-Object Name -eq 'Private')
        $chocolateyPackageCount = @(
            $manifests | ForEach-Object { @($_.Data.Chocolatey).Count }
        ) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

        if ($coreManifests.Count -gt 0) {
            if ($Force) {
                $installCorePackages = $true
            } else {
                $reply = Read-Host "Install missing core packages now? [y/N]"
                $installCorePackages = $reply -match '^[Yy]$'
            }

            if ($installCorePackages) {
                Install-WindowsPackageBaseline -Manifests $coreManifests -ManifestNames @('Core')
            }
        }

        if ($optionalManifests.Count -gt 0) {
            if ($Force) {
                $installOptionalPackages = $true
            } else {
                $reply = Read-Host "Install optional packages now? [y/N]"
                $installOptionalPackages = $reply -match '^[Yy]$'
            }

            if ($installOptionalPackages) {
                Install-WindowsPackageBaseline -Manifests $optionalManifests -ManifestNames @('Optional')
            }
        }

        if ($privateManifests.Count -gt 0) {
            $privatePackageCount = @(
                $privateManifests | ForEach-Object {
                    @($_.Data.Winget).Count + @($_.Data.Scoop).Count + @($_.Data.Chocolatey).Count + @($_.Data.NpmGlobal).Count
                }
            ) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

            if ($privatePackageCount -gt 0) {
                if ($Force) {
                    $installPrivatePackages = $true
                } else {
                    $reply = Read-Host "Install local private packages now? [y/N]"
                    $installPrivatePackages = $reply -match '^[Yy]$'
                }

                if ($installPrivatePackages) {
                    Install-WindowsPackageBaseline -Manifests $privateManifests -ManifestNames @('Private')
                }
            }
        }

        if ($chocolateyPackageCount -gt 0) {
            if ($Force) {
                $installChocolatey = $true
            } else {
                $reply = Read-Host "Install Chocolatey if missing for private/legacy packages? [y/N]"
                $installChocolatey = $reply -match '^[Yy]$'
            }

            if ($installChocolatey) {
                Install-ChocolateyBootstrap
            }
        } else {
            Write-Info 'Chocolatey is deprecated in the public baseline and is not bootstrapped.'
        }
    }
} else {
    Write-Info "Minimal mode: skipping package manager bootstrap."
}

Write-WindowsAliasSummary

Write-Section "Complete"
Write-Info "Open a new PowerShell session to load the updated profile, or run rld/rldz manually if you want to refresh in place."
