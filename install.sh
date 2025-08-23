#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
FORCE_MODE=false
MINIMAL_MODE=false
DRY_RUN=false
COPY_MODE=false
CLEAN_BACKUPS=false
SHOW_HELP=false
INSTALL_ALL=false
SKIP_GIT_CONFIG=false
UNINSTALL_MODE=false
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
    --uninstall)
        UNINSTALL_MODE=true
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
    echo "      --uninstall        Remove links and revert shell rc additions"
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
    if [ -f "$rc_file" ] && grep -Fq "$line_to_add" "$rc_file"; then
        echo "📄 $line_to_add found in $rc_file, no need to add"
    else
        echo "📝 adding $line_to_add to $rc_file"
        echo "$line_to_add" >>"$rc_file"
    fi
}

remove_from_rc_if_present() {
    local rc_file="${1/#\~/$HOME}"
    local line_to_remove="$2"
    if [ -f "$rc_file" ] && grep -Fq "$line_to_remove" "$rc_file"; then
        echo "🧽 removing line from $rc_file: $line_to_remove"
        # Create a temp file safely
        tmp_file="${rc_file}.tmp.$$"
        grep -Fv "$line_to_remove" "$rc_file" >"$tmp_file" || true
        mv "$tmp_file" "$rc_file"
    fi
}

