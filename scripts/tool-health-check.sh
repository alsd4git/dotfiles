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
manifest="$repo_root/scripts/tool-health.json"
missing=0

if ! command -v jq >/dev/null 2>&1; then
    echo "missing: jq (required to read $manifest)" >&2
    exit 2
fi

if [ ! -f "$manifest" ] || ! jq empty "$manifest" >/dev/null 2>&1; then
    echo "invalid: tool manifest at $manifest" >&2
    exit 2
fi

while IFS= read -r tool_entry; do
    tool_name=$(jq -r '.name' <<<"$tool_entry")
    tool_command=$(jq -r '.command' <<<"$tool_entry")
    required=$(jq -r '.required' <<<"$tool_entry")
    version_args=()
    while IFS= read -r version_arg; do
        version_args+=("$version_arg")
    done < <(jq -r '.version_args[]' <<<"$tool_entry")

    if ! command -v "$tool_command" >/dev/null 2>&1; then
        printf 'missing: %s (%s)\n' "$tool_name" "$tool_command" >&2
        if $strict || [ "$required" = true ]; then
            missing=1
        fi
        continue
    fi

    if version_output=$("$tool_command" "${version_args[@]}" 2>&1); then
        first_line=${version_output%%$'\n'*}
        if [ -n "$first_line" ]; then
            printf 'ok: %s — %s\n' "$tool_name" "$first_line"
        else
            printf 'warning: %s returned no version output\n' "$tool_name" >&2
            if $strict; then
                missing=1
            fi
        fi
    else
        first_line=${version_output%%$'\n'*}
        printf 'warning: %s failed to report its version%s\n' "$tool_name" "${first_line:+ — $first_line}" >&2
        if $strict || [ "$required" = true ]; then
            missing=1
        fi
    fi
done < <(jq -c '.tools[]' "$manifest")

exit "$missing"
