#!/usr/bin/env bash
# shellcheck disable=SC2016

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-installer-tests.XXXXXX")
stub_bin="$test_root/bin"
test_home="$test_root/home"
test_log="$test_root/calls.log"
mkdir -p "$stub_bin" "$test_home"

cleanup() {
    rm -f "$stub_bin/gh" "$stub_bin/nvm" "$test_root"/*.out "$test_log"
    rmdir "$stub_bin" "$test_home" "$test_root" 2>/dev/null || true
}
trap cleanup EXIT

write_gh_stub() {
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'printf "%s\\n" "$*" >>"$DOTFILES_TEST_LOG"' \
        'case "$1 $2" in' \
        '    "auth status") exit "${DOTFILES_TEST_GH_STATUS:-1}" ;;' \
        '    "auth login") exit "${DOTFILES_TEST_GH_LOGIN_STATUS:-0}" ;;' \
        'esac' >"$stub_bin/gh"
    chmod +x "$stub_bin/gh"
}

write_nvm_stub() {
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'printf "%s\\n" "$*" >>"$DOTFILES_TEST_LOG"' \
        'case "$1 $2" in' \
        '    "version current") printf "%s\\n" "${DOTFILES_TEST_NVM_TARGET:-v22.0.0}" ;;' \
        '    "reinstall-packages "*) exit "${DOTFILES_TEST_NVM_REINSTALL_STATUS:-0}" ;;' \
        'esac' >"$stub_bin/nvm"
    chmod +x "$stub_bin/nvm"
}

write_curl_stub() {
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'output=""' \
        'while [ "$#" -gt 0 ]; do' \
        '    if [ "$1" = "-o" ]; then output="$2"; shift 2; else shift; fi' \
        'done' \
        'printf "%s\\n" "$DOTFILES_TEST_REMOTE_PAYLOAD" >"$output"' >"$stub_bin/curl"
    chmod +x "$stub_bin/curl"
}

run_installer_function() {
    local function_name="$1"
    local input="$2"
    local output_file="$3"
    local interactive="$4"

    : >"$test_log"
    if [ "$interactive" = true ]; then
        printf '%s\n' "$input" | env \
            HOME="$test_home" \
            SHELL=/bin/bash \
            PATH="$stub_bin:$PATH" \
            DOTFILES_TEST_FUNCTION="$function_name" \
            DOTFILES_TEST_INTERACTIVE=true \
            DOTFILES_TEST_LOG="$test_log" \
            DOTFILES_TEST_GH_STATUS="${DOTFILES_TEST_GH_STATUS:-1}" \
            DOTFILES_TEST_GH_LOGIN_STATUS="${DOTFILES_TEST_GH_LOGIN_STATUS:-0}" \
            DOTFILES_TEST_NVM_TARGET="${DOTFILES_TEST_NVM_TARGET:-v22.0.0}" \
            DOTFILES_TEST_NVM_REINSTALL_STATUS="${DOTFILES_TEST_NVM_REINSTALL_STATUS:-0}" \
            DOTFILES_TEST_REMOTE_SHA256="${DOTFILES_TEST_REMOTE_SHA256:-}" \
            DOTFILES_TEST_REMOTE_URL="${DOTFILES_TEST_REMOTE_URL:-https://example.invalid/script.sh}" \
            DOTFILES_TEST_REMOTE_PAYLOAD="${DOTFILES_TEST_REMOTE_PAYLOAD:-}" \
            "$repo_root/install.sh" >"$output_file" 2>&1
    else
        env \
            HOME="$test_home" \
            SHELL=/bin/bash \
            PATH="$stub_bin:$PATH" \
            DOTFILES_TEST_FUNCTION="$function_name" \
            DOTFILES_TEST_LOG="$test_log" \
            DOTFILES_TEST_GH_STATUS="${DOTFILES_TEST_GH_STATUS:-1}" \
            DOTFILES_TEST_GH_LOGIN_STATUS="${DOTFILES_TEST_GH_LOGIN_STATUS:-0}" \
            DOTFILES_TEST_NVM_TARGET="${DOTFILES_TEST_NVM_TARGET:-v22.0.0}" \
            DOTFILES_TEST_NVM_REINSTALL_STATUS="${DOTFILES_TEST_NVM_REINSTALL_STATUS:-0}" \
            DOTFILES_TEST_REMOTE_SHA256="${DOTFILES_TEST_REMOTE_SHA256:-}" \
            DOTFILES_TEST_REMOTE_URL="${DOTFILES_TEST_REMOTE_URL:-https://example.invalid/script.sh}" \
            DOTFILES_TEST_REMOTE_PAYLOAD="${DOTFILES_TEST_REMOTE_PAYLOAD:-}" \
            "$repo_root/install.sh" </dev/null >"$output_file" 2>&1
    fi
}

write_gh_stub
run_installer_function gh-auth "" "$test_root/gh-notty.out" false
if grep -Fq 'auth login' "$test_log"; then exit 1; fi
grep -Fq 'not authenticated' "$test_root/gh-notty.out"

DOTFILES_TEST_GH_STATUS=0 run_installer_function gh-auth "" "$test_root/gh-authenticated.out" false
if grep -Fq 'auth login' "$test_log"; then exit 1; fi
grep -Fq 'already authenticated' "$test_root/gh-authenticated.out"

DOTFILES_TEST_GH_STATUS=1 run_installer_function gh-auth n "$test_root/gh-declined.out" true
if grep -Fq 'auth login' "$test_log"; then exit 1; fi
grep -Fq 'Skipping GitHub CLI authentication' "$test_root/gh-declined.out"

DOTFILES_TEST_GH_STATUS=1 DOTFILES_TEST_GH_LOGIN_STATUS=0 run_installer_function gh-auth y "$test_root/gh-success.out" true
grep -Fq 'auth login' "$test_log"
grep -Fq 'authentication completed' "$test_root/gh-success.out"

DOTFILES_TEST_GH_STATUS=1 DOTFILES_TEST_GH_LOGIN_STATUS=1 run_installer_function gh-auth y "$test_root/gh-failed.out" true
grep -Fq 'auth login' "$test_log"
grep -Fq 'authentication was not completed' "$test_root/gh-failed.out"

write_nvm_stub
DOTFILES_TEST_NVM_TARGET=v20.0.0 run_installer_function nvm-migrate n "$test_root/nvm-same.out" true
if grep -Fq 'reinstall-packages' "$test_log"; then exit 1; fi

DOTFILES_TEST_NVM_TARGET=v22.0.0 DOTFILES_TEST_NVM_REINSTALL_STATUS=0 run_installer_function nvm-migrate y "$test_root/nvm-success.out" true
grep -Fq 'reinstall-packages v0.0.0' "$test_log"
grep -Fq 'packages migrated' "$test_root/nvm-success.out"

DOTFILES_TEST_NVM_TARGET=v22.0.0 DOTFILES_TEST_NVM_REINSTALL_STATUS=1 run_installer_function nvm-migrate y "$test_root/nvm-failed.out" true
grep -Fq 'reinstall-packages v0.0.0' "$test_log"
grep -Fq 'migration failed' "$test_root/nvm-failed.out"

DOTFILES_TEST_NVM_TARGET=v22.0.0 run_installer_function nvm-migrate y "$test_root/nvm-notty.out" false
if grep -Fq 'reinstall-packages' "$test_log"; then exit 1; fi
grep -Fq 'non-interactive/automatic mode' "$test_root/nvm-notty.out"

run_installer_function nvm-wrapper "" "$test_root/nvm-wrapper.out" false

write_curl_stub
remote_payload=$'#!/usr/bin/env bash\nprintf "remote stub executed\\n" >>"$DOTFILES_TEST_LOG"'
remote_sha256=$(printf '%s\n' "$remote_payload" | shasum -a 256 | awk '{print $1}')
export DOTFILES_TEST_REMOTE_PAYLOAD="$remote_payload"
DOTFILES_TEST_REMOTE_SHA256="$remote_sha256" run_installer_function remote-script "" "$test_root/remote-success.out" false
grep -Fq 'remote stub executed' "$test_log"

if DOTFILES_TEST_REMOTE_SHA256="$(printf '%s\n' incorrect | shasum -a 256 | awk '{print $1}')" run_installer_function remote-script "" "$test_root/remote-failed.out" false; then
    exit 1
fi
grep -Fq 'SHA-256 mismatch' "$test_root/remote-failed.out"

printf 'installer interactive function tests passed\n'
