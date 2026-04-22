# Windows PowerShell profile for the dotfiles repo.
# Keep this file portable: useful defaults, optional integrations, and no machine-specific paths.

#----------------------------------------------------------------
# SHARED HELPERS
#----------------------------------------------------------------
function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

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

function Get-ProfilePath {
    if ($PROFILE.PSObject.Properties.Name -contains 'CurrentUserAllHosts' -and $PROFILE.CurrentUserAllHosts) {
        return $PROFILE.CurrentUserAllHosts
    }

    return $PROFILE
}

function Ensure-ParentDirectory {
    param([string]$Path)

    $parent = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($parent) -or (Test-Path -LiteralPath $parent)) {
        return
    }

    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

#----------------------------------------------------------------
# PROFILE AND GIT HELPERS
#----------------------------------------------------------------
function Get-GitCurrentBranch {
    if (-not (Test-CommandExists git)) {
        return $null
    }

    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch) -or $branch.Trim() -eq 'HEAD') {
        return $null
    }

    return $branch.Trim()
}

function Invoke-ListDirectory {
    param(
        [switch]$Force,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$Arguments
    )

    if (Test-CommandExists eza) {
        $ezaArgs = @('--long')
        if ($Force) {
            $ezaArgs += '--all'
        }
        $ezaArgs += @(
            '--group-directories-first'
            '--header'
            '--links'
            '--sort=name'
            '--icons'
            '--group'
            '--git'
        )

        if ($Arguments.Count -gt 0) {
            eza @ezaArgs @Arguments
        } else {
            eza @ezaArgs
        }
        return
    }

    $childArgs = @()
    if ($Force) {
        $childArgs += '-Force'
    }
    $childArgs += $Arguments

    if ($childArgs.Count -gt 0) {
        Get-ChildItem @childArgs
    } else {
        Get-ChildItem
    }
}

function rld {
    . (Get-ProfilePath)
}

Set-Alias rldz rld -Force

#----------------------------------------------------------------
# OPTIONAL MODULES
#----------------------------------------------------------------
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Set-PSReadLineOption -EditMode Windows
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    } catch {
        # Keep startup resilient if the host blocks PSReadLine customization.
    }
}

if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
    try {
        Import-Module Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
    } catch {
        # Optional module; ignore failures.
    }
}

if (Get-Module -ListAvailable -Name gsudoModule) {
    try {
        Import-Module gsudoModule -ErrorAction SilentlyContinue
        Set-Alias sudo gsudo -Force
    } catch {
        # Optional module; ignore failures.
    }
}

if ((Test-CommandExists gsudo) -and -not (Test-CommandExists sudo)) {
    try {
        Set-Alias sudo gsudo -Force
    } catch {
        # Optional executable; ignore failures.
    }
}

#----------------------------------------------------------------
# VARIABLES
#----------------------------------------------------------------
function Resolve-OhMyPoshThemesPath {
    $cachePath = Join-Path $HOME '.config\dotfiles\windows\omp.path'
    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($env:DOTFILES_WINDOWS_OMP_THEMES_PATH)) {
        $candidates += $env:DOTFILES_WINDOWS_OMP_THEMES_PATH
    }

    if (Test-Path -LiteralPath $cachePath) {
        $cachedPath = (Get-Content -LiteralPath $cachePath -Raw).Trim()
        if (-not [string]::IsNullOrWhiteSpace($cachedPath)) {
            $candidates += $cachedPath
        }
    }

    $candidates += @(
        'C:\Program Files (x86)\oh-my-posh\themes'
        'C:\Program Files\oh-my-posh\themes'
    )

    $ompCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if ($ompCommand.Path) {
        $binaryFolder = Split-Path -Parent $ompCommand.Path
        $candidates = @(
            (Join-Path (Split-Path -Parent $binaryFolder) 'themes')
        ) + $candidates
    }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        $themeFile = Join-Path $candidate 'tokyo.omp.json'
        if (Test-Path -LiteralPath $themeFile) {
            try {
                Ensure-ParentDirectory -Path $cachePath
                Set-Content -LiteralPath $cachePath -Value $candidate -NoNewline
            } catch {
                # Cache writes are best-effort only.
            }

            return $candidate
        }
    }

    return $null
}

