#!/usr/bin/env bash

set -euo pipefail

strict=false
if [ "${1:-}" = "--strict" ]; then
    strict=true
elif [ -n "${1:-}" ]; then
    echo "Usage: $0 [--strict]" >&2
    exit 2
fi

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

exit "$missing"
