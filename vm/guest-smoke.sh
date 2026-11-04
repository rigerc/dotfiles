#!/usr/bin/env bash
# Execute on a *disposable Arch VM*, never on the host.
set -euo pipefail
repo=${1:-/mnt/dotfiles}
[[ -r $repo/.chezmoiroot ]] || { echo 'Mount the repository read-only at /mnt/dotfiles first' >&2; exit 2; }
[[ -r /etc/os-release ]] || exit 2
# shellcheck disable=SC1091
. /etc/os-release
[[ ${ID:-} == arch ]] || { echo 'This smoke harness expects an Arch Linux guest' >&2; exit 2; }
if ! { command -v systemd-detect-virt >/dev/null && systemd-detect-virt -q; } && \
   ! { grep -Eqi 'QEMU|KVM|Virtual' /sys/class/dmi/id/{sys_vendor,product_name} 2>/dev/null; }; then
    echo 'Refusing to run the VM harness outside a recognizable virtual machine' >&2
    exit 2
fi
printf '\n== Bootstrap dry run (must be side-effect free) ==\n'
bash "$repo/install.sh" --dry-run --source "$repo"

printf '\n== Temp-root system tuning simulation ==\n'
if [[ ! -f "$repo/home/.chezmoitemplates/chromebook-tune.sh" ]]; then
    echo 'Chromebook tuner missing' >&2
    exit 2
fi
sandbox=$(mktemp -d)
trap 'rm -rf -- "$sandbox"' EXIT
bash "$repo/home/.chezmoitemplates/chromebook-tune.sh" --root "$sandbox" --dry-run
bash "$repo/home/.chezmoitemplates/chromebook-tune.sh" --root "$sandbox" --apply
test -f "$sandbox/etc/systemd/zram-generator.conf.d/50-chezmoi-chromebook.conf"
bash "$repo/home/.chezmoitemplates/chromebook-tune.sh" --root "$sandbox" --rollback
test ! -f "$sandbox/etc/systemd/zram-generator.conf.d/50-chezmoi-chromebook.conf"

if command -v python3 >/dev/null && command -v chezmoi >/dev/null; then
    printf '\n== Python tests and chezmoi disposable-home integration ==\n'
    # Read-only 9p source is supported by chezmoi's --source flag.
    (cd "$repo" && python3 -m unittest discover -s tests -v)
else
    cat <<'EOF'
Optional live chezmoi/python tests skipped. On this throwaway Arch VM, install:
  pacman -Syu --needed chezmoi python
then rerun this guest script. This may perform a full system upgrade.
EOF
fi
printf '\nVM smoke checks complete. No Chromebook hardware was configured.\n'
