#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-prompt-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/bin"
cat >"$test_root/bin/oh-my-posh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$DOTFILES_OMP_TEST_LOG"
EOF
chmod +x "$test_root/bin/oh-my-posh"

for mode in link copy; do
    for config in default custom; do
        export HOME="$test_root/$mode-$config"
        export SHELL=/bin/bash
        export GIT_CONFIG_GLOBAL="$HOME/gitconfig"
        export DOTFILES_OMP_TEST_LOG="$HOME/prompt.log"
        export PATH="$test_root/bin:$PATH"
        mkdir -p "$HOME"
        unset XDG_CONFIG_HOME
        if [ "$config" = custom ]; then export XDG_CONFIG_HOME="$HOME/custom-config"; fi
        theme_path="${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-posh/themes/tokyo.omp.json"

        args=(--minimal --yes)
        if [ "$mode" = copy ]; then args+=(--copy); fi
        "$repo_root/install.sh" "${args[@]}" >"$HOME/install.log"
        cmp "$repo_root/general/themes/tokyo.omp.json" "$theme_path"
        if [ "$mode" = link ]; then test -L "$theme_path"; else test ! -L "$theme_path"; fi
        test ! -e "$HOME/.cache/oh-my-posh"

        for shell_bin in bash zsh; do
            if ! command -v "$shell_bin" >/dev/null 2>&1; then continue; fi
            # shellcheck disable=SC2016 # HOME belongs to the interactive child.
            "$shell_bin" -ic '. "$HOME/.omp_init"' >"$HOME/prompt.out" 2>"$HOME/prompt.err"
            grep -Fq -- "init $shell_bin --config $theme_path" "$DOTFILES_OMP_TEST_LOG"
        done

        "$repo_root/install.sh" --uninstall --force >"$HOME/uninstall.log"
        # Uninstall removes managed links, preserving copied user files.
        if [ "$mode" = link ]; then
            test ! -e "$theme_path"
        else
            cmp "$repo_root/general/themes/tokyo.omp.json" "$theme_path"
        fi
    done
done

printf 'Persistent prompt theme tests passed\n'
