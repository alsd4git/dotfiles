#!/usr/bin/env bash
# Run with Bash or Zsh. Docker calls are always simulated.

set -eu
repo_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-shell-tests.XXXXXX")
cleanup() {
    rm -f "$test_root/config dir/config.json" "$test_root/calls" "$test_root/warnings" "$test_root/netuse"
    rmdir "$test_root/config dir" "$test_root"
}
trap cleanup EXIT
# shellcheck source=general/.functions
source "$repo_root/general/.functions"

docker() {
    printf '<%s>\n' "$@" >"$test_root/calls"
    return "${docker_result:-0}"
}

export DOCKER_CONFIG="$test_root/config dir"
mkdir -p "$DOCKER_CONFIG"
watchtower_run_once 'container with spaces' 2>"$test_root/warnings"
if grep -Fq '/config.json:ro' "$test_root/calls"; then exit 1; fi
grep -Fxq '<container with spaces>' "$test_root/calls"
test ! -s "$test_root/warnings"

printf '%s\n' '{"auths":{}}' >"$DOCKER_CONFIG/config.json"
watchtower_run_once 2>"$test_root/warnings"
grep -Fxq "<$DOCKER_CONFIG/config.json:/config.json:ro>" "$test_root/calls"
test ! -s "$test_root/warnings"

for config_fixture in '{"credsStore":"desktop"}' '{"credHelpers":{"registry.example":"helper"}}' '{
"credsStore"
: "desktop"
}'; do
    printf '%s\n' "$config_fixture" >"$DOCKER_CONFIG/config.json"
    watchtower_run_once 2>"$test_root/warnings"
    grep -Fq 'credential helpers' "$test_root/warnings"
    if grep -Fq 'registry.example' "$test_root/warnings"; then exit 1; fi
done
docker_result=17
actual_result=0
watchtower_run_once 2>"$test_root/warnings" || actual_result=$?
test "$actual_result" -eq 17

if [ "$(uname -s)" = Linux ]; then
    netuse --iface lo true >"$test_root/netuse"
    fail_command() {
        printf '%s\n' '__DONE__'
        printf 'stderr without newline' >&2
        return 23
    }
    actual_result=0
    netuse --iface lo fail_command >"$test_root/netuse" || actual_result=$?
    test "$actual_result" -eq 23
    grep -Fq '__DONE__' "$test_root/netuse"
    grep -Fq 'stderr without newline' "$test_root/netuse"
    grep -Fq 'Riepilogo' "$test_root/netuse"

    for expected_result in 0 7; do
        actual_result=0
        netuse --iface lo exit "$expected_result" >"$test_root/netuse" || actual_result=$?
        test "$actual_result" -eq "$expected_result"
        grep -Fq 'Riepilogo' "$test_root/netuse"
    done

    actual_result=0
    netuse --iface lo exec sh -c 'printf "exec output\n"; exit 29' >"$test_root/netuse" || actual_result=$?
    test "$actual_result" -eq 29
    grep -Fq 'exec output' "$test_root/netuse"
    grep -Fq 'Riepilogo' "$test_root/netuse"
else
    printf '%s\n' 'netuse runtime tests skipped: Linux /proc required'
fi
printf '%s\n' 'Shell function tests passed'
