# dotfiles

My personal dotfiles collection, designed for consistency across macOS and Debian/Ubuntu systems using Bash or Zsh, with a separate Windows PowerShell preview path.

The Unix installer requires Bash 3.2 or newer. CI exercises the macOS-compatible Bash 3.2 baseline as well as current Bash and Zsh on Ubuntu 24.04.

## License

MIT. See [LICENSE](LICENSE).

---

## ✨ Features

* 🧼 **Clean Structure:** Configuration logically separated into `general/`, `git/`, and `nano/` directories.
* ✅ **Shell Compatibility:** Works seamlessly with both Bash and Zsh.
* 🚀 **Intelligent Installer (`install.sh`):**
  * Symlinks configurations into your `$HOME` directory (default).
  * Automatically backs up existing conflicting files (`.bak.<timestamp>`).
  * Supports copy mode (`--copy`) instead of symlinking.
  * Offers minimal setup (`--minimal`) for core files only.
  * Provides dry-run (`--dry-run`) to preview changes.
  * Separates component selection (`--all`) from non-interactive confirmation (`--yes`).
  * Optional backup cleanup (`--clean-backups`).

* 🛠️ **Optional Tool Installation:** Installs useful tools via a macOS Brewfile or apt (Debian/Ubuntu):
  * `fzf` (Fuzzy finder) + keybindings/completions
  * `eza` (Modern `ls` replacement)
  * `zoxide` (Smarter `cd`) with shell init
  * `bat` (Syntax-highlighting `cat`) with `batcat` shim on Ubuntu
  * `fd` (Fast `find`) with `fdfind` shim on Ubuntu
  * `ripgrep` (`rg`, fast grep)
  * `jq` (Lightweight JSON processor)
  * `delta` (Enhanced Git pager/diff viewer)
  * `gh` (GitHub CLI)
  * `oh-my-posh` (Customizable prompt)
  * `exiv2` (Needed for `ren_pics` function)
  * `fastfetch` (System info display - preferred)
  * `nano` (Ensures a consistent editor is available)
  * `shellcheck` (Shell script static analysis)
  * `shfmt` (Shell script formatter)
  * `uv` (Python tooling manager; can optionally install CPython 3.13 under `~/.local`)
  * `swiftly` (Swift toolchain manager; installed but does not install a Swift toolchain)
  * macOS also applies a small recommended `defaults` baseline for typing, Finder, Dock, and screenshots, plus an optional saved Dock layout
* 🪄 **Enhanced Shell Experience:**
  * Sensible command history settings with cross-session sharing.
  * `oh-my-posh` integration for an informative prompt (interactive shells only).
  * Helpful aliases and functions for common tasks.
  * Discover aliases quickly: run `aa` to print a readable alias list (`nice_print_aliases`).
* ⚙️ **Git Enhancements:** Useful Git aliases, functions (like `fzf` branch switching), and recommended global settings for branch/tag sorting, safer rebases, richer diffs, push/fetch hygiene, and `core.excludesfile`.
  * Examples: `gl` (pull current branch with rebase/autostash), `gp` (push current branch), `gsu` (set upstream), `gla`/`glaf` (last commit summary/full), `lg`/`lgr` (commits missing on origin/release).
* 🔒 **Private Aliases:** Supports loading personal, untracked aliases from `~/.private_aliases`.
* 🪟 **Windows Preview:** `install.ps1` bootstraps a small PowerShell profile plus `winget`-based Windows manifests, separately from the Bash/Zsh path.

---

## 📁 Directory Structure

```sh
.
├── archive/       # Historical installers, not used by the supported workflow
├── general/       # Shared shell config (aliases, functions, history, prompt)
├── git/           # Git-specific aliases, functions, and global ignore
├── lib/           # Sourced installer modules (CLI, bootstrap policy, reporting)
├── macos/         # macOS Brewfile and system defaults
│   ├── Brewfile
│   ├── dock.sh
│   └── defaults.sh
├── nano/          # Nano text editor configuration
├── scripts/       # Installer health checks and tool manifest
│   ├── health-check.sh
│   ├── tool-health-check.sh
│   └── tool-health.json
├── tests/         # Isolated installer behavior tests with command stubs
│   ├── test-installer-functions.sh
│   ├── docker-ubuntu-smoke.sh
│   └── windows-smoke.ps1
├── windows/       # Minimal PowerShell profile for Windows
│   ├── Dotfiles.WindowsPackages.psm1
│   ├── packages.optional.psd1
│   ├── packages.private.example.psd1
│   ├── packages.psd1
│   ├── terminal/
│   │   └── settings.json
│   ├── profile.local.example.ps1
│   └── profile.ps1
├── install.sh     # Recommended installation script
├── install.ps1    # Windows/PowerShell installer preview
└── README.md      # This file
```

