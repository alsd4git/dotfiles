#!/usr/bin/env bash
# shellcheck disable=SC2034 # This sourced manifest exports installer arrays.

# Canonical shell-side tool classification. Package names intentionally match
# Debian/Ubuntu; macOS and Windows retain their native declarative manifests.
REQUIRED_APT_PACKAGES=(curl exiv2 fzf gnupg jq nano ripgrep unzip)
OPTIONAL_APT_PACKAGES=(bat delta fd-find fastfetch zoxide)
RECOMMENDED_COMMANDS=(nano docker swift git)
