#!/usr/bin/env bash
# shellcheck disable=SC2034 # This sourced module mutates installer state.

parse_installer_args() {
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
            -cb | --clean-backups) CLEAN_BACKUPS=true ;;
            -y | --yes) YES_MODE=true ;;
            -f | --force)
                # Backward-compatible alias. New scripts should use --all --yes.
                FORCE_MODE=true
                YES_MODE=true
                ;;
            -m | --minimal) MINIMAL_MODE=true ;;
            --skip-tools) SKIP_TOOLS=true ;;
            --brew-upgrade) BREW_UPGRADE=true ;;
            --sync) SYNC_MODE=true ;;
            --trust-brew-taps) TRUST_BREW_TAPS=true ;;
            -h | --help) SHOW_HELP=true ;;
            -a | --all) INSTALL_ALL=true ;;
            --uninstall) UNINSTALL_MODE=true ;;
            *)
                echo "❌ Unknown argument: $arg" >&2
                return 2
                ;;
        esac
    done
}

show_installer_help() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  -dr, --dry-run         Preview actions without modifying files
  -c,  --copy            Copy files instead of symlinking
  -y,  --yes             Answer yes to prompts for selected operations
  -a,  --all             Select all optional components
  -f,  --force           Deprecated alias for --all --yes
  -m,  --minimal         Install core dotfiles only
      --skip-tools        Skip package managers and optional tools
      --brew-upgrade      Upgrade Brewfile dependencies on macOS
      --sync              Reconcile dotfiles and Git defaults only
      --trust-brew-taps   Trust third-party taps declared in the Brewfile
  -cb, --clean-backups   Offer to remove installer-recorded backups
      --uninstall        Remove managed links and restore managed settings
  -h,  --help            Show this help message
EOF
}

validate_installer_modes() {
    if $SYNC_MODE && { $MINIMAL_MODE || $INSTALL_ALL || $YES_MODE || $FORCE_MODE || $BREW_UPGRADE || $CLEAN_BACKUPS || $TRUST_BREW_TAPS; }; then
        echo "❌ --sync cannot be combined with --minimal, --all, --yes, --force, --brew-upgrade, --clean-backups, or --trust-brew-taps." >&2
        return 2
    fi

    if $UNINSTALL_MODE && { $COPY_MODE || $MINIMAL_MODE || $SKIP_TOOLS || $BREW_UPGRADE || $INSTALL_ALL || $SYNC_MODE || $TRUST_BREW_TAPS; }; then
        echo "❌ --uninstall cannot be combined with installation-only options." >&2
        return 2
    fi

    if $FORCE_MODE && ! $UNINSTALL_MODE; then
        INSTALL_ALL=true
    fi

    if $MINIMAL_MODE; then
        INSTALL_ALL=false
        SKIP_GIT_CONFIG=true
        SKIP_FETCH=true
        SKIP_TOOLS=true
    fi

    if $SYNC_MODE; then
        SKIP_TOOLS=true
        SKIP_FETCH=true
    fi
}
