# dotfiles

My personal dotfiles collection, designed for consistency across macOS and Debian/Ubuntu systems using Bash or Zsh, with a separate Windows PowerShell preview path.

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
  * Includes force mode (`--force`) to skip prompts.
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
* ⚙️ **Git Enhancements:** Useful Git aliases, functions (like `fzf` branch switching), and recommended global settings (`pull.rebase`, `rebase.autostash`, `core.editor`, `core.excludesfile`).
  * Examples: `gl` (pull current branch with rebase/autostash), `gp` (push current branch), `gsu` (set upstream), `gla`/`glaf` (last commit summary/full), `lg`/`lgr` (commits missing on origin/release).
* 🔒 **Private Aliases:** Supports loading personal, untracked aliases from `~/.private_aliases`.
* 🪟 **Windows Preview:** `install.ps1` bootstraps a small PowerShell profile plus `winget`-based Windows manifests, separately from the Bash/Zsh path.

---

## 📁 Directory Structure

```sh
.
├── general/       # Shared shell config (aliases, functions, history, prompt)
├── git/           # Git-specific aliases, functions, and global ignore
├── macos/         # macOS Brewfile and system defaults
│   ├── Brewfile
│   ├── dock.sh
│   └── defaults.sh
├── nano/          # Nano text editor configuration
├── windows/       # Minimal PowerShell profile for Windows
│   ├── omp/
│   │   └── tokyo.omp.json
│   ├── packages.optional.psd1
│   ├── packages.private.example.psd1
│   ├── packages.psd1
│   ├── terminal/
│   │   └── settings.json
│   ├── profile.local.example.ps1
│   └── profile.ps1
├── install.sh     # Recommended installation script
├── install.ps1    # Windows/PowerShell installer preview
├── old_setup.sh   # DEPRECATED: Legacy copy-with-backup installer
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

    * The script will guide you through the process, asking for confirmation before installing optional tools, recommended macOS defaults, and the saved Dock layout unless run with `-f` or `-a`.

**Installer Options:**

* `./install.sh --help` or `-h`: Show help message.
* `./install.sh --dry-run` or `-dr`: Show what would be done without making changes (no file writes, no deletions, no global Git config changes).
* `./install.sh --copy` or `-c`: Copy files instead of creating symlinks (backs up existing files).
* `./install.sh --force` or `-f`: Skip all prompts, assumes yes to optional installs and backup cleaning.
* `./install.sh --minimal` or `-m`: Install only core dotfiles, skip optional tools and Git config.
* `./install.sh --all` or `-a`: Automatically install all optional tools without prompting.
* `./install.sh --uninstall`: Remove symlinks and revert shell rc additions this installer made, including Homebrew bootstrap entries on macOS (runs uninstall flow only, then exits).
* `./install.sh --clean-backups` or `-cb`: Offer to remove old `.bak.*` files created by this script in `$HOME` (or preview removals in dry-run mode).

---

## 🪟 Windows Preview

The Windows path is intentionally smaller and currently focuses on PowerShell profile setup plus package manager bootstrap.

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install.ps1
```

The Windows installer backs up any conflicting profile or Git ignore file as `.bak.<timestamp>` before copying the shared version into place, and it also creates the optional local overlay directory used by the public profile loader.

There is also a tracked example at `windows/profile.local.example.ps1` you can copy or adapt for local-only tweaks.

The installer copies the curated Windows package baseline into `~\.config\dotfiles\windows\packages.psd1` and the optional extras into `~\.config\dotfiles\windows\packages.optional.psd1`, so the shared manifests stay available even after the repo is moved or not mounted.

There is also a tracked template at `windows/packages.private.example.psd1` that can be copied to `~\.config\dotfiles\windows\packages.private.psd1` for local-only package entries.

If you want to remove old Windows backup files later, run `.\install.ps1 -CleanBackups` and confirm the prompt, or add `-Force` to skip the confirmation.

The Windows bootstrap assumes `winget` is already available through App Installer.

