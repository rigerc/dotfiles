#!/usr/bin/env bash
set -euo pipefail
[[ -t 0 ]] || { echo 'chezmoi: SSH server setup requires a terminal' >&2; exit 1; }
(( EUID != 0 )) || { echo 'chezmoi: run SSH server setup as your normal user' >&2; exit 1; }
[[ -r /etc/os-release ]] || exit 1
# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == arch || " ${ID_LIKE:-} " == *' arch '* ]] || {
    echo 'chezmoi: SSH server setup requires Arch or a derivative' >&2; exit 1;
}
for tool in sudo sshd systemctl; do
    command -v "$tool" >/dev/null || { echo "chezmoi: install $tool first" >&2; exit 1; }
done
username=$(id -un)
echo "chezmoi: enabling SSH for $username from private/local IP ranges on port 22"
sudo bash -s -- "$username" <<'ROOT'
set -euo pipefail
username=$1
# Reject characters meaningful to sshd's user-pattern grammar.
[[ $username =~ ^[a-zA-Z_][a-zA-Z0-9_-]*\$?$ ]] || {
    echo 'Unsupported SSH username' >&2; exit 1;
}
target=/etc/ssh/sshd_config.d/00-chezmoi-lan.conf
marker='# Managed by chezmoi: LAN SSH access'
if [[ -e $target ]] && [[ $(head -n 1 "$target") != "$marker" ]]; then
    echo "Refusing to overwrite unmanaged $target" >&2
    exit 1
fi
stage=$(mktemp -d)
had_target=false
installed=false
committed=false
cleanup() {
    local result=$?
    if $installed && ! $committed; then
        if $had_target; then
            cp -p -- "$stage/previous" "$target"
        else
            rm -f -- "$target"
        fi
    fi
    rm -rf -- "$stage"
    exit "$result"
}
trap cleanup EXIT
if [[ -e $target ]]; then
    cp -p -- "$target" "$stage/previous"
    had_target=true
fi
{
    printf '%s\n' "$marker" 'Port 22' 'PermitRootLogin no' \
        'PubkeyAuthentication yes' 'PasswordAuthentication yes' \
        'KbdInteractiveAuthentication no' 'PermitEmptyPasswords no'
    printf 'AllowUsers'
    for network in 127.0.0.0/8 ::1/128 10.0.0.0/8 172.16.0.0/12 \
        192.168.0.0/16 169.254.0.0/16 fc00::/7 fe80::/10; do
        printf ' %s@%s' "$username" "$network"
    done
    printf '\n'
} > "$stage/config"
ssh-keygen -A
install -d -m 755 /etc/ssh/sshd_config.d
install -m 644 "$stage/config" "$target"
installed=true
sshd -t
# Fail closed if an earlier directive or missing Include overrides this drop-in.
effective=$(sshd -T -C "user=$username,host=localhost,addr=192.168.1.2" |
    awk '{$1=tolower($1); print}')
# OpenSSH versions differ in keyword casing and print one AllowUsers entry
# per line. Compare all entries so additional users cannot widen this policy.
expected_allow=$(awk '$1=="AllowUsers" {for (i=2;i<=NF;i++) print $i}' "$stage/config" | LC_ALL=C sort)
actual_allow=$(awk '$1=="allowusers" {for (i=2;i<=NF;i++) print $i}' <<< "$effective" | LC_ALL=C sort)
if [[ $actual_allow != "$expected_allow" ]]; then
    echo 'SSH AllowUsers conflict. Restoring previous drop-in.' >&2
    exit 1
fi
for setting in 'permitrootlogin no' 'pubkeyauthentication yes' \
    'passwordauthentication yes' 'kbdinteractiveauthentication no' \
    'permitemptypasswords no'; do
    if ! grep -Fxq -- "$setting" <<< "$effective"; then
        echo "SSH configuration conflict: expected $setting. Restoring previous drop-in." >&2
        exit 1
    fi
done
# Configuration is valid; service failures leave it available for diagnosis/retry.
committed=true
systemctl enable --now sshd
systemctl reload sshd
echo 'LAN SSH enabled. Connect using this machine’s LAN IP and your normal username.'
echo 'Copy a client key with ssh-copy-id; firewall rules remain machine-local.'
ROOT