---

## 🚀 Setup Instructions

1. **Clone the repository** (Recommended location: `~/.dotfiles`):

    ```bash
    git clone https://github.com/alsd4git/dotfiles ~/.dotfiles
    ```

2. **Navigate into the directory:**

    ```bash
    cd ~/.dotfiles
    ```

3. **Make the installer executable:**

    ```bash
    chmod +x install.sh
    ```

4. **Run the installer:**

    ```bash
    ./install.sh
    ```

    * The script guides you through optional tools and platform settings. Use `--all --yes` for the full non-interactive selection.

**Installer Options:**

* `./install.sh --help` or `-h`: Show help message.
* `./install.sh --dry-run` or `-dr`: Show what would be done without making changes (no file writes, no deletions, no global Git config changes).
* `./install.sh --copy` or `-c`: Copy files instead of creating symlinks (backs up existing files).
* `./install.sh --yes` or `-y`: Answer yes to prompts for the operations selected by the invocation.
* `./install.sh --all` or `-a`: Select all optional components.
* `./install.sh --force` or `-f`: Deprecated compatibility alias for `--all --yes`. Backup cleanup remains opt-in.
* `./install.sh --minimal` or `-m`: Install only core dotfiles, skip optional tools and Git config.
* `./install.sh --skip-tools`: Skip optional package managers and tool installation while keeping the normal dotfile and Git setup.
* `./install.sh --sync`: Reconcile dotfiles, shell setup, and Git defaults without installing tools or adding optional startup commands.
* `./install.sh --trust-brew-taps`: On macOS, explicitly trust every third-party tap declared in `macos/Brewfile` before installing packages.
* `./install.sh --brew-upgrade`: On macOS, upgrade the packages tracked by `macos/Brewfile`; the default bootstrap only installs missing packages.
* `./install.sh --uninstall`: Remove symlinks, restore untouched Git defaults captured on first install, and revert shell rc additions this installer made, including Homebrew bootstrap entries on macOS (runs uninstall flow only, then exits).
* `./install.sh --clean-backups` or `-cb`: Offer to remove `.bak.*` files recorded as created by this installer (or preview removals in dry-run mode). Backups from other programs are never selected.

---

## 🪟 Windows Preview

The Windows path is intentionally smaller and currently focuses on PowerShell profile setup plus package manager bootstrap.

### Refreshing the macOS inventory

The companion `list-macOS-apps` tool can produce a current snapshot without changing this repository:

```bash
mkdir -p /tmp/macos-inventory
../list-macOS-apps/list-installed-apps.sh \
  --with-formulae \
  --export-json \
  --output-dir /tmp/macos-inventory
```

