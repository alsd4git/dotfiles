#!/usr/bin/env bash

set -e
FORCE_MODE=false
MINIMAL_MODE=false
DRY_RUN=false
COPY_MODE=false
CLEAN_BACKUPS=false
SHOW_HELP=false
INSTALL_ALL=false
SKIP_GIT_CONFIG=false
for arg in "$@"; do
    case "$arg" in
    -dr | --dry-run)
        DRY_RUN=true
        echo "🧪 Running in dry-run mode. No files will be changed."
        ;;
    -c | --copy)
        COPY_MODE=true
        echo "📄 Running in copy mode with backup."
        ;;
    -cb |--clean-backups)
        CLEAN_BACKUPS=true
        ;;
    -f | --force)
        FORCE_MODE=true
        ;;
    -m | --minimal)
        MINIMAL_MODE=true
        ;;
    -h | --help)
        SHOW_HELP=true
        ;;
    -a | --all)
        INSTALL_ALL=true
        ;;
    *)
        echo "❓ Unknown argument: $arg"
        ;;
    esac
done

if $SHOW_HELP; then
    echo "Usage: ./install.sh [options]"
    echo ""
    echo "Options:"
    echo "  -dr, --dry-run         Run in dry mode (no files modified)"
    echo "  -c,  --copy            Copy files instead of symlinking"
    echo "  -f,  --force           Skip prompts and force all actions"
    echo "  -m,  --minimal         Install only core dotfiles (no extras or tools)"
    echo "  -cb, --clean-backups   Remove existing .bak.* files in \$HOME"
    echo "  -a,  --all             Automatically install all optional tools"
    echo "  -h,  --help            Show this help message"
    exit 0
fi

if $FORCE_MODE; then
    INSTALL_ALL=true
    CLEAN_BACKUPS=true
    REPLY_ALL="y"
fi

if $MINIMAL_MODE; then
    INSTALL_ALL=false
    SKIP_GIT_CONFIG=true
    SKIP_FETCH=true
fi

### === Detect Environment ===
OS="$(uname -s)"
SHELL_NAME=$(basename "$SHELL")

printf "\n🔍 Detected OS: %s\n" "$OS"
printf "🔍 Detected Shell: %s\n" "$SHELL_NAME"

add_to_rc_if_not_present() {
    local rc_file="${1/#\~/$HOME}" # expand ~ to $HOME
    local line_to_add="$2"
    if grep -Fq "$line_to_add" "$rc_file"; then
        echo "📄 $line_to_add found in $rc_file, no need to add"
    else
        echo "📝 adding $line_to_add to $rc_file"
        echo "$line_to_add" >>"$rc_file"
    fi
}

### === Define dotfiles ===
# Feel free to extend the SYMLINKS array if new files/folders are added
BASEDIR=$(cd "$(dirname "$0")" && pwd)
DOTFILES_HOME="$BASEDIR"

# Create SYMLINKS map in a way compatible with both Bash and Zsh
SYMLINK_KEYS=(
    "$HOME/.shell_aliases"
    "$HOME/.shell_functions"
    "$HOME/.history_settings"
    "$HOME/.omp_init"
    "$HOME/.nanorc"
    "$HOME/.git_aliases"
    "$HOME/.git_functions"
    "$HOME/.global.gitignore"
)
SYMLINK_VALUES=(
    "$DOTFILES_HOME/general/.aliases"
    "$DOTFILES_HOME/general/.functions"
    "$DOTFILES_HOME/general/.history_settings"
    "$DOTFILES_HOME/general/.omp_init"
    "$DOTFILES_HOME/nano/.nanorc"
    "$DOTFILES_HOME/git/.git_aliases"
    "$DOTFILES_HOME/git/.git_functions"
    "$DOTFILES_HOME/git/global.gitignore"
)

### === Symlink Files ===
echo -e "\n🔗 Linking or copying files..."
for i in "${!SYMLINK_KEYS[@]}"; do
    dest="${SYMLINK_KEYS[$i]}"
    src="${SYMLINK_VALUES[$i]}"
    if $DRY_RUN; then
        action=$([[ $COPY_MODE == true ]] && echo "copy" || echo "link")
        echo "🧪 Would $action $dest → $src"
    elif $COPY_MODE; then
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            mv "$dest" "$dest.bak.$(date +%s)"
            echo "📦 Backed up $dest"
        fi
        cp "$src" "$dest"
        echo "📄 Copied $src → $dest"
    else
        if [ -e "$dest" ]; then
            if [ ! -L "$dest" ] || [ "$(readlink "$dest")" != "$src" ]; then
                mv "$dest" "$dest.bak.$(date +%s)"
                echo "📦 Backed up existing $dest"
            fi
        fi
        ln -sf "$src" "$dest"
        echo "✅ Linked $dest → $src"
    fi
