#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

DRY_RUN=false
RESTART=false
SHOW_HELP=false
TRACKPAD_DOMAINS=(
    com.apple.AppleMultitouchTrackpad
    com.apple.driver.AppleBluetoothMultitouch.trackpad
)

usage() {
    cat <<'EOF'
Usage: ./macos/defaults.sh [options]

Options:
  -n, --dry-run   Print the macOS defaults that would be applied.
      --restart   Restart Finder and Dock after applying defaults.
  -h, --help      Show this help message.
EOF
}

for arg in "$@"; do
    case "$arg" in
        -n | --dry-run)
            DRY_RUN=true
            ;;
        --restart)
            RESTART=true
            ;;
        -h | --help)
            SHOW_HELP=true
            ;;
        *)
            echo "❓ Unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

if $SHOW_HELP; then
    usage
    exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "❌ macOS defaults can only be applied on Darwin hosts." >&2
    exit 1
fi

run_cmd() {
    if $DRY_RUN; then
        printf '🧪 Would run:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

write_trackpad_bool() {
    local key="$1"
    local value="$2"

    for domain in "${TRACKPAD_DOMAINS[@]}"; do
        run_cmd defaults write "$domain" "$key" -bool "$value"
    done
}

echo "🍎 Applying recommended macOS defaults..."

run_cmd mkdir -p "$HOME/Pictures/Screenshots"
run_cmd defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
run_cmd defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
run_cmd defaults write NSGlobalDomain AppleShowAllExtensions -bool true
run_cmd defaults write NSGlobalDomain com.apple.springing.enabled -bool true
run_cmd defaults write NSGlobalDomain com.apple.springing.delay -float 0.5
run_cmd defaults write NSGlobalDomain com.apple.swipescrolldirection -bool true
run_cmd defaults write com.apple.finder ShowPathbar -bool true
run_cmd defaults write com.apple.finder ShowStatusBar -bool true
run_cmd defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
run_cmd defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
run_cmd defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
run_cmd defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
run_cmd defaults write com.apple.dock tilesize -int 62
run_cmd defaults write com.apple.dock magnification -bool true
run_cmd defaults write com.apple.dock largesize -int 93
run_cmd defaults write com.apple.dock show-recents -bool false
run_cmd defaults write com.apple.dock autohide -bool false
write_trackpad_bool Clicking true
write_trackpad_bool TrackpadThreeFingerDrag true
write_trackpad_bool Dragging true
write_trackpad_bool DragLock false
run_cmd defaults write NSGlobalDomain com.apple.trackpad.forceClick -bool true
run_cmd defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
run_cmd defaults write com.apple.screencapture type -string png

if $RESTART; then
    if $DRY_RUN; then
        echo "🧪 Would restart Finder and Dock"
    else
        killall Finder Dock >/dev/null 2>&1 || true
    fi
fi

echo "✅ macOS defaults applied"
