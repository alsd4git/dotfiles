# dotfiles

My dotfiles used across multiple machines and environments (mainly Debian, macOS).

---

## ✨ Features

- 🧼 Clean separation between Bash, Zsh, Git, Nano, and general-purpose shell setup
- ✅ Compatible with both Bash and Zsh
- 🛠️ Optional install of tools like `fzf`, `eza`, `zoxide`, `bat`, `oh-my-posh`
- 🪄 History sync, prompt setup, and Git helpers included
- 🧪 `--dry-run` and `--copy` modes for safe testing or legacy-style installation

---

## 📁 Directory Structure

```sh
.
├── general/       # Shared shell config (aliases, functions, history, prompt)
├── git/           # Git aliases and helpers
├── nano/          # Nano config
├── install.sh     # New modular setup script (recommended)
├── old_setup.sh   # Legacy copy-with-backup installer
└── README.md
```

> All managed dotfiles are linked into `~/.dotfiles`, and symlinked into your `$HOME` directory by `install.sh`.

---

## 🚀 Setup Instructions

Clone the repo and run the installer:

```bash
git clone https://github.com/alsd4git/dotfiles ~/.dotfiles
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

You can also run in:

- 🧪 Dry-run mode: `./install.sh --dry-run`
- 📄 Copy mode (like old setup): `./install.sh --copy`

---

## 🧠 What `install.sh` Does

- Symlinks dotfiles from `~/.dotfiles/` into your `$HOME`
- Backs up any pre-existing config files
- Ensures `.bashrc` or `.zshrc` sources the right config parts
- Optionally installs:
  - `fzf`
  - `eza`
  - `zoxide`
  - `bat`
  - `oh-my-posh`

---

## 💬 Notes

- The legacy `old_setup.sh` uses copy-based installation and is still available.
- Shared logic (like aliases, functions, prompt config, history) is centralized in the `general/` folder.
- If you're using Zsh, make sure it's your default shell:
  
```bash
chsh -s $(which zsh)
```