# Get the latest nvm tag from GitHub (falls back silently on failure)
latest_nvm_tag() {
    git ls-remote --tags https://github.com/nvm-sh/nvm.git 2>/dev/null \
      | awk -F/ '/refs\/tags\/v[0-9]/{print $3}' \
      | sed 's/\^{}//' \
      | sort -V \
      | tail -n1
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
        cp -a "$src" "$dest"
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
    git config --global init.defaultBranch main
    git config --global push.autoSetupRemote true
    git config --global fetch.prune true
    git config --global diff.colorMoved zebra
fi

### === Optional Tools Install ===
if $UNINSTALL_MODE && ! $DRY_RUN; then
    echo -e "\n🧹 Uninstalling dotfiles symlinks and shell rc additions..."
    # Remove symlinks we manage if they point to our repo
    for i in "${!SYMLINK_KEYS[@]}"; do
        dest="${SYMLINK_KEYS[$i]}"
        src="${SYMLINK_VALUES[$i]}"
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            echo "🗑️  Removing symlink $dest"
            rm -f "$dest"
        fi
    done
    # Remove startup additions (guarded lines)
    for rc in ~/.zshrc ~/.bashrc; do
        remove_from_rc_if_present "$rc" "[[ -f ~/.shell_aliases ]] && source ~/.shell_aliases"
        remove_from_rc_if_present "$rc" "[[ -f ~/.shell_functions ]] && source ~/.shell_functions"
        remove_from_rc_if_present "$rc" "[[ -f ~/.git_aliases ]] && source ~/.git_aliases"
        remove_from_rc_if_present "$rc" "[[ -f ~/.git_functions ]] && source ~/.git_functions"
        remove_from_rc_if_present "$rc" "[[ -f ~/.history_settings ]] && source ~/.history_settings"
        remove_from_rc_if_present "$rc" "[[ -f ~/.omp_init ]] && source ~/.omp_init"
        remove_from_rc_if_present "$rc" "[[ \$- == *i* ]] && nice_print_aliases"
        remove_from_rc_if_present "$rc" "[[ \$- == *i* ]] && fastfetch 2>/dev/null"
        remove_from_rc_if_present "$rc" "[[ \$- == *i* ]] && screenfetch 2>/dev/null"
        remove_from_rc_if_present "$rc" "[[ \$- == *i* ]] && eval \"\$(zoxide init zsh)\""
        remove_from_rc_if_present "$rc" "[[ \$- == *i* ]] && eval \"\$(zoxide init bash)\""
        remove_from_rc_if_present "$rc" "source /usr/share/fzf/key-bindings.bash"
        remove_from_rc_if_present "$rc" "source /usr/share/fzf/completion.bash"
        remove_from_rc_if_present "$rc" "source /usr/share/fzf/key-bindings.zsh"
        remove_from_rc_if_present "$rc" "source /usr/share/fzf/completion.zsh"
        # nvm
        remove_from_rc_if_present "$rc" 'export NVM_DIR="$HOME/.nvm"'
        remove_from_rc_if_present "$rc" '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
        remove_from_rc_if_present "$rc" '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
    done
fi

### === Optional Tools Install ===
if ! $MINIMAL_MODE && ! $DRY_RUN; then
    if $INSTALL_ALL; then
        do_install="y"
    else
        read -p $'\n✨ Install optional tools? (fzf, eza, bat, zoxide, oh-my-posh, nano, fd, ripgrep, uv, swiftly)? [y/N]: ' do_install
    fi

    if [[ "$do_install" =~ ^[Yy]$ ]]; then
        echo -e "\n📦 Installing tools..."

        case "$OS" in
        Darwin)
            if ! command -v brew >/dev/null; then
                echo "🍺 Homebrew not found. Installing..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                # Initialize Homebrew in current session and future shells
                if [ -x /opt/homebrew/bin/brew ]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                    add_to_rc_if_not_present "~/.zprofile" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
                    add_to_rc_if_not_present "~/.bash_profile" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
                elif [ -x /usr/local/bin/brew ]; then
                    eval "$(/usr/local/bin/brew shellenv)"
                    add_to_rc_if_not_present "~/.zprofile" 'eval "$(/usr/local/bin/brew shellenv)"'
                    add_to_rc_if_not_present "~/.bash_profile" 'eval "$(/usr/local/bin/brew shellenv)"'
                fi
            fi

            # Install standard tools only if missing
            for pkg in fzf eza bat zoxide exiv2 fastfetch nano fd ripgrep uv; do
                if ! brew list "$pkg" >/dev/null 2>&1; then
                    echo "📦 Installing $pkg..."
                    brew install "$pkg"
                else
                    echo "✅ $pkg already installed"
                fi
            done

            # Install oh-my-posh only if not present (works whether installed via formula or cask)
            if command -v oh-my-posh >/dev/null 2>&1; then
                echo "✅ oh-my-posh already installed"
            else
                echo "📦 Installing oh-my-posh from tap..."
                brew install jandedobbeleer/oh-my-posh/oh-my-posh
            fi
            # fzf keybindings/completions (Homebrew layout)
            if $INSTALL_ALL || $FORCE_MODE; then configure_fzf="y"; else read -p $'\n🎹 Enable fzf keybindings and completions? [y/N]: ' configure_fzf; fi
            if [[ "$configure_fzf" =~ ^[Yy]$ ]]; then
                echo "⚙️  Configuring fzf keybindings/completions..."
                "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc || true
                zsh_bind="$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"
                zsh_comp="$(brew --prefix)/opt/fzf/shell/completion.zsh"
                bash_bind="$(brew --prefix)/opt/fzf/shell/key-bindings.bash"
                bash_comp="$(brew --prefix)/opt/fzf/shell/completion.bash"
                if [[ "$SHELL_NAME" == "zsh" ]]; then
                    if [ -f "$zsh_bind" ]; then add_to_rc_if_not_present "~/.zshrc" "source $zsh_bind"; fi
                    if [ -f "$zsh_comp" ]; then add_to_rc_if_not_present "~/.zshrc" "source $zsh_comp"; fi
                else
                    if [ -f "$bash_bind" ]; then add_to_rc_if_not_present "~/.bashrc" "source $bash_bind"; fi
                    if [ -f "$bash_comp" ]; then add_to_rc_if_not_present "~/.bashrc" "source $bash_comp"; fi
                fi
            fi

            # swiftly (Swift toolchain manager)
            if command -v swiftly >/dev/null 2>&1; then
                echo "✅ swiftly already installed"
            else
                echo "📦 Installing swiftly (Swift toolchain manager)..."
                if brew install swiftly; then
                    :
                else
                    echo "⚠️  Homebrew install for swiftly failed. Falling back to official installer."
                    echo "   Note: piping install scripts is potentially unsafe. Review https://swiftlang.github.io/swiftly/ before proceeding."
                    curl -fsSL https://swiftlang.github.io/swiftly/install.sh | bash
                fi
            fi

            # Optional: install latest Python via uv
            if command -v uv >/dev/null 2>&1; then
                if $INSTALL_ALL || $FORCE_MODE; then uv_install_py="y"; else read -p $'🐍 Install latest Python via uv? [y/N]: ' uv_install_py; fi
                if [[ "$uv_install_py" =~ ^[Yy]$ ]]; then
                    uv python install --latest || true
                fi
            fi

            # Optional: install latest stable Swift toolchain via swiftly
            if command -v swiftly >/dev/null 2>&1; then
                if $INSTALL_ALL || $FORCE_MODE; then sw_install_tc="y"; else read -p $'🦅 Install latest stable Swift toolchain via swiftly? [y/N]: ' sw_install_tc; fi
                if [[ "$sw_install_tc" =~ ^[Yy]$ ]]; then
                    swiftly install stable || true
                fi
            fi
            ;;
        Linux)
            echo "🐧 Detected Linux; targeting Debian/Ubuntu via apt"
            sudo apt update
            sudo apt install -y fzf bat zoxide curl unzip ripgrep fd-find nano exiv2 gnupg || true

            # eza
            if ! command -v eza >/dev/null; then
                echo "📥 Installing eza (apt or manual)..."
                if ! sudo apt install -y eza; then
                    arch=$(dpkg --print-architecture 2>/dev/null || echo amd64)
                    echo "   apt eza unavailable; attempting manual .deb for $arch"
                    curl -LO "https://github.com/eza-community/eza/releases/latest/download/eza_${arch}.deb"
                    sudo dpkg -i "eza_${arch}.deb" || true
                    rm -f "eza_${arch}.deb"
                fi
            fi

            # oh-my-posh
            if ! command -v oh-my-posh >/dev/null; then
                echo "📥 Installing oh-my-posh..."
                echo "   Note: piping install scripts is potentially unsafe. Review https://ohmyposh.dev before proceeding."
                curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
            fi

            # fastfetch
            if ! command -v fastfetch >/dev/null; then
                echo "📥 Installing fastfetch..."
                sudo apt install -y fastfetch || {
                    echo "⚠️ fastfetch not available via apt. You can build it manually:"
                    echo "   https://github.com/fastfetch-cli/fastfetch"
                }
            fi

            # handle batcat/bat and fdfind/fd shims
            if command -v batcat >/dev/null && ! command -v bat >/dev/null; then
                sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
                echo "🔗 Created shim: bat -> batcat"
            fi
            if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
                sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
                echo "🔗 Created shim: fd -> fdfind"
            fi

            # uv (Python tool)
            if ! command -v uv >/dev/null 2>&1; then
                echo "📥 Installing uv (Python tooling)..."
                echo "   Note: piping install scripts is potentially unsafe. Review https://astral.sh/uv before proceeding."
                curl -LsSf https://astral.sh/uv/install.sh | sh
            else
                echo "✅ uv already installed"
            fi

            # swiftly (Swift toolchain manager)
            # Try to source existing env so detection works even if not on PATH yet
            swiftly_home="${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}"
            swiftly_env="$swiftly_home/env.sh"
            swiftly_bin="$swiftly_home/bin/swiftly"
            if [ -f "$swiftly_env" ]; then . "$swiftly_env"; fi
            if ! command -v swiftly >/dev/null 2>&1 && [ ! -x "$swiftly_bin" ]; then
                echo "📥 Installing swiftly (Swift toolchain manager)..."
                # Ensure GnuPG is available for signature verification required by swiftly
                if ! command -v gpg >/dev/null 2>&1; then
                    echo "   ↪ Installing gnupg (required by swiftly)..."
                    sudo apt install -y gnupg || true
                fi
                arch="$(uname -m)"
                url="https://download.swift.org/swiftly/linux/swiftly-${arch}.tar.gz"
                tmpdir="$(mktemp -d)"
                (
                    set -e
                    cd "$tmpdir"
                    echo "   ↪ Downloading $url"
                    curl -fLO "$url"
                    tar zxf "swiftly-${arch}.tar.gz"
                    ./swiftly init --quiet-shell-followup --skip-install
                ) && {
                    env_file="$swiftly_env"
                    if [ -f "$env_file" ]; then . "$env_file"; fi
                    hash -r || true
                    echo "✅ swiftly installed"
                } || {
                    if ! command -v gpg >/dev/null 2>&1; then
                        echo "⚠️  swiftly failed and 'gpg' is missing. Install it with: sudo apt install -y gnupg"
                    fi
                    echo "⚠️  swiftly installation failed. See https://www.swift.org/install/linux/ for manual steps."
                }
                rm -rf "$tmpdir"
            else
                echo "✅ swiftly already installed"
            fi

            # Ensure current session can find freshly installed user binaries
            if [ -x "$HOME/.local/bin/uv" ]; then export PATH="$HOME/.local/bin:$PATH"; fi
            if [ -f "$swiftly_env" ]; then . "$swiftly_env"; fi

            # Optional: install latest Python via uv
            if command -v uv >/dev/null 2>&1; then
                if $INSTALL_ALL || $FORCE_MODE; then uv_install_py="y"; else read -p $'🐍 Install latest Python via uv? [y/N]: ' uv_install_py; fi
                if [[ "$uv_install_py" =~ ^[Yy]$ ]]; then
                    uv python install --latest || true
                fi
            fi

            # Optional: install latest stable Swift toolchain via swiftly
            if command -v swiftly >/dev/null 2>&1; then
                if $INSTALL_ALL || $FORCE_MODE; then sw_install_tc="y"; else read -p $'🦅 Install latest stable Swift toolchain via swiftly? [y/N]: ' sw_install_tc; fi
                if [[ "$sw_install_tc" =~ ^[Yy]$ ]]; then
                    swiftly install stable || true
                fi
            fi
            ;;
        *)
            echo "❌ Unsupported OS. Install dependencies manually."
            ;;
        esac
    fi
