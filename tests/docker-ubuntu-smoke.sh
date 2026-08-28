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

            case "$shell_bin" in
                /bin/bash)
                    rc_file="$test_home/.bashrc"
                    expected_shell=bash
                    ;;
                /usr/bin/zsh)
                    rc_file="$test_home/.zshrc"
                    expected_shell=zsh
                    ;;
            esac

            printf "\nexport DOTFILES_RLD_SMOKE=%s\n" "$expected_shell" >>"$rc_file"
            "$shell_bin" -ic "
                unset DOTFILES_RLD_SMOKE
                type aa >/dev/null
                type gl >/dev/null
                type rld >/dev/null
                type npmupg >/dev/null
                rld >/tmp/rld.log
                test \"\$DOTFILES_RLD_SMOKE\" = \"$expected_shell\"
            "
            grep -Fq "Reloading $expected_shell configuration: $rc_file" /tmp/rld.log

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
