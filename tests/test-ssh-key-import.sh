#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/dotfiles-ssh-import.XXXXXXXX)
case "$test_root" in /tmp/dotfiles-ssh-import.*) ;; *) exit 1 ;; esac
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/home"
ssh-keygen -q -t ed25519 -N '' -f "$test_root/key"
cat >"$test_root/bin/curl" <<'EOF'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then cp "$SSH_TEST_RESPONSE" "$2"; printf '%s' "${SSH_TEST_STATUS:-200}"; exit "${SSH_TEST_CURL_EXIT:-0}"; fi
    shift
done
exit 1
EOF
chmod +x "$test_root/bin/curl"
export PATH="$test_root/bin:$PATH" HOME="$test_root/home" SSH_TEST_RESPONSE="$test_root/key.pub"

bash "$repo_root/scripts/import-ssh-keys.sh" --provider github --username example --dry-run >/dev/null
test ! -e "$HOME/.ssh"
printf 'y\n' | bash "$repo_root/scripts/import-ssh-keys.sh" --provider github --username example >/dev/null
test "$(wc -l <"$HOME/.ssh/authorized_keys" | tr -d ' ')" = 1
test "$(stat -c %a "$HOME/.ssh")" = 700
test "$(stat -c %a "$HOME/.ssh/authorized_keys")" = 600
cp "$HOME/.ssh/authorized_keys" "$test_root/before"
printf 'y\n' | bash "$repo_root/scripts/import-ssh-keys.sh" --provider gitlab --username example >/dev/null
cmp -s "$test_root/before" "$HOME/.ssh/authorized_keys"
printf 'not a key\n' >"$test_root/invalid"
export SSH_TEST_RESPONSE="$test_root/invalid"
if printf 'y\n' | bash "$repo_root/scripts/import-ssh-keys.sh" --provider github --username example >/dev/null 2>&1; then exit 1; fi
cmp -s "$test_root/before" "$HOME/.ssh/authorized_keys"
printf 'ssh-ed25519 AAAA\033[31m\n' >"$test_root/control"
export SSH_TEST_RESPONSE="$test_root/control"
if printf 'y\n' | bash "$repo_root/scripts/import-ssh-keys.sh" --provider github --username example >/dev/null 2>&1; then exit 1; fi
cmp -s "$test_root/before" "$HOME/.ssh/authorized_keys"
export SSH_TEST_RESPONSE="$test_root/key.pub" SSH_TEST_STATUS=302
if printf 'y\n' | bash "$repo_root/scripts/import-ssh-keys.sh" --provider github --username example >/dev/null 2>&1; then exit 1; fi
unset SSH_TEST_STATUS
export SSH_TEST_CURL_EXIT=22
if printf 'y\n' | bash "$repo_root/scripts/import-ssh-keys.sh" --provider github --username example >/dev/null 2>&1; then exit 1; fi
unset SSH_TEST_CURL_EXIT
cmp -s "$test_root/before" "$HOME/.ssh/authorized_keys"
ssh-keygen -q -t ed25519 -N '' -f "$test_root/second"
printf '# manual comment without newline' >>"$HOME/.ssh/authorized_keys"
cp "$HOME/.ssh/authorized_keys" "$test_root/before-second"
export SSH_TEST_RESPONSE="$test_root/second.pub"
printf 'y\n' | bash "$repo_root/scripts/import-ssh-keys.sh" --provider github --username example >/dev/null
cmp -s "$test_root/before-second" "$(find "$HOME/.ssh" -maxdepth 1 -name 'authorized_keys.bak.*' -print -quit)"
grep -Fq '# manual comment without newline' "$HOME/.ssh/authorized_keys"
test "$(ssh-keygen -lf "$HOME/.ssh/authorized_keys" | wc -l | tr -d ' ')" = 2
if bash "$repo_root/scripts/import-ssh-keys.sh" --provider github --username '../bad' --dry-run >/dev/null 2>&1; then exit 1; fi
echo 'SSH key import tests passed.'
