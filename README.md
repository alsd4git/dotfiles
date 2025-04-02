# dotfiles

My personal dotfiles collection, designed for consistency across macOS and Debian-based Linux systems using Bash or Zsh.

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

* 🛠️ **Optional Tool Installation:** Can install useful tools via package managers (Homebrew on macOS, apt on Linux):
  * `fzf` (Fuzzy finder)
  * `eza` (Modern `ls` replacement)
  * `zoxide` (Smarter `cd`)
  * `bat` (Syntax-highlighting `cat`)
  * `oh-my-posh` (Customizable prompt)
  * `exiv2` (Needed for `ren_pics` function)
  * `fastfetch` (System info display - preferred)
  * `nano` (Ensures a consistent editor is available)
* 🪄 **Enhanced Shell Experience:**
  * Sensible command history settings with cross-session sharing.
  * `oh-my-posh` integration for an informative prompt.
  * Helpful aliases and functions for common tasks.
* ⚙️ **Git Enhancements:** Useful Git aliases, functions (like `fzf` branch switching), and recommended global settings (`pull.rebase`, `rebase.autostash`, `core.editor`, `core.excludesfile`).
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
* `./install.sh --clean-backups` or `-cb`: Offer to remove old `.bak.*` files created by this script in `$HOME`.

---

## 🧠 What `install.sh` Does

* **Detects OS and Shell:** Determines if you're on macOS or Linux, and using Bash or Zsh.
* **Creates Symlinks (Default):** For each configuration file (e.g., `general/.aliases`), it creates a symlink in your home directory (e.g., `~/.shell_aliases`) pointing back to the file in the `~/.dotfiles` repository.
  * If a file or symlink already exists at the destination, it's backed up as `~/<filename>.bak.<timestamp>`.
* **Updates RC Files:** Adds lines to your `~/.bashrc` or `~/.zshrc` (creating them if they don't exist) to source the new alias, function, history, and prompt files. It checks if lines already exist to avoid duplicates.
* **Configures Global Git Ignore:**
  * Symlinks `git/global.gitignore` to `$HOME/.global.gitignore`.
  * Runs `git config --global core.excludesfile "$HOME/.global.gitignore"` to tell Git to use this file.
* **Sets Git Defaults:** Configures recommended global Git settings: `pull.rebase = true`, `rebase.autostash = true`, `core.editor = nano`.
* **Installs Optional Tools (if confirmed or `--all`/`--force`):** Uses `brew` (macOS) or `apt` (Linux) to install tools listed in the Features section.
* **Checks for Dependencies:** Verifies if essential commands used by aliases/functions (like `docker`, `swift`, `git`, `nano`) are present and warns if not.
* **Configures Startup Commands (Optional):** Asks if you want `nice_print_aliases` and `fastfetch` (or `screenfetch` as a fallback if `fastfetch` isn't found) to run when a new shell starts.

---

## 💬 Notes

* **Legacy Installer:** The `old_setup.sh` script uses a simple copy-and-backup method. It's kept for historical purposes but **`install.sh` is the recommended method**.
* **Zsh Default:** If you use Zsh, ensure it's set as your default login shell: `chsh -s $(which zsh)`
* **Private Aliases:** You can create a `~/.private_aliases` file to store personal aliases you don't want to commit to Git. The main alias file (`general/.aliases`) will automatically source it if it exists.
* **Backups:** Old configuration files backed up by the script will have names like `~/.bashrc.bak.1678886400`. You can manually remove them (`rm ~/*.bak.*`) or use the `./install.sh --clean-backups` option.
* **System Info:** The script configures `fastfetch` to run on startup if available. If `fastfetch` is not found, it falls back to trying `screenfetch`. Note that the installer only attempts to *install* `fastfetch`, not `screenfetch`.
