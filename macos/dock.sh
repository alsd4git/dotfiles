#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

DRY_RUN=false
RESTART=false
SHOW_HELP=false

usage() {
    cat <<'EOF'
Usage: ./macos/dock.sh [options]

Options:
  -n, --dry-run   Print the Dock operations that would be applied.
      --restart   Restart the Dock after applying the layout.
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
    echo "❌ Dock layout can only be applied on Darwin hosts." >&2
    exit 1
fi

if ! command -v dockutil >/dev/null 2>&1; then
    echo "❌ dockutil not found. Install Homebrew packages first." >&2
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

add_app() {
    local path="$1"
    local label="${2:-}"

    if [[ ! -e "$path" ]]; then
        echo "⚠️  Skipping missing Dock app: $path" >&2
        return 0
    fi

    if [[ -n "$label" ]]; then
        run_cmd dockutil --add "$path" --label "$label" --section apps --no-restart
    else
        run_cmd dockutil --add "$path" --section apps --no-restart
    fi
}

add_other() {
    local path="$1"
    local display="$2"

    if [[ ! -e "$path" ]]; then
        echo "⚠️  Skipping missing Dock item: $path" >&2
        return 0
    fi

    run_cmd dockutil --add "$path" --section others --view grid --display "$display" --no-restart
}

echo "🧷 Applying saved Dock layout..."

run_cmd dockutil --remove all --no-restart

add_app "/System/Applications/Apps.app" "App"
add_app "/Applications/Google Chrome.app"
add_app "/System/Applications/Mail.app"
add_app "/System/Applications/Notes.app"
add_app "/System/Applications/System Settings.app"
add_app "/Applications/ChatGPT.app"
add_app "/Applications/Codex.app"
add_app "/Applications/Codex (Beta).app"
add_app "/Applications/ChatGPT Atlas.app"
add_app "/Applications/Visual Studio Code.app"
add_app "/Applications/Microsoft Teams.app"
add_app "/Applications/Warp.app"
add_app "/Applications/Telegram.app"
add_app "/Applications/Postman.app"
add_app "/Applications/MongoDB Compass.app"
add_app "/Applications/Sublime Merge.app"
add_app "/Applications/Beekeeper Studio.app"

add_other "/Applications/" "folder"
add_other "$HOME/Downloads" "stack"

if $RESTART; then
    if $DRY_RUN; then
        echo "🧪 Would restart the Dock"
    else
        killall Dock >/dev/null 2>&1 || true
    fi
fi

echo "✅ Dock layout applied"
