# Installer-only NVM v2 bootstrap. Importing this module has no side effects.
Set-StrictMode -Version Latest

$script:NvmPackageId = 'AuthorSoftware.NVMWindows'
$script:NvmVersion = '2.0.1'
$script:StandaloneNodeIds = @('OpenJS.NodeJS.LTS', 'OpenJS.NodeJS')

function Get-DotfilesNvmExecutables {
    $candidates = @()
    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA 'Author Software\nvm\nvm.exe')
    }
    foreach ($command in @(Get-Command nvm -All -CommandType Application -ErrorAction SilentlyContinue)) {
        if ($command.Source) { $candidates += $command.Source }
    }

    foreach ($path in @($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        try {
            $version = (@(& $path --version 2>$null) -join ' ').Trim()
            if ($LASTEXITCODE -ne 0 -or $version -notmatch 'v?(\d+)\.(\d+)\.(\d+)') { continue }
            [pscustomobject]@{ Path = $path; Version = $Matches[0]; Major = [int]$Matches[1] }
        } catch {
            # Ignore broken executables; never treat them as a working manager.
        }
    }
}

function Get-DotfilesNodeState {
    $managers = @(Get-DotfilesNvmExecutables)
    $nvmV2 = $managers | Where-Object { $_.Major -ge 2 } | Select-Object -First 1
    $legacyNvm = @($managers | Where-Object { $_.Major -lt 2 }).Count -gt 0
    $installedIds = @()
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $installedIds = @(Get-WingetInstalledPackageIds)
    }
    if ($installedIds -contains 'CoreyButler.NVMforWindows') { $legacyNvm = $true }
    $standaloneIds = @($script:StandaloneNodeIds | Where-Object { $installedIds -contains $_ })

    $officialDirs = @()
    foreach ($root in @(
        $env:ProgramFiles,
        [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),
        $env:ProgramW6432
    )) {
        if ($root) { $officialDirs += (Join-Path $root 'nodejs') }
    }

    $paths = @(
        Get-Command node -All -CommandType Application -ErrorAction SilentlyContinue |
            Where-Object { $_.Source } | ForEach-Object { $_.Source }
    )
    foreach ($directory in @($officialDirs | Select-Object -Unique)) {
        $candidate = Join-Path $directory 'node.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $paths += $candidate }
    }

    $standalonePaths = @()
    $otherPaths = @()
    $nvmRoot = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Author Software\nvm' } else { '' }
    foreach ($path in @($paths | Select-Object -Unique)) {
        if ($nvmRoot -and $path.StartsWith(($nvmRoot.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $isOfficial = $false
        foreach ($directory in $officialDirs) {
            if ($path.Equals((Join-Path $directory 'node.exe'), [StringComparison]::OrdinalIgnoreCase)) {
                $isOfficial = $true
                break
            }
        }
        if ($isOfficial) { $standalonePaths += $path } else { $otherPaths += $path }
    }

    [pscustomobject]@{
        NvmExecutable     = if ($nvmV2) { $nvmV2.Path } else { $null }
        HasLegacyNvm      = $legacyNvm
        StandaloneIds     = @($standaloneIds)
        StandalonePaths   = @($standalonePaths)
        OtherNodePaths    = @($otherPaths)
        HasStandaloneNode = ($standaloneIds.Count -gt 0 -or $standalonePaths.Count -gt 0)
    }
}

# Pure decision logic, intentionally independent of -Force.
function Get-DotfilesNodePlan {
    param([Parameter(Mandatory = $true)][psobject]$State, [switch]$ExplicitMigration)
    if ($State.HasLegacyNvm) { return 'LegacyNvm' }
    if (@($State.OtherNodePaths).Count -gt 0) { return 'OtherNode' }
    if ($State.HasStandaloneNode) {
        if (@($State.StandaloneIds).Count -eq 0) { return 'ManualNode' }
        if ($ExplicitMigration) { return 'Migrate' }
        return 'Prompt'
    }
    if ($State.NvmExecutable) { return 'Existing' }
    return 'Install'
}

function Save-DotfilesNodeInventory {
    param([Parameter(Mandatory = $true)][psobject]$State)

    $npmPath = $null
    foreach ($nodePath in $State.StandalonePaths) {
        $candidate = Join-Path (Split-Path -Parent $nodePath) 'npm.cmd'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $npmPath = $candidate
            break
        }
    }
    if (-not $npmPath) {
        $npm = Get-Command npm -CommandType Application -ErrorAction SilentlyContinue
        if ($npm) { $npmPath = $npm.Source }
    }

    $globals = @()
    if ($npmPath) {
        $raw = (& $npmPath ls -g --depth=0 --json 2>$null | Out-String).Trim()
        if (-not $raw) { throw 'npm returned no global inventory; migration was cancelled.' }
        try {
            $inventory = $raw | ConvertFrom-Json -ErrorAction Stop
            if ($inventory.dependencies) {
                foreach ($item in $inventory.dependencies.PSObject.Properties) {
                    if ($item.Name -in @('npm', 'corepack')) { continue }
                    if ($item.Value.version) {
                        $globals += "$($item.Name)@$($item.Value.version)"
                    } else {
                        $globals += $item.Name
                    }
                }
            }
        } catch {
            throw 'Unable to parse npm global inventory; migration was cancelled.'
        }
    } else {
        Write-Warning 'npm not found; the migration inventory will not contain global packages.'
    }

    $dir = Join-Path $env:LOCALAPPDATA 'dotfiles\node-migration'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $file = Join-Path $dir ("before-nvm-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + "-$PID.json")
    [ordered]@{
        SavedAt = (Get-Date).ToString('o')
        StandaloneIds = @($State.StandaloneIds)
        StandalonePaths = @($State.StandalonePaths)
        NpmExecutable = $npmPath
        GlobalPackages = @($globals)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $file -Encoding UTF8 -ErrorAction Stop
    return $file
}

function Test-DotfilesNvmDefault {
    param([Parameter(Mandatory = $true)][string]$NvmExecutable)
    try {
        $default = (& $NvmExecutable default 2>$null | Out-String).Trim()
        return ($LASTEXITCODE -eq 0 -and $default -match 'v?\d+\.\d+\.\d+')
    } catch {
        return $false
    }
}

function Install-DotfilesNodeLts {
    param([Parameter(Mandatory = $true)][string]$NvmExecutable)
    Write-Host '  Installing Node.js LTS using NVM...'
    & $NvmExecutable install lts
    if ($LASTEXITCODE -ne 0) { throw 'nvm install lts failed; existing Node.js was not removed.' }
    & $NvmExecutable use lts
    if ($LASTEXITCODE -ne 0 -or -not (Test-DotfilesNvmDefault -NvmExecutable $NvmExecutable)) {
        throw 'nvm use lts failed; existing Node.js was not removed.'
    }
}

function Invoke-DotfilesNvmBootstrap {
    param([switch]$DryRun, [switch]$NonInteractive, [switch]$ExplicitMigration)

    $state = Get-DotfilesNodeState
    $plan = Get-DotfilesNodePlan -State $state -ExplicitMigration:$ExplicitMigration
    switch ($plan) {
        'LegacyNvm' {
            Write-Warning 'NVM for Windows v1 detected. Migrate it manually before installing v2.'
            if ($ExplicitMigration -and -not $DryRun) { throw 'Explicit migration cannot proceed with NVM v1 present.' }
            return
        }
        'OtherNode' {
            Write-Warning "Another Node runtime is on PATH ($($state.OtherNodePaths -join ', ')); resolve this conflict before installing NVM."
            if ($ExplicitMigration -and -not $DryRun) { throw 'Explicit migration cannot proceed with another Node runtime on PATH.' }
            return
        }
        'ManualNode' {
            Write-Warning "Standalone Node found outside recognized WinGet packages ($($state.StandalonePaths -join ', ')). Uninstall it manually first."
            if ($ExplicitMigration -and -not $DryRun) { throw 'Explicit migration requires WinGet-managed standalone Node.' }
            return
        }
        'Existing' {
            Write-Host '  NVM v2 already installed; keeping its current Node.js version unchanged.'
            return
        }
        'Prompt' {
            if ($DryRun) {
                Write-Host '  Would ask whether to replace standalone Node.js (default No); no changes.'
                return
            }
            if ($NonInteractive) {
                Write-Warning 'Standalone Node present. -Force does not authorize removal; skipping NVM. Use -MigrateNodeToNvm to opt in.'
                return
            }
            Write-Host "  Standalone Node.js detected: $($state.StandaloneIds -join ', ')."
            Write-Host '  Migration saves npm globals, activates Node LTS in NVM, then uninstalls standalone Node.'
            $reply = Read-Host '  Replace standalone Node.js with NVM for Windows? [y/N]'
            if ($reply -notmatch '^[Yy]$') {
                Write-Host '  Keeping standalone Node.js and skipping NVM to avoid PATH conflicts.'
                return
            }
            $plan = 'Migrate'
        }
    }

    if ($DryRun) {
        if ($plan -eq 'Migrate') {
            Write-Host "  Would back up npm globals, install NVM + Node LTS, then uninstall $($state.StandaloneIds -join ', ')."
        } else {
            Write-Host "  Would install $script:NvmPackageId $script:NvmVersion and Node LTS."
        }
        return
    }

    $backup = $null
    try {
        if ($plan -eq 'Migrate') {
            $backup = Save-DotfilesNodeInventory -State $state
            Write-Host "  Saved npm globals inventory: $backup"
        }

        $nvmExe = $state.NvmExecutable
        if (-not $nvmExe) {
            Write-Host "  Installing $script:NvmPackageId $script:NvmVersion..."
            # The pinned installer must not uninstall old Node before LTS is ready.
            & winget install --id $script:NvmPackageId --exact --version $script:NvmVersion --source winget --accept-package-agreements --accept-source-agreements --silent --custom '/OFFICIALNODE=ignore'
            if ($LASTEXITCODE -ne 0) { throw 'WinGet could not install NVM; existing Node.js was not removed.' }
            $newNvm = @(Get-DotfilesNvmExecutables | Where-Object { $_.Major -ge 2 } | Select-Object -First 1)
            if ($newNvm.Count -eq 0) { throw 'WinGet reported success but nvm.exe was not found; inspect the installation in a new shell.' }
            $nvmExe = $newNvm[0].Path
        }

        if ($plan -eq 'Install' -or -not (Test-DotfilesNvmDefault -NvmExecutable $nvmExe)) {
            Install-DotfilesNodeLts -NvmExecutable $nvmExe
        } else {
            Write-Host '  Reusing the existing NVM default version.'
        }

        if ($plan -eq 'Migrate') {
            # Uninstall only AFTER a usable NVM default has been verified.
            foreach ($id in $state.StandaloneIds) {
                Write-Host "  Uninstalling standalone Node.js: $id"
                & winget uninstall --id $id --exact --source winget --accept-source-agreements
                if ($LASTEXITCODE -ne 0) { throw "Failed to uninstall $id; both installations may remain. Resolve the PATH conflict manually." }
            }
            $left = @($state.StandalonePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
            if ($left.Count -gt 0) { throw "Old node.exe still exists at $($left -join ', '); resolve this conflict before using NVM." }
            Write-Host '  Migration complete. Review the saved npm global list; reinstall needed tools under NVM.'
        } else {
            Write-Host '  NVM and Node.js LTS installed.'
        }
        Write-Host '  Restart PowerShell, then run: nvm default; where.exe node; node -v; npm -v'
    } catch {
        Write-Warning "NVM bootstrap incomplete: $($_.Exception.Message)"
        if ($backup) { Write-Warning "Saved npm inventory: $backup" }
        Write-Warning 'No automatic rollback was attempted. Inspect WinGet and PATH before rerunning.'
        throw 'NVM bootstrap failed; package installation was stopped to avoid concealing a Node/PATH conflict.'
    }
}

Export-ModuleMember -Function @(
    'Get-DotfilesNvmExecutables'
    'Get-DotfilesNodePlan'
    'Get-DotfilesNodeState'
    'Invoke-DotfilesNvmBootstrap'
)
