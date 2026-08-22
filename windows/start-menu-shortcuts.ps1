[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Repair
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$startMenuPrograms = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'
$wingetPackagesRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'

$shortcutDefinitions = @(
    [pscustomobject]@{
        Name       = 'Keyguard'
        PackageId  = 'ArtemChepurnyi.Keyguard'
        Executable = 'Keyguard.exe'
        Fallbacks  = @('C:\Program Files\Keyguard\Keyguard.exe')
    }
    [pscustomobject]@{
        Name       = 'Krokiet'
        PackageId  = 'qarmin.krokiet'
        Executable = 'krokiet.exe'
        Fallbacks  = @()
    }
    [pscustomobject]@{
        Name       = 'Sublime Merge'
        PackageId  = 'SublimeHQ.SublimeMerge'
        Executable = 'sublime_merge.exe'
        Fallbacks  = @()
    }
    [pscustomobject]@{
        Name       = 'TrafficMonitor'
        PackageId  = 'zhongyang219.TrafficMonitor.Full'
        Executable = 'TrafficMonitor.exe'
        Fallbacks  = @()
    }
    [pscustomobject]@{
        Name       = 'Ventoy'
        PackageId  = 'Ventoy.Ventoy'
        Executable = 'Ventoy2Disk.exe'
        Fallbacks  = @()
    }
)

function Resolve-WingetExecutable {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$Executable,
        [string[]]$Fallbacks = @()
    )

    $candidates = @($Fallbacks | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })

    if (Test-Path -LiteralPath $wingetPackagesRoot -PathType Container) {
        $packageRoots = Get-ChildItem -LiteralPath $wingetPackagesRoot -Directory -Filter "${PackageId}_*" -ErrorAction SilentlyContinue
        foreach ($packageRoot in $packageRoots) {
            $candidates += Get-ChildItem -LiteralPath $packageRoot.FullName -Recurse -File -Filter $Executable -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
        }
    }

    return @($candidates | Select-Object -Unique | Select-Object -First 1)
}

function Get-ShortcutTarget {
    param([Parameter(Mandatory = $true)][string]$Path)

    $shell = New-Object -ComObject WScript.Shell
    try {
        return $shell.CreateShortcut($Path).TargetPath
    } finally {
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
}

if (-not (Test-Path -LiteralPath $startMenuPrograms -PathType Container)) {
    New-Item -ItemType Directory -Path $startMenuPrograms -Force | Out-Null
}

$existingShortcuts = @(Get-ChildItem -LiteralPath $startMenuPrograms -Recurse -File -Filter '*.lnk' -ErrorAction SilentlyContinue)
$shell = New-Object -ComObject WScript.Shell
try {
    foreach ($definition in $shortcutDefinitions) {
        $target = Resolve-WingetExecutable -PackageId $definition.PackageId -Executable $definition.Executable -Fallbacks $definition.Fallbacks
        $shortcutPath = Join-Path $startMenuPrograms "$($definition.Name).lnk"
        $existing = $existingShortcuts | Where-Object { $_.BaseName -eq $definition.Name } | Select-Object -First 1

        if ($existing -and -not $Repair) {
            $existingTarget = Get-ShortcutTarget -Path $existing.FullName
            [pscustomobject]@{
                Name   = $definition.Name
                Status = if (Test-Path -LiteralPath $existingTarget -PathType Leaf) { 'present' } else { 'stale' }
                Target = $existingTarget
            }
            continue
        }

        if (-not $target) {
            [pscustomobject]@{ Name = $definition.Name; Status = 'not-installed'; Target = $null }
            continue
        }

        if ($existing -and $Repair) {
            $shortcutPath = $existing.FullName
        }

        if ($PSCmdlet.ShouldProcess($shortcutPath, "Create Start Menu shortcut for $($definition.Name)")) {
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $target
            $shortcut.WorkingDirectory = [IO.Path]::GetDirectoryName($target)
            $shortcut.IconLocation = "$target,0"
            $shortcut.Description = "$($definition.Name) (installed with Winget)"
            $shortcut.Save()
            [pscustomobject]@{ Name = $definition.Name; Status = if ($existing) { 'repaired' } else { 'created' }; Target = $target }
        }
    }
} finally {
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
}
