#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
image="${DOTFILES_TEST_UBUNTU_IMAGE:-ubuntu:24.04}"

docker run --rm \
    --mount "type=bind,src=$repo_root,dst=/workspace,readonly" \
    --env DEBIAN_FRONTEND=noninteractive \
    "$image" \
    bash -ceu '
        apt-get update >/dev/null
        apt-get install -y --no-install-recommends ca-certificates git zsh >/dev/null

        for shell_bin in /bin/bash /usr/bin/zsh; do
            test_home=$(mktemp -d /tmp/dotfiles-home.XXXXXX)
            export HOME="$test_home"
            export SHELL="$shell_bin"
            export GIT_CONFIG_GLOBAL="$test_home/gitconfig"

            /workspace/install.sh --sync >/tmp/install.log
            /workspace/scripts/health-check.sh --strict >/tmp/health.log
            grep -Fq "Required failures: 0" /tmp/install.log

            "$shell_bin" -ic "type aa >/dev/null; type gl >/dev/null"

            /workspace/install.sh --uninstall --force >/tmp/uninstall.log
            test ! -e "$test_home/.shell_aliases"
        done
    '

printf 'Ubuntu container smoke tests passed (%s)\n' "$image"

docker run --rm \
    --mount "type=bind,src=$repo_root,dst=/workspace,readonly" \
    --env HOME=/tmp/dotfiles-home \
    --env SHELL=/bin/bash \
    bash:3.2 \
    /workspace/install.sh --dry-run --minimal >/dev/null

printf 'Bash 3.2 compatibility smoke test passed\n'
