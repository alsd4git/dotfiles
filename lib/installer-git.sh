#!/usr/bin/env bash

snapshot_git_config_value() {
    local state_file="$1" setting_id="$2" setting_key="$3" value
    while IFS= read -r value; do
        git config --file "$state_file" --add "snapshot.$setting_id" "$value"
    done < <(git config --global --get-all "$setting_key" 2>/dev/null || true)
}

snapshot_git_config_key_if_missing() {
    local state_file="$1" setting_key="$2" setting_id
    setting_id=$(git_config_setting_id "$setting_key")
    if git config --file "$state_file" --get-all "snapshot.$setting_id" >/dev/null 2>&1; then
        return
    fi
    snapshot_git_config_value "$state_file" "$setting_id" "$setting_key"
}

snapshot_git_default_from_baseline() {
    local state_file="$1" setting_key="$2" setting_id
    setting_id=$(git_config_setting_id "$setting_key")
    snapshot_git_config_value "$state_file" "$setting_id" "$setting_key"
}

git_config_setting_id() {
    printf '%s' "$1" | tr '[:upper:].' '[:lower:]-'
}

for_each_git_default() {
    local callback="$1" setting_key setting_value
    local callback_failed=false
    shift
    while IFS='=' read -r setting_key setting_value; do
        if [ -z "$setting_key" ] || [[ "$setting_key" == \#* ]]; then
            continue
        fi
        if [ -z "$setting_value" ]; then
            echo "❌ Invalid Git defaults entry: $setting_key" >&2
            return 2
        fi
        if ! "$callback" "$@" "$setting_key" "$setting_value"; then
            callback_failed=true
        fi
    done <"$GIT_DEFAULTS_FILE"
    if $callback_failed; then
        return 1
    fi
}

snapshot_git_config_before_install() {
    if [ -f "$GIT_CONFIG_STATE_FILE" ]; then
        return
    fi
    mkdir -p "$GIT_CONFIG_STATE_DIR"
    local state_tmp
    state_tmp=$(mktemp "$GIT_CONFIG_STATE_DIR/git-config.before.XXXXXX")
    chmod 600 "$state_tmp"
    git config --file "$state_tmp" installer.version 1
    snapshot_git_config_value "$state_tmp" core-excludesfile core.excludesfile
    for_each_git_default snapshot_git_default_from_baseline "$state_tmp"
    mv "$state_tmp" "$GIT_CONFIG_STATE_FILE"
}

configure_git_default() {
    local setting_key="$1" setting_value="$2" setting_id
    setting_id=$(git_config_setting_id "$setting_key")
    git config --global "$setting_key" "$setting_value"
    git config --file "$GIT_CONFIG_STATE_FILE" --replace-all "managed.$setting_id" "$setting_value"
}

configure_git_default_from_baseline() { configure_git_default "$1" "$2"; }

configure_delta_git() {
    local setting_entry setting_key setting_value
    if ! command -v delta >/dev/null 2>&1; then
        return 0
    fi
    snapshot_git_config_before_install
    for setting_entry in "${DELTA_GIT_DEFAULTS[@]}"; do
        IFS='=' read -r setting_key setting_value <<<"$setting_entry"
        snapshot_git_config_key_if_missing "$GIT_CONFIG_STATE_FILE" "$setting_key"
        configure_git_default "$setting_key" "$setting_value"
    done
    echo "✅ Configured Git to use delta with navigation, side-by-side output, and line numbers."
}

restore_git_default() {
    local setting_key="$1" setting_id installed_value current_value snapshot_value
    setting_id=$(git_config_setting_id "$setting_key")
    installed_value=$(git config --file "$GIT_CONFIG_STATE_FILE" --get "managed.$setting_id" 2>/dev/null || true)
    if [ -z "$installed_value" ]; then
        return
    fi
    current_value=$(git config --global --get-all "$setting_key" 2>/dev/null || true)
    if [ "$current_value" != "$installed_value" ]; then
        echo "⚠️  Keeping Git setting $setting_key because it changed after installation."
        return 1
    fi
    git config --global --unset-all "$setting_key" || true
    while IFS= read -r snapshot_value; do
        git config --global --add "$setting_key" "$snapshot_value"
    done < <(git config --file "$GIT_CONFIG_STATE_FILE" --get-all "snapshot.$setting_id" 2>/dev/null || true)
}

restore_git_default_from_baseline() { restore_git_default "$1"; }

restore_git_config_before_install() {
    if [ ! -f "$GIT_CONFIG_STATE_FILE" ]; then
        return
    fi
    if $DRY_RUN; then
        echo "🧪 Would restore Git settings managed by the installer."
        return
    fi
    if ! command -v git >/dev/null 2>&1; then
        echo "⚠️  git not found; leaving installer-managed Git settings in place."
        return
    fi
    local restore_failed=false delta_entry delta_key
    echo "🔧 Restoring Git settings managed by the installer..."
    restore_git_default core.excludesfile || restore_failed=true
    for_each_git_default restore_git_default_from_baseline || restore_failed=true
    for delta_entry in "${DELTA_GIT_DEFAULTS[@]}"; do
        delta_key="${delta_entry%%=*}"
        restore_git_default "$delta_key" || restore_failed=true
    done
    if ! $restore_failed; then
        rm -f "$GIT_CONFIG_STATE_FILE"
        rmdir "$GIT_CONFIG_STATE_DIR" 2>/dev/null || true
    fi
}
