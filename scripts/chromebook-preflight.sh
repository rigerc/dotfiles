#!/usr/bin/env bash
# Read-only Chromebook hardware inventory. Does not install, modify or reboot.
set -u
section() { printf '\n=== %s ===\n' "$1"; }
warn() { printf 'WARNING: %s\n' "$1" >&2; }
section 'Architecture and CPU'
printf 'Architecture: %s\n' "$(uname -m)"
if [[ $(uname -m) != x86_64 ]]; then
    warn 'This preset is for x86_64 Arch; do not run Chromebook package provisioning.'
fi
if command -v lscpu >/dev/null; then
    lscpu | grep -E '^(Architecture|Model name|CPU\(s\)|Vendor ID):' || true
fi
if grep -qiw pni /proc/cpuinfo 2>/dev/null; then
    echo 'SSE3 (pni) reported; check each browser CPU requirement separately.'
else
    warn 'No SSE3 (pni) flag detected; verify browser support.'
fi
section 'Memory, swap, storage'
command -v free >/dev/null && free -h || true
command -v swapon >/dev/null && swapon --show || true
command -v lsblk >/dev/null && lsblk -o NAME,SIZE,TYPE,MODEL,FSTYPE,MOUNTPOINTS || true
df -h / || true
command -v lsblk >/dev/null && lsblk -D || true
section 'Boot and hardware identity'
if [[ -d /sys/firmware/efi ]]; then
    echo 'UEFI reported by Linux.'
else
    warn 'UEFI not reported; validate your board-specific boot path.'
fi
if [[ -r /sys/firmware/efi/fw_platform_size ]]; then
    printf 'UEFI platform size: %s-bit\\n' "$(cat /sys/firmware/efi/fw_platform_size)"
fi
for file in /sys/class/dmi/id/board_name /sys/class/dmi/id/product_name /sys/class/dmi/id/bios_version; do
    [[ -r $file ]] && printf '%s: %s\n' "$file" "$(cat "$file")"
done
section 'Graphics, audio, radios'
if command -v lspci >/dev/null; then
    lspci -nn | grep -Ei 'VGA|display|audio|network|wireless' || true
    lspci -nnk | grep -A 3 -Ei 'VGA compatible controller|3D controller|Display controller' || true
fi
if [[ -d /dev/dri ]]; then
    ls -l /dev/dri 2>/dev/null || true
else
    warn '/dev/dri missing: verify kernel graphics driver before launching Hyprland.'
fi
command -v rfkill >/dev/null && rfkill list || true
section 'Backlight, battery, power management'
ls /sys/class/backlight /sys/class/power_supply 2>/dev/null || true
if command -v systemctl >/dev/null; then
    for svc in NetworkManager systemd-networkd power-profiles-daemon tlp tuned; do
        printf '%s: ' "$svc"
        systemctl is-active "$svc" 2>/dev/null || true
    done
fi
section 'Key packages and compressed RAM swap'
if command -v pacman >/dev/null; then
    for pkg in hyprland noctalia mesa foot zram-generator; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
            printf '%s: installed\\n' "$pkg"
        else
            printf '%s: missing\\n' "$pkg"
        fi
    done
fi
command -v zramctl >/dev/null && zramctl || true
echo
echo 'Read docs/CHROMEBOOK.md before making hardware changes.'
echo 'For Acer CB3-431 (EDGAR), also read docs/EDGAR.md.'
echo 'This report does not prove firmware, graphics or audio support.'
