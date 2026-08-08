Set-StrictMode -Version Latest

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
    param(
        [Parameter(Mandatory = $true)][string]$WindowsRoot,
        [Parameter(Mandatory = $true)][string]$LocalRoot
    )

    $manifestSpecs = @(
        [pscustomobject]@{
            Name       = 'Core'
            Env        = @('DOTFILES_WINDOWS_PACKAGE_MANIFEST', 'DOTFILES_WINDOWS_PACKAGE_CORE_MANIFEST')
            LocalPath  = Join-Path $LocalRoot 'packages.psd1'
            SourcePath = Join-Path $WindowsRoot 'packages.psd1'
        }
        [pscustomobject]@{
            Name       = 'Optional'
            Env        = @('DOTFILES_WINDOWS_PACKAGE_OPTIONAL_MANIFEST')
            LocalPath  = Join-Path $LocalRoot 'packages.optional.psd1'
            SourcePath = Join-Path $WindowsRoot 'packages.optional.psd1'
        }
        [pscustomobject]@{
            Name       = 'Private'
            Env        = @('DOTFILES_WINDOWS_PACKAGE_PRIVATE_MANIFEST')
            LocalPath  = Join-Path $LocalRoot 'packages.private.psd1'
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

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
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
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
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

Export-ModuleMember -Function @(
    'Format-WindowsPackageEntry'
    'Get-WindowsPackageManifestEntries'
    'Get-WingetInstalledPackageIds'
    'Resolve-WindowsPackageEntry'
    'Resolve-WindowsPackageManifestPath'
    'Test-WingetPackageInstalled'
)