$OhMyPoshThemesPath = Resolve-OhMyPoshThemesPath
if ([string]::IsNullOrWhiteSpace($OhMyPoshThemesPath)) {
    $OhMyPoshThemesPath = 'C:\Program Files (x86)\oh-my-posh\themes'
}

#----------------------------------------------------------------
# INIT SHELL
#----------------------------------------------------------------
if (Test-CommandExists oh-my-posh) {
    try {
        oh-my-posh init pwsh --config "$OhMyPoshThemesPath\tokyo.omp.json" | Invoke-Expression
    } catch {
        # Keep startup non-fatal if the prompt engine is temporarily unavailable.
    }
}

#----------------------------------------------------------------
# SHELL HELPERS
#----------------------------------------------------------------
function Set-Mini {
    if (-not (Test-CommandExists oh-my-posh)) {
        Write-Warning 'oh-my-posh not found.'
        return
    }

    oh-my-posh init pwsh --config "$OhMyPoshThemesPath\amro.omp.json" | Invoke-Expression
}

function Set-Tokyo {
    if (-not (Test-CommandExists oh-my-posh)) {
        Write-Warning 'oh-my-posh not found.'
        return
    }

    oh-my-posh init pwsh --config "$OhMyPoshThemesPath\tokyo.omp.json" | Invoke-Expression
}

Set-Alias c Clear-Host -Force
Set-Alias h Get-History -Force
Set-Alias a Get-Alias -Force

function l {
    Invoke-ListDirectory -Arguments $args
}

function la {
    Invoke-ListDirectory -Force -Arguments $args
}

function ll {
    Invoke-ListDirectory -Force -Arguments $args
}

function aa {
    Get-Alias | Sort-Object Name | Format-Table Name, Definition -AutoSize
}

function which {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Name)

    foreach ($item in $Name) {
        $command = Get-Command $item -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            Write-Warning "$item not found."
            continue
        }

        if ($command.Path) {
            $command.Path
        } elseif ($command.Source) {
            $command.Source
        } else {
            $command.Definition
        }
    }
}

function mntlist {
    Get-PSDrive -PSProvider FileSystem | Sort-Object Name | Format-Table Name, Root, Used, Free -AutoSize
}

function myip {
    try {
        (Invoke-RestMethod -Uri 'https://ifconfig.me').Trim()
    } catch {
        Write-Warning 'Unable to resolve public IP.'
    }
}

function Get-Weather {
    param(
        [string]$Location
    )

    if ($Location) {
        $encodedLocation = [Uri]::EscapeDataString($Location)
        $uri = "https://wttr.in/$encodedLocation?format=4"
    } else {
        $uri = 'https://wttr.in?format=4'
    }

    try {
        (Invoke-RestMethod -Uri $uri).Trim()
    } catch {
        Write-Warning 'Unable to fetch weather.'
    }
}

Set-Alias weather Get-Weather -Force

#----------------------------------------------------------------
# WINDOWS PACKAGE HELPERS
#----------------------------------------------------------------
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

