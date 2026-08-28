# dotfiles

[![Shell Quality](https://github.com/alsd4git/dotfiles/actions/workflows/shell-quality.yml/badge.svg)](https://github.com/alsd4git/dotfiles/actions/workflows/shell-quality.yml)

Personal, opinionated dotfiles for macOS, Debian/Ubuntu, and Windows. The Unix path configures Bash or Zsh through `install.sh`; the Windows path configures PowerShell through `install.ps1` and uses WinGet for packages.

Review the dry-run and the relevant platform files before applying the configuration to a new machine. The installers can update shell profiles, global Git defaults, package manifests, and platform-specific settings.

## Contents

- [Platform support](#platform-support)
- [Quick start](#quick-start)
  - [Windows](#windows)
  - [macOS](#macos)
  - [Debian and Ubuntu](#debian-and-ubuntu)
- [What this repository manages](#what-this-repository-manages)
- [Installer modes](#installer-modes)
- [Local and private configuration](#local-and-private-configuration)
- [Safety and recovery](#safety-and-recovery)
- [Common commands](#common-commands)
- [Verification and tests](#verification-and-tests)
- [Repository layout](#repository-layout)
- [Detailed guides](#detailed-guides)
- [License](#license)

## Platform support

| Platform | Status | Entry point | Package manager | Validation |
| --- | --- | --- | --- | --- |
| macOS | Supported | `install.sh` | Homebrew Bundle | Bash 3.2 compatibility, shell checks, and macOS defaults/Dock dry-runs |
| Debian/Ubuntu | Supported | `install.sh` | APT | Bash and Zsh lifecycle tests on Ubuntu 24.04 |
| Windows | Preview | `install.ps1` | WinGet | PowerShell parsing plus dry-run, sync, and Git restore smoke tests |

Other Linux distributions are not covered by the installer. The shell files can still be adapted manually, but package installation and platform setup assume Debian or Ubuntu.

The Windows path is marked as preview because it does not yet provide a complete uninstall workflow and CI does not perform a real installation of every WinGet package.

## Quick start

### Windows

Open a regular PowerShell window. WinGet may request elevation for individual packages when required.

1. Install Git, which is not included in a standard Windows installation:

   ```powershell
   winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
   ```

   Close and reopen PowerShell after the installation, then verify the command is available:

   ```powershell
   git --version
   ```

2. Clone the repository and enter it:

   ```powershell
   git clone https://github.com/alsd4git/dotfiles.git "$HOME\.dotfiles"
   Set-Location "$HOME\.dotfiles"
   ```

3. Allow locally stored PowerShell scripts and profiles for the current user:

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. Preview the changes, then run the interactive installer:

   ```powershell
   .\install.ps1 -DryRun
   .\install.ps1
   ```

5. Open a new PowerShell or Windows Terminal session to load the installed profile.

See the [Windows guide](docs/windows.md) for WinGet recovery, package selection, changed files, local overlays, backup behavior, and known limitations.

### macOS

Check that Git is available:

```bash
git --version
```

On a new Mac, install the Xcode Command Line Tools first if that command is unavailable:

```bash
xcode-select --install
```

After the tools finish installing:

```bash
git clone https://github.com/alsd4git/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh --dry-run
./install.sh
```

The executable bit for `install.sh` is tracked by Git, so a normal clone does not require `chmod +x`.

The Command Line Tools are enough for Git and the initial clone. The current optional macOS package/defaults path also checks `xcodebuild -version`, so install full Xcode before approving that phase. A configuration-only run with `--skip-tools` does not enter the Xcode/Homebrew path.

See the [macOS guide](docs/macos.md) before applying the Homebrew manifest, system defaults, or saved Dock layout.

### Debian and Ubuntu

Install Git before cloning the repository:

```bash
sudo apt update
sudo apt install -y git

git clone https://github.com/alsd4git/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh --dry-run
./install.sh
```

Run the initial APT commands as `root` instead when `sudo` is not installed. The package phase inside the current installer invokes `sudo`; use `./install.sh --skip-tools` and manage packages separately when `sudo` is intentionally unavailable.

See the [Debian/Ubuntu guide](docs/linux.md) for package groups, shell setup, optional toolchains, update behavior, and troubleshooting.

## What this repository manages

- **Shell configuration:** shared aliases, functions, history settings, prompt initialization, Nano configuration, and Bash/Zsh startup entries.
- **PowerShell configuration:** profiles for Windows PowerShell and PowerShell 7, aliases and helper functions, local profile overlays, Windows Terminal settings, and selected application configuration.
- **Git configuration:** a shared global ignore file and a conservative set of global defaults without replacing the complete user `.gitconfig`.
- **Packages:** `macos/Brewfile`, Debian/Ubuntu package groups, and separate Windows core, optional, and private manifests.
- **Platform settings:** an optional macOS defaults baseline, an optional saved Dock layout, Windows Terminal settings, and TrafficMonitor configuration.
- **Recovery state:** timestamped backups and snapshots of the Git settings managed by the installers.

Package manifests are the source of truth for the current inventory. The README intentionally does not duplicate every package name.

## Installer modes

### macOS and Debian/Ubuntu

| Command | Behavior |
| --- | --- |
| `./install.sh` | Interactive setup with managed dotfiles, Git defaults, and optional components |
| `./install.sh --dry-run` | Preview managed file and Git actions without modifying the machine; the package/tool phase is skipped |
| `./install.sh --minimal` | Install only the core dotfiles; skip Git defaults, package installation, and remote bootstrap operations |
| `./install.sh --skip-tools` | Apply dotfiles and Git defaults without installing packages or optional tools |
| `./install.sh --sync` | Reconcile managed dotfiles and Git defaults without installing tools or adding optional startup commands |
| `./install.sh --all --yes` | Select all optional components and answer yes to their prompts |
| `./install.sh --copy` | Copy managed files instead of symlinking them, with backups for conflicts |
| `./install.sh --clean-backups` | Offer to remove only backups recorded by this installer |
| `./install.sh --uninstall` | Remove managed links/startup entries and restore unchanged Git settings captured before installation |

Run `./install.sh --help` for the complete option list. macOS-specific options such as `--trust-brew-taps` and `--brew-upgrade` are documented in the [macOS guide](docs/macos.md).

### Windows

| Command | Behavior |
| --- | --- |
| `.\install.ps1` | Apply managed configuration and ask separately about core, optional, and private packages |
| `.\install.ps1 -DryRun` | Preview file, Git, and package operations without changing the machine |
| `.\install.ps1 -Minimal` | Apply managed configuration but skip package installation |
| `.\install.ps1 -Sync` | Reconcile profiles, copied configuration, and Git defaults without installing packages |
| `.\install.ps1 -Force` or `-y` | Answer yes to all package prompts; this includes optional and non-empty private manifests |
| `.\install.ps1 -CleanBackups` | Inspect the currently supported Windows backup-cleanup scope and ask before deletion |
| `.\install.ps1 -RestoreGitDefaults` | Restore managed Git values when they have not changed since installation |

For a non-destructive preview of the complete Windows package selection, use:

```powershell
.\install.ps1 -DryRun -Force
```

Do not use `-Force` for a conservative first installation: it selects all available package manifests rather than merely overwriting files.

## Local and private configuration

Keep machine-specific or sensitive configuration outside the tracked public files.

### macOS and Debian/Ubuntu

Create `~/.private_aliases`. The shared aliases file loads it automatically when present.

### Windows

The PowerShell profile loads these locations last:

1. `~\.config\dotfiles\windows\profile.d\*.ps1`, in filename order
2. `~\.private_profile.ps1`

Use [`windows/profile.local.example.ps1`](windows/profile.local.example.ps1) as a starting point. The overlay directory can also be replaced with the `DOTFILES_WINDOWS_PROFILE_DIR` environment variable.

For local-only package entries, edit the scaffold created at:

```text
~\.config\dotfiles\windows\packages.private.psd1
```

The public template is [`windows/packages.private.example.psd1`](windows/packages.private.example.psd1).

## Safety and recovery

- Run the appropriate dry-run before the first installation and after material configuration changes. Review package manifests separately because the Unix dry-run skips the package/tool phase.
- Existing conflicting files are moved to timestamped paths such as `.bak.<timestamp>` before replacement.
- The Unix installer records the backups it creates and limits `--clean-backups` to that manifest.
- The Windows installer currently creates backups but does not maintain an equivalent recursive backup manifest. Its cleanup command has a narrower scope; see the [Windows recovery notes](docs/windows.md#backup-and-recovery).
- Both installers snapshot the Git values they manage. Restore logic leaves a setting untouched when it was changed after installation.
- `install.sh --uninstall` provides a conservative Unix uninstall. Windows currently has `-RestoreGitDefaults`, not a complete uninstall.
- macOS defaults, the saved Dock layout, Windows Terminal settings, and TrafficMonitor configuration are opinionated. Review their source files before applying them.

## Common commands

| Command | Platform | Purpose |
| --- | --- | --- |
| `a` / `aa` | All configured shells | Inspect a command or print aliases |
| `l`, `la`, `ll`, `lt` | All configured shells | Directory listings, using `eza` when available |
| `gl` / `gp` | All configured shells | Pull with rebase/autostash or push the current branch |
| `gsu` | All configured shells | Set the upstream to `origin/<current-branch>` |
| `gla` / `glaf` | All configured shells | Show the latest commit summary or full patch |
| `npmupg` | Unix and Windows | Inspect and update global npm packages |
| `brewup` | macOS | Update, upgrade, and clean Homebrew packages |
| `wingup` | Windows | Show and apply WinGet upgrades |
| `rld` | Windows | Reload the managed PowerShell profile |

## Verification and tests

After a Unix installation:

```bash
command -v git nano fzf zoxide uv swiftly gh
git config --global --get core.excludesfile
./scripts/health-check.sh --strict
./scripts/tool-health-check.sh
```

After a Windows installation, open a new PowerShell session and run:

```powershell
Get-Command git, winget, aa, l, gl, wingup -ErrorAction SilentlyContinue
git config --global --get core.excludesfile
```

Repository checks include:

```bash
./tests/test-installer-functions.sh
./tests/docker-ubuntu-smoke.sh
```

```powershell
pwsh -File .\tests\windows-smoke.ps1
```

GitHub Actions runs ShellCheck, `shfmt`, Unix installer tests, Ubuntu lifecycle tests, macOS defaults/Dock dry-runs, and Windows PowerShell smoke tests.

## Repository layout

```text
.
├── .github/        GitHub Actions workflow
├── archive/        Historical installers, not part of the supported workflow
├── docs/           Platform-specific setup and troubleshooting guides
├── general/        Shared aliases, functions, history, and prompt setup
├── git/            Git aliases, functions, defaults, and global ignore
├── lib/            Unix installer modules and package policy
├── macos/          Brewfile, defaults, and saved Dock layout
├── nano/           Nano configuration
├── scripts/        Health checks and tool inventory
├── tests/          Installer, lifecycle, and PowerShell smoke tests
├── windows/        PowerShell profile, manifests, Terminal, and app configuration
├── install.sh      macOS and Debian/Ubuntu installer
└── install.ps1     Windows installer
```

## Detailed guides

- [Windows setup](docs/windows.md)
- [macOS setup](docs/macos.md)
- [Debian and Ubuntu setup](docs/linux.md)

## License

MIT. See [LICENSE](LICENSE).
