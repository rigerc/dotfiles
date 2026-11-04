#!/usr/bin/env bash
# Download the latest official Arch x86_64 ISO and validate it before use.
set -euo pipefail
umask 077

mirror=https://geo.mirror.pkgbuild.com/iso/latest
iso_dir=${XDG_CACHE_HOME:-${HOME:?}/.cache}/dotfiles-arch-vm
output=$iso_dir/archlinux-x86_64.iso
force=false

usage() {
    cat <<'HELP'
Usage: vm/download-iso.sh [--output /absolute/path/archlinux.iso] [--mirror https://.../iso/latest] [--force]

Downloads the rolling Arch x86_64 installation ISO from a HTTPS mirror and
verifies its SHA-256 using that mirror's sha256sums.txt before making the file
available to QEMU. A previously downloaded ISO is reused only when its hash
matches the current release manifest. No host system files are modified.
HELP
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
while (($#)); do
    case $1 in
        --output) (($# >= 2)) || fail '--output needs a file path'; output=$2; shift ;;
        --mirror) (($# >= 2)) || fail '--mirror needs an HTTPS URL'; mirror=${2%/}; shift ;;
        --force) force=true ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
    shift
done
[[ $output = /* ]] || fail '--output must be an absolute path'
[[ $mirror == https://* ]] || fail 'Only HTTPS mirrors are supported'
[[ $mirror != *'?'* && $mirror != *'#'* ]] || fail 'Invalid mirror URL'
command -v curl >/dev/null 2>&1 || fail 'curl is required for ISO download'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum (coreutils) is required'
mkdir -p -- "$(dirname -- "$output")"
sums=$(mktemp "${output}.sha256.XXXXXX")
partial=
cleanup() {
    rm -f -- "$sums"
    if [[ -n $partial ]]; then rm -f -- "$partial"; fi
}
trap cleanup EXIT
printf 'Fetching checksum manifest from %s\n' "$mirror"
curl --fail --silent --show-error --location --retry 3 \
    --connect-timeout 15 --proto '=https' --proto-redir '=https' \
    --output "$sums" "$mirror/sha256sums.txt"
expected=$(awk '$2 == "archlinux-x86_64.iso" {print $1; exit}' "$sums")
[[ $expected =~ ^[0-9a-fA-F]{64}$ ]] || fail 'No valid archlinux-x86_64.iso SHA-256 in mirror manifest'
expected=${expected,,}
valid_iso() {
    [[ -f $1 ]] || return 1
    local line actual
    line=$(sha256sum -- "$1") || return 1
    actual=${line%% *}
    [[ ${actual,,} == "$expected" ]]
}
if ! $force && valid_iso "$output"; then
    printf 'Cached Arch ISO verified: %s\n' "$output"
    exit 0
fi
if [[ -e $output ]]; then
    printf 'Cached ISO is outdated or fails verification; fetching current release.\n' >&2
fi
partial=$(mktemp "${output}.partial.XXXXXX")
printf 'Downloading latest Arch x86_64 ISO to %s\n' "$output"
curl --fail --show-error --location --retry 3 --connect-timeout 15 \
    --proto '=https' --proto-redir '=https' \
    --output "$partial" "$mirror/archlinux-x86_64.iso"
valid_iso "$partial" || fail 'ISO checksum mismatch: refusing to use the downloaded file'
mv -f -- "$partial" "$output"
partial=
printf 'SHA-256 verified. Arch ISO ready: %s\n' "$output"