Use the snapshot to review `macos/Brewfile`, but promote only stable, cross-machine tools. Manual applications, beta builds, browsers, personal services, and machine-specific SDKs should remain outside the public manifest unless they have an explicit baseline role.

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install.ps1
```

Use `.\install.ps1 -Sync` to reconcile profiles and Git defaults without installing packages. Use `.\install.ps1 -RestoreGitDefaults` to restore the Git values saved before the first install; settings changed after installation are preserved.

The Windows installer backs up any conflicting profile or Git ignore file as `.bak.<timestamp>` before copying the shared version into place, and it also creates the optional local overlay directory used by the public profile loader.

It also applies the same recommended global Git defaults as the Bash/Zsh installer path, so Git behavior stays consistent across machines.

There is also a tracked example at `windows/profile.local.example.ps1` you can copy or adapt for local-only tweaks.

The installer copies the curated Windows package baseline into `~\.config\dotfiles\windows\packages.psd1` and the optional extras into `~\.config\dotfiles\windows\packages.optional.psd1`, so the shared manifests stay available even after the repo is moved or not mounted.

Winget manifest normalization, manifest discovery, and installed-package detection live in `windows/Dotfiles.WindowsPackages.psm1`; the installer and copied profile both use that module to keep package state interpretation consistent.

There is also a tracked template at `windows/packages.private.example.psd1` that can be copied to `~\.config\dotfiles\windows\packages.private.psd1` for local-only package entries.

If you want to remove old Windows backup files later, run `.\install.ps1 -CleanBackups` and confirm the prompt, or add `-Force` to skip the confirmation.

The Windows bootstrap assumes `winget` is already available through App Installer.

The Windows profile also exposes `a` to inspect commands, `aa` to print aliases, plus update helpers like `npmupg` and `wingup`.

The installer does not reload the active PowerShell session in place, which keeps the current prompt stable. Open a new PowerShell window after installation, or run `rld` manually if you want to re-source the profile.

There are curated public manifests in `windows/packages.psd1` and `windows/packages.optional.psd1` that track the starter baseline by package manager:

- `winget` for core shell/runtime apps and Store-backed desktop apps
- `Bitwarden`, `Chrome`, `Quick Share`, `Telegram`, `Android Studio`, `Keyguard`, `RustDesk`, `Tailscale`, `Zen Browser`, `UniGetUI`, and the rest of the desktop apps you asked for live in the optional extras manifest
- Cross-platform CLI tools that are equally useful on Windows now include `shellcheck`, `shfmt`, `yq`, `ast-grep`, `actionlint`, `pandoc`, `ffmpeg`, and `ExifTool`
- `NpmGlobal` remains intentionally empty so we do not encode machine-specific or personal globals into the repo
- If a future app only exists through Microsoft Store, the Windows manifest already supports `Source = 'msstore'` on a Winget entry; for now we only use that when it is genuinely needed.

The Windows prompt uses the upstream `tokyo.omp.json` shipped with the `JanDeDobbeleer.OhMyPosh` package, the minimal Windows Terminal settings live in `windows/terminal/settings.json`, and `JetBrainsMono Nerd Font` is part of the core `winget` baseline. The live prompt resolves the installed `oh-my-posh` theme folder once, preferring the AppX install location when available, and caches it under `AppData\Local` so the profile stays simple while still adapting to the installed path.

The installer prints a summary of the manifests, shows a short alias cheat sheet, and can install only the missing items after an explicit confirmation, so you can rerun the bootstrap as many times as needed without duplicating work. Use `-y` if you want to answer yes to all installer prompts without typing each confirmation.

Winget does not guarantee a Start Menu shortcut for every desktop package. To create the curated shortcuts for GUI packages that are installed without one, run `.\windows\start-menu-shortcuts.ps1`; use `-Repair` after a Winget upgrade if a package moved its executable.

For machine-specific PowerShell tweaks, keep them outside the repo in one of these optional local overlays:

- `~\.private_profile.ps1` for one-off overrides
- `~\.config\dotfiles\windows\profile.d\*.ps1` for ordered local fragments

The public profile loads those overlays last, so they can override the shared defaults without forcing personal details into the repo.

---

## 🧠 What `install.sh` Does

* **Detects OS and Shell:** Determines if you're on macOS or Debian/Ubuntu Linux, and using Bash or Zsh.
* **Creates Symlinks (Default):** For each configuration file (e.g., `general/.aliases`), it creates a symlink in your home directory (e.g., `~/.shell_aliases`) pointing back to the file in the `~/.dotfiles` repository.
  * If a file or symlink already exists at the destination, it's backed up as `~/<filename>.bak.<timestamp>`.
* **Updates RC Files:** Adds lines to your `~/.bashrc` or `~/.zshrc` (creating them if they don't exist) to source the new alias, function, history, and prompt files. It checks if lines already exist to avoid duplicates.
* **Configures Global Git Ignore:**
  * Symlinks `git/global.gitignore` to `$HOME/.global.gitignore`.
  * Runs `git config --global core.excludesfile "$HOME/.global.gitignore"` to tell Git to use this file.
* **Sets Git Defaults:** Merges the shared [`git/defaults.conf`](git/defaults.conf) baseline into the existing user config without replacing the machine's `.gitconfig`. It covers branch/tag sorting, rebase ergonomics, verbose commits, smarter diffs, push/fetch hygiene, `core.editor = nano`, and `init.defaultBranch = main`.
  * The first install saves the previous values for these keys under `~/.config/dotfiles/installer-state`. `--uninstall` restores them unless a setting was changed after installation, in which case it leaves the newer value untouched.
  * When optional tools are approved and `delta` is available, the installer offers an explicit opt-in for `core.pager`, interactive diff filtering, navigation, dark theme, side-by-side output, and line numbers. Automatic, minimal, sync, and dry-run modes never enable it implicitly.
* **Installs Optional Tools (if confirmed or selected with `--all`):** Uses `brew` (macOS) or `apt` (Debian/Ubuntu) to install tools listed in the Features section.
  * If Homebrew is missing on macOS, the installer bootstraps it and sets up shell env automatically (adds `eval "$(/opt/homebrew/bin/brew shellenv)"` or `eval "$(/usr/local/bin/brew shellenv)"` depending on install path).
  * On macOS, the tool manifest lives in `macos/Brewfile`, the baseline defaults live in `macos/defaults.sh`, and the saved Dock layout lives in `macos/dock.sh`.
  * On Ubuntu/Debian, the `bat` binary may be named `batcat`, and `fd` as `fdfind`. The installer creates shims (`/usr/local/bin/bat` and `/usr/local/bin/fd`) for a consistent experience.
  * For Python/Swift tooling, the managers are installed (`uv`, `swiftly`), and the script can optionally install CPython 3.13 via `uv` or the latest stable Swift toolchain via `swiftly`.
  * Ensures `~/.local/bin` is on `PATH` (if the directory exists) so user-installed tools like `uv` and `swiftly` are available.
  * On Linux, `swiftly` is installed from the official Swift.org tarball flow and initialized with `--skip-install` to avoid installing a Swift toolchain by default.
  * On Linux, `swiftly` requires `gpg` for signature verification; the installer ensures `gnupg` is installed.
  * On macOS, `brew bundle install` runs with `--no-upgrade` by default. Use `--brew-upgrade` to update managed dependencies, or Homebrew's `HOMEBREW_BUNDLE_BREW_SKIP`, `HOMEBREW_BUNDLE_CASK_SKIP`, `HOMEBREW_BUNDLE_MAS_SKIP`, and `HOMEBREW_BUNDLE_TAP_SKIP` environment variables for per-machine exclusions.
  * Fresh Homebrew installations that enforce tap trust need `--trust-brew-taps` when the Brewfile contains third-party taps. The flag is deliberately explicit because it grants those taps permission to run their formulae and casks.
  * Linux installs follow [eza's official Debian/Ubuntu instructions](https://github.com/eza-community/eza/blob/main/INSTALL.md): the upstream `deb.asc` key is stored in a dedicated `signed-by` keyring and the documented `http://deb.gierens.de` repository URL is preserved. Package integrity is enforced by APT signatures; the installer does not download an unverified `latest` release `.deb`.
  * Bootstrap policy is canonical in `lib/bootstrap-policy.sh`. Run `DOTFILES_TEST_FUNCTION=bootstrap-policy ./install.sh` to print the current inventory. `nvm` is pinned by default to `v0.40.4`; moving official channels are explicitly labeled `trusted-upstream-dynamic`.
  * Optional bootstrap verification: `run_remote_script` accepts `--sha256`; provide `DOTFILES_HOMEBREW_INSTALL_SHA256`, `DOTFILES_OHMYPOSH_INSTALL_SHA256`, `DOTFILES_UV_INSTALL_SHA256`, or `DOTFILES_NVM_INSTALL_SHA256` to verify the downloaded installer before execution. `DOTFILES_SWIFTLY_INSTALL_SHA256` verifies the Swiftly archive, and `DOTFILES_EZA_KEY_SHA256` verifies the eza repository key, before use. These values are intentionally opt-in because the corresponding upstream channels are dynamic and do not publish one stable digest for the moving bootstrap URL.
  * Supply-chain exceptions: eza follows the upstream signed APT repository flow (the repository key is fetched from the official eza source), while Homebrew, Oh My Posh, uv, Swiftly, and the pinned nvm installer remain upstream-controlled channels unless an operator supplies a digest. Prefer reviewing those upstream release/install pages before a new-machine bootstrap.
