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

if ! jq -e '
    type == "object"
    and (.tools | type == "array" and length > 0)
    and all(.tools[];
        (.name | type == "string" and length > 0)
        and (.command | type == "string" and length > 0)
        and (.version_args | type == "array" and length > 0 and all(.[]; type == "string"))
        and (.required | type == "boolean")
        and ((.configuration_probe // "") | type == "string")
    )
    and (([.tools[].name] | unique | length) == (.tools | length))
' "$manifest" >/dev/null 2>&1; then
    echo "invalid: tool manifest schema at $manifest" >&2
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

    configuration_probe=$(jq -r '.configuration_probe // ""' <<<"$tool_entry")
    if [ "$configuration_probe" = swiftly ]; then
        swiftly_config=""
        for swiftly_home in "${SWIFTLY_HOME_DIR:-}" "$HOME/.swiftly" "$HOME/.local/share/swiftly"; do
            if [ -n "$swiftly_home" ] && [ -f "$swiftly_home/config.json" ]; then
                swiftly_config="$swiftly_home/config.json"
                break
            fi
        done
        if [ -z "$swiftly_config" ]; then
            printf 'warning: %s is installed but not initialized (missing swiftly config)\n' "$tool_name" >&2
            if $strict; then
                missing=1
            fi
            continue
        fi
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
