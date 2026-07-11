#!/usr/bin/env bash

set -euo pipefail

strict=false
if [ "${1:-}" = "--strict" ]; then
    strict=true
elif [ -n "${1:-}" ]; then
    echo "Usage: $0 [--strict]" >&2
    exit 2
fi

repo_root=$(cd "$(dirname "$0")/.." && pwd)
git_defaults_file="$repo_root/git/defaults.conf"
missing=0

check_file() {
    local path="$1"

    if [ -e "$path" ] || [ -L "$path" ]; then
        printf 'ok: %s\n' "$path"
    else
        printf 'missing: %s\n' "$path" >&2
        missing=1
    fi
}

check_file "$HOME/.shell_aliases"
check_file "$HOME/.shell_functions"
check_file "$HOME/.history_settings"
check_file "$HOME/.omp_init"
check_file "$HOME/.nanorc"
check_file "$HOME/.git_aliases"
check_file "$HOME/.git_functions"
check_file "$HOME/.global.gitignore"

if command -v git >/dev/null 2>&1; then
    expected_ignore="$HOME/.global.gitignore"
    configured_ignore=$(git config --global --get core.excludesfile 2>/dev/null || true)
    if [ "$configured_ignore" = "$expected_ignore" ]; then
        printf 'ok: git core.excludesfile\n'
    else
        printf 'warning: git core.excludesfile is %s\n' "${configured_ignore:-unset}" >&2
        if $strict; then
            missing=1
        fi
    fi
else
    printf 'warning: git is not installed\n' >&2
    if $strict; then
        missing=1
    fi
fi

if [ ! -f "$git_defaults_file" ]; then
    printf 'missing: Git defaults manifest at %s\n' "$git_defaults_file" >&2
    exit 2
fi

if command -v git >/dev/null 2>&1; then
    while IFS='=' read -r setting_key setting_value; do
        if [ -z "$setting_key" ] || [[ "$setting_key" == \#* ]]; then
            continue
        fi
        if [ -z "$setting_value" ]; then
            printf 'invalid: Git defaults entry %s\n' "$setting_key" >&2
            exit 2
        fi

        actual_value=$(git config --global --get "$setting_key" 2>/dev/null || true)
        if [ "$actual_value" = "$setting_value" ]; then
            printf 'ok: git %s\n' "$setting_key"
        else
            printf 'warning: git %s is %s, expected %s\n' "$setting_key" "${actual_value:-unset}" "$setting_value" >&2
            if $strict; then
                missing=1
            fi
        fi
    done <"$git_defaults_file"
fi

exit "$missing"
