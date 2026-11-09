[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'scripts/import-ssh-keys.ps1')
if ((Resolve-AuthorizedKeysDestination 'authorizedkeysfile .ssh/authorized_keys .ssh/authorized_keys2') -ne 'User') { throw 'User destination was not recognized.' }
if ((Resolve-AuthorizedKeysDestination 'authorizedkeysfile __PROGRAMDATA__\ssh\administrators_authorized_keys') -ne 'Administrators') { throw 'Shared destination was not recognized.' }
if ($null -ne (Resolve-AuthorizedKeysDestination 'authorizedkeysfile C:/custom/keys')) { throw 'Custom destination must not be guessed.' }
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-ssh-import-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$testRoot = (Resolve-Path -LiteralPath $testRoot).Path
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $testRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected test directory.' }

function Get-UserSshTarget { Join-Path $testRoot '.ssh\authorized_keys' }
function Test-SafeAcl { param($Path, $AllowedSids) }
function Read-PublicKeys { param($Url) if ($script:failDownload) { throw 'Simulated network failure.' }; return $script:payload }
function Read-Host { param($Prompt) return $script:confirmation }
function Get-Command {
    param($Name, $ErrorAction)
    if ($Name -eq 'sshd.exe') { return $null }
    Microsoft.PowerShell.Core\Get-Command $Name -ErrorAction SilentlyContinue
}

try {
    $identitySid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $acl = New-Object Security.AccessControl.FileSecurity
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier($identitySid)))
    $acl.SetAccessRuleProtection($true, $false)
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($identitySid)), 'FullControl', 'Allow')))
    Assert-SafeAcl -Acl $acl -Path 'fixture' -AllowedSids @($identitySid, 'S-1-5-32-544', 'S-1-5-18')
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier('S-1-1-0')), 'Read', 'Allow')))
    $aclRejected = $false
    try { Assert-SafeAcl -Acl $acl -Path 'fixture' -AllowedSids @($identitySid, 'S-1-5-32-544', 'S-1-5-18') } catch { $aclRejected = $true }
    if (-not $aclRejected) { throw 'An ACL allowing Everyone must be rejected.' }
    $script:payload = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ0cTStxdRoWnKOMcJlXMLKfTr2Km6eKqLhc9eYLCQ1y test-fixture'
    $script:failDownload = $false
    $script:confirmation = 'n'
    $target = Get-UserSshTarget
    Invoke-DotfilesSshKeyImport -Provider github -Username test-user -Destination User -DryRun
    if (Test-Path -LiteralPath $target) { throw 'Dry run created a target.' }
    Invoke-DotfilesSshKeyImport -Provider github -Username test-user -Destination User
    if (Test-Path -LiteralPath $target) { throw 'Declined confirmation created a target.' }
    $script:confirmation = 'y'
    Invoke-DotfilesSshKeyImport -Provider github -Username test-user -Destination User
    $original = [IO.File]::ReadAllBytes($target)
    $script:payload = $script:payload -replace 'test-fixture$', 'different-comment'
    Invoke-DotfilesSshKeyImport -Provider gitlab -Username test-user -Destination User
    if ([Convert]::ToBase64String($original) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($target))) { throw 'Duplicate key changed the file.' }
    $script:payload = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCoQ9S7V+CufAgwoehnf2TqsJ9LTsu8pUA3FgpS2mdVwcMcTs++8P5sQcXHLtDmNLpWN4k7NQgxaY1oXy5e25x/4VhXaJXWEt3luSw+Phv/PB2+aGLvqCUirsLTAD2r7ieMhd/pcVf/HlhNUQgnO1mupdbDyqZoGD/uCcJiYav8i/V7nJWJouHA8yq31XS2yqXp9m3VC7UZZHzUsVJA9Us5YqF0hKYeaGruIHR2bwoDF9ZFMss5t6/pzxMljU/ccYwvvRDdI7WX4o4+zLuZ6RWvsU6LGbbb0pQdB72tlV41fSefwFsk4JRdKbyV3Xjf25pV4IXOTcqhy+4JTB/jXxrF second-fixture'
    Invoke-DotfilesSshKeyImport -Provider github -Username test-user -Destination User
    $updated = [IO.File]::ReadAllBytes($target)
    if ($updated.Length -le $original.Length -or [Convert]::ToBase64String($updated[0..($original.Length - 1)]) -ne [Convert]::ToBase64String($original)) { throw 'Existing contents were not preserved.' }
    $backups = @(Get-ChildItem -LiteralPath (Split-Path -Parent $target) -Filter 'authorized_keys.bak.*')
    if ($backups.Count -ne 1 -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($backups[0].FullName)) -ne [Convert]::ToBase64String($original)) { throw 'Expected a backup of the previous file.' }
    $original = $updated
    foreach ($failure in @('invalid', 'network')) {
        $script:payload = 'not a key'
        $script:failDownload = $failure -eq 'network'
        $failed = $false
        try { Invoke-DotfilesSshKeyImport -Provider github -Username test-user -Destination User } catch { $failed = $true }
        if (-not $failed) { throw "Expected $failure failure." }
        if ([Convert]::ToBase64String($original) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($target))) { throw "File changed after $failure failure." }
    }
    $script:failDownload = $false
    $script:payload = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ0cTStxdRoWnKOMcJlXMLKfTr2Km6eKqLhc9eYLCQ1y $([char]27)[31m"
    $failed = $false
    try { Invoke-DotfilesSshKeyImport -Provider github -Username test-user -Destination User } catch { $failed = $true }
    if (-not $failed) { throw 'Keys containing terminal control characters must be rejected.' }
    if ([Convert]::ToBase64String($original) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($target))) { throw 'File changed after a control-character failure.' }
    Write-Host 'Windows SSH key import tests passed.'
} finally {
    if ((Test-Path -LiteralPath $testRoot) -and $testRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