fi

### === Optional NVM Install ===
if ! $MINIMAL_MODE && ! $DRY_RUN; then
    if $FORCE_MODE; then want_nvm="y"; else read -p $'\n🟢 Install/Update nvm (Node Version Manager)? [y/N]: ' want_nvm; fi
    if [[ "$want_nvm" =~ ^[Yy]$ ]]; then
        NVM_TAG=$(latest_nvm_tag || true)
        if [ -z "${NVM_TAG:-}" ]; then NVM_TAG="v0.39.7"; fi

        if [ -d "$HOME/.nvm/.git" ]; then
            echo "🔄 Updating existing nvm to $NVM_TAG..."
            git -C "$HOME/.nvm" fetch --tags origin || true
            git -C "$HOME/.nvm" checkout "$NVM_TAG" || true
        else
            echo "📦 Installing nvm ($NVM_TAG)..."
            # Use official installer pinned to the resolved tag
            curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_TAG/install.sh" | bash
        fi

        # Ensure nvm is initialized for the current shell; avoid touching rc of other shells
        if [[ "$SHELL_NAME" == "zsh" ]]; then
            add_to_rc_if_not_present "~/.zshrc" 'export NVM_DIR="$HOME/.nvm"'
            add_to_rc_if_not_present "~/.zshrc" '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
            add_to_rc_if_not_present "~/.zshrc" '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
        else
            add_to_rc_if_not_present "~/.bashrc" 'export NVM_DIR="$HOME/.nvm"'
            add_to_rc_if_not_present "~/.bashrc" '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
            add_to_rc_if_not_present "~/.bashrc" '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
        fi

        # Initialize nvm in current session if possible
        export NVM_DIR="$HOME/.nvm"
        if [ -s "$NVM_DIR/nvm.sh" ]; then . "$NVM_DIR/nvm.sh"; fi
        if [ -s "$NVM_DIR/bash_completion" ]; then . "$NVM_DIR/bash_completion"; fi

        # Determine current and latest LTS versions (best-effort)
        current_node="$(nvm version current 2>/dev/null || echo none)"
        remote_lts="$(nvm version-remote --lts 2>/dev/null || echo '')"

        if [[ "$current_node" != "none" && "$current_node" != "system" ]]; then
            # User already has a Node version active via nvm → offer to switch
            if $FORCE_MODE || $INSTALL_ALL; then
                switch_to_lts="y"
            else
                read -p $'\n🌳 Detected Node '"$current_node"$' active via nvm.'$'\n'\
