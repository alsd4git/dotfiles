# Generic PowerShell profile for the dotfiles repo.
# Keep this file portable: useful defaults, optional integrations, and no machine-specific paths.

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-ProfilePath {
    if ($PROFILE.PSObject.Properties.Name -contains 'CurrentUserAllHosts' -and $PROFILE.CurrentUserAllHosts) {
        return $PROFILE.CurrentUserAllHosts
    }

    return $PROFILE
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

if (Test-CommandExists oh-my-posh) {
    try {
        oh-my-posh init pwsh | Invoke-Expression
    } catch {
        # Keep startup non-fatal if the prompt engine is temporarily unavailable.
    }
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

function npmupg {
    if (-not (Test-CommandExists npm)) {
        Write-Warning 'npm not found.'
        return
    }

    npm outdated -g
    npm update -g
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

    choco install $PackageName
}

Set-Alias cinst Install-ChocoPackage -Force

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

# Put machine-specific prompt/theme tweaks or private helpers in this optional local file.
$privateProfile = Join-Path $HOME '.private_profile.ps1'
if (Test-Path $privateProfile) {
    . $privateProfile
}
