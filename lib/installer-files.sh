#!/usr/bin/env bash

add_to_rc_if_not_present() {
    local rc_file="${1/#\~/$HOME}"
    local line_to_add="$2"
    if [ -f "$rc_file" ] && grep -Fq "$line_to_add" "$rc_file"; then
        echo "📄 $line_to_add found in $rc_file, no need to add"
    elif $DRY_RUN; then
        echo "🧪 Would add to $rc_file: $line_to_add"
    else
        echo "📝 adding $line_to_add to $rc_file"
        echo "$line_to_add" >>"$rc_file"
        record_managed_rc_line "$rc_file" "$line_to_add"
    fi
}

record_managed_rc_line() {
    local rc_file="$1"
    local line="$2"
    local entry

    mkdir -p "$GIT_CONFIG_STATE_DIR"
    touch "$RC_LINE_MANIFEST"
    entry=$(printf '%s\t%s' "$rc_file" "$line")
    if ! grep -Fqx -- "$entry" "$RC_LINE_MANIFEST"; then
        printf '%s\n' "$entry" >>"$RC_LINE_MANIFEST"
    fi
}

remove_exact_line_once() {
    local rc_file="$1"
    local line_to_remove="$2"
    local tmp_file="${rc_file}.tmp.$$"
    local current_line removed=false

    : >"$tmp_file"
    while IFS= read -r current_line || [ -n "$current_line" ]; do
        if ! $removed && [ "$current_line" = "$line_to_remove" ]; then
            removed=true
            continue
        fi
        printf '%s\n' "$current_line" >>"$tmp_file"
    done <"$rc_file"
    mv "$tmp_file" "$rc_file"
}

remove_managed_rc_lines() {
    local rc_file line

    if [ ! -f "$RC_LINE_MANIFEST" ]; then
        echo "ℹ️  No recorded shell startup additions found; leaving startup files unchanged."
        return 0
    fi

    while IFS=$'\t' read -r rc_file line; do
        case "$rc_file" in
            "$HOME/.bashrc" | "$HOME/.zshrc" | "$HOME/.bash_profile" | "$HOME/.zprofile") ;;
            *)
                echo "⚠️  Ignoring unexpected startup file in $RC_LINE_MANIFEST: $rc_file" >&2
                continue
                ;;
        esac
        if [ ! -f "$rc_file" ] || ! grep -Fxq -- "$line" "$rc_file"; then
            continue
        fi
        if $DRY_RUN; then
            echo "🧪 Would remove recorded line from $rc_file: $line"
        else
            echo "🧽 removing recorded line from $rc_file: $line"
            remove_exact_line_once "$rc_file" "$line"
        fi
    done <"$RC_LINE_MANIFEST"

    if ! $DRY_RUN; then
        rm -f "$RC_LINE_MANIFEST"
    fi
}

record_backup() {
    local backup_path="$1"
    mkdir -p "$GIT_CONFIG_STATE_DIR"
    touch "$BACKUP_MANIFEST"
    if ! grep -Fqx -- "$backup_path" "$BACKUP_MANIFEST"; then
        printf '%s\n' "$backup_path" >>"$BACKUP_MANIFEST"
    fi
}

backup_existing_path() {
    local path="$1"
    local backup_path counter=0
    backup_path="${path}.bak.$(date +%s)"
    while [ -e "$backup_path" ] || [ -L "$backup_path" ]; do
        counter=$((counter + 1))
        backup_path="${path}.bak.$(date +%s).$counter"
    done
    mv -- "$path" "$backup_path"
    record_backup "$backup_path"
    printf '%s\n' "$backup_path"
}

remove_from_rc_if_present() {
    local rc_file="${1/#\~/$HOME}"
    local line_to_remove="$2"
    local tmp_file
    if [ -f "$rc_file" ] && grep -Fq "$line_to_remove" "$rc_file"; then
        if $DRY_RUN; then
            echo "🧪 Would remove line from $rc_file: $line_to_remove"
        else
            echo "🧽 removing line from $rc_file: $line_to_remove"
            tmp_file="${rc_file}.tmp.$$"
            grep -Fv "$line_to_remove" "$rc_file" >"$tmp_file" || true
            mv "$tmp_file" "$rc_file"
        fi
    fi
}

cleanup_legacy_path_dedup() {
    local rc_file="$1"
    remove_from_rc_if_present "$rc_file" "$LEGACY_PATH_DEDUP_MARKER"
    remove_from_rc_if_present "$rc_file" "$LEGACY_PATH_DEDUP_LINE"
}

apply_rc_lines() {
    local action="$1"
    local rc_file="$2"
    shift 2
    local line
    for line in "$@"; do
        if [ "$action" = add ]; then
            add_to_rc_if_not_present "$rc_file" "$line"
        else
            remove_from_rc_if_present "$rc_file" "$line"
        fi
    done
}

phase_banner() {
    printf '\n%s\n' "────────────────────────────────────────────────"
    printf '▶ %s\n' "$1"
    printf '%s\n' "────────────────────────────────────────────────"
}
