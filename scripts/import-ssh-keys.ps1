[CmdletBinding()]
param(
    [ValidateSet('github', 'gitlab')][string]$Provider,
    [string]$Username,
    [ValidateSet('User', 'Administrators')][string]$Destination,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-PublicKeys {
    param([string]$Url)
    $request = [Net.HttpWebRequest]::Create($Url)
    $request.AllowAutoRedirect = $false
    $request.Timeout = 30000
    $request.ReadWriteTimeout = 30000
    $response = $request.GetResponse()
    try {
        if ([int]$response.StatusCode -ne 200 -or $response.ContentLength -gt 1048576) { throw 'Unexpected or oversized response.' }
        $stream = $response.GetResponseStream()
        $buffer = New-Object byte[] 8192
        $memory = New-Object IO.MemoryStream
        try {
            while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                if ($memory.Length + $count -gt 1048576) { throw 'Public-key response exceeds 1 MiB.' }
                $memory.Write($buffer, 0, $count)
            }
            return [Text.Encoding]::UTF8.GetString($memory.ToArray())
        } finally { $memory.Dispose(); $stream.Dispose() }
    } finally { $response.Dispose() }
}

function Test-SafeAcl {
    param([string]$Path, [string[]]$AllowedSids)
    $acl = Get-Acl -LiteralPath $Path
    Assert-SafeAcl -Acl $acl -Path $Path -AllowedSids $AllowedSids
}

function Assert-SafeAcl {
    param($Acl, [string]$Path, [string[]]$AllowedSids)
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin $AllowedSids) { throw "Unexpected owner on $Path; inspect its ACL before importing." }
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin $AllowedSids) {
            throw "Unexpected allowed identity on $Path; inspect its ACL before importing."
        }
    }
}

function Get-UserSshTarget {
    Join-Path $HOME '.ssh\authorized_keys'
}

