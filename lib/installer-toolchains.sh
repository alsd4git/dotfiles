#!/usr/bin/env bash

offer_github_authentication() {
    if ! command -v gh >/dev/null 2>&1; then return 0; fi
    if gh auth status --hostname github.com >/dev/null 2>&1; then
        echo "✅ GitHub CLI is already authenticated on github.com"
        return 0
    fi
    if [ "${DOTFILES_TEST_INTERACTIVE:-false}" != true ] && { [ ! -t 0 ] || [ ! -t 1 ]; }; then
        echo "ℹ️  gh is not authenticated. Run 'gh auth login' from an interactive shell when ready."
        return 0
    fi
    local configure_gh_auth
    read -r -p $'\n🐙 Authenticate GitHub CLI with gh auth login? [y/N]: ' configure_gh_auth || return 0
    if [[ ! "$configure_gh_auth" =~ ^[Yy]$ ]]; then
        echo "ℹ️  Skipping GitHub CLI authentication. Run 'gh auth login' later when ready."
        return 0
    fi
    if gh auth login; then
        echo "✅ GitHub CLI authentication completed."
        echo "ℹ️  Configure Git to use gh credentials with: gh auth setup-git"
        echo "ℹ️  Add an SSH authentication key with: gh ssh-key add ~/.ssh/<key>.pub --type authentication"
        echo "ℹ️  Add an SSH signing key with: gh ssh-key add ~/.ssh/<key>.pub --type signing"
        echo "ℹ️  Add a GPG signing key with: gh gpg-key add <public-key-file>"
    else
        echo "⚠️  GitHub CLI authentication was not completed; you can retry with: gh auth login"
    fi
}

run_nvm() {
    local status
    set +u
    if nvm "$@"; then status=0; else status=$?; fi
    set -u
    return "$status"
}

offer_nvm_global_package_migration() {
    local previous_node="$1" target_node migrate_packages
    target_node="$(run_nvm version current 2>/dev/null || echo none)"
    if [ "$target_node" = "$previous_node" ] || [ "$target_node" = none ] || [ "$target_node" = system ]; then
        return 0
    fi
    echo "ℹ️  Global npm packages are scoped to each nvm Node version."
    echo "   Current target: $target_node"
    echo "   Source version: $previous_node"
    if $YES_MODE || $INSTALL_ALL || { [ "${DOTFILES_TEST_INTERACTIVE:-false}" != true ] && { [ ! -t 0 ] || [ ! -t 1 ]; }; }; then
        echo "ℹ️  Skipping package migration in non-interactive/automatic mode."
        echo "   Run when ready: nvm use $target_node && nvm reinstall-packages $previous_node"
        return 0
    fi
    read -r -p $'📦 Migrate global npm packages to the new Node version with nvm reinstall-packages? [y/N]: ' migrate_packages || return 0
    if [[ "$migrate_packages" =~ ^[Yy]$ ]]; then
        if run_nvm reinstall-packages "$previous_node"; then
            echo "✅ Global npm packages migrated from $previous_node to $target_node"
        else
            echo "⚠️  Global npm package migration failed; retry with: nvm use $target_node && nvm reinstall-packages $previous_node"
        fi
    else
        echo "ℹ️  Skipping package migration. Run when ready: nvm use $target_node && nvm reinstall-packages $previous_node"
    fi
}

ensure_local_bin_on_path() {
    if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

install_uv_python_version() {
    if uv python install --preview --default "$UV_PYTHON_VERSION"; then
        ensure_local_bin_on_path
        return 0
    fi
    echo "⚠️  uv default executables require preview mode; falling back to Python $UV_PYTHON_VERSION without default executables."
    uv python install "$UV_PYTHON_VERSION" || true
    ensure_local_bin_on_path
}
