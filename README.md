# dotfiles

My personal dotfiles collection, designed for consistency across macOS and Debian/Ubuntu systems using Bash or Zsh.

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

* 🛠️ **Optional Tool Installation:** Installs useful tools via Homebrew (macOS) or apt (Debian/Ubuntu):
  * `fzf` (Fuzzy finder) + keybindings/completions
  * `eza` (Modern `ls` replacement)
  * `zoxide` (Smarter `cd`) with shell init
  * `bat` (Syntax-highlighting `cat`) with `batcat` shim on Ubuntu
  * `fd` (Fast `find`) with `fdfind` shim on Ubuntu
  * `ripgrep` (`rg`, fast grep)
  * `oh-my-posh` (Customizable prompt)
  * `exiv2` (Needed for `ren_pics` function)
  * `fastfetch` (System info display - preferred)
  * `nano` (Ensures a consistent editor is available)
  * `uv` (Python tooling manager; installed but does not pin a Python version)
  * `swiftly` (Swift toolchain manager; installed but does not install a Swift toolchain)
* 🪄 **Enhanced Shell Experience:**
  * Sensible command history settings with cross-session sharing.
  * `oh-my-posh` integration for an informative prompt (interactive shells only).
  * Helpful aliases and functions for common tasks.
  * Discover aliases quickly: run `aa` to print a readable alias list (`nice_print_aliases`).
* ⚙️ **Git Enhancements:** Useful Git aliases, functions (like `fzf` branch switching), and recommended global settings (`pull.rebase`, `rebase.autostash`, `core.editor`, `core.excludesfile`).
  * Examples: `gl` (pull current branch with rebase/autostash), `gp` (push current branch), `gsu` (set upstream), `gla`/`glaf` (last commit summary/full), `lg`/`lgr` (commits missing on origin/release).
* 🔒 **Private Aliases:** Supports loading personal, untracked aliases from `~/.private_aliases`.

---

## 📁 Directory Structure

```sh
.
├── general/       # Shared shell config (aliases, functions, history, prompt)
├── git/           # Git-specific aliases, functions, and global ignore
├── nano/          # Nano text editor configuration
├── install.sh     # Recommended installation script
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

    * The script will guide you through the process, asking for confirmation before installing optional tools unless run with `-f` or `-a`.

**Installer Options:**

* `./install.sh --help` or `-h`: Show help message.
* `./install.sh --dry-run` or `-dr`: Show what would be done without making changes.
* `./install.sh --copy` or `-c`: Copy files instead of creating symlinks (backs up existing files).
* `./install.sh --force` or `-f`: Skip all prompts, assumes yes to optional installs and backup cleaning.
* `./install.sh --minimal` or `-m`: Install only core dotfiles, skip optional tools and Git config.
* `./install.sh --all` or `-a`: Automatically install all optional tools without prompting.
* `./install.sh --uninstall`: Remove symlinks and revert shell rc additions this installer made.
* `./install.sh --clean-backups` or `-cb`: Offer to remove old `.bak.*` files created by this script in `$HOME`.

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
  * If Homebrew is missing on macOS, the installer bootstraps it and sets up the shell env automatically (adds `eval "$($(brew_path)/brew shellenv)"` to `~/.zprofile` and `~/.bash_profile`).
  * On Ubuntu/Debian, the `bat` binary may be named `batcat`, and `fd` as `fdfind`. The installer creates shims (`/usr/local/bin/bat` and `/usr/local/bin/fd`) for a consistent experience.
  * For Python/Swift tooling, only the managers are installed (`uv`, `swiftly`); no specific Python or Swift toolchain versions are installed by this script.
  * Ensures `~/.local/bin` is on `PATH` (if the directory exists) so user-installed tools like `uv` and `swiftly` are available.
  * On Linux, `swiftly` is installed from the official Swift.org tarball flow and initialized with `--skip-install` to avoid installing a Swift toolchain by default.
  * On Linux, `swiftly` requires `gpg` for signature verification; the installer ensures `gnupg` is installed.
* **Checks for Dependencies:** Verifies if essential commands used by aliases/functions (like `docker`, `swift`, `git`, `nano`) are present and warns if not.
* **Configures Startup Commands (Optional):** Asks if you want `nice_print_aliases` and `fastfetch` (or `screenfetch` as a fallback) to run when a new shell starts. These run only in interactive shells.
* **fzf & zoxide Initialization:** If installed, `zoxide` is initialized for your shell; `fzf` keybindings/completions are sourced when available.
* **Swiftly Env:** On Linux, the installer adds a line to your shell rc to source `~/.local/share/swiftly/env.sh` (if present) so `swiftly` and installed toolchains are on `PATH`.
* **Optional Node Tooling:** Offers to install or update `nvm` (Node Version Manager) to the latest released tag. If installed, your shell will source `~/.nvm/nvm.sh` automatically.
  * If no Node is active via `nvm`, you can install the latest LTS and set it as default.
  * If a Node version is already active via `nvm`, the installer offers to switch to the latest LTS and set it as default, with a warning that global npm packages are per-version and won’t move automatically. To migrate them later, run: `nvm reinstall-packages <previous_version>`.
  * If `corepack` is available, it is enabled after installing/switching to LTS to provide Yarn/PNPM shims.
* **Optional Python Tooling:** Installs `uv` (Python tool and package manager). Optionally offers to install the latest CPython release managed by `uv` (does not change your system `python`).
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

- macOS (via Homebrew)
- Debian/Ubuntu (via apt)

Other Linux distributions are not covered by the installer. You can adapt the scripts or install tools manually on those platforms.

---

## 🧭 Cheatsheet

- Shell basics:
  - `aa`: Pretty-print aliases (`nice_print_aliases`).
  - `l`/`lt`/`ll`: Directory listings (use `eza` if installed, otherwise `ls`).
  - `mntlist`: Show mounted volumes (portable, does not shadow `mount`).
  - `myip`: Show public IP.
  - `rld` / `rldz`: Reload `~/.bashrc` / `~/.zshrc`.
  - `brewup`: Update, upgrade and clean Homebrew (macOS).

- Packages and repos:
  - `npmupg`: Update all globally installed npm packages (respecting semver ranges).
  - `rpx`: Run RepoMix and output `<folder>-repomix.md`, ignoring `*.html`.

- Docker helpers:
  - `up_dockers`: Pull latest tags for all local image repositories.
  - `up_dockers_wt`: One-shot updates via Watchtower (`--run-once --cleanup`).
  - `up_portainer_ce` / `up_portainer_be`: Recreate Portainer CE/BE containers with volumes/ports.

- Git aliases (highlights):
  - `gl` / `gp`: Pull (rebase+autostash) / push current branch.
  - `gsu`: Set upstream to `origin/<current-branch>`.
  - `gla` / `glaf`: Show last commit summary / full diff.
  - `gd` / `gds`: Diff vs. HEAD / diff stats.
  - `gcb` / `gca` / `gcd`: New branch / amend / amend with now timestamp.
  - `lg`: Commits on local branch not on `origin/<branch>`.
  - `lgr`: Commits on current branch not in `origin/release`.

- Git fzf functions:
  - `fuzzy_branch_selector`: Select a branch (includes remotes); uses `git switch` with tracking.
  - `fuzzy_log_viewer`: Fuzzy-find commits with preview (`git show`).
  - `git_see_authors`: Shortlog authors summary.
