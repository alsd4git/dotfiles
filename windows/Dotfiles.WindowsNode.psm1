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
        if ($LASTEXITCODE -ne 0 -or -not $raw) { throw 'npm global inventory failed; migration was cancelled.' }
        try {
            $inventory = $raw | ConvertFrom-Json -ErrorAction Stop
            $dependencies = $inventory.PSObject.Properties['dependencies']
            if ($dependencies -and $dependencies.Value) {
                foreach ($item in $dependencies.Value.PSObject.Properties) {
                    if ($item.Name -in @('npm', 'corepack')) { continue }
                    $version = $item.Value.PSObject.Properties['version']
                    if (-not $version -or [string]::IsNullOrWhiteSpace([string]$version.Value)) { throw 'Package version missing.' }
                    $globals += "$($item.Name)@$($version.Value)"
                }
            }
        } catch {
            throw 'Unable to parse npm global inventory; migration was cancelled.'
        }
    } else {
        throw 'npm not found; cannot inventory global packages. Migration was cancelled.'
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
        return ($LASTEXITCODE -eq 0 -and $default -match '(?m)^\s*Default\s*:\s*v?\d+\.\d+\.\d+\s*$')
    } catch {
        return $false
    }
}

function Assert-DotfilesNpmInventory {
    param([Parameter(Mandatory = $true)][psobject]$Saved, [Parameter(Mandatory = $true)][psobject]$Adopted)
    foreach ($package in @($Saved.GlobalPackages)) {
        if ($package -notmatch '^(.+)@([^@]+)$') { throw "Cannot verify saved package: $package" }
        $name = $Matches[1]; $version = $Matches[2]
        $property = $Adopted.dependencies.PSObject.Properties[$name]
        if (-not $property -or $property.Value.version -ne $version) { throw "Adopted npm package missing or changed: $package" }
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
            if (Test-DotfilesNvmDefault -NvmExecutable $state.NvmExecutable) {
                Write-Host '  NVM v2 already installed; keeping its current Node.js version unchanged.'
                return
            }
            $installedJson = (& $state.NvmExecutable list --json 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or -not $installedJson.StartsWith('[')) { throw 'Cannot inspect installed NVM versions; leaving the default unchanged.' }
            try { $installed = @($installedJson | ConvertFrom-Json -ErrorAction Stop) } catch { throw 'Cannot parse installed NVM versions; leaving the default unchanged.' }
            if (@($installed | Where-Object { $_ -and $_.default }).Count -gt 0) { throw 'NVM reports a default that could not be verified; leaving it unchanged.' }
            if ($DryRun) { Write-Host '  Would install and activate Node.js LTS for existing NVM without a default.'; return }
            Install-DotfilesNodeLts -NvmExecutable $state.NvmExecutable
            return
        }
        'Prompt' {
            if ($DryRun) { Write-Host '  Would ask to migrate standalone Node and its npm globals (default No).'; return }
            if ($NonInteractive) { Write-Warning 'Standalone Node detected; migration requires explicit consent.'; return }
            Write-Warning 'NVM adoption copies Node and global npm modules, then may uninstall standalone Node during setup.'
            $reply = Read-Host '  Migrate standalone Node and global npm modules to NVM? [y/N]'
            if ($reply -notmatch '^[Yy]$') { return }
            $plan = 'Migrate'
        }
    }

    if ($DryRun) {
        if ($plan -eq 'Migrate') {
            Write-Host '  Would save the npm inventory and run NVM adoption; setup may uninstall standalone Node.'
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
            $installerArgs = @('install', '--id', $script:NvmPackageId, '--exact', '--version', $script:NvmVersion, '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--silent')
            if ($plan -eq 'Migrate') { $installerArgs += @('--custom', '/OFFICIALNODE=adopt') }
            & winget @installerArgs
            if ($LASTEXITCODE -ne 0) { throw 'WinGet could not install NVM; inspect the machine before retrying.' }
            $newNvm = @(Get-DotfilesNvmExecutables | Where-Object { $_.Major -ge 2 } | Select-Object -First 1)
            if ($newNvm.Count -eq 0) { throw 'WinGet reported success but nvm.exe was not found; inspect the installation in a new shell.' }
            $nvmExe = $newNvm[0].Path
        }

        if ($plan -eq 'Install') {
            Install-DotfilesNodeLts -NvmExecutable $nvmExe
        } elseif (-not (Test-DotfilesNvmDefault -NvmExecutable $nvmExe)) {
            throw 'NVM did not report an adopted default Node version. Inspect the saved inventory and installation before retrying.'
        }

        if ($plan -eq 'Migrate') {
            # Verify the adopted executable and npm global inventory before removing
            # any standalone installation still present after the NVM installer.
            $versionText = (& $nvmExe default 2>$null | Out-String)
            if ($versionText -notmatch '(?m)^\s*Default\s*:\s*v?(\d+\.\d+\.\d+)\s*$') { throw 'Cannot identify the adopted Node version.' }
            $adoptedDir = Join-Path (Split-Path -Parent $nvmExe) ("installs\v" + $Matches[1])
            $adoptedNode = Join-Path $adoptedDir 'node.exe'
            $adoptedNpm = Join-Path $adoptedDir 'node_modules\npm\bin\npm-cli.js'
            if (-not (Test-Path -LiteralPath $adoptedNode) -or -not (Test-Path -LiteralPath $adoptedNpm)) { throw 'Adopted Node or npm is missing.' }
            $adoptedJson = (& $adoptedNode $adoptedNpm ls -g --depth=0 --json 2>$null | Out-String)
            if ($LASTEXITCODE -ne 0) { throw 'Unable to verify adopted npm globals.' }
            $adopted = $adoptedJson | ConvertFrom-Json -ErrorAction Stop
            $saved = Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json -ErrorAction Stop
            Assert-DotfilesNpmInventory -Saved $saved -Adopted $adopted
            $installedNow = @(Get-WingetInstalledPackageIds -Refresh)
            foreach ($id in $state.StandaloneIds) {
                if ($installedNow -notcontains $id) { continue }
                Write-Host "  Uninstalling standalone Node.js: $id"
                & winget uninstall --id $id --exact --source winget --accept-source-agreements
                if ($LASTEXITCODE -ne 0) { throw "Failed to uninstall $id; both installations may remain. Resolve the PATH conflict manually." }
            }
            $left = @($state.StandalonePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
            if ($left.Count -gt 0) { throw "Old node.exe still exists at $($left -join ', '); resolve this conflict before using NVM." }
            Write-Host '  Migration complete. The adopted Node version and saved npm globals were verified.'
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
    'Assert-DotfilesNpmInventory'
    'Get-DotfilesNvmExecutables'
    'Get-DotfilesNodePlan'
    'Get-DotfilesNodeState'
    'Invoke-DotfilesNvmBootstrap'
)
