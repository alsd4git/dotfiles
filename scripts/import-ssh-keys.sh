#!/usr/bin/env bash
# Import public keys into the current user's authorized_keys after confirmation.
set -eu

provider=''
username=''
dry_run=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --provider)
            [ "$#" -ge 2 ] || {
                echo 'Missing provider.' >&2
                exit 2
            }
            provider=$2
            shift 2
            ;;
        --username)
            [ "$#" -ge 2 ] || {
                echo 'Missing username.' >&2
                exit 2
            }
            username=$2
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [ -z "$provider" ]; then
    printf 'Provider (github/gitlab): '
    IFS= read -r provider
fi
if [ -z "$username" ]; then
    printf 'Username: '
    IFS= read -r username
fi
case "$provider" in
    github) base='https://github.com' ;;
    gitlab) base='https://gitlab.com' ;;
    *)
        echo 'Provider must be github or gitlab.' >&2
        exit 2
        ;;
esac
case "$username" in
    '' | *[!a-zA-Z0-9_.-]* | -* | .* | *..*)
        echo 'Invalid username.' >&2
        exit 2
        ;;
esac
for cmd in curl ssh-keygen awk grep mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Missing required command: $cmd" >&2
        exit 1
    }
done

umask 077
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-ssh-keys.XXXXXXXX")
cleanup() {
    rm -f "$temp_dir/download" "$temp_dir/keys" "$temp_dir/one" "$temp_dir/existing" "$temp_dir/new"
    rmdir "$temp_dir" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM
status=$(curl --fail --silent --show-error --proto '=https' --connect-timeout 10 --max-time 30 --max-filesize 1048576 "$base/$username.keys" -o "$temp_dir/download" -w '%{http_code}')
[ "$status" = 200 ] || {
    echo "Unexpected HTTP status: $status" >&2
    exit 1
}
[ -s "$temp_dir/download" ] || {
    echo 'No public keys returned.' >&2
    exit 1
}
: >"$temp_dir/keys"
while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    if printf '%s' "$line" | LC_ALL=C grep -q '[[:cntrl:]]'; then
        echo 'Public key contains control characters.' >&2
        exit 1
    fi
    # A downloaded line must begin with a supported public-key type, not options.
    type=${line%%[[:space:]]*}
    case "$type" in
        ssh-ed25519 | ssh-rsa | ecdsa-sha2-nistp256 | ecdsa-sha2-nistp384 | ecdsa-sha2-nistp521 | sk-ssh-ed25519@openssh.com | sk-ecdsa-sha2-nistp256@openssh.com) ;;
        *)
            echo 'Invalid or unsupported public key.' >&2
            exit 1
            ;;
    esac
    printf '%s\n' "$line" >"$temp_dir/one"
    ssh-keygen -lf "$temp_dir/one" >/dev/null 2>&1 || {
        echo 'Invalid public key.' >&2
        exit 1
    }
    printf '%s\n' "$line" >>"$temp_dir/keys"
done <"$temp_dir/download"
[ -s "$temp_dir/keys" ] || {
    echo 'No valid public keys returned.' >&2
    exit 1
}

ssh_dir="$HOME/.ssh"
target="$ssh_dir/authorized_keys"
[ ! -L "$ssh_dir" ] && [ ! -L "$target" ] || {
    echo 'Refusing symlinked SSH paths.' >&2
    exit 1
}
if [ -e "$target" ] && [ ! -f "$target" ]; then
    echo 'authorized_keys is not a regular file.' >&2
    exit 1
fi
target_existed=false
if [ -f "$target" ]; then
    target_existed=true
    cp -p "$target" "$temp_dir/existing"
else
    : >"$temp_dir/existing"
fi
# Compare type + base64, including existing entries with authorized_keys options.
awk '
    FILENAME == ARGV[1] { for (i=1; i<NF; i++) if ($i ~ /^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com)$/) seen[$i " " $(i+1)]=1; next }
    { id=$1 " " $2; if (!seen[id]++) print }
' "$temp_dir/existing" "$temp_dir/keys" >"$temp_dir/new"
count=$(awk 'END { print NR+0 }' "$temp_dir/new")
total=$(awk 'END { print NR+0 }' "$temp_dir/keys")
printf 'Destination: %s\nNew keys: %s; already present or duplicate: %s\n' "$target" "$count" "$((total - count))"
ssh-keygen -lf "$temp_dir/keys"
echo 'Removing a key from the provider does not revoke access here; remove it from authorized_keys manually.'
if $dry_run || [ "$count" -eq 0 ]; then exit 0; fi
printf 'Add these keys to allow incoming SSH access? [y/N] '
IFS= read -r answer || exit 1
case "$answer" in y | Y) ;; *)
    echo 'No changes made.'
    exit 0
    ;;
esac

mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
[ ! -L "$ssh_dir" ] && [ ! -L "$target" ] || {
    echo 'SSH path changed; no keys written.' >&2
    exit 1
}
if $target_existed && [ -f "$target" ]; then
    cmp -s "$target" "$temp_dir/existing" || {
        echo 'authorized_keys changed; retry.' >&2
        exit 1
    }
elif $target_existed || [ -e "$target" ]; then
    echo 'authorized_keys changed; retry.' >&2
    exit 1
fi
staged=$(mktemp "$ssh_dir/.authorized_keys.dotfiles.XXXXXXXX")
trap 'rm -f "$staged"; cleanup' EXIT HUP INT TERM
if [ -s "$temp_dir/existing" ]; then
    cat "$temp_dir/existing" >"$staged"
    # Separate the new entry from a last line without a newline.
    [ "$(tail -c 1 "$staged" | wc -l | tr -d ' ')" -ne 0 ] || printf '\n' >>"$staged"
fi
cat "$temp_dir/new" >>"$staged"
chmod 600 "$staged"
if $target_existed; then
    backup=$(mktemp "$ssh_dir/authorized_keys.bak.XXXXXXXX")
    cp -p "$target" "$backup"
    chmod 600 "$backup"
    echo "Previous authorized_keys saved to $backup"
    cmp -s "$target" "$temp_dir/existing" || {
        echo 'authorized_keys changed; retry.' >&2
        exit 1
    }
    mv "$staged" "$target"
else
    # Creating a hard link fails atomically if another process created the target.
    ln "$staged" "$target" || {
        echo 'authorized_keys changed; retry.' >&2
        exit 1
    }
    rm -f "$staged"
fi
echo 'Keys imported.'
