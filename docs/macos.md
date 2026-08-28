# macOS setup

[Back to the main README](../README.md)

The macOS path manages Bash/Zsh dotfiles, Git defaults, a Homebrew Bundle manifest, an optional system-defaults baseline, and an optional saved Dock layout. The configuration is intentionally opinionated; preview it before applying it to an existing Mac.

## Contents

- [Requirements](#requirements)
- [Fresh installation](#fresh-installation)
- [Installer modes](#installer-modes)
- [Homebrew management](#homebrew-management)
- [macOS defaults](#macos-defaults)
- [Saved Dock layout](#saved-dock-layout)
- [Local configuration](#local-configuration)
- [Updating and uninstalling](#updating-and-uninstalling)
- [Bootstrap security](#bootstrap-security)
- [Refreshing the application inventory](#refreshing-the-application-inventory)
- [Troubleshooting](#troubleshooting)
- [Verification](#verification)

## Requirements

- macOS
- Bash 3.2 or newer, or Zsh
- Xcode Command Line Tools for Git and the initial clone
- Full Xcode when using the current optional Homebrew/defaults/Dock path, which verifies `xcodebuild -version`
- Internet access for Homebrew and optional tool installation

The installer supports the Bash 3.2 baseline shipped by older macOS releases and current Zsh. Native Apple Silicon is the primary macOS bootstrap path; the installer does not automatically add Rosetta for Intel-only software.

## Fresh installation

### 1. Install the Command Line Tools

Check whether Git is available:

```bash
git --version
```

On a new Mac, request the Xcode Command Line Tools if that command is unavailable:

```bash
xcode-select --install
```

Finish the graphical installation before continuing. Verify both the selected developer directory and Git:

```bash
xcode-select -p
git --version
```

The Command Line Tools are sufficient for this bootstrap and clone step.

### 2. Clone the repository

```bash
git clone https://github.com/alsd4git/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

The executable bit for `install.sh` is tracked by Git. A normal clone does not require a separate `chmod +x install.sh` step.

### 3. Choose the installation scope

For managed dotfiles and Git defaults without Homebrew, macOS defaults, or Dock changes:

```bash
./install.sh --dry-run --skip-tools
./install.sh --skip-tools
```

For the optional macOS package/defaults/Dock phase, the current installer requires full Xcode because its preflight checks `xcodebuild -version`. Install Xcode from the App Store, select it, and verify it before approving that phase:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

### 4. Preview and run the interactive installer

```bash
./install.sh --dry-run
./install.sh
```

The default run configures the managed dotfiles and asks before optional tools and platform settings are applied. The Unix dry-run previews file and Git operations; it deliberately skips the package/tool phase. Review the Brewfile and use the standalone macOS script dry-runs before approving the full platform setup.

## Installer modes

| Command | Behavior |
| --- | --- |
| `./install.sh` | Interactive dotfile, Git, package, and macOS setup |
| `./install.sh --dry-run` | Preview managed file and Git operations; the package/tool phase is skipped |
| `./install.sh --minimal` | Install only core dotfiles; skip Git defaults, tools, and remote fetches |
| `./install.sh --skip-tools` | Apply dotfiles and Git defaults without package-manager or tool installation |
| `./install.sh --sync` | Reconcile dotfiles and Git defaults without tools or optional startup commands |
| `./install.sh --copy` | Copy managed files instead of symlinking them |
| `./install.sh --all` | Select all optional components; review the platform files before using it |
| `./install.sh --yes` | Answer yes to prompts for the operations selected by the invocation |
| `./install.sh --all --yes` | Full non-interactive component selection |
| `./install.sh --trust-brew-taps` | Explicitly trust third-party taps declared by the Brewfile |
| `./install.sh --brew-upgrade` | Upgrade dependencies tracked by the Brewfile instead of installing only missing items |
| `./install.sh --clean-backups` | Offer to remove only backups recorded by the installer |
| `./install.sh --uninstall` | Remove managed links/startup entries and conservatively restore Git settings |

`--force` remains a deprecated compatibility alias for `--all --yes`. Prefer the two explicit switches in scripts and documentation.

## Homebrew management

The declarative inventory lives in [`macos/Brewfile`](../macos/Brewfile). It contains formulae, casks, Mac App Store entries, fonts, and the third-party taps required by selected packages.

When optional tools are approved and Homebrew is missing, the installer can bootstrap Homebrew and add the appropriate shell environment line:

- Apple Silicon: `eval "$(/opt/homebrew/bin/brew shellenv)"`
- Intel: `eval "$(/usr/local/bin/brew shellenv)"`

### Default install behavior

The default Homebrew Bundle operation installs missing dependencies without upgrading every already-installed package. Use this for a predictable new-machine bootstrap:

```bash
./install.sh --all --yes --trust-brew-taps
```

The trust switch is explicit because the current Brewfile contains third-party taps. Review [`macos/Brewfile`](../macos/Brewfile) before approving them.

### Upgrade managed dependencies

```bash
./install.sh --all --yes --trust-brew-taps --brew-upgrade
```

This permits Homebrew Bundle to upgrade dependencies tracked by the manifest.

### Per-machine exclusions

Homebrew Bundle supports environment variables for skipping selected entries without editing the shared file:

- `HOMEBREW_BUNDLE_BREW_SKIP`
- `HOMEBREW_BUNDLE_CASK_SKIP`
- `HOMEBREW_BUNDLE_MAS_SKIP`
- `HOMEBREW_BUNDLE_TAP_SKIP`

Keep personal applications, beta builds, machine-specific SDKs, and software with a reliable built-in updater outside the public baseline unless they have a clear cross-machine role.

Do not add an automatic `brew bundle cleanup` step to the installer. Cleanup removes packages that are absent from the Brewfile, including intentionally unmanaged software.

## macOS defaults

[`macos/defaults.sh`](../macos/defaults.sh) manages a compact shared baseline. It currently covers:

- dark interface style
- key-repeat behavior instead of press-and-hold accents
- visible file extensions
- spring-loaded folders
- natural scrolling
- Finder path/status bars and list view
- external, mounted, and removable volumes on the desktop
- Dock size, magnification, recent apps, and autohide behavior
- tap-to-click and Force Click preferences
- PNG screenshots stored under `~/Pictures/Screenshots`

Preview the exact commands independently:

```bash
./macos/defaults.sh --dry-run --restart
```

Apply them and restart the affected UI processes:

```bash
./macos/defaults.sh --restart
```

Review the source before applying it to an established Mac. macOS does not provide a universal automatic rollback for arbitrary `defaults write` operations.

## Saved Dock layout

[`macos/dock.sh`](../macos/dock.sh) uses `dockutil` to replace the existing Dock contents with the saved application/folder layout. Missing applications are skipped, but the current Dock is still cleared first.

Preview the operation:

```bash
./macos/dock.sh --dry-run --restart
```

Apply it only after reviewing the tracked app list:

```bash
./macos/dock.sh --restart
```

This operation is intentionally separate and destructive with respect to the existing Dock arrangement.

## Local configuration

### Private aliases

Create `~/.private_aliases` for aliases that should not be committed:

```bash
touch ~/.private_aliases
```

The shared aliases file loads it automatically when present.

### Homebrew exclusions

Prefer the Homebrew Bundle skip variables for one-machine omissions rather than deleting shared manifest entries.

### Git identity

The installer manages behavior defaults but does not invent a personal identity. Configure it separately when needed:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## Updating and uninstalling

Update the repository:

```bash
git -C ~/.dotfiles pull --ff-only
cd ~/.dotfiles
```

Preview and apply configuration reconciliation without package installation:

```bash
./install.sh --dry-run --sync
./install.sh --sync
```

Run the normal or full installer when the Brewfile or optional components changed:

```bash
./install.sh
```

The conservative uninstall path is:

```bash
./install.sh --dry-run --uninstall
./install.sh --uninstall
```

It removes managed symlinks and shell-startup additions, restores Git values that have not been changed since installation, and reverts Homebrew bootstrap entries added by the installer. It does not uninstall Homebrew packages, reverse every macOS default, or reconstruct a previous Dock layout.

## Bootstrap security

The canonical remote-bootstrap classification is in [`lib/bootstrap-policy.sh`](../lib/bootstrap-policy.sh). Print it with:

```bash
DOTFILES_TEST_FUNCTION=bootstrap-policy ./install.sh
```

Moving upstream installers are not treated as immutable artifacts. Optional SHA-256 environment variables can pin reviewed downloads before execution, including:

- `DOTFILES_HOMEBREW_INSTALL_SHA256`
- `DOTFILES_OHMYPOSH_INSTALL_SHA256`
- `DOTFILES_UV_INSTALL_SHA256`
- `DOTFILES_NVM_INSTALL_SHA256`
- `DOTFILES_SWIFTLY_INSTALL_SHA256`

These values are opt-in because upstream moving install URLs do not expose one permanent digest. Review the corresponding upstream release/install page before bootstrapping a new machine.

The NVM release defaults to the pinned `v0.40.4`. Override it only with another reviewed semantic version:

```bash
DOTFILES_NVM_VERSION=v0.40.4 ./install.sh
```

## Refreshing the application inventory

The companion [`alsd4git/list-macOS-apps`](https://github.com/alsd4git/list-macOS-apps) repository can create an inventory snapshot without changing this repository.

With both repositories cloned as siblings:

```bash
mkdir -p /tmp/macos-inventory
../list-macOS-apps/list-installed-apps.sh \
  --with-formulae \
  --export-json \
  --output-dir /tmp/macos-inventory
```

Use the result as review input for [`macos/Brewfile`](../macos/Brewfile), not as a file to copy wholesale. Promote only stable items with a clear shared purpose.

## Troubleshooting

### Homebrew is not on `PATH`

Open a new shell, or initialize it manually for the active session:

```bash
# Apple Silicon
eval "$(/opt/homebrew/bin/brew shellenv)"

# Intel
eval "$(/usr/local/bin/brew shellenv)"
```

Then verify:

```bash
brew --version
```

### Xcode developer tools are missing

The Command Line Tools provide Git for the bootstrap, but the current optional macOS package path checks both `xcode-select -p` and `xcodebuild -version`. Install full Xcode, select its developer directory, and retry:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Use `./install.sh --skip-tools` when only the managed dotfiles and Git defaults are required.

### A third-party tap is rejected

Review the `tap` declarations in [`macos/Brewfile`](../macos/Brewfile), then rerun with explicit trust:

```bash
./install.sh --all --yes --trust-brew-taps
```

Do not add the trust switch blindly to a machine-wide automation before reviewing new tap changes.

### Three-finger drag did not apply

Set it manually in:

```text
System Settings > Accessibility > Pointer Control > Trackpad Options
```

Enable **Use trackpad for dragging**. macOS does not persist this preference reliably through the same `defaults` interfaces used for the rest of the baseline.

### Advisory-only system checks

The installer may report that Stats still has a quarantine attribute or that Touch ID for `sudo` is not enabled. It does not remove quarantine attributes or edit PAM configuration automatically. Verify the application source and current macOS guidance before making either system-level change manually.

### The prompt or optional tools are missing

Open a new interactive shell and verify the installed commands:

```bash
command -v brew fzf zoxide oh-my-posh
```

Prompt initialization is intentionally skipped for non-interactive shells.

## Verification

Open a new Bash or Zsh session and run:

```bash
command -v git nano fzf zoxide uv swiftly gh
git config --global --get core.excludesfile
./scripts/health-check.sh --strict
./scripts/tool-health-check.sh
```

Preview the standalone macOS scripts:

```bash
./macos/defaults.sh --dry-run --restart
./macos/dock.sh --dry-run --restart
```

GitHub Actions checks the shared shell sources and runs these macOS dry-runs on a macOS runner.
