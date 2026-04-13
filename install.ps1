[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Minimal,
    [switch]$Elevated,
    [switch]$ChocolateyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Section {
    param([string]$Message)
    Write-Host "`n$Message"
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message
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
        Write-Info "Would back up $Path -> $backupPath"
    } else {
        Move-Item -LiteralPath $Path -Destination $backupPath
        Write-Info "Backed up $Path -> $backupPath"
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
        Write-Info "Would copy $Source -> $Target"
    } else {
        Copy-Item -LiteralPath $Source -Destination $Target -Force
        Write-Info "Copied $Source -> $Target"
    }
}

function Get-ForwardedArgs {
    $argsOut = @()
    if ($DryRun) { $argsOut += '-DryRun' }
    if ($Force) { $argsOut += '-Force' }
    if ($Minimal) { $argsOut += '-Minimal' }
    if ($Elevated) { $argsOut += '-Elevated' }
    if ($ChocolateyOnly) { $argsOut += '-ChocolateyOnly' }
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

function Ensure-Scoop {
    if (Test-CommandExists scoop) {
        Write-Info "Scoop already installed."
        return
    }

    if ($DryRun) {
        Write-Info "Would install Scoop."
        return
    }

    Write-Info "Installing Scoop..."
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    } catch {
        Write-Warning "Could not update execution policy for Scoop. Continuing with bootstrap."
    }

    Invoke-Expression (Invoke-RestMethod -Uri 'https://get.scoop.sh')
}

function Install-ChocolateyBootstrap {
    if (Test-CommandExists choco) {
        Write-Info "Chocolatey already installed."
        return
    }

    if ($DryRun) {
        Write-Info "Would install Chocolatey."
        return
    }

    if (-not (Test-Administrator)) {
        Invoke-SelfElevated -ChocolateyMode
        return
    }

    Write-Info "Installing Chocolatey..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $script = Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1'
    Invoke-Expression $script
}

if (-not (Test-IsWindows)) {
    throw "install.ps1 is intended for Windows."
}

$RepoRoot = Split-Path -Parent $PSCommandPath
$WindowsProfileSource = Join-Path $RepoRoot 'windows/profile.ps1'
$GitIgnoreSource = Join-Path $RepoRoot 'git/global.gitignore'
$PowerShellProfileTarget = $PROFILE.CurrentUserAllHosts
$GitIgnoreTarget = Join-Path $HOME '.gitignore_global'
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
Ensure-Directory -Path $WindowsOverlayDir
Write-Info "Local overlay example: $($RepoRoot)\windows\profile.local.example.ps1"

Write-Section "Package managers"
if (Test-CommandExists winget) { $wingetState = 'available' } else { $wingetState = 'not found' }
if (Test-CommandExists scoop) { $scoopState = 'available' } else { $scoopState = 'not found' }
if (Test-CommandExists choco) { $chocoState = 'available' } else { $chocoState = 'not found' }
Write-Info "winget: $wingetState"
Write-Info "scoop: $scoopState"
Write-Info "choco: $chocoState"
Write-Info "Elevation helper: $(if (Test-CommandExists gsudo) { 'gsudo detected' } elseif (Test-CommandExists sudo) { 'sudo detected' } else { 'UAC runas' })"

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
} else {
    Write-Info "Minimal mode: skipping package manager bootstrap."
}

Write-Section "Complete"
Write-Info "Open a new PowerShell session so the profile changes are loaded."