done

# Set up Git global ignore config
if ! $SKIP_GIT_CONFIG; then
    GIT_IGNORE_GLOBAL="$HOME/.global.gitignore"
    if [ -f "$GIT_IGNORE_GLOBAL" ]; then
        echo "🔧 Configuring Git global ignore path..."
        git config --global core.excludesfile "$GIT_IGNORE_GLOBAL"
    fi
fi

# Set up Git recommended defaults
if ! $SKIP_GIT_CONFIG; then
    echo "🔧 Configuring global Git behavior..."
    git config --global pull.rebase true
    git config --global rebase.autostash true
    git config --global core.editor "nano"
fi

### === Optional Tools Install ===
if ! $MINIMAL_MODE && ! $DRY_RUN; then
    if $INSTALL_ALL; then
        do_install="y"
    else
        read -p $'\n✨ Install optional tools? (fzf, eza, bat, zoxide, oh-my-posh, nano)? [y/N]: ' do_install
    fi

    if [[ "$do_install" =~ ^[Yy]$ ]]; then
        echo -e "\n📦 Installing tools..."

        case "$OS" in
        Darwin)
            if ! command -v brew >/dev/null; then
                echo "🍺 Homebrew not found. Installing..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi

            # Install standard tools only if missing
            for pkg in fzf eza bat zoxide exiv2 fastfetch nano; do
                if ! brew list --formula | grep -q "^$pkg$"; then
                    echo "📦 Installing $pkg..."
                    brew install "$pkg"
                else
                    echo "✅ $pkg already installed"
                fi
            done

            # Install oh-my-posh from tap only if missing
            if ! brew list --formula | grep -q "^oh-my-posh$"; then
                echo "📦 Installing oh-my-posh from tap..."
                brew install jandedobbeleer/oh-my-posh/oh-my-posh
            else
                echo "✅ oh-my-posh already installed"
            fi
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
fi

### === Check for other tools used in aliases/functions ===
echo -e "\n🔍 Checking for other recommended tools..."

REQUIRED_TOOLS=(nano docker swift git)

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

if [[ "$SHELL_NAME" == "zsh" ]]; then
    if [ -f ~/.zshrc ]; then
        echo "🧠 .zshrc present, checking lines..."
        if ! $DRY_RUN; then
            add_to_rc_if_not_present "~/.zshrc" "[[ -f ~/.shell_aliases ]] && source ~/.shell_aliases"
            add_to_rc_if_not_present "~/.zshrc" "[[ -f ~/.shell_functions ]] && source ~/.shell_functions"
            add_to_rc_if_not_present "~/.zshrc" "[[ -f ~/.git_aliases ]] && source ~/.git_aliases"
            add_to_rc_if_not_present "~/.zshrc" "[[ -f ~/.git_functions ]] && source ~/.git_functions"
            add_to_rc_if_not_present "~/.zshrc" "[[ -f ~/.history_settings ]] && source ~/.history_settings"
            add_to_rc_if_not_present "~/.zshrc" "[[ -f ~/.omp_init ]] && source ~/.omp_init"

            if $FORCE_MODE; then
                reply="y"
            else
                read -p "🧠 Do you want to run nice_print_aliases on shell startup? [y/N]: " reply
            fi
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                add_to_rc_if_not_present "~/.zshrc" "nice_print_aliases"
            fi

            if $FORCE_MODE; then
                reply="y"
            else
                read -p "🖼️  Do you want to run $FETCH_CMD on shell startup? [y/N]: " reply
            fi
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                add_to_rc_if_not_present "~/.zshrc" "$FETCH_CMD"
            fi
        fi
    else
        echo "📝 .zshrc not found, creating a new one..."
        touch ~/.zshrc
        echo "[[ -f ~/.shell_aliases ]] && source ~/.shell_aliases" >>~/.zshrc
        echo "[[ -f ~/.shell_functions ]] && source ~/.shell_functions" >>~/.zshrc
        echo "[[ -f ~/.git_aliases ]] && source ~/.git_aliases" >>~/.zshrc
        echo "[[ -f ~/.git_functions ]] && source ~/.git_functions" >>~/.zshrc
        echo "[[ -f ~/.history_settings ]] && source ~/.history_settings" >>~/.zshrc
        echo "[[ -f ~/.omp_init ]] && source ~/.omp_init" >>~/.zshrc

        if $FORCE_MODE; then
            reply="y"
        else
            read -p "🧠 Do you want to run nice_print_aliases on shell startup? [y/N]: " reply
        fi
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            add_to_rc_if_not_present "~/.zshrc" "nice_print_aliases"
        fi

        if $FORCE_MODE; then
            reply="y"
        else
            read -p "🖼️  Do you want to run $FETCH_CMD on shell startup? [y/N]: " reply
        fi
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            add_to_rc_if_not_present "~/.zshrc" "$FETCH_CMD"
        fi
    fi