The Windows profile also exposes `a` to inspect commands, `aa` to print aliases, plus update helpers like `npmupg` and `wingup`.

The installer does not reload the active PowerShell session in place, which keeps the current prompt stable. Open a new PowerShell window after installation, or run `rld` / `rldz` manually if you want to re-source the profile.

There are curated public manifests in `windows/packages.psd1` and `windows/packages.optional.psd1` that track the starter baseline by package manager:

- `winget` for core shell/runtime apps and Store-backed desktop apps
- `Bitwarden`, `Chrome`, `Quick Share`, `Telegram`, `Android Studio`, `Keyguard`, `RustDesk`, `Tailscale`, `Zen Browser`, `UniGetUI`, and the rest of the desktop apps you asked for live in the optional extras manifest
- Cross-platform CLI tools that are equally useful on Windows now include `shellcheck`, `shfmt`, `yq`, `ast-grep`, `actionlint`, `pandoc`, `ffmpeg`, and `ExifTool`
- `NpmGlobal` remains intentionally empty so we do not encode machine-specific or personal globals into the repo
- If a future app only exists through Microsoft Store, the Windows manifest already supports `Source = 'msstore'` on a Winget entry; for now we only use that when it is genuinely needed.

The current Windows prompt theme is tracked in `windows/omp/tokyo.omp.json`, the minimal Windows Terminal settings live in `windows/terminal/settings.json`, and `JetBrainsMono Nerd Font` is part of the core `winget` baseline. The live prompt resolves the installed `oh-my-posh` theme folder once, preferring the AppX install location when available, and caches it locally under `~\.config\dotfiles\windows\omp.path`, so the profile stays simple while still adapting to the installed path.

The installer prints a summary of the manifests, shows a short alias cheat sheet, and can install only the missing items after an explicit confirmation, so you can rerun the bootstrap as many times as needed without duplicating work. Use `-y` if you want to answer yes to all installer prompts without typing each confirmation.

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
* **Sets Git Defaults:** Configures recommended global Git settings: `pull.rebase = true`, `rebase.autostash = true`, `core.editor = nano`.
* **Installs Optional Tools (if confirmed or `--all`/`--force`):** Uses `brew` (macOS) or `apt` (Debian/Ubuntu) to install tools listed in the Features section.
  * If Homebrew is missing on macOS, the installer bootstraps it and sets up shell env automatically (adds `eval "$(/opt/homebrew/bin/brew shellenv)"` or `eval "$(/usr/local/bin/brew shellenv)"` depending on install path).
  * On macOS, the tool manifest lives in `macos/Brewfile`, the baseline defaults live in `macos/defaults.sh`, and the saved Dock layout lives in `macos/dock.sh`.
  * On Ubuntu/Debian, the `bat` binary may be named `batcat`, and `fd` as `fdfind`. The installer creates shims (`/usr/local/bin/bat` and `/usr/local/bin/fd`) for a consistent experience.
  * For Python/Swift tooling, the managers are installed (`uv`, `swiftly`), and the script can optionally install CPython 3.13 via `uv` or the latest stable Swift toolchain via `swiftly`.
  * Ensures `~/.local/bin` is on `PATH` (if the directory exists) so user-installed tools like `uv` and `swiftly` are available.
  * On Linux, `swiftly` is installed from the official Swift.org tarball flow and initialized with `--skip-install` to avoid installing a Swift toolchain by default.
  * On Linux, `swiftly` requires `gpg` for signature verification; the installer ensures `gnupg` is installed.
