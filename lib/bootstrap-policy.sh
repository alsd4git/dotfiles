#!/usr/bin/env bash

# Canonical bootstrap inventory. A fixed-release source may accept an optional
# SHA-256 override. Dynamic upstream channels are intentionally explicit.
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
HOMEBREW_INSTALL_POLICY="trusted-upstream-dynamic"
OH_MY_POSH_INSTALL_URL="https://ohmyposh.dev/install.sh"
OH_MY_POSH_INSTALL_POLICY="trusted-upstream-dynamic"
UV_INSTALL_URL="https://astral.sh/uv/install.sh"
UV_INSTALL_POLICY="trusted-upstream-dynamic"
EZA_KEY_URL="https://raw.githubusercontent.com/eza-community/eza/main/deb.asc"
EZA_KEY_POLICY="trusted-upstream-dynamic"
SWIFTLY_INSTALL_URL_TEMPLATE="https://download.swift.org/swiftly/linux/swiftly-%s.tar.gz"
SWIFTLY_INSTALL_POLICY="upstream-signature-verification"

calculate_sha256() {
    local path="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{print $1}'
    else
        return 1
    fi
}

verify_sha256_file() {
    local expected_sha256="$1"
    local path="$2"
    local actual_sha256

    if [[ ! "$expected_sha256" =~ ^[[:xdigit:]]{64}$ ]]; then
        echo "❌ Invalid SHA-256 digest for $path" >&2
        return 2
    fi
    if ! actual_sha256=$(calculate_sha256 "$path"); then
        echo "❌ No SHA-256 utility available; refusing to use $path" >&2
        return 1
    fi
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "❌ SHA-256 mismatch for $path" >&2
        return 1
    fi
}

run_remote_script() {
    local url="$1"
    shift
    local expected_sha256=""
    local script status

    if [ "${1:-}" = "--sha256" ]; then
        if [ "$#" -lt 2 ]; then
            echo "❌ --sha256 requires a SHA-256 digest for $url" >&2
            return 2
        fi
        expected_sha256="$2"
        shift 2
        if [[ ! "$expected_sha256" =~ ^[[:xdigit:]]{64}$ ]]; then
            echo "❌ Invalid SHA-256 digest for $url" >&2
            return 2
        fi
    fi

    script=$(mktemp "${TMPDIR:-/tmp}/dotfiles-download.XXXXXX")
    register_temp_path "$script"
    if ! curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 -o "$script" "$url"; then
        rm -f "$script"
        return 1
    fi

    if [ -n "$expected_sha256" ]; then
        if ! verify_sha256_file "$expected_sha256" "$script"; then
            rm -f "$script"
            return 1
        fi
        echo "🔐 Verified SHA-256 for $url"
    fi

    if bash "$script" "$@"; then
        status=0
    else
        status=$?
    fi
    rm -f "$script"
    forget_temp_path "$script"
    return "$status"
}

print_bootstrap_policy() {
    printf '%-16s %-34s %s\n' "component" "policy" "source"
    printf '%-16s %-34s %s\n' "homebrew" "$HOMEBREW_INSTALL_POLICY" "$HOMEBREW_INSTALL_URL"
    printf '%-16s %-34s %s\n' "oh-my-posh" "$OH_MY_POSH_INSTALL_POLICY" "$OH_MY_POSH_INSTALL_URL"
    printf '%-16s %-34s %s\n' "uv" "$UV_INSTALL_POLICY" "$UV_INSTALL_URL"
    printf '%-16s %-34s %s\n' "eza-key" "$EZA_KEY_POLICY" "$EZA_KEY_URL"
    printf '%-16s %-34s %s\n' "swiftly" "$SWIFTLY_INSTALL_POLICY" "$SWIFTLY_INSTALL_URL_TEMPLATE"
    printf '%-16s %-34s %s\n' "nvm" "fixed-release-optional-sha256" "https://raw.githubusercontent.com/nvm-sh/nvm/<version>/install.sh"
}
