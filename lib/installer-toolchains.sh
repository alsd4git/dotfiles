#!/usr/bin/env bash
# shellcheck disable=SC2034 # Selection state is consumed by install.sh.

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

latest_semver_tag() {
    awk '
        /^v[0-9]+\.[0-9]+\.[0-9]+$/ {
            split(substr($0, 2), version, ".")
            if (!found || version[1] + 0 > major ||
                (version[1] + 0 == major && version[2] + 0 > minor) ||
                (version[1] + 0 == major && version[2] + 0 == minor && version[3] + 0 > patch)) {
                found = 1
                major = version[1] + 0
                minor = version[2] + 0
                patch = version[3] + 0
                latest = $0
            }
        }
        END { if (found) print latest }
    '
}

resolve_latest_nvm_remote_tag() {
    git ls-remote --tags --refs https://github.com/nvm-sh/nvm.git 'refs/tags/v[0-9]*' 2>/dev/null \
        | awk '{ sub("refs/tags/", "", $2); print $2 }' \
        | latest_semver_tag
}

prepare_nvm_release_update() {
    local nvm_dir="$1"
    local configured_tag="$2"
    local current_tag latest_tag update_nvm

    NVM_SELECTED_TAG="$configured_tag"
    NVM_RELEASE_UPDATE_APPROVED=true

    if ! git -C "$nvm_dir" fetch --tags origin; then
        echo "⚠️  Could not fetch NVM release tags; keeping the installed version."
        NVM_RELEASE_UPDATE_APPROVED=false
        return 0
    fi
    if [ -n "$configured_tag" ]; then
        return 0
    fi
    latest_tag=$(git -C "$nvm_dir" tag --list 'v[0-9]*' 2>/dev/null | latest_semver_tag)
    if [ -z "$latest_tag" ]; then
        echo "⚠️  Could not determine the latest NVM release; keeping the installed version."
        NVM_RELEASE_UPDATE_APPROVED=false
        return 0
    fi
    NVM_SELECTED_TAG="$latest_tag"
    if $YES_MODE || $INSTALL_ALL; then
        return 0
    fi
    if [ "${DOTFILES_TEST_INTERACTIVE:-false}" != true ] && { [ ! -t 0 ] || [ ! -t 1 ]; }; then
        return 0
    fi

    current_tag=$(git -C "$nvm_dir" describe --tags --exact-match HEAD 2>/dev/null || echo unknown)
    if [ "$current_tag" = "$latest_tag" ]; then
        echo "✅ NVM $current_tag is already the latest release."
        NVM_RELEASE_UPDATE_APPROVED=false
        return 0
    fi

    printf '\n🟢 NVM %s is installed. Update to %s? [y/N]: ' "$current_tag" "$latest_tag"
    read -r update_nvm || update_nvm=n
    if [[ "$update_nvm" =~ ^[Yy]$ ]]; then
        return 0
    else
        echo "ℹ️  Keeping NVM $current_tag."
        NVM_RELEASE_UPDATE_APPROVED=false
    fi
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
