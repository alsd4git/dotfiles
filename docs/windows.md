# Windows setup

[Back to the main README](../README.md)

The Windows path installs a shared PowerShell profile, applies the repository's Git defaults, copies the Windows package manifests, and manages selected Windows Terminal and application settings. It is usable but remains a preview because there is not yet a complete Windows uninstall workflow.

## Contents

- [Requirements](#requirements)
- [Fresh installation](#fresh-installation)
- [What the installer changes](#what-the-installer-changes)
- [Installer modes](#installer-modes)
- [Package manifests](#package-manifests)
- [Local configuration](#local-configuration)
- [Start Menu shortcuts](#start-menu-shortcuts)
- [Updating and rerunning](#updating-and-rerunning)
- [Backup and recovery](#backup-and-recovery)
- [Troubleshooting](#troubleshooting)
- [Verification](#verification)

## Requirements

- Windows with [WinGet](https://learn.microsoft.com/windows/package-manager/winget/) available through App Installer
- Windows PowerShell 5.1 or PowerShell 7
- Git for cloning the repository and applying the managed Git configuration
- Internet access when installing packages

Run the installer from a regular PowerShell session. WinGet can request elevation for individual packages that require it.

## Fresh installation

### 1. Install Git

Git is not included in a standard Windows installation. Install it with WinGet before attempting to clone this repository:

```powershell
winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
```

Close and reopen PowerShell so the refreshed `PATH` is visible, then verify the installation:

```powershell
git --version
```

### 2. Clone the repository

```powershell
git clone https://github.com/alsd4git/dotfiles.git "$HOME\.dotfiles"
Set-Location "$HOME\.dotfiles"
```

### 3. Allow local scripts and profiles

The shared profile must be allowed to run in future PowerShell sessions:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

This is a persistent current-user setting. Review the effective policies with:

```powershell
Get-ExecutionPolicy -List
```

A domain or device-management policy can override `CurrentUser`. See the official [`Set-ExecutionPolicy` documentation](https://learn.microsoft.com/powershell/module/microsoft.powershell.security/set-executionpolicy) for the precedence rules.

### 4. Preview the changes

```powershell
.\install.ps1 -DryRun
```

To include every package group in the preview without answering prompts:

```powershell
.\install.ps1 -DryRun -Force
```

### 5. Run the installer

```powershell
.\install.ps1
```

The default run applies the managed configuration and then asks separately whether to install missing core, optional, and local private packages.

### 6. Start a new shell

Open a new PowerShell or Windows Terminal session after installation. The installer deliberately does not reload the active session in place.

## What the installer changes

The installer compares file contents before replacing them. When an existing target differs, it moves the old file to a timestamped `.bak.<timestamp>` path before writing the managed version.

| Area | Target | Behavior |
| --- | --- | --- |
| Shared PowerShell profile | `<Documents>\PowerShell\profile.ps1` | Copies [`windows/profile.ps1`](../windows/profile.ps1) for PowerShell 7 |
| PowerShell host profile | `<Documents>\PowerShell\Microsoft.PowerShell_profile.ps1` | Writes a small managed shim so the shared profile is loaded only once |
| Shared Windows PowerShell profile | `<Documents>\WindowsPowerShell\profile.ps1` | Copies the same shared profile for Windows PowerShell 5.1 |
| Windows PowerShell host profile | `<Documents>\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` | Writes the same managed shim |
| Global Git ignore | `~\.gitignore_global` | Copies [`git/global.gitignore`](../git/global.gitignore) and sets `core.excludesfile` |
| Global Git defaults | User Git config | Merges the keys in [`git/defaults.conf`](../git/defaults.conf) without replacing the whole `.gitconfig` |
| Windows package state | `~\.config\dotfiles\windows\` | Copies the core and optional manifests plus the shared PowerShell package module |
| Private package scaffold | `~\.config\dotfiles\windows\packages.private.psd1` | Creates it from the public example only when it does not already exist |
| Local profile fragments | `~\.config\dotfiles\windows\profile.d\` | Creates the directory when missing |
| Windows Terminal | The detected Terminal `LocalState\settings.json` | Copies [`windows/terminal/settings.json`](../windows/terminal/settings.json) with backup |
| TrafficMonitor | Supported user-local and WinGet package paths | Copies [`windows/trafficmonitor/config.ini`](../windows/trafficmonitor/config.ini) with backup |

The Documents directory is resolved through Windows rather than assumed to be `C:\Users\<name>\Documents`, so redirected or OneDrive-backed Documents folders are respected.

Windows Terminal and TrafficMonitor configuration are currently copied during normal, `-Minimal`, and `-Sync` runs. Package selection only controls package installation; it does not disable these managed files.

## Installer modes

| Command | Behavior |
| --- | --- |
| `.\install.ps1` | Apply files and Git defaults, then ask about each package group |
| `.\install.ps1 -DryRun` | Preview files, Git changes, manifest selection, and missing packages without modifying the machine |
| `.\install.ps1 -Minimal` | Apply managed files and Git defaults but skip package installation |
| `.\install.ps1 -Sync` | Reconcile profiles, copied files, manifests, and Git defaults without installing packages |
| `.\install.ps1 -Force` | Answer yes to core, optional, and non-empty private package prompts |
| `.\install.ps1 -y` | Alias for `-Force` |
| `.\install.ps1 -CleanBackups` | List backups in the currently supported cleanup scope and ask before deletion |
| `.\install.ps1 -RestoreGitDefaults` | Restore installer-managed Git values when they still match the values applied by the installer |

Important mode rules:

- `-Sync` cannot be combined with `-Minimal`, `-Force`, or `-CleanBackups`.
- `-RestoreGitDefaults` is a dedicated operation and cannot be combined with installation options.
- `-DryRun` can be combined with `-Force` or `-Sync` for a non-destructive full preview.
- `-Force` is a yes-to-all switch, not simply an overwrite switch. It opts into optional and local private packages as well.

## Package manifests

The package inventory is split by intent:

| Manifest | Purpose |
| --- | --- |
| [`windows/packages.psd1`](../windows/packages.psd1) | Conservative public core: Git, PowerShell, Windows Terminal, prompt/font support, and common CLI tools |
| [`windows/packages.optional.psd1`](../windows/packages.optional.psd1) | Public-safe desktop applications and additional development/media utilities |
| `~\.config\dotfiles\windows\packages.private.psd1` | Machine-specific or private packages that must not be committed |

[`windows/Dotfiles.WindowsPackages.psm1`](../windows/Dotfiles.WindowsPackages.psm1) is shared by the installer and installed profile. It normalizes manifest entries, discovers core/optional/private manifests, and checks whether packages are already installed.

Both `Winget` and `NpmGlobal` sections are supported. The public `NpmGlobal` sections are intentionally empty so machine-specific global npm tools are not encoded into the repository.

A WinGet entry can be either a package ID string or a structured entry with an explicit source. The installer uses exact package IDs and installs only packages it does not detect as already present.

## Local configuration

### PowerShell overlays

The shared profile loads local configuration at the end, so local files can override public defaults without modifying the repository.

The default order is:

1. `~\.config\dotfiles\windows\profile.d\*.ps1`, sorted by filename
2. `~\.private_profile.ps1`

Copy [`windows/profile.local.example.ps1`](../windows/profile.local.example.ps1) as a starting point:

```powershell
Copy-Item .\windows\profile.local.example.ps1 "$HOME\.private_profile.ps1"
```

For multiple ordered fragments:

```powershell
Copy-Item .\windows\profile.local.example.ps1 "$HOME\.config\dotfiles\windows\profile.d\90-local.ps1"
```

Set `DOTFILES_WINDOWS_PROFILE_DIR` when the fragment directory must live somewhere else.

### Private packages

The first installer run creates this local-only scaffold when it is missing:

```text
~\.config\dotfiles\windows\packages.private.psd1
```

Keep credentials, internal package identifiers, and machine-specific choices out of the tracked public manifests.

## Start Menu shortcuts

Some portable or WinGet-installed applications do not create useful Start Menu shortcuts. Run the curated helper after package installation:

```powershell
.\windows\start-menu-shortcuts.ps1
```

After a package upgrade moves an executable, repair an existing shortcut with:

```powershell
.\windows\start-menu-shortcuts.ps1 -Repair
```

The script currently knows selected package-specific executable locations; it is not a general shortcut generator for every manifest entry.

## Updating and rerunning

Update the repository first:

```powershell
git -C "$HOME\.dotfiles" pull --ff-only
Set-Location "$HOME\.dotfiles"
```

Preview and apply configuration-only reconciliation:

```powershell
.\install.ps1 -DryRun -Sync
.\install.ps1 -Sync
```

Run the normal installer again when newly added packages should be considered:

```powershell
.\install.ps1
```

Reruns are content-aware for managed files and check package presence before attempting installation.

## Backup and recovery

### File backups

A replaced file is moved beside its original target with a name such as:

```text
profile.ps1.bak.<timestamp>
settings.json.bak.<timestamp>
```

Restore a file by moving the managed version aside and renaming the desired backup to its original name.

### Current cleanup limitation

`-CleanBackups` currently scans only the top level of `$HOME` for `*.bak.*` files. It does not recurse into Documents, AppData, Windows Terminal, or TrafficMonitor directories, where several installer backups can exist.

Treat the command as a limited helper rather than a complete backup manager. Inspect nested backups manually before deleting them. A future installer change should record every Windows backup in a manifest, matching the safer Unix behavior.

### Git defaults

Before the first Git configuration change, the installer stores previous values in:

```text
~\.config\dotfiles\installer-state\git-config.before.windows.json
```

Restore them with:

```powershell
.\install.ps1 -RestoreGitDefaults
```

For safety, a Git key is left unchanged when its current value no longer matches the value previously applied by the installer.

### No complete uninstall yet

The Windows path does not currently remove profiles, copied manifests, Terminal settings, TrafficMonitor configuration, or overlay directories automatically. Restore backed-up files and remove managed copies manually when a full rollback is required.

## Troubleshooting

### `winget` is not available

WinGet is supplied through App Installer. Update or install App Installer, then open a new PowerShell session.

On a newly provisioned Windows account where App Installer exists but WinGet has not registered yet, request registration with:

```powershell
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
```

Then verify:

```powershell
winget --version
```

See Microsoft's [WinGet installation and troubleshooting documentation](https://learn.microsoft.com/windows/package-manager/winget/) for current platform requirements.

### `git` is not found after WinGet installation

Close every open PowerShell/Terminal window and start a new session. Then run:

```powershell
git --version
Get-Command git
```

If the command is still unavailable, inspect the Git installation with:

```powershell
winget list --id Git.Git --exact
```

### Script execution is blocked

Inspect the effective policy order:

```powershell
Get-ExecutionPolicy -List
```

Apply the current-user policy again when it is not overridden by Group Policy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Do not permanently switch the machine to `Bypass` merely to run this repository.

### The new profile is not loaded

Open a new PowerShell session. If an older version of the profile is already active and provides `rld`, run:

```powershell
rld
```

Check the profile paths PowerShell is using:

```powershell
$PROFILE | Format-List * -Force
```

### Windows Terminal settings changed unexpectedly

The installer manages the detected Terminal `settings.json`. Look for the adjacent timestamped backup and restore it manually, or edit [`windows/terminal/settings.json`](../windows/terminal/settings.json) before the next sync.

Keep machine-specific Terminal profiles outside the tracked template; the managed file is intentionally a minimal shared baseline.

### A package installation fails

Inspect the exact manifest ID and ask WinGet for details:

```powershell
winget show --id Git.Git --exact --source winget
```

Run the installer again after correcting the package source or local WinGet state. Successful and already-installed packages are skipped on subsequent runs.

## Verification

Open a new PowerShell session and run:

```powershell
Get-Command git, winget, aa, l, gl, npmupg, wingup -ErrorAction SilentlyContinue
git config --global --get core.excludesfile
git config --global --get init.defaultBranch
```

Run the repository smoke test with PowerShell 7:

```powershell
pwsh -File .\tests\windows-smoke.ps1
```

The smoke test parses the PowerShell sources, validates manifest normalization, performs a minimal dry-run, uses temporary HOME/Git state for the lifecycle checks, applies `-Sync`, and verifies `-RestoreGitDefaults`.