* **macOS Defaults:** On macOS, the installer can apply a small `defaults` baseline for typing, Finder, Dock, and screenshots.
* **macOS Dock Layout:** The installer can also restore the saved Dock apps/folders from `macos/dock.sh` using `dockutil`.
* **Checks for Dependencies:** Verifies if essential commands used by aliases/functions (like `docker`, `swift`, `git`, `nano`) are present and warns if not.
* **Configures Startup Commands (Optional):** Asks if you want `nice_print_aliases` and `fastfetch` (or `screenfetch` as a fallback) to run when a new shell starts. These run only in interactive shells.
* **fzf & zoxide Initialization:** If installed, `zoxide` is initialized for your shell; `fzf` keybindings/completions are sourced when available.
* **Swiftly Env:** On Linux, the installer adds a line to your shell rc to source `~/.local/share/swiftly/env.sh` (if present) so `swiftly` and installed toolchains are on `PATH`.
* **PATH Cleanup:** The installer appends a snippet to remove duplicate entries from `PATH` while preserving order. During upgrades it also removes the legacy de-duplication lines from older installer versions before adding the current implementation.
* **Optional Node Tooling:** Offers to install or update `nvm` (Node Version Manager) to the pinned `v0.40.4` release. Set `DOTFILES_NVM_VERSION` explicitly when you want a different reviewed release. If installed, your shell will source `~/.nvm/nvm.sh` automatically.
  * nvm commands run through a narrow compatibility wrapper that temporarily disables Bash `nounset` while nvm executes, because nvm's internal functions can read an unset local variable under `set -u`. The installer restores strict mode immediately after each call.
  * If no Node is active via `nvm`, you can install the latest LTS and set it as default.
  * If a Node version is already active via `nvm`, the installer offers to switch to the latest LTS and set it as default. After a successful switch it asks whether to migrate global npm packages with `nvm reinstall-packages <previous_version>` ([official nvm guidance](https://github.com/nvm-sh/nvm#copying-global-packages-from-previously-installed-version)); declining leaves the old environment untouched. Automatic modes never migrate packages implicitly and print the command for later use.
  * If `corepack` is available, it is enabled after installing/switching to LTS to provide Yarn/PNPM shims.
* **Optional Python Tooling:** Installs `uv` (Python tool and package manager). Optionally offers to install CPython 3.13 managed by `uv` with `python`/`python3` defaults (does not change your system `python`).
* **Optional Swift Tooling:** Installs `swiftly` (Swift toolchain manager). Optionally offers to install the latest stable Swift toolchain via `swiftly`.
* **GitHub CLI Authentication:** After optional tools are approved, if `gh` is installed and not authenticated, the installer offers an interactive [`gh auth login`](https://cli.github.com/manual/gh_auth_login). It never starts authentication in automatic, minimal, sync, dry-run, or non-interactive runs. After a successful login it prints optional commands for [`gh auth setup-git`](https://cli.github.com/manual/gh_auth_setup-git) and SSH/GPG signing-key setup.

Run `./scripts/health-check.sh --strict` after a standard installation to verify the managed shell files and global Git ignore configuration.

For an isolated Linux lifecycle check, run `./tests/docker-ubuntu-smoke.sh`. It uses `ubuntu:24.04`, mounts the repository read-only, and validates install, shell loading, health checks, and uninstall for Bash and Zsh in disposable homes.

The main workflow is organized into named platform-tools, Git, and NVM phases. Required, optional, and advisory operations use the shared reporting policy so failures remain visible in the final summary.

Run `./scripts/tool-health-check.sh` to inspect the availability and reported versions of the curated Git, JSON, editor, GitHub, Python, and Swift tools. The check reports Swiftly separately when its binary is present but its user configuration is not initialized. Add `--strict` when missing optional tools or failed version commands should fail the check.

---

## 💬 Notes

* **Legacy Installer:** `archive/old_setup.sh` is retained only for historical reference. It is not part of the supported installation workflow.
* **Zsh Default:** If you use Zsh, ensure it's set as your default login shell: `chsh -s $(which zsh)`
* **Private Aliases:** You can create a `~/.private_aliases` file to store personal aliases you don't want to commit to Git. The main alias file (`general/.aliases`) will automatically source it if it exists.
* **Backups:** Old configuration files backed up by the script will have names like `~/.bashrc.bak.1678886400`. The installer records these paths in its state directory; `./install.sh --clean-backups` only considers that manifest, so backups from other programs are left untouched.
* **System Info:** The script can run `fastfetch` on startup if available. If `fastfetch` is not found, it falls back to trying `screenfetch`. Note that the installer only attempts to install `fastfetch`, not `screenfetch`.

---

## ⚠️ Supported Platforms

* macOS (via Homebrew Bundle)
* Debian/Ubuntu (via apt)

Other Linux distributions are not covered by the installer. You can adapt the scripts or install tools manually on those platforms.

---

## 🧩 Platform Matrix

| Platform | Package manager | What the installer does |
| --- | --- | --- |
| macOS | Homebrew Bundle | Bootstraps Homebrew if missing, installs the manifest in `macos/Brewfile`, applies the recommended defaults in `macos/defaults.sh`, restores the Dock layout in `macos/dock.sh`, and updates shell startup files for `brew`, `fzf`, `zoxide`, `nvm`, and `swiftly` when relevant. |
| Debian/Ubuntu | apt | Installs core packages, configures `gh` from the official repository, creates `bat`/`fd` shims when needed, and installs `swiftly` from the official tarball flow. |
| Windows | winget | Installs the PowerShell profile and uses winget for the public baseline. |

---

## 🔎 Troubleshooting

* **Homebrew not on `PATH`:** Open a new shell or run `eval "$(/opt/homebrew/bin/brew shellenv)"` on Apple Silicon, or `eval "$(/usr/local/bin/brew shellenv)"` on Intel Macs.
* **No Rosetta bootstrap:** The macOS bootstrap is intended for native Apple Silicon. Intel-only software is left to manual installation or a separate, explicit bootstrap path.
* **`nvm` does not load:** Restart the shell or source `~/.bashrc` / `~/.zshrc`; if you need a one-off recovery, run `export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"; nvm use --lts`.
* **`swiftly` is missing on Linux:** Make sure `~/.local/share/swiftly/env.sh` exists and that `gnupg` is installed, because signature verification depends on `gpg`; a manual recovery is `test -f "$HOME/.local/share/swiftly/env.sh" && . "$HOME/.local/share/swiftly/env.sh" && swiftly install stable`.
* **Xcode developer tools are missing on macOS:** The installer now checks `xcode-select -p` and `xcodebuild -version` before running the macOS package/bootstrap path. If either check fails, install Xcode from the App Store or run `xcode-select --install` and retry.
* **Three-finger drag is not taking effect:** Set it manually in `System Settings > Accessibility > Pointer Control > Trackpad Options` and enable `Use trackpad for dragging`. macOS may not persist that toggle reliably through `defaults`.
* **`fzf` bindings are missing:** Rerun the installer with `--all` or source the `fzf` keybindings and completion files manually from your shell rc.
* **`bat` and `fd` look unfamiliar on Ubuntu:** `batcat` and `fdfind` are the packaged binary names; the installer creates `bat` and `fd` shims when it can write to `/usr/local/bin`.
* **Prompt customization is not visible:** `oh-my-posh` only loads in interactive shells, so non-interactive sessions will not show the prompt theme.
* **`winget` is missing on Windows:** Install App Installer from Microsoft and retry the bootstrap.
* **Touch ID for `sudo`:** On macOS, the installer can only check whether Touch ID is already enabled for `sudo` and print a manual recovery hint if it is missing. The file to edit is `/etc/pam.d/sudo`, and the line to add is `auth       sufficient     pam_tid.so`.
* **Stats.app is blocked by Gatekeeper:** If Stats is installed via Homebrew but still refuses to open, run `sudo xattr -r -d com.apple.quarantine /Applications/Stats.app/`.
* **Inventory sync:** The companion `list-macOS-apps` repo can help snapshot installed Mac apps before you expand or prune `macos/Brewfile`.
* **Warp on macOS:** Keep Warp outside `macos/Brewfile` and install/update it manually, because its built-in updater is less conflict-prone than managing the app through Homebrew.
* **Homebrew ownership:** `brewup` updates formulae and standard casks. Use `brewupall` only when you intentionally want to include `:latest` and self-updating casks. Do not add `brew bundle cleanup` to the installer: it removes packages that are not in the Brewfile.
* **Windows package baseline:** The public starter inventory lives in `windows/packages.psd1` and `windows/packages.optional.psd1`; treat them as curated baselines, not a dump of every installed Windows app.
* **Windows package sources:** Use `winget` for GUI apps and for the CLI tools that are available there. Store-only apps that do not resolve reliably in `winget` should stay manual instead of making the bootstrap more fragile; `PC Manager` is one of those edge cases on some machines.
* **Windows prompt assets:** the prompt uses the upstream `tokyo.omp.json` shipped with the `JanDeDobbeleer.OhMyPosh` package, `windows/terminal/settings.json` captures the minimal Terminal defaults, and `JetBrainsMono Nerd Font` is bootstrapped through the core `winget` manifest. The live profile points to the installed theme path, prefers the AppX install location when present, and caches the resolved folder under `AppData\Local` so the prompt stays straightforward.
* **Windows Terminal cleanup:** The template intentionally leaves out machine-specific SSH and one-off profiles; keep those in a local overlay if you still want them.
* **Windows reruns are safe:** `install.ps1` only installs missing packages after you confirm the prompt.
* **Prompt refresh:** If the shell prompt looks stale after a run, use `rld` to re-source the profile and refresh `oh-my-posh`.

---

## 📚 Sources and Inspiration

* Git defaults: [How Core Git Developers Configure Git](https://blog.gitbutler.com/how-git-core-devs-configure-git) by Scott Chacon. The installer adopts the broadly useful settings from the article, while leaving personal conflict-resolution memory (`rerere`), repository-size-specific options such as `core.fsmonitor` and `core.untrackedCache`, plus version-sensitive conflict marker defaults such as `merge.conflictStyle = zdiff3`, out of the global baseline.

---

## ✅ Verification

After installation, a quick smoke check is:

```bash
command -v git nano fzf zoxide uv swiftly gh
git config --global --get core.excludesfile
./scripts/tool-health-check.sh
```

If you use Zsh, open a new interactive shell and confirm that `aa`, `l`, `gl`, and `myip` are available.

---

## 🧭 Cheatsheet

* Shell basics:
  * `a` / `aa`: Inspect a command or print aliases.
  * `l`/`lt`/`ll`: Directory listings (use `eza` if installed, otherwise `ls`).
  * `mntlist`: Show mounted volumes (portable, does not shadow `mount`).
  * `myip`: Show public IP.
  * `rld`: Reload the current PowerShell profile.
  * `brewup`: Update, upgrade and clean Homebrew (macOS).

* Packages and repos:
  * `npmupg`: Update all globally installed npm packages (respecting semver ranges).
  * `rpx`: Run RepoMix and output `<folder>-repomix.md`, ignoring `*.html`.

* Docker helpers:
  * `up_dockers`: Pull latest tags for all local image repositories.
  * `up_dockers_wt`: One-shot updates via Watchtower (`--run-once --cleanup`).
  * `up_portainer_ce` / `up_portainer_be`: Recreate Portainer CE/BE containers with volumes/ports.

* Git aliases (highlights):
  * `gl` / `gp`: Pull (rebase+autostash) / push current branch.
  * `gsu`: Set upstream to `origin/<current-branch>`.
  * `gla` / `glaf`: Show last commit summary / full diff.
  * `gd` / `gds`: Diff vs. HEAD / diff stats.
  * `gcb` / `gca` / `gcd`: New branch / amend / amend with now timestamp.
  * `lg`: Commits on local branch not on `origin/<branch>`.
  * `lgr`: Commits on current branch not in `origin/release`.

* Git fzf functions:
  * `fuzzy_branch_selector`: Select a branch (includes remotes); uses `git switch` with tracking.
  * `fuzzy_log_viewer`: Fuzzy-find commits with preview (`git show`).
  * `git_see_authors`: Shortlog authors summary.