$'   Switch to latest LTS'"${remote_lts:+ ($remote_lts)}"$' and set as default?\n'\
$'   Heads-up: global npm packages are per-Node-version and will not move automatically.\n'\
$'   You can later migrate with: nvm reinstall-packages '"$current_node"$'\n'\
$'   Proceed? [y/N]: ' switch_to_lts
            fi
            if [[ "$switch_to_lts" =~ ^[Yy]$ ]]; then
                prev_node="$current_node"
                nvm install --lts || true
                nvm alias default 'lts/*' || true
                nvm use --lts || true
                # Optionally enable Corepack for yarn/pnpm shims (non-fatal if missing)
                if command -v corepack >/dev/null 2>&1; then corepack enable || true; fi
                echo "ℹ️  Tip: to copy your global packages, run: nvm reinstall-packages $prev_node"
            fi
        else
            # No active Node via nvm → offer to install latest LTS and set default
            if $FORCE_MODE || $INSTALL_ALL; then install_node="y"; else read -p $'🌱 Install latest LTS Node via nvm and set default? [y/N]: ' install_node; fi
            if [[ "$install_node" =~ ^[Yy]$ ]]; then
                nvm install --lts && nvm alias default 'lts/*'
                # Optionally enable Corepack for yarn/pnpm shims (non-fatal if missing)
                if command -v corepack >/dev/null 2>&1; then corepack enable || true; fi
            fi
        fi
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
            # Ensure ~/.local/bin is on PATH for user-installed tools (uv, swiftly, etc.)
            add_to_rc_if_not_present "~/.zshrc" '[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"'
            # Ensure swiftly env (adds swiftly bin to PATH) is sourced if present
            add_to_rc_if_not_present "~/.zshrc" '[[ -f "$HOME/.local/share/swiftly/env.sh" ]] && . "$HOME/.local/share/swiftly/env.sh"'
            # De-duplicate PATH entries (zsh-native)
            add_to_rc_if_not_present "~/.zshrc" '# PATH de-dup (dotfiles installer)'
            add_to_rc_if_not_present "~/.zshrc" 'typeset -U path'

            if ! ${SKIP_FETCH:-false}; then
              if $FORCE_MODE; then
                reply="y"
              else
                read -p "🧠 Run nice_print_aliases at shell startup? [y/N]: " reply
              fi
              if [[ "$reply" =~ ^[Yy]$ ]]; then
                  add_to_rc_if_not_present "~/.zshrc" "[[ \$- == *i* ]] && nice_print_aliases"
              fi

              if $FORCE_MODE; then
                  reply="y"
              else
                  read -p "🖼️  Run $FETCH_CMD at shell startup? [y/N]: " reply
              fi
              if [[ "$reply" =~ ^[Yy]$ ]]; then
                  add_to_rc_if_not_present "~/.zshrc" "[[ \$- == *i* ]] && $FETCH_CMD"
              fi
            fi

            # zoxide init
            if command -v zoxide >/dev/null 2>&1; then
                add_to_rc_if_not_present "~/.zshrc" "[[ \$- == *i* ]] && eval \"\$(zoxide init zsh)\""
            fi
            # fzf keybindings/completions (Linux layout)
            if [ -f /usr/share/fzf/key-bindings.zsh ]; then
                add_to_rc_if_not_present "~/.zshrc" "source /usr/share/fzf/key-bindings.zsh"
            fi
            if [ -f /usr/share/fzf/completion.zsh ]; then
                add_to_rc_if_not_present "~/.zshrc" "source /usr/share/fzf/completion.zsh"
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
        echo '[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"' >>~/.zshrc
        echo '[[ -f "$HOME/.local/share/swiftly/env.sh" ]] && . "$HOME/.local/share/swiftly/env.sh"' >>~/.zshrc
        echo '# PATH de-dup (dotfiles installer)' >>~/.zshrc
        echo 'typeset -U path' >>~/.zshrc

        if ! ${SKIP_FETCH:-false}; then
          if $FORCE_MODE; then
              reply="y"
          else
              read -p "🧠 Run nice_print_aliases at shell startup? [y/N]: " reply
          fi
          if [[ "$reply" =~ ^[Yy]$ ]]; then
              add_to_rc_if_not_present "~/.zshrc" "[[ \$- == *i* ]] && nice_print_aliases"
          fi

          if $FORCE_MODE; then
              reply="y"
          else
              read -p "🖼️  Run $FETCH_CMD at shell startup? [y/N]: " reply
          fi
          if [[ "$reply" =~ ^[Yy]$ ]]; then
              add_to_rc_if_not_present "~/.zshrc" "[[ \$- == *i* ]] && $FETCH_CMD"
          fi
        fi

        if command -v zoxide >/dev/null 2>&1; then
            add_to_rc_if_not_present "~/.zshrc" "[[ \$- == *i* ]] && eval \"\$(zoxide init zsh)\""
        fi
        if [ -f /usr/share/fzf/key-bindings.zsh ]; then
            add_to_rc_if_not_present "~/.zshrc" "source /usr/share/fzf/key-bindings.zsh"
        fi
        if [ -f /usr/share/fzf/completion.zsh ]; then
            add_to_rc_if_not_present "~/.zshrc" "source /usr/share/fzf/completion.zsh"
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
            # Ensure ~/.local/bin is on PATH for user-installed tools (uv, swiftly, etc.)
            add_to_rc_if_not_present "~/.bashrc" '[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"'
            # Ensure swiftly env (adds swiftly bin to PATH) is sourced if present
            add_to_rc_if_not_present "~/.bashrc" '[[ -f "$HOME/.local/share/swiftly/env.sh" ]] && . "$HOME/.local/share/swiftly/env.sh"'
            # De-duplicate PATH entries (awk-based with absolute paths; bash/posix)
            add_to_rc_if_not_present "~/.bashrc" '# PATH de-dup (dotfiles installer)'
            add_to_rc_if_not_present "~/.bashrc" '[ -x /usr/bin/awk ] && [ -x /usr/bin/paste ] && [ -x /usr/bin/tr ] && PATH="$([ -x /usr/bin/printf ] && /usr/bin/printf %s "$PATH" | /usr/bin/tr ":" "\n" | /usr/bin/awk '\''!seen[$0]++'\'' | /usr/bin/paste -sd:)" && export PATH'

            if ! ${SKIP_FETCH:-false}; then
              if $FORCE_MODE; then
                  reply="y"
              else
                  read -p "🧠 Run nice_print_aliases at shell startup? [y/N]: " reply
              fi
              if [[ "$reply" =~ ^[Yy]$ ]]; then
                  add_to_rc_if_not_present "~/.bashrc" "[[ \$- == *i* ]] && nice_print_aliases"
              fi

              if $FORCE_MODE; then
                  reply="y"
              else
                  read -p "🖼️  Run $FETCH_CMD at shell startup? [y/N]: " reply
              fi
              if [[ "$reply" =~ ^[Yy]$ ]]; then
                  add_to_rc_if_not_present "~/.bashrc" "[[ \$- == *i* ]] && $FETCH_CMD"
              fi
            fi

            if command -v zoxide >/dev/null 2>&1; then
                add_to_rc_if_not_present "~/.bashrc" "[[ \$- == *i* ]] && eval \"\$(zoxide init bash)\""
            fi
            # fzf keybindings/completions
            if [ -f /usr/share/fzf/key-bindings.bash ]; then
                add_to_rc_if_not_present "~/.bashrc" "source /usr/share/fzf/key-bindings.bash"
            fi
            if [ -f /usr/share/fzf/completion.bash ]; then
                add_to_rc_if_not_present "~/.bashrc" "source /usr/share/fzf/completion.bash"
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
        echo '[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
        echo '[[ -f "$HOME/.local/share/swiftly/env.sh" ]] && . "$HOME/.local/share/swiftly/env.sh"' >>~/.bashrc
        echo '# PATH de-dup (dotfiles installer)' >>~/.bashrc
        echo '[ -x /usr/bin/awk ] && [ -x /usr/bin/paste ] && [ -x /usr/bin/tr ] && PATH="$([ -x /usr/bin/printf ] && /usr/bin/printf %s "$PATH" | /usr/bin/tr ":" "\n" | /usr/bin/awk '\''!seen[$0]++'\'' | /usr/bin/paste -sd:)" && export PATH' >>~/.bashrc

        if ! ${SKIP_FETCH:-false}; then
          if $FORCE_MODE; then
              reply="y"
          else
              read -p "🧠 Run nice_print_aliases at shell startup? [y/N]: " reply
          fi
          if [[ "$reply" =~ ^[Yy]$ ]]; then
              add_to_rc_if_not_present "~/.bashrc" "[[ \$- == *i* ]] && nice_print_aliases"
          fi

          if $FORCE_MODE; then
              reply="y"
          else
              read -p "🖼️  Run $FETCH_CMD at shell startup? [y/N]: " reply
          fi
          if [[ "$reply" =~ ^[Yy]$ ]]; then
          add_to_rc_if_not_present "~/.bashrc" "[[ \$- == *i* ]] && $FETCH_CMD"
          fi
        fi

        if command -v zoxide >/dev/null 2>&1; then
            add_to_rc_if_not_present "~/.bashrc" "[[ \$- == *i* ]] && eval \"\$(zoxide init bash)\""
        fi
        if [ -f /usr/share/fzf/key-bindings.bash ]; then
            add_to_rc_if_not_present "~/.bashrc" "source /usr/share/fzf/key-bindings.bash"
        fi
        if [ -f /usr/share/fzf/completion.bash ]; then
            add_to_rc_if_not_present "~/.bashrc" "source /usr/share/fzf/completion.bash"
        fi
    fi
fi

if $CLEAN_BACKUPS; then
    echo -e "\n🧹 Looking for backup files to remove in $HOME..."
    BACKUPS=()
    for file in "$HOME"/*.bak.*; do
        [ -e "$file" ] || continue
        BACKUPS+=("$file")
    done

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
