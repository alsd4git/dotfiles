#!/usr/bin/env bash

set -e
DRY_RUN=false
COPY_MODE=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🧪 Running in dry-run mode. No files will be changed."
elif [[ "$1" == "--copy" ]]; then
    COPY_MODE=true
    echo "📄 Running in copy mode with backup."
fi

### === Detect Environment ===
OS="$(uname -s)"
SHELL_NAME=$(basename "$SHELL")

printf "\n🔍 Detected OS: %s\n" "$OS"
printf "🔍 Detected Shell: %s\n" "$SHELL_NAME"

add_to_rc_if_not_present() {
    local rc_file="$1"
    local line_to_add="$2"
    if grep -Fq "$line_to_add" "$rc_file"; then
        echo "$line_to_add found in $rc_file, no need to add"
    else
        echo "adding $line_to_add to $rc_file"
        echo "$line_to_add" >>"$rc_file"
    fi
}

### === Define dotfiles ===
# Feel free to extend the SYMLINKS array if new files/folders are added
BASEDIR=$(cd "$(dirname "$0")" && pwd)
DOTFILES_HOME="$HOME/.dotfiles"
mkdir -p "$DOTFILES_HOME"

SYMLINKS=(
    # ~/.shell_aliases → ~/.dotfiles/general/.aliases
    ["$HOME/.shell_aliases"]="$DOTFILES_HOME/general/.aliases"
    # ~/.shell_functions → ~/.dotfiles/general/.functions
    ["$HOME/.shell_functions"]="$DOTFILES_HOME/general/.functions"
    # ~/.history_settings → ~/.dotfiles/general/.history_settings
    ["$HOME/.history_settings"]="$DOTFILES_HOME/general/.history_settings"
    # ~/.omp_init → ~/.dotfiles/general/.omp_init
    ["$HOME/.omp_init"]="$DOTFILES_HOME/general/.omp_init"
    # ~/.nanorc → ~/.dotfiles/nano/.nanorc
    ["$HOME/.nanorc"]="$DOTFILES_HOME/nano/.nanorc"
    # ~/.git_aliases → ~/.dotfiles/git/.git_aliases
    ["$HOME/.git_aliases"]="$DOTFILES_HOME/git/.git_aliases"
    # ~/.git_functions → ~/.dotfiles/git/.git_functions
    ["$HOME/.git_functions"]="$DOTFILES_HOME/git/.git_functions"
)

### === Symlink Files ===
echo "\n🔗 Linking or copying files..."
for dest in "${!SYMLINKS[@]}"; do
    src="${SYMLINKS[$dest]}"
    if $DRY_RUN; then
        echo "🧪 Would link $dest → $src"
    elif $COPY_MODE; then
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            mv "$dest" "$dest.backup.$(date +%s)"
            echo "📦 Backed up $dest"
        fi
        cp "$src" "$dest"
        echo "📄 Copied $src → $dest"
    else
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            mv "$dest" "$dest.backup.$(date +%s)"
            echo "🛑 Backed up $dest"
        fi
        ln -sf "$src" "$dest"
        echo "✅ Linked $dest → $src"
    fi
done

### === Optional Tools Install ===
read -p $'\n✨ Install optional tools? (fzf, eza, bat, zoxide, oh-my-posh)? [y/N]: ' do_install
if [[ "$do_install" =~ ^[Yy]$ ]]; then
    echo "\n📦 Installing tools..."

    case "$OS" in
    Darwin)
        if ! command -v brew >/dev/null; then
            echo "🍺 Homebrew not found. Installing..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install fzf eza bat zoxide oh-my-posh
        brew install exiv2 fastfetch
        ;;
    Linux)
        sudo apt update
        sudo apt install -y fzf bat zoxide curl unzip

        # eza
        if ! command -v eza >/dev/null; then
            echo "📥 Installing eza manually..."
            curl -LO https://github.com/eza-community/eza/releases/latest/download/eza_amd64.deb
            sudo dpkg -i eza_amd64.deb && rm eza_amd64.deb
        fi

        # oh-my-posh
        if ! command -v oh-my-posh >/dev/null; then
            echo "📥 Installing oh-my-posh..."
            curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
        fi

        # exiv2
        if ! command -v exiv2 >/dev/null; then
            echo "📥 Installing exiv2..."
            sudo apt install -y exiv2
        fi

        # fastfetch
        if ! command -v fastfetch >/dev/null; then
            echo "📥 Installing fastfetch..."
            sudo apt install -y fastfetch || {
                echo "⚠️ fastfetch not available via apt. You can build it manually:"
                echo "   https://github.com/fastfetch-cli/fastfetch"
            }
        fi
        ;;
    *)
        echo "❌ Unsupported OS. Install dependencies manually."
        ;;
    esac