* **macOS Defaults:** On macOS, the installer can apply a small `defaults` baseline for typing, Finder, Dock, and screenshots.
* **macOS Dock Layout:** The installer can also restore the saved Dock apps/folders from `macos/dock.sh` using `dockutil`.
* **Checks for Dependencies:** Verifies if essential commands used by aliases/functions (like `docker`, `swift`, `git`, `nano`) are present and warns if not.
* **Configures Startup Commands (Optional):** Asks if you want `nice_print_aliases` and `fastfetch` (or `screenfetch` as a fallback) to run when a new shell starts. These run only in interactive shells.
* **fzf & zoxide Initialization:** If installed, `zoxide` is initialized for your shell; `fzf` keybindings/completions are sourced when available.
* **Swiftly Env:** On Linux, the installer adds a line to your shell rc to source `~/.local/share/swiftly/env.sh` (if present) so `swiftly` and installed toolchains are on `PATH`.
* **PATH Cleanup:** The installer appends a snippet to remove duplicate entries from `PATH` while preserving order.
* **Optional Node Tooling:** Offers to install or update `nvm` (Node Version Manager) to the latest released tag. If installed, your shell will source `~/.nvm/nvm.sh` automatically.
  * If no Node is active via `nvm`, you can install the latest LTS and set it as default.
  * If a Node version is already active via `nvm`, the installer offers to switch to the latest LTS and set it as default, with a warning that global npm packages are per-version and won’t move automatically. To migrate them later, run: `nvm reinstall-packages <previous_version>`.
  * If `corepack` is available, it is enabled after installing/switching to LTS to provide Yarn/PNPM shims.
* **Optional Python Tooling:** Installs `uv` (Python tool and package manager). Optionally offers to install CPython 3.13 managed by `uv` with `python`/`python3` defaults (does not change your system `python`).
* **Optional Swift Tooling:** Installs `swiftly` (Swift toolchain manager). Optionally offers to install the latest stable Swift toolchain via `swiftly`.

---

## 💬 Notes

* **Legacy Installer:** The `old_setup.sh` script uses a simple copy-and-backup method. It's kept for historical purposes but **`install.sh` is the recommended method**.
* **Zsh Default:** If you use Zsh, ensure it's set as your default login shell: `chsh -s $(which zsh)`
* **Private Aliases:** You can create a `~/.private_aliases` file to store personal aliases you don't want to commit to Git. The main alias file (`general/.aliases`) will automatically source it if it exists.
* **Backups:** Old configuration files backed up by the script will have names like `~/.bashrc.bak.1678886400`. You can manually remove them (`rm ~/*.bak.*`) or use the `./install.sh --clean-backups` option.
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
* **Windows package baseline:** The public starter inventory lives in `windows/packages.psd1` and `windows/packages.optional.psd1`; treat them as curated baselines, not a dump of every installed Windows app.
* **Windows package sources:** Use `winget` for GUI apps and for the CLI tools that are available there. Store-only apps that do not resolve reliably in `winget` should stay manual instead of making the bootstrap more fragile; `PC Manager` is one of those edge cases on some machines.
* **Windows prompt assets:** `windows/omp/tokyo.omp.json` captures the current `oh-my-posh` theme, `windows/terminal/settings.json` captures the minimal Terminal defaults, and `JetBrainsMono Nerd Font` is bootstrapped through the core `winget` manifest. The live profile points to the installed theme path, prefers the AppX install location when present, and caches the resolved folder locally so the prompt stays straightforward.
* **Windows Terminal cleanup:** The template intentionally leaves out machine-specific SSH and one-off profiles; keep those in a local overlay if you still want them.
* **Windows reruns are safe:** `install.ps1` only installs missing packages after you confirm the prompt.
* **Prompt refresh:** If the shell prompt looks stale after a run, use `rld` or `rldz` to re-source the profile and refresh `oh-my-posh`.

---

## ✅ Verification

After installation, a quick smoke check is:

```bash
command -v git nano fzf zoxide uv swiftly gh
git config --global --get core.excludesfile
```

If you use Zsh, open a new interactive shell and confirm that `aa`, `l`, `gl`, and `myip` are available.

---

## 🧭 Cheatsheet

* Shell basics:
  * `a` / `aa`: Inspect a command or print aliases.
  * `l`/`lt`/`ll`: Directory listings (use `eza` if installed, otherwise `ls`).
  * `mntlist`: Show mounted volumes (portable, does not shadow `mount`).
  * `myip`: Show public IP.
  * `rld` / `rldz`: Reload the current PowerShell profile.
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