function Get-WindowsPackageManifestEntries {
    $windowsRoot = Split-Path -Parent $PSCommandPath
    $repoRoot = Split-Path -Parent $windowsRoot
    $localRoot = Join-Path $HOME '.config\dotfiles\windows'

    $manifestSpecs = @(
        [pscustomobject]@{
            Name       = 'Core'
            Env        = @('DOTFILES_WINDOWS_PACKAGE_MANIFEST', 'DOTFILES_WINDOWS_PACKAGE_CORE_MANIFEST')
            LocalPath  = Join-Path $localRoot 'packages.psd1'
            SourcePath = (Join-Path $windowsRoot 'packages.psd1')
        }
        [pscustomobject]@{
            Name       = 'Optional'
            Env        = @('DOTFILES_WINDOWS_PACKAGE_OPTIONAL_MANIFEST')
            LocalPath  = Join-Path $localRoot 'packages.optional.psd1'
            SourcePath = (Join-Path $windowsRoot 'packages.optional.psd1')
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
    $manifests = @(Get-WindowsPackageManifestEntries)
    if ($manifests.Count -eq 0) {
        return @()
    }

    $comparison = @()

    foreach ($manifest in $manifests) {
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

function pkgcmp {
    $comparison = @(Get-WindowsPackageComparison)
    if ($comparison.Count -eq 0) {
        Write-Warning 'No curated Windows package manifest found.'
        return
    }

    foreach ($manifestGroup in $comparison | Group-Object Manifest | Sort-Object Name) {
        $manifestRows = @($manifestGroup.Group)
        $installedCount = @($manifestRows | Where-Object Installed).Count
        $missingCount = $manifestRows.Count - $installedCount

        Write-Section $manifestGroup.Name
        Write-Info "Installed: $installedCount/$($manifestRows.Count)"

        foreach ($managerGroup in $manifestRows | Group-Object Manager | Sort-Object Name) {
            $managerRows = @($managerGroup.Group)
            $managerInstalledCount = @($managerRows | Where-Object Installed).Count
            $managerMissingRows = @($managerRows | Where-Object { -not $_.Installed })

            Write-Info "$($managerGroup.Name): $managerInstalledCount/$($managerRows.Count)"

            if ($managerMissingRows.Count -eq 0) {
                continue
            }

            Write-Info 'Missing:'
            foreach ($row in $managerMissingRows) {
                Write-Info " - $($row.Package)"
            }
        }

        if ($missingCount -eq 0) {
            Write-Info 'Missing: none'
        }
    }
}

#----------------------------------------------------------------
# PACKAGE COMMANDS
#----------------------------------------------------------------
function Get-PackageManagerStatus {
    $packageManagers = @(
        [pscustomobject]@{ Name = 'winget'; Command = 'winget' }
        [pscustomobject]@{ Name = 'scoop'; Command = 'scoop' }
        [pscustomobject]@{ Name = 'choco'; Command = 'choco' }
        [pscustomobject]@{ Name = 'npm'; Command = 'npm' }
        [pscustomobject]@{ Name = 'corepack'; Command = 'corepack' }
    )

    foreach ($item in $packageManagers) {
        $command = Get-Command $item.Command -ErrorAction SilentlyContinue
        $source = $null
        if ($command) {
            if ($command.Source) {
                $source = $command.Source
            } elseif ($command.Path) {
                $source = $command.Path
            } else {
                $source = $command.Definition
            }
        }

        [pscustomobject]@{
            Manager   = $item.Name
            Available = [bool]$command
            Source    = $source
        }
    }
}

function pkgmgr {
    Get-PackageManagerStatus | Format-Table -AutoSize
}

function Get-ElevationRunner {
    if (Test-CommandExists sudo) {
        return 'sudo'
    }

    if (Test-CommandExists gsudo) {
        return 'gsudo'
    }

    return $null
}

function Invoke-ChocolateyElevated {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $elevationRunner = Get-ElevationRunner
    if (-not $elevationRunner) {
        Write-Warning 'sudo/gsudo not found.'
        return $false
    }

    & $elevationRunner choco @Arguments
    return ($LASTEXITCODE -eq 0)
}

function npmupg {
    if (-not (Test-CommandExists npm)) {
        Write-Warning 'npm not found.'
        return
    }

    Write-Section 'npm global updates'
    npm outdated -g
    npm update -g
}

function scoopup {
    if (-not (Test-CommandExists scoop)) {
        Write-Warning 'scoop not found.'
        return
    }

    Write-Section 'Scoop updates'
    scoop status
    scoop update *
}

function wingup {
    if (-not (Test-CommandExists winget)) {
        Write-Warning 'winget not found.'
        return
    }

    Write-Section 'winget updates'
    winget upgrade
    winget upgrade --all --accept-package-agreements --accept-source-agreements
}

function rpx {
    if (-not (Test-CommandExists repomix)) {
        Write-Warning 'repomix not found.'
        return
    }

    $repoName = Split-Path -Leaf (Get-Location)
    repomix -o "$repoName-repomix.md" --style markdown --ignore '*.html'
}

function Install-ChocoPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    if (-not (Test-CommandExists choco)) {
        Write-Warning 'Chocolatey not found.'
        return
    }

    if (-not (Invoke-ChocolateyElevated -Arguments @('install', $PackageName))) {
        Write-Warning "Chocolatey install failed for $PackageName."
    }
}

Set-Alias cinst Install-ChocoPackage -Force

function cupa {
    if (-not (Test-CommandExists choco)) {
        Write-Warning 'Chocolatey not found.'
        return
    }

    Write-Section 'Chocolatey updates'
    if (-not (Invoke-ChocolateyElevated -Arguments @('outdated'))) {
        return
    }

    if (-not (Invoke-ChocolateyElevated -Arguments @('upgrade', 'all', '-y'))) {
        Write-Warning 'Chocolatey upgrade failed.'
    }
}

#----------------------------------------------------------------
# EDITING AND GIT HELPERS
#----------------------------------------------------------------
function edt {
    $profilePath = Get-ProfilePath

    if (Test-CommandExists nano) {
        nano $profilePath
    } elseif (Test-CommandExists nvim) {
        nvim $profilePath
    } else {
        notepad $profilePath
    }
}

function gac {
    git add .; git commit -m @args
}

function gb {
    git branch @args
}

function gc {
    git checkout @args
}

function gca {
    git commit --amend --no-edit
}

function gcb {
    git checkout -b @args
}

function gcd {
    git commit --amend --no-edit --date "$(Get-Date -Format R)"
}

function gcl {
    git clone @args
}

function gd {
    git diff @args
}

function gds {
    git diff --stat @args
}

function gf {
    git fetch @args
}

function Invoke-GitPullRebase {
    git pull --rebase --autostash -Xignore-all-space @args
}

function gla {
    git log -1 --stat @args
}

function glaf {
    git show -p --stat --color=always -1 @args
}

function gln {
    git log --graph --decorate --pretty=oneline --abbrev-commit @args
}

function glo {
    git log --oneline @args
}

function glop {
    git log --pretty=format:'%C(yellow)%h%Creset - %C(green)%ad%Creset - %<(140,trunc)%s %<(45,trunc) %C(red)%d %C(green)%<(14,trunc)%ar %C(cyan)<%aN>' --abbrev-commit --date=short @args
}

function gp {
    git push @args
}

function gr {
    git rebase -Xignore-all-space --autostash @args
}

function gs {
    git status @args
}

function gsu {
    $branch = Get-GitCurrentBranch
    if (-not $branch) {
        Write-Warning 'Unable to determine the current branch.'
        return
    }

    git branch --set-upstream-to="origin/$branch"
}

function gu {
    git reset --soft HEAD~1
}

function lg {
    git log '@{upstream}..HEAD' @args
}

function lgr {
    $branch = Get-GitCurrentBranch
    if (-not $branch) {
        Write-Warning 'Unable to determine the current branch.'
        return
    }

    git log "origin/release..$branch" @args
}

Remove-Item Alias:gl -Force -ErrorAction SilentlyContinue
Set-Alias gl Invoke-GitPullRebase -Force

#----------------------------------------------------------------
# LOCAL OVERLAYS
#----------------------------------------------------------------
function Import-ProfileFile {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
        return
    }

    . $Path
}

function Import-ProfileDirectory {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path -PathType Container)) {
        return
    }

    Get-ChildItem -Path $Path -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

$profileOverlayDir = $env:DOTFILES_WINDOWS_PROFILE_DIR
if ([string]::IsNullOrWhiteSpace($profileOverlayDir)) {
    $profileOverlayDir = Join-Path $HOME '.config\dotfiles\windows\profile.d'
}

Import-ProfileDirectory -Path $profileOverlayDir
Import-ProfileFile -Path (Join-Path $HOME '.private_profile.ps1')
