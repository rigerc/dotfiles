#!/usr/bin/env bash
# Safe, narrow Chromebook system tuning. No firmware, audio driver or boot edits.
set -euo pipefail

mode=apply
root=/
marker='# Managed by rigerc/dotfiles: Chromebook tuning. Remove with --rollback.'
usage() {
    cat <<'EOF'
Usage: chromebook-tune.sh [--dry-run | --apply | --rollback] [--root DIR]
  --dry-run   Show planned changes without writing anything.
  --apply     Create/update only this setup's specifically named files (default).
  --rollback  Delete only files with the managed marker, never others.
  --root DIR  Write under an alternate *test-only* root (no systemctl/sysctl).

For the real / root, --apply and --rollback require root privileges and
refuse virtual machines and non-Google/non-Chromebook DMI systems.
EOF
}
fail() { echo "chromebook-tune: $*" >&2; exit 1; }
while (($#)); do
    case "$1" in
        --dry-run) mode=preview ;;
        --apply) mode=apply ;;
        --rollback) mode=rollback ;;
        --root)
            (($# >= 2)) || fail '--root needs an absolute directory'
            root=$2
            shift ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done
[[ $root == /* ]] || fail '--root must be absolute'
root=$(realpath -m -- "$root")
[[ -d $root && ! -L $root ]] || fail 'The staging root must be an existing directory, not a symlink'
if [[ $root == / && $mode != preview ]]; then
    if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --quiet; then
        echo 'chromebook-tune: virtual machine detected; skipping host hardware changes.'
        exit 0
    fi
    if [[ $(id -u) != 0 ]]; then
        command -v sudo >/dev/null 2>&1 || fail 'sudo is required for system tuning'
        exec sudo -- bash "$0" "--$mode"
    fi
    [[ $(uname -m) == x86_64 ]] || fail 'This tuning profile supports x86_64 only'
    [[ -r /etc/os-release ]] || fail 'Missing /etc/os-release'
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ ${ID:-} == arch || " ${ID_LIKE:-} " == *' arch '* ]] || fail 'Not an Arch installation'
    dmi=$(cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/board_vendor /sys/class/dmi/id/product_name /sys/class/dmi/id/board_name 2>/dev/null || true)
    if [[ ! $dmi =~ [Gg]oogle|[Cc]hromebook ]]; then
        fail 'DMI does not identify a Google/Chromebook machine; refusing system tuning'
    fi
fi

files=(
    etc/systemd/zram-generator.conf.d/50-chezmoi-chromebook.conf
    etc/sysctl.d/90-chezmoi-chromebook.conf
    etc/systemd/journald.conf.d/50-chezmoi-chromebook.conf
)
render() {
    local kind=$1
    case "$kind" in
        zram)
            cat <<EOF
$marker
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
EOF
            ;;
        sysctl)
            cat <<EOF
$marker
# Moderate swap preference when using zram; minimize disk swap readahead.
vm.swappiness = 80
vm.page-cluster = 0
EOF
            ;;
        journal)
            cat <<EOF
$marker
[Journal]
SystemMaxUse=200M
EOF
            ;;
    esac
}

kinds=(zram sysctl journal)
for i in "${!files[@]}"; do
    file="$root/${files[$i]}"
    kind=${kinds[$i]}
    if [[ -e $file || -L $file ]]; then
        [[ ! -L $file && -f $file ]] || fail "Refusing non-regular file: $file"
        IFS= read -r first_line < "$file" || true
        [[ $first_line == "$marker" ]] || fail "Refusing to overwrite unmanaged file: $file"
    fi
    if [[ $mode == preview ]]; then
        printf 'Would manage: %s\n' "$file"
        continue
    fi
    if [[ $mode == rollback ]]; then
        if [[ -e $file ]]; then
            rm -- "$file"
            printf 'Removed managed file: %s\n' "$file"
        fi
        continue
    fi
    mkdir -p -- "$(dirname -- "$file")"
    # Refuse to follow a last-component symlink, even if introduced after the check.
    [[ ! -L $file ]] || fail "Refusing symlink: $file"
    tmp=$(mktemp "$(dirname -- "$file")/.chezmoi-chromebook.XXXXXXXX")
    render "$kind" > "$tmp"
    chmod 0644 "$tmp"
    if [[ -f $file ]] && cmp -s "$tmp" "$file"; then
        rm -- "$tmp"
        printf 'Already current: %s\n' "$file"
    else
        mv -f -- "$tmp" "$file"
        printf 'Wrote: %s\n' "$file"
    fi
done

if [[ $root == / && $mode == apply ]]; then
    echo 'Reloading systemd unit generators; zram will be configured at next boot.'
    systemctl daemon-reload || echo 'systemd reload failed; reboot to enable zram' >&2
    if command -v sysctl >/dev/null 2>&1; then
        sysctl -p /etc/sysctl.d/90-chezmoi-chromebook.conf || \
            echo 'Could not apply sysctl immediately; settings will load at next boot' >&2
    fi
fi
if [[ $root == / && $mode == rollback ]]; then
    echo 'Reboot to restore kernel parameters and zram configuration defaults.'
fi
