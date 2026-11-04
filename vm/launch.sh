#!/usr/bin/env bash
# Launch disposable Arch live ISO; 9p-shared checkout is read-only in guest.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
iso=
boot_disk=false
download_only=false
disk=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-arch-vm/disk.qcow2
ram=4096
cpus=2
usage() { cat <<'EOF'
Usage: vm/launch.sh [--iso /path/to/archlinux.iso | --boot-disk] [--download-only] [--disk /path/to/test.qcow2] [--ram 4096] [--cpus 2]
Requires qemu-system-x86_64 and qemu-img on the host. This uses a read-only
9p share and user-mode NAT. It never modifies the host's dotfiles.
Boot the Arch ISO, then in the guest:
  mkdir -p /mnt/dotfiles
  mount -t 9p -o trans=virtio,version=9p2000.L,ro dotfiles /mnt/dotfiles
  bash /mnt/dotfiles/vm/guest-smoke.sh
Without --iso, downloads and SHA-256 verifies the latest Arch ISO into the
local cache automatically. Use --download-only to fetch without launching QEMU.
For a manually supplied --iso, verify that file yourself.
EOF
}
while (($#)); do
    case $1 in
        --iso) (($#>=2)) || { echo 'Missing ISO path' >&2; exit 2; }; iso=$2; shift ;;
        --boot-disk) boot_disk=true ;;
        --download-only) download_only=true ;;
        --disk) (($#>=2)) || exit 2; disk=$2; shift ;;
        --ram) (($#>=2)) || exit 2; ram=$2; shift ;;
        --cpus) (($#>=2)) || exit 2; cpus=$2; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
if $boot_disk; then
    [[ -z $iso ]] || { echo 'Use either --iso or --boot-disk' >&2; exit 2; }
    ! $download_only || { echo '--download-only cannot be combined with --boot-disk' >&2; exit 2; }
    [[ -f $disk ]] || { echo "VM disk does not exist: $disk" >&2; exit 2; }
else
    if [[ -z $iso ]]; then
        iso=${XDG_CACHE_HOME:-${HOME:?}/.cache}/dotfiles-arch-vm/archlinux-x86_64.iso
        bash "$root/vm/download-iso.sh" --output "$iso"
    else
        ! $download_only || { echo '--download-only cannot be combined with --iso' >&2; exit 2; }
        [[ -f $iso ]] || { echo "ISO file not found: $iso" >&2; exit 2; }
    fi
    if $download_only; then
        printf 'Verified Arch ISO: %s\n' "$iso"
        exit 0
    fi
fi
command -v qemu-system-x86_64 >/dev/null || { echo 'Install qemu-system-x86_64 on the host' >&2; exit 1; }
command -v qemu-img >/dev/null || { echo 'Install qemu-img on the host' >&2; exit 1; }
[[ $ram =~ ^[0-9]+$ && $cpus =~ ^[0-9]+$ ]] || { echo 'RAM/CPUs must be integers' >&2; exit 2; }
mkdir -p -- "$(dirname -- "$disk")"
if [[ ! -f $disk ]]; then
    echo "Creating a disposable 20G qcow2 VM disk: $disk"
    qemu-img create -f qcow2 -- "$disk" 20G
fi
accel=()
if [[ -r /dev/kvm && -w /dev/kvm ]]; then accel=(-enable-kvm); fi
cat <<EOF
Booting Arch VM in QEMU with read-only host repo share: $root
In the guest run:
  mkdir -p /mnt/dotfiles
  mount -t 9p -o trans=virtio,version=9p2000.L,ro dotfiles /mnt/dotfiles
  bash /mnt/dotfiles/vm/guest-smoke.sh
The guest uses QEMU virtual networking, not a real Chromebook wireless device.
EOF
bootargs=(-boot order=c)
if ! $boot_disk; then bootargs=(-boot order=d -cdrom "$iso"); fi
exec qemu-system-x86_64 "${accel[@]}" -m "$ram" -smp "$cpus" \
    "${bootargs[@]}" \
    -drive "file=$disk,format=qcow2,if=virtio" \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
    -virtfs "local,id=dotfiles,path=$root,security_model=none,mount_tag=dotfiles,readonly=on"
