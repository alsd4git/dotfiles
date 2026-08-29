# Debian and Ubuntu setup

[Back to the main README](../README.md)

The Linux installer supports Debian and Ubuntu with Bash or Zsh. It manages shared dotfiles and Git defaults, installs a curated package baseline through APT, and can bootstrap selected cross-platform development tools.

## Contents

- [Supported systems and requirements](#supported-systems-and-requirements)
- [Fresh installation](#fresh-installation)
- [What the installer changes](#what-the-installer-changes)
- [Installer modes](#installer-modes)
- [Packages and optional toolchains](#packages-and-optional-toolchains)
- [Local configuration](#local-configuration)
- [Updating and uninstalling](#updating-and-uninstalling)
- [Bootstrap security](#bootstrap-security)
- [Troubleshooting](#troubleshooting)
- [Verification and lifecycle tests](#verification-and-lifecycle-tests)

## Supported systems and requirements

Supported package-manager path:

- Debian
- Ubuntu

The installer expects:

- Bash 3.2 or newer for the installer itself
- Bash or Zsh as the configured interactive shell
- APT
- `sudo` for package installation performed by the current installer
- Internet access for packages and approved optional bootstrap operations

Other Linux distributions are not supported by the package and platform logic. The shell files can be adapted manually, but do not run the APT path unchanged on another distribution.

## Fresh installation

### 1. Install Git

Git is required before the repository can be cloned:

```bash
sudo apt update
sudo apt install -y git
```

Run the commands as `root` instead when `sudo` is not installed.

### 2. Clone the repository

```bash
git clone https://github.com/alsd4git/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

The executable bit for `install.sh` is tracked by Git, so a normal clone does not require `chmod +x`.

### 3. Preview the installer

```bash
./install.sh --dry-run
```

The dry-run previews managed file and Git operations. The package/tool phase is skipped rather than simulated, so review [`lib/tool-manifest.sh`](../lib/tool-manifest.sh) and the bootstrap policy before a full installation.

### 4. Run the installer

```bash
./install.sh
```

The default run configures the shared files and asks before optional package/tool operations.

## What the installer changes

### Managed dotfiles

By default, the installer creates symlinks from the home directory to the repository:

| Home path | Repository source |
| --- | --- |
| `~/.shell_aliases` | `general/.aliases` |
| `~/.shell_functions` | `general/.functions` |
| `~/.history_settings` | `general/.history_settings` |
| `~/.omp_init` | `general/.omp_init` |
| `~/.nanorc` | `nano/.nanorc` |
| `~/.git_aliases` | `git/.git_aliases` |
| `~/.git_functions` | `git/.git_functions` |
| `~/.global.gitignore` | `git/global.gitignore` |

Use `--copy` when symlinks back to the repository are not desirable.

### Shell startup files

The installer updates the active Bash or Zsh startup file so it loads the managed aliases, functions, history, prompt, `~/.local/bin`, and Swiftly environment when available. Additions are marker-aware and designed to avoid duplicates.

It also installs a PATH de-duplication snippet and removes the legacy implementation used by older versions of this repository.

### Git defaults

The keys in [`git/defaults.conf`](../git/defaults.conf) are merged into the user's global Git config. The installer does not replace the complete `.gitconfig`.

Before the first change, previous values are recorded under:

```text
~/.config/dotfiles/installer-state/
```

The global ignore is configured with:

```text
core.excludesfile = ~/.global.gitignore
```

When `delta` is available, its pager configuration remains an explicit opt-in; automatic, minimal, sync, and dry-run modes do not enable it implicitly.

### Backups

Conflicting files are moved to timestamped `.bak.<timestamp>` paths. Every backup created by the Unix installer is recorded, allowing cleanup to target only installer-owned backups.

## Installer modes

| Command | Behavior |
| --- | --- |
| `./install.sh` | Interactive managed dotfiles, Git defaults, packages, and optional tooling |
| `./install.sh --dry-run` | Preview managed file and Git operations; the package/tool phase is skipped |
| `./install.sh --minimal` | Install core dotfiles only; skip Git defaults, package installation, and remote fetches |
| `./install.sh --skip-tools` | Apply dotfiles and Git defaults without package-manager or optional-tool installation |
| `./install.sh --sync` | Reconcile dotfiles and Git defaults without tools or optional startup commands |
| `./install.sh --copy` | Copy files instead of symlinking them, backing up conflicts first |
| `./install.sh --all` | Select every optional component; review the package and bootstrap sources before using it |
| `./install.sh --yes` | Answer yes to prompts for operations already selected by the invocation |
| `./install.sh --all --yes` | Full non-interactive component selection |
| `./install.sh --clean-backups` | Offer to remove only paths recorded in the installer's backup manifest |
| `./install.sh --uninstall` | Remove managed links/startup entries and conservatively restore Git settings |

`--force` is a deprecated compatibility alias for `--all --yes`.

Mode restrictions are validated before installation. For example, `--sync` cannot be mixed with component-selection or cleanup switches, and `--uninstall` cannot be mixed with installation-only options.

## Packages and optional toolchains

The canonical Debian/Ubuntu package groups are in [`lib/tool-manifest.sh`](../lib/tool-manifest.sh).

### Required APT baseline

```text
curl exiv2 fzf gnupg jq nano ripgrep unzip
```

### Optional APT baseline

```text
bat delta fd-find fastfetch zoxide
```

Additional platform logic installs or configures selected tools through their appropriate upstream path, including GitHub CLI, eza, Oh My Posh, uv, Swiftly, and NVM.

### Consistent command names

Debian/Ubuntu package names can differ from the upstream command names:

- `bat` may be installed as `batcat`
- `fd` may be installed as `fdfind`

The installer creates `/usr/local/bin/bat` and `/usr/local/bin/fd` shims when it can write there, so aliases and scripts can use the cross-platform names.

### Python with uv

The installer can install `uv` and optionally install CPython 3.13 under the user environment. It does not replace the distribution's system Python.

Verify the managed runtime with:

```bash
uv python list
```

### Swift with Swiftly

On Linux, Swiftly is installed through the official archive/signature flow and initialized without installing a Swift toolchain by default. `gnupg` is required for verification.

The shell startup file loads this environment when present:

```text
~/.local/share/swiftly/env.sh
```

A stable Swift toolchain is a separate optional choice.

### Node.js with NVM

The installer can install or update NVM. The reviewed default version is:

```text
v0.40.4
```

Override it only with another reviewed semantic version:

```bash
DOTFILES_NVM_VERSION=v0.40.4 ./install.sh
```

When no NVM-managed Node version is active, the installer can install the latest LTS and set it as default. When moving from an existing version, migration of global npm packages remains an explicit prompt and is never performed automatically.

If available, Corepack is enabled after the selected Node LTS is active.

### GitHub CLI authentication

After optional tools are approved, an interactive run can offer `gh auth login` when GitHub CLI is installed but not authenticated.

Authentication is not started in automatic, minimal, sync, dry-run, or non-interactive flows.

## Local configuration

### Private aliases

Create an untracked `~/.private_aliases` file:

```bash
touch ~/.private_aliases
```

The shared alias configuration loads it automatically.

### Git identity

The installer configures shared behavior, not personal identity:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### Zsh as the login shell

When Zsh is installed but is not the login shell:

```bash
chsh -s "$(command -v zsh)"
```

Log out and back in before expecting every terminal to use it.

## Updating and uninstalling

Update the repository:

```bash
git -C ~/.dotfiles pull --ff-only
cd ~/.dotfiles
```

Preview and apply a configuration-only sync:

```bash
./install.sh --dry-run --sync
./install.sh --sync
```

Run the normal installer again when package groups or optional tool choices changed:

```bash
./install.sh
```

Preview and run the conservative uninstall:

```bash
./install.sh --dry-run --uninstall
./install.sh --uninstall
```

Uninstall removes managed symlinks and shell-startup lines recorded when the installer added them. It restores Git values that still match the installer's managed values. Installations made before the ownership record was introduced leave unrecorded startup lines untouched. It does not remove packages installed through APT or third-party tool managers.

Clean only backups recorded by this installer:

```bash
./install.sh --dry-run --clean-backups
./install.sh --clean-backups
```

Backups created by other applications are not selected.

## Bootstrap security

The canonical bootstrap classification is in [`lib/bootstrap-policy.sh`](../lib/bootstrap-policy.sh). Print it with:

```bash
DOTFILES_TEST_FUNCTION=bootstrap-policy ./install.sh
```

The eza path follows its signed Debian/Ubuntu repository flow. Other moving upstream installers remain upstream-controlled unless an operator supplies a reviewed digest.

Optional digest variables include:

- `DOTFILES_OHMYPOSH_INSTALL_SHA256`
- `DOTFILES_UV_INSTALL_SHA256`
- `DOTFILES_NVM_INSTALL_SHA256`
- `DOTFILES_SWIFTLY_INSTALL_SHA256`
- `DOTFILES_EZA_KEY_SHA256`

Use these when a reviewed artifact digest is available. Do not copy a digest from an unrelated version merely to satisfy the check.

## Troubleshooting

### `sudo` is not installed

The initial `apt install git` bootstrap can be run from a root shell, but the current package phase inside `install.sh` invokes `sudo` explicitly. Install/configure `sudo`, or use `--skip-tools` and manage packages separately. The dotfile operations themselves target the current user's home directory.

### `bat` or `fd` is missing

Check the distribution binary names:

```bash
command -v bat batcat fd fdfind
```

Rerun the installer after ensuring `/usr/local/bin` is writable for the shim creation, or define user-local aliases manually.

### `fzf` keybindings or completion are missing

Open a new interactive shell, then confirm the package is available:

```bash
command -v fzf
```

Rerun the installer with optional tools selected if it is missing:

```bash
./install.sh --all
```

### NVM does not load

Open a new shell or recover the active session manually:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use --lts
```

### Swiftly is installed but unavailable

Check and source its environment:

```bash
test -f "$HOME/.local/share/swiftly/env.sh" && . "$HOME/.local/share/swiftly/env.sh"
command -v swiftly
```

`gnupg` must be installed because the Linux Swiftly flow verifies signatures with `gpg`.

### The prompt is missing

Oh My Posh initialization runs only in interactive shells. Verify from a new terminal rather than a non-interactive CI shell:

```bash
command -v oh-my-posh
```

### Unsupported Linux distributions

Before entering the APT package phase, `install.sh` reads `/etc/os-release` and accepts only `ID=debian` or `ID=ubuntu`. Configuration-only modes and uninstall do not need this check. A dry-run remains available for previewing managed file operations, but it does not simulate package installation. Adapt the shared shell files manually or add a dedicated, tested platform module before using package installation.

## Verification and lifecycle tests

Open a new interactive shell and verify the managed configuration:

```bash
type rld npmupg
git config --global --get core.excludesfile
./scripts/health-check.sh --strict
./scripts/tool-health-check.sh
```

If you approved the optional tool phase, verify those commands separately:

```bash
command -v git nano fzf zoxide uv swiftly gh
```

Run the isolated installer function tests:

```bash
./tests/test-installer-functions.sh
```

Run the full disposable Ubuntu 24.04 Bash/Zsh lifecycle test when Docker is available:

```bash
./tests/docker-ubuntu-smoke.sh
```

The container test mounts the repository read-only and verifies install, interactive shell loading, health checks, and uninstall in isolated home directories.