fi

### === Check for other tools used in aliases/functions ===
echo -e "\n🔍 Checking for other recommended tools..."

REQUIRED_TOOLS=(nano docker swift)

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "⚠️  $tool not found. Some aliases or functions may not work correctly."
    else
        echo "✅ $tool is available."
    fi
done

FETCH_CMD=""
if command -v fastfetch >/dev/null 2>&1; then
    FETCH_CMD="fastfetch 2>/dev/null"
else
    FETCH_CMD="screenfetch 2>/dev/null"
fi

if [ -f ~/.zshrc ]; then
    echo ".zshrc present, checking lines..."
    add_to_rc_if_not_present ".zshrc" "[[ -f ~/.shell_aliases ]] && source ~/.shell_aliases"
    add_to_rc_if_not_present ".zshrc" "[[ -f ~/.shell_functions ]] && source ~/.shell_functions"
    add_to_rc_if_not_present ".zshrc" "[[ -f ~/.git_aliases ]] && source ~/.git_aliases"
    add_to_rc_if_not_present ".zshrc" "[[ -f ~/.git_functions ]] && source ~/.git_functions"
    add_to_rc_if_not_present ".zshrc" "[[ -f ~/.history_settings ]] && source ~/.history_settings"
    add_to_rc_if_not_present ".zshrc" "[[ -f ~/.omp_init ]] && source ~/.omp_init"
    add_to_rc_if_not_present ".zshrc" "nice_print_aliases"
    add_to_rc_if_not_present ".zshrc" "$FETCH_CMD"
else
    echo ".zshrc not found, creating a new one..."
    touch ~/.zshrc
    echo "[[ -f ~/.shell_aliases ]] && source ~/.shell_aliases" >>~/.zshrc
    echo "[[ -f ~/.shell_functions ]] && source ~/.shell_functions" >>~/.zshrc
    echo "[[ -f ~/.git_aliases ]] && source ~/.git_aliases" >>~/.zshrc
    echo "[[ -f ~/.git_functions ]] && source ~/.git_functions" >>~/.zshrc
    echo "[[ -f ~/.history_settings ]] && source ~/.history_settings" >>~/.zshrc
    echo "[[ -f ~/.omp_init ]] && source ~/.omp_init" >>~/.zshrc
    echo "nice_print_aliases" >>~/.zshrc
    echo "$FETCH_CMD" >>~/.zshrc
fi

if [ -f ~/.bashrc ]; then
    echo ".bashrc present, checking lines..."
    add_to_rc_if_not_present ".bashrc" ". ~/.shell_aliases"
    add_to_rc_if_not_present ".bashrc" ". ~/.shell_functions"
    add_to_rc_if_not_present ".bashrc" ". ~/.git_aliases"
    add_to_rc_if_not_present ".bashrc" ". ~/.git_functions"
    add_to_rc_if_not_present ".bashrc" ". ~/.history_settings"
    add_to_rc_if_not_present ".bashrc" ". ~/.omp_init"
    add_to_rc_if_not_present ".bashrc" "nice_print_aliases"
    add_to_rc_if_not_present ".bashrc" "$FETCH_CMD"
else
    echo ".bashrc not found, creating a new one..."
    touch ~/.bashrc
    echo ". ~/.shell_aliases" >>~/.bashrc
    echo ". ~/.shell_functions" >>~/.bashrc
    echo ". ~/.git_aliases" >>~/.bashrc
    echo ". ~/.git_functions" >>~/.bashrc
    echo ". ~/.history_settings" >>~/.bashrc
    echo ". ~/.omp_init" >>~/.bashrc
    echo "nice_print_aliases" >>~/.bashrc
    echo "$FETCH_CMD" >>~/.bashrc
fi

echo -e "\n📎 Note: If using Zsh, make sure your terminal is using it (chsh -s $(which zsh))"
echo -e "\n✅ Setup complete. You may need to restart your shell or source the new config."
