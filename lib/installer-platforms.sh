#!/usr/bin/env bash

apt_package_installed() { dpkg -s "$1" >/dev/null 2>&1; }

install_required_apt_package() {
    local pkg="$1"
    if apt_package_installed "$pkg"; then
        echo "✅ $pkg already installed"
    else
        echo "📦 Installing $pkg..."
        sudo apt install -y "$pkg"
    fi
}

install_optional_apt_package() {
    local pkg="$1"
    if apt_package_installed "$pkg"; then
        echo "✅ $pkg already installed"
    else
        echo "📦 Installing $pkg..."
        if sudo apt install -y "$pkg"; then
            echo "✅ Installed $pkg"
            report_completed "$pkg"
        else
            echo "⚠️  $pkg is unavailable from apt on this system; continuing without it"
            report_optional_failure "$pkg"
        fi
    fi
}

install_eza_from_apt_repository() {
    local key_url="$EZA_KEY_URL"
    local keyring="/etc/apt/keyrings/gierens.gpg"
    local source_file="/etc/apt/sources.list.d/gierens.list"
    local architecture key_tmp
    if apt_package_installed eza; then
        echo "✅ eza already installed"
        return 0
    fi
    architecture=$(dpkg --print-architecture 2>/dev/null || true)
    if [ -z "$architecture" ]; then
        echo "⚠️  Cannot determine the Debian architecture; skipping eza."
        return 0
    fi
    echo "📥 Configuring the official eza apt repository..."
    key_tmp=$(mktemp "${TMPDIR:-/tmp}/eza-key.XXXXXX")
    if ! curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 -o "$key_tmp" "$key_url"; then
        rm -f "$key_tmp"
        echo "⚠️  Could not download the eza repository key; skipping eza."
        return 0
    fi
    if [ -n "${DOTFILES_EZA_KEY_SHA256:-}" ] && ! verify_sha256_file "$DOTFILES_EZA_KEY_SHA256" "$key_tmp"; then
        rm -f "$key_tmp"
        echo "⚠️  eza repository key verification failed; skipping eza."
        return 0
    fi
    if [ -n "${DOTFILES_EZA_KEY_SHA256:-}" ]; then echo "🔐 Verified SHA-256 for the eza repository key"; fi
    if ! sudo mkdir -p "$(dirname "$keyring")" || ! sudo gpg --dearmor --yes --output "$keyring" "$key_tmp"; then
        rm -f "$key_tmp"
        echo "⚠️  Could not install the eza repository key; skipping eza."
        return 0
    fi
    rm -f "$key_tmp"
    sudo chmod 0644 "$keyring"
    printf 'deb [arch=%s signed-by=%s] http://deb.gierens.de stable main\n' "$architecture" "$keyring" | sudo tee "$source_file" >/dev/null
    sudo chmod 0644 "$source_file"
    sudo apt update
    if ! sudo apt install -y eza; then echo "⚠️  eza is unavailable from the official repository; skipping it."; fi
}

report_macos_sudo_touch_id_status() {
    local sudo_pam="/etc/pam.d/sudo" sudo_tid_line='auth       sufficient     pam_tid.so'
    if grep -Fqx "$sudo_tid_line" "$sudo_pam" 2>/dev/null; then
        echo "✅ Touch ID is already enabled for sudo via $sudo_pam"
        return 0
    fi
    echo "⚠️  Touch ID for sudo does not appear to be enabled."
    echo "ℹ️  Manual recovery path:"
    echo "   1. Edit /etc/pam.d/sudo with sudo"
    echo "   2. Ensure this exact line is present: $sudo_tid_line"
    echo "   3. Test with: sudo -k && sudo -v"
}

ensure_macos_xcode_tools() {
    local developer_dir xcode_version xcode_line
    if ! developer_dir=$(xcode-select -p 2>/dev/null); then
        echo "⚠️  Xcode developer tools are missing."
        echo "ℹ️  Install Xcode from the App Store or run: xcode-select --install"
        return 1
    fi
    if ! xcode_version=$(xcodebuild -version 2>/dev/null); then
        echo "⚠️  xcodebuild is unavailable even though xcode-select points to $developer_dir"
        echo "ℹ️  Install Xcode, then run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        return 1
    fi
    echo "✅ Xcode developer directory: $developer_dir"
    while IFS= read -r xcode_line; do [[ -n "$xcode_line" ]] && echo "✅ $xcode_line"; done <<<"$xcode_version"
}

report_macos_stats_quarantine_hint() {
    local stats_app="/Applications/Stats.app"
    if [ ! -d "$stats_app" ] || ! command -v xattr >/dev/null 2>&1; then return 0; fi
    if xattr -p com.apple.quarantine "$stats_app" >/dev/null 2>&1; then
        echo "ℹ️  Stats.app still has the quarantine bit set."
        echo "   If it refuses to open, run:"
        echo "   sudo xattr -r -d com.apple.quarantine /Applications/Stats.app/"
    fi
}

trust_brewfile_taps() {
    local tap
    while IFS= read -r tap; do
        echo "🔐 Trusting Homebrew tap: $tap"
        brew trust --tap "$tap"
    done < <(sed -nE 's/^[[:space:]]*tap[[:space:]]+"([^"]+)".*/\1/p' "$MACOS_BREWFILE")
}
