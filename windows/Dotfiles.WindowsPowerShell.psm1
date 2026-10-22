# Installer-only PowerShell 7 MSI migration helpers. Import has no side effects.
# Explicitly target PowerShell 7.6: 7.7 and later are MSIX-only upstream.
Set-StrictMode -Version Latest

$script:PwshPackageId = 'Microsoft.PowerShell'
$script:PwshMsiVersion = '7.6.7.0'

function Get-DotfilesPwshMsiPath {
    $programFiles = [Environment]::GetEnvironmentVariable('ProgramW6432')
    if ([string]::IsNullOrWhiteSpace($programFiles)) {
        $programFiles = $env:ProgramFiles
    }
    if ([string]::IsNullOrWhiteSpace($programFiles)) {
        throw 'Cannot determine Program Files directory.'
    }
    return (Join-Path $programFiles 'PowerShell\7\pwsh.exe')
}

function Test-DotfilesPwshMsiPresent {
    $path = Get-DotfilesPwshMsiPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    try {
        $item = Get-Item -LiteralPath $path -ErrorAction Stop
        if ($item.Length -le 0 -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            return $false
        }
        $major = @(& $path -NoLogo -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.Major' 2>$null)
        return ($LASTEXITCODE -eq 0 -and $major.Count -eq 1 -and $major[0].ToString().Trim() -eq '7')
    } catch {
        return $false
    }
}

function Get-DotfilesPowerShellState {
    $fixedPath = Get-DotfilesPwshMsiPath
    $isMsiPresent = Test-DotfilesPwshMsiPresent
    $isMsiFilePresent = Test-Path -LiteralPath $fixedPath -PathType Leaf

    $msixQuerySucceeded = $false
    $msixPackages = @()
    if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
        try {
            $msixPackages = @(
                Get-AppxPackage -Name 'Microsoft.PowerShell' -ErrorAction Stop |
                    Where-Object { $_.Name -eq 'Microsoft.PowerShell' -and $_.PackageFullName -like 'Microsoft.PowerShell_*' }
            )
            $msixQuerySucceeded = $true
        } catch {
            # An incomplete AppX query must never authorize a destructive migration.
        }
    }

    $runningMsix = (
        $PSVersionTable.PSEdition -eq 'Core' -and
        $PSHOME -match '[\\/]WindowsApps[\\/]'
    )

    $otherPaths = @()
    foreach ($command in @(Get-Command pwsh -All -CommandType Application -ErrorAction SilentlyContinue)) {
        $path = $command.Source
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        if ($path.Equals($fixedPath, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($path -match '[\\/]Microsoft[\\/]WindowsApps[\\/]pwsh\.exe$') { continue }
        if ($path -match '[\\/]WindowsApps[\\/].+[\\/]pwsh\.exe$') { continue }
        $otherPaths += $path
    }

    [pscustomobject]@{
        FixedPath           = $fixedPath
        MsiPresent          = [bool]$isMsiPresent
        MsiFilePresent      = [bool]$isMsiFilePresent
        MsixPackages        = @($msixPackages)
        MsixQuerySucceeded  = [bool]$msixQuerySucceeded
        RunningMsix         = [bool]$runningMsix
        OtherPwshPaths      = @($otherPaths | Select-Object -Unique)
    }
}

# Pure planning function; dotfiles -Force never supplies migration consent.
function Get-DotfilesPowerShellPlan {
    param(
        [Parameter(Mandatory = $true)][psobject]$State,
        [switch]$ExplicitMigration
    )

    if (-not $State.MsixQuerySucceeded) { return 'UnknownAppx' }
    if (@($State.OtherPwshPaths).Count -gt 0) { return 'OtherPwsh' }
    if ($State.MsiFilePresent -and -not $State.MsiPresent) { return 'BrokenMsi' }
    if (@($State.MsixPackages).Count -gt 0) {
        if (-not $ExplicitMigration) { return 'Prompt' }
        if ($State.RunningMsix) { return 'Relaunch' }
        return 'Migrate'
    }
    if ($State.RunningMsix) { return 'UnknownAppx' }
    if ($State.MsiPresent) { return 'Existing' }
    return 'Install'
}

function Install-DotfilesPwshMsi {
    param([switch]$MsixAlreadyPresent)

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'WinGet is not installed; cannot install PowerShell MSI.'
    }

    $args = @(
        'install', '--id', $script:PwshPackageId, '--exact',
        '--source', 'winget', '--version', $script:PwshMsiVersion,
        '--installer-type', 'wix', '--scope', 'machine',
        '--accept-package-agreements', '--accept-source-agreements', '--silent'
    )

    if ($MsixAlreadyPresent) {
        # Both distributions have the same WinGet package ID. Without --force,
        # WinGet may refuse to install MSI because it detects the MSIX package.
        $args += '--force'
    }

    Write-Host "  Installing PowerShell $script:PwshMsiVersion with WinGet (MSI / wix)..."
    & winget @args
    if ($LASTEXITCODE -ne 0) {
        throw "WinGet MSI installation failed with exit code $LASTEXITCODE. No MSIX package was removed."
    }

    if (-not (Test-DotfilesPwshMsiPresent)) {
        throw 'The MSI install did not create a working Program Files\PowerShell\7\pwsh.exe. MSIX has not been removed.'
    }
}

function Show-DotfilesPwshRelaunch {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $windowsPs = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $helper = Join-Path $RepoRoot 'windows\Install-PowerShellMsi.ps1'
    Write-Warning 'This installer is running inside PowerShell MSIX. It will not uninstall its own executable.'
    Write-Host '  Close this PowerShell 7 session and any other packaged pwsh.exe processes.'
    Write-Host '  Then relaunch ONLY the PowerShell migration from Windows PowerShell 5.1:'
    Write-Host ('  & "{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -Migrate' -f $windowsPs, $helper)
}

function Invoke-DotfilesPowerShellBootstrap {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [switch]$DryRun,
        [switch]$NonInteractive,
        [switch]$ExplicitMigration
    )

    $state = Get-DotfilesPowerShellState
    $plan = Get-DotfilesPowerShellPlan -State $state -ExplicitMigration:$ExplicitMigration
    switch ($plan) {
        'UnknownAppx' {
            Write-Warning 'Cannot reliably identify the current-user PowerShell MSIX installation. Skipping to avoid modifying an unknown PowerShell installation.'
            if ($ExplicitMigration -and -not $DryRun) {
                throw 'Cannot migrate without a reliable Get-AppxPackage result.'
            }
            return
        }
        'OtherPwsh' {
            Write-Warning "Another pwsh.exe is on PATH: $($state.OtherPwshPaths -join ', '). Resolve that installation first."
            if ($ExplicitMigration -and -not $DryRun) {
                throw 'Unexpected PowerShell executable on PATH.'
            }
            return
        }
        'BrokenMsi' {
            Write-Warning "A PowerShell executable exists at $($state.FixedPath) but cannot be validated. Repair it manually before continuing."
            if ($ExplicitMigration -and -not $DryRun) {
                throw 'Cannot migrate with a broken Program Files PowerShell installation.'
            }
            return
        }
        'Existing' {
            Write-Host "  PowerShell 7 already runs from the fixed path: $($state.FixedPath)"
            return
        }
        'Prompt' {
            if ($DryRun) {
                Write-Host '  Would ask whether to replace PowerShell Store/MSIX with MSI (default No).'
                return
            }
            if ($NonInteractive) {
                Write-Warning 'PowerShell MSIX detected. -Force is not consent to remove it; leaving it installed. Use -MigratePowerShellToMsi explicitly.'
                return
            }
            Write-Host '  PowerShell Store/MSIX is installed.'
            Write-Host "  MSI gives a fixed, SSH-friendly executable: $($state.FixedPath)"
            Write-Host '  Migration installs/verifies MSI first, then removes MSIX for the current user.'
            $reply = Read-Host '  Replace Store/MSIX PowerShell 7 with the MSI variant? [y/N]'
            if ($reply -notmatch '^[Yy]$') {
                Write-Host '  Keeping MSIX unchanged.'
                return
            }
            $plan = Get-DotfilesPowerShellPlan -State $state -ExplicitMigration
        }
    }

    if ($plan -eq 'Relaunch') {
        Show-DotfilesPwshRelaunch -RepoRoot $RepoRoot
        if ($ExplicitMigration -and -not $DryRun) {
            throw 'Relaunch from Windows PowerShell 5.1 before removing an active MSIX installation.'
        }
        return
    }

    if ($DryRun) {
        if ($plan -eq 'Migrate') {
            Write-Host "  Would verify MSI at $($state.FixedPath), installing $script:PwshMsiVersion via wix first if missing, then remove only current-user Microsoft.PowerShell MSIX."
        } else {
            Write-Host "  Would install PowerShell $script:PwshMsiVersion via wix (MSI) at $($state.FixedPath)."
        }
        return
    }

    try {
        if (-not $state.MsiPresent) {
            Install-DotfilesPwshMsi -MsixAlreadyPresent:($plan -eq 'Migrate')
        }

        if (-not (Test-DotfilesPwshMsiPresent)) {
            throw 'MSI executable verification failed. No PowerShell MSIX uninstall attempted.'
        }

        if ($plan -eq 'Migrate') {
            if ($state.RunningMsix) {
                throw 'Refusing to remove the PowerShell MSIX executable currently running this script.'
            }
            foreach ($package in @($state.MsixPackages)) {
                Write-Host "  Removing current-user MSIX package: $($package.PackageFullName)"
                Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
            }
            $remaining = @(
                Get-AppxPackage -Name 'Microsoft.PowerShell' -ErrorAction Stop |
                    Where-Object { $_.Name -eq 'Microsoft.PowerShell' }
            )
            if ($remaining.Count -gt 0) {
                throw 'PowerShell MSIX is still registered. Close packaged pwsh.exe sessions and retry removal.'
            }
            Write-Host '  PowerShell MSI migration complete. Restart any SSH sessions before testing.'
        } else {
            Write-Host '  PowerShell MSI installation complete.'
        }

        Write-Host ('  Fixed executable: {0}' -f $state.FixedPath)
        Write-Host '  In a new shell: where.exe pwsh; $PSHOME; pwsh -NoProfile -Command $PSHOME'
    } catch {
        Write-Warning "PowerShell MSI bootstrap incomplete: $($_.Exception.Message)"
        Write-Warning 'No attempt was made to uninstall or overwrite Windows PowerShell 5.1.'
        throw
    }
}

Export-ModuleMember -Function @(
    'Get-DotfilesPowerShellPlan'
    'Get-DotfilesPowerShellState'
    'Get-DotfilesPwshMsiPath'
    'Invoke-DotfilesPowerShellBootstrap'
    'Test-DotfilesPwshMsiPresent'
)
