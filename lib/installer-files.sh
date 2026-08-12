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
