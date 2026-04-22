# Generic PowerShell profile for the dotfiles repo.
# Keep this file portable: useful defaults, optional integrations, and no machine-specific paths.

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

if (Test-CommandExists oh-my-posh) {
    try {
        oh-my-posh init pwsh | Invoke-Expression
    } catch {
        # Keep startup non-fatal if the prompt engine is temporarily unavailable.
    }
}

function Set-PoshTheme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-CommandExists oh-my-posh)) {
        Write-Warning 'oh-my-posh not found.'
        return
    }

    if (-not (Test-Path $ConfigPath)) {
        Write-Warning "Theme not found: $ConfigPath"
        return
    }

    oh-my-posh init pwsh --config $ConfigPath | Invoke-Expression
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

function Get-WindowsPackageManifestPath {
    if (-not [string]::IsNullOrWhiteSpace($env:DOTFILES_WINDOWS_PACKAGE_MANIFEST) -and (Test-Path -LiteralPath $env:DOTFILES_WINDOWS_PACKAGE_MANIFEST)) {
        return $env:DOTFILES_WINDOWS_PACKAGE_MANIFEST
    }

    $defaultPath = Join-Path $HOME '.config\dotfiles\windows\packages.psd1'
    if (Test-Path -LiteralPath $defaultPath) {
        return $defaultPath
    }

    return $null
}

function Get-WindowsPackageManifest {
    param([string]$ManifestPath)

    $resolvedPath = $ManifestPath
    if ([string]::IsNullOrWhiteSpace($resolvedPath)) {
        $resolvedPath = Get-WindowsPackageManifestPath
    }

    if ([string]::IsNullOrWhiteSpace($resolvedPath) -or -not (Test-Path -LiteralPath $resolvedPath)) {
        return $null
    }

    return Import-PowerShellDataFile -LiteralPath $resolvedPath
}

function Test-WingetPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$PackageId)

    if (-not (Test-CommandExists winget)) {
        return $false
    }

    & winget list --id $PackageId --exact *> $null
    return $LASTEXITCODE -eq 0
}

function Get-ScoopInstalledPackages {
    $roots = @()

    foreach ($root in @(
        $env:SCOOP
        $env:SCOOP_GLOBAL
        (Join-Path $HOME 'scoop')
        $env:ProgramData
    )) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        $appsRoot = if ($root -like '*scoop') {
            Join-Path $root 'apps'
        } elseif ($root -eq $env:ProgramData) {
            Join-Path $root 'scoop\apps'
        } else {
            Join-Path $root 'apps'
        }

        if (Test-Path -LiteralPath $appsRoot) {
            $roots += $appsRoot
        }
    }

    if ($roots.Count -eq 0) {
        return @()
    }

    $packages = foreach ($root in ($roots | Sort-Object -Unique)) {
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
    }

    return @($packages | Sort-Object -Unique)
}

function Test-ScoopPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$PackageName)

    return @(Get-ScoopInstalledPackages) -contains $PackageName
}

function Get-ChocolateyInstalledPackages {
    if (-not (Test-CommandExists choco)) {
        return @()
    }

    $lines = & choco list --local-only --limit-output 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $lines) {
        return @()
    }

    return @(
        $lines |
            ForEach-Object { ($_ -split '\|')[0] } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

function Test-ChocolateyPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$PackageName)

    return @(Get-ChocolateyInstalledPackages) -contains $PackageName
}

function Get-NpmGlobalPackages {
    if (-not (Test-CommandExists npm)) {
        return @()
    }

    $lines = & npm list -g --depth=0 --parseable 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $lines) {
        return @()
    }

    return @(
        $lines |
            ForEach-Object { Split-Path -Leaf $_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

function Test-NpmGlobalPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$PackageName)

    return @(Get-NpmGlobalPackages) -contains $PackageName
}

function Get-WindowsPackageComparison {
    $manifest = Get-WindowsPackageManifest
    if (-not $manifest) {
        return @()
    }

    $comparison = @()

    foreach ($section in @(
        [pscustomobject]@{ Manager = 'Winget'; Packages = @($manifest.Winget) }
        [pscustomobject]@{ Manager = 'Scoop'; Packages = @($manifest.Scoop) }
        [pscustomobject]@{ Manager = 'Chocolatey'; Packages = @($manifest.Chocolatey) }
        [pscustomobject]@{ Manager = 'NpmGlobal'; Packages = @($manifest.NpmGlobal) }
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

function pkgcmp {
    $comparison = @(Get-WindowsPackageComparison)
    if ($comparison.Count -eq 0) {
        Write-Warning 'No curated Windows package manifest found.'
        return
    }

    foreach ($group in $comparison | Group-Object Manager | Sort-Object Name) {
        $groupRows = @($group.Group)
        $installedCount = @($groupRows | Where-Object Installed).Count
        $missingRows = @($groupRows | Where-Object { -not $_.Installed })

        Write-Section $group.Name
        Write-Info "Installed: $installedCount/$($groupRows.Count)"

        if ($missingRows.Count -eq 0) {
            Write-Info 'Missing: none'
            continue
        }

        Write-Info 'Missing:'
        foreach ($row in $missingRows) {
            Write-Info " - $($row.Package)"
        }
    }
}

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

function gl {
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

# Load optional local overlays last so they can override the public defaults above.
$profileOverlayDir = $env:DOTFILES_WINDOWS_PROFILE_DIR
if ([string]::IsNullOrWhiteSpace($profileOverlayDir)) {
    $profileOverlayDir = Join-Path $HOME '.config\dotfiles\windows\profile.d'
}

Import-ProfileDirectory -Path $profileOverlayDir
Import-ProfileFile -Path (Join-Path $HOME '.private_profile.ps1')