fi

if [[ "$SHELL_NAME" == "bash" ]]; then
    if [ -f ~/.bashrc ]; then
        echo "🧠 .bashrc present, checking lines..."
        if ! $DRY_RUN; then
            add_to_rc_if_not_present "~/.bashrc" "[[ -f ~/.shell_aliases ]] && source ~/.shell_aliases"
            add_to_rc_if_not_present "~/.bashrc" "[[ -f ~/.shell_functions ]] && source ~/.shell_functions"
            add_to_rc_if_not_present "~/.bashrc" "[[ -f ~/.git_aliases ]] && source ~/.git_aliases"
            add_to_rc_if_not_present "~/.bashrc" "[[ -f ~/.git_functions ]] && source ~/.git_functions"
            add_to_rc_if_not_present "~/.bashrc" "[[ -f ~/.history_settings ]] && source ~/.history_settings"
            add_to_rc_if_not_present "~/.bashrc" "[[ -f ~/.omp_init ]] && source ~/.omp_init"

            if $FORCE_MODE; then
                reply="y"
            else
                read -p "🧠 Do you want to run nice_print_aliases on shell startup? [y/N]: " reply
            fi
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                add_to_rc_if_not_present "~/.bashrc" "nice_print_aliases"
            fi

            if $FORCE_MODE; then
                reply="y"
            else
                read -p "🖼️  Do you want to run $FETCH_CMD on shell startup? [y/N]: " reply
            fi
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                add_to_rc_if_not_present "~/.bashrc" "$FETCH_CMD"
            fi
        fi
    else
        echo "📝 .bashrc not found, creating a new one..."
        touch ~/.bashrc
        echo '[[ -f ~/.shell_aliases ]] && source ~/.shell_aliases' >>~/.bashrc
        echo '[[ -f ~/.shell_functions ]] && source ~/.shell_functions' >>~/.bashrc
        echo '[[ -f ~/.git_aliases ]] && source ~/.git_aliases' >>~/.bashrc
        echo '[[ -f ~/.git_functions ]] && source ~/.git_functions' >>~/.bashrc
        echo '[[ -f ~/.history_settings ]] && source ~/.history_settings' >>~/.bashrc
        echo '[[ -f ~/.omp_init ]] && source ~/.omp_init' >>~/.bashrc

        if $FORCE_MODE; then
            reply="y"
        else
            read -p "🧠 Do you want to run nice_print_aliases on shell startup? [y/N]: " reply
        fi
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            add_to_rc_if_not_present "~/.bashrc" "nice_print_aliases"
        fi

        if $FORCE_MODE; then
            reply="y"
        else
            read -p "🖼️  Do you want to run $FETCH_CMD on shell startup? [y/N]: " reply
        fi
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            add_to_rc_if_not_present "~/.bashrc" "$FETCH_CMD"
        fi
    fi
fi

if $CLEAN_BACKUPS; then
    echo -e "\n🧹 Looking for backup files to remove in $HOME..."
    BACKUPS=()
    while IFS= read -r file; do
        BACKUPS+=("$file")
    done < <(find "$HOME" -maxdepth 1 -name "*.bak.*")

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo "✅ No backup files found."
    else
        echo "🗒️  Found the following backup files:"
        for file in "${BACKUPS[@]}"; do
            echo " - $file"
        done
        echo
        read -p "🛑 Do you want to delete all these files? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            for file in "${BACKUPS[@]}"; do
                echo "🗑️  Removing $file"
                rm -f "$file"
            done
            echo "✅ Done cleaning up backups."
        else
            echo "❌ Skipped backup cleanup."
        fi
    fi
fi

echo -e "\n🚀 Setup complete. You may need to restart your shell or source the new config."