function Resolve-AuthorizedKeysDestination {
    param([string]$Line)
    if ($Line -notmatch '^authorizedkeysfile\s+') { return $null }
    $value = ($Line -replace '^authorizedkeysfile\s+', '').Trim().Replace('\', '/')
    if ($value -match '^\.ssh/authorized_keys(?:\s|$)') { return 'User' }
    if ($value -match '^(?:__PROGRAMDATA__|%programdata%)/ssh/administrators_authorized_keys(?:\s|$)') { return 'Administrators' }
    return $null
}

function Invoke-DotfilesSshKeyImport {
param(
    [ValidateSet('github', 'gitlab')][string]$Provider,
    [string]$Username,
    [ValidateSet('User', 'Administrators')][string]$Destination,
    [switch]$DryRun
)

if (-not $Provider) { $Provider = Read-Host 'Provider (github/gitlab)' }
if ($Provider -notin @('github', 'gitlab')) { throw 'Provider must be github or gitlab.' }
if (-not $Username) { $Username = Read-Host 'Username' }
if ($Username -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]*$' -or $Username.Contains('..')) { throw 'Invalid username.' }
if (-not (Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue)) { throw 'ssh-keygen is required.' }

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$userSid = $identity.User.Value
$adminSid = 'S-1-5-32-544'
$systemSid = 'S-1-5-18'
$groups = @(whoami.exe /groups /fo csv /nh | ConvertFrom-Csv -Header Name, Type, Sid, Attributes)
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine Windows group membership.' }
$isAdminMember = @($groups | Where-Object Sid -eq $adminSid).Count -gt 0
$elevated = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$userTarget = Get-UserSshTarget
$adminTarget = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'

# Ask when the effective sshd configuration cannot be established safely.
$resolved = $null
$sshd = Get-Command sshd.exe -ErrorAction SilentlyContinue
if (-not (Get-Service -Name sshd -ErrorAction SilentlyContinue)) { Write-Warning 'OpenSSH Server service was not found; it will not be installed or started.' }
if ($sshd) {
    $config = @(& $sshd.Source -T -C "user=$env:USERNAME,host=localhost,addr=127.0.0.1" 2>$null)
    if ($LASTEXITCODE -eq 0) {
        $line = @($config | Where-Object { $_ -match '^authorizedkeysfile\s+' } | Select-Object -First 1)
        if ($line.Count -eq 1) {
            $resolved = Resolve-AuthorizedKeysDestination -Line $line[0]
        }
    }
} else { Write-Warning 'OpenSSH Server was not found; it will not be installed or started.' }
if ($Destination -and $resolved -and $Destination -ne $resolved) { throw 'Selected destination conflicts with the effective sshd configuration.' }
if ($resolved) { Write-Warning 'The sshd configuration was checked for localhost; Match rules can select a different file for remote clients.' }
if ($Destination -and -not $resolved) { Write-Warning 'The effective AuthorizedKeysFile could not be verified; confirm that this destination matches sshd_config.' }
if (-not $Destination) { $Destination = $resolved }
if (-not $Destination) {
    Write-Warning 'Could not determine the effective AuthorizedKeysFile. Check sshd_config before selecting a destination.'
    $Destination = Read-Host 'Destination (User/Administrators; anything else cancels)'
    if ($Destination -notin @('User', 'Administrators')) { throw 'No destination selected.' }
}
if ($Destination -eq 'Administrators') {
    if (-not $isAdminMember) { throw 'The shared administrators file is only intended for administrator accounts.' }
    Write-Warning 'This file grants access to administrator accounts and is shared between administrators.'
    if (-not $DryRun -and -not $elevated) { throw 'Run this helper from an elevated PowerShell session to modify the shared file.' }
    $target = $adminTarget
    $allowedSids = @($adminSid, $systemSid)
} else {
    $target = $userTarget
    $allowedSids = @($userSid, $adminSid, $systemSid)
}
$folder = Split-Path -Parent $target
foreach ($path in @($folder, $target)) {
    if (Test-Path -LiteralPath $path) {
        if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing a reparse point: $path" }
        Test-SafeAcl -Path $path -AllowedSids $allowedSids
    }
}

$hostName = if ($Provider -eq 'github') { 'github.com' } else { 'gitlab.com' }
$payload = Read-PublicKeys -Url "https://$hostName/$Username.keys"
if ([string]::IsNullOrWhiteSpace($payload)) { throw 'No public keys returned.' }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-ssh-key-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $keys = @()
    foreach ($line in ($payload -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '\p{Cc}') { throw 'Public key contains control characters.' }
        if ($line -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(?:256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)\s+[A-Za-z0-9+/]+={0,3}(?:\s+[^\r\n]*)?$') { throw 'Invalid or unsupported public key.' }
        $keyFile = Join-Path $temp 'key.pub'
        [IO.File]::WriteAllText($keyFile, $line + "`n", (New-Object Text.UTF8Encoding($false)))
        $fingerprint = @(& ssh-keygen.exe -lf $keyFile 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Public-key validation failed: $($fingerprint -join ' ')" }
        Write-Host ($fingerprint -join ' ')
        $keys += $line
    }
    if ($keys.Count -eq 0) { throw 'No valid public keys returned.' }
    $original = if (Test-Path -LiteralPath $target) { [IO.File]::ReadAllBytes($target) } else { $null }
    $existingText = if ($null -ne $original) { [Text.Encoding]::UTF8.GetString($original) } else { '' }
    # SSH key base64 is case-sensitive; PowerShell hashtables are not.
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($line in ($existingText -split "`r?`n")) {
        $fields = $line.TrimStart([char]0xFEFF) -split '\s+'
        for ($i = 0; $i -lt $fields.Count - 1; $i++) {
            if ($fields[$i] -match '^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com)$') { [void]$seen.Add("$($fields[$i]) $($fields[$i+1])"); break }
        }
    }
    $newKeys = @()
    foreach ($line in $keys) {
        $parts = $line -split '\s+', 3
        $id = "$($parts[0]) $($parts[1])"
        if ($seen.Add($id)) { $newKeys += $line }
    }
    Write-Host "Destination: $target"
    Write-Host "New keys: $($newKeys.Count); already present or duplicate: $($keys.Count - $newKeys.Count)"
    Write-Warning 'Removing a key from the provider does not revoke it here. Remove it from authorized_keys manually.'
    if ($DryRun -or $newKeys.Count -eq 0) { return }
    if ((Read-Host 'Add these keys to allow incoming SSH access? [y/N]') -notmatch '^[Yy]$') { Write-Host 'No changes made.'; return }

    if (-not (Test-Path -LiteralPath $folder)) {
        if ($Destination -ne 'User') { throw 'Shared SSH folder does not exist.' }
        New-Item -ItemType Directory -Path $folder | Out-Null
        $folderAcl = New-Object Security.AccessControl.DirectorySecurity
        $folderAcl.SetAccessRuleProtection($true, $false)
        foreach ($sid in $allowedSids) {
            $rule = New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $folderAcl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $folder -AclObject $folderAcl
    }
    foreach ($path in @($folder, $target)) {
        if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "SSH path changed to a reparse point: $path" }
    }
    Test-SafeAcl -Path $folder -AllowedSids $allowedSids
    if (Test-Path -LiteralPath $target) {
        if ($null -eq $original -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($original)).Replace('-', ''))) { throw 'authorized_keys changed; retry.' }
        Test-SafeAcl -Path $target -AllowedSids $allowedSids
    } elseif ($null -ne $original) { throw 'authorized_keys was removed; retry.' }
    $staged = Join-Path $folder ('.authorized_keys.dotfiles.' + [guid]::NewGuid().ToString('N'))
    try {
        $suffix = if ($existingText.Length -gt 0 -and -not $existingText.EndsWith("`n")) { "`r`n" } else { '' }
        $bytes = [Text.Encoding]::UTF8.GetBytes($suffix + (($newKeys -join "`r`n") + "`r`n"))
        $file = [IO.File]::Open($staged, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { if ($null -ne $original) { $file.Write($original, 0, $original.Length) }; $file.Write($bytes, 0, $bytes.Length) } finally { $file.Dispose() }
        $fileAcl = New-Object Security.AccessControl.FileSecurity
        $fileAcl.SetAccessRuleProtection($true, $false)
        foreach ($sid in $allowedSids) { $fileAcl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)), 'FullControl', 'Allow'))) }
        Set-Acl -LiteralPath $staged -AclObject $fileAcl
        if ($null -ne $original) {
            $backup = Join-Path $folder ('authorized_keys.bak.' + [guid]::NewGuid().ToString('N'))
            [IO.File]::Replace($staged, $target, $backup)
            Write-Host "Previous authorized_keys saved to $backup"
        } else { [IO.File]::Move($staged, $target) }
        Write-Host 'Keys imported.'
    } finally { if (Test-Path -LiteralPath $staged) { Remove-Item -LiteralPath $staged -Force } }
} finally {
    Remove-Item -LiteralPath (Join-Path $temp 'key.pub') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-DotfilesSshKeyImport @PSBoundParameters
}
