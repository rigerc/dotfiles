#!/usr/bin/env bash
# Interactive first-run bootstrap for a new Arch Linux installation.
# Day-to-day dotfile and package management belongs to chezmoi.
set -euo pipefail
umask 077

# Also supports `curl ... | bash` (where BASH_SOURCE has no filesystem path).
if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
    project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
else
    project_root=$(pwd -P)
fi
source_root=$project_root
remote_repository=https://github.com/rigerc/dotfiles.git
preview=false
skip_wifi=false
skip_apply=false
check_network=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run] [--check-network] [--no-wifi] [--no-apply] [--source PATH]

  --dry-run      No prompts or modifications; describe first-run actions.
  --check-network  Report whether an active default network route exists; no changes.
  --no-wifi      Do not offer to configure Wi-Fi.
  --no-apply     Initialize chezmoi but do not apply any files or scripts.
  --source PATH  Use an existing local checkout as the chezmoi source.
  -h, --help     Show this help.

Run as an ordinary user on an Arch installation, not as root. Existing
An active network route skips Wi-Fi setup automatically, including in VMs.
NetworkManager or iwd connections are preserved. Wi-Fi secrets are entered
through their interfaces, never through shell arguments or dotfile prompts.
A controlling terminal is required; piped installers read answers from /dev/tty.
EOF
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '\n%s\n' "$*"; }
ask() {
    # Defaults to No. No destructive step may be approved by empty input.
    local answer
    printf '%s [y/N]: ' "$1" >&2
    IFS= read -r answer <&3 || return 1
    [[ $answer == [yY] || $answer == [yY][eE][sS] ]]
}
have() { command -v "$1" >/dev/null 2>&1; }
network_detected() {
    # Detect a usable network route without probing websites or logging traffic.
    # A default route does not guarantee DNS or Internet access.
    if have ip; then
        [[ -n $(ip -4 route show default 2>/dev/null) ]] && return 0
        [[ -n $(ip -6 route show default 2>/dev/null) ]] && return 0
    fi
    if have nmcli; then
        local state
        state=$(nmcli -t -f STATE general status 2>/dev/null || true)
        [[ $state == connected* ]] && return 0
    fi
    return 1
}
is_arch() {
    [[ -r /etc/os-release ]] || return 1
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ ${ID:-} == arch ]] || [[ " ${ID_LIKE:-} " == *' arch '* ]]
}

while (($#)); do
    case $1 in
        --dry-run) preview=true ;;
        --check-network) check_network=true ;;
        --no-wifi) skip_wifi=true ;;
        --no-apply) skip_apply=true ;;
        --source)
            (($# >= 2)) || fail '--source requires a directory'
            source_root=$2
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown argument $1 (see --help)" ;;
    esac
    shift
done

if $check_network; then
    if network_detected; then
        echo 'Network detected (active default route or connected NetworkManager state).'
        exit 0
    fi
    echo 'No active network detected.'
    exit 1
fi

if $preview; then
    cat <<'EOF'
DRY RUN — this script will not modify your system.
  1. Verify Arch and require a normal user with sudo.
  2. Detect existing networking; skip Wi-Fi setup when a route is active.
     If disconnected, offer nmtui (or interactive iwctl).
     No password is read, printed, or stored by this installer.
  3. With explicit consent, use sudo pacman -Syu --needed to install
     missing git and chezmoi (full system upgrade).
  4. Initialize chezmoi, prompting for Git identity, machine role,
     package profile, and opt-in Chromebook tuning.
  5. Preview chezmoi's diff and file-only dry run.
  6. With separate consent, apply files and run enabled chezmoi scripts.
Wi-Fi/network access is required before pacman or git clone can work.
EOF
    printf 'Source: %s\n' "$source_root"
    $skip_wifi && echo 'Wi-Fi step explicitly skipped.'
    $skip_apply && echo 'Automatic chezmoi apply step explicitly skipped.'
    exit 0
fi

((EUID != 0)) || fail 'Run as your normal user; pacman uses sudo when needed.'
[[ -t 2 ]] || fail 'This installer needs a terminal. Use --dry-run for a preview.'
# Keep the terminal as a dedicated input descriptor. This works with curl | bash.
exec 3</dev/tty || fail 'No controlling terminal available for interactive prompts.' 
is_arch || fail 'This installer supports Arch Linux and Arch derivatives only.'
have pacman || fail 'pacman is required; run on an installed Arch system, not ChromeOS.'
have sudo || fail 'sudo is required. Install/configure sudo for your normal user first.'

if $skip_wifi; then
    info 'Wi-Fi setup explicitly skipped (--no-wifi).'
elif network_detected; then
    info 'Network already detected; skipping Wi-Fi setup and preserving existing network services.'
else
    info 'No active network route detected; optional Wi-Fi setup is available.'
    if have systemctl && systemctl is-active --quiet NetworkManager 2>/dev/null \
        && have nmtui; then
        if ask 'Open NetworkManager Wi-Fi selection now?'; then
            nmtui connect <&3
        fi
    elif have systemctl && systemctl is-active --quiet iwd 2>/dev/null \
        && have iwctl; then
        if ask 'Open the active iwd Wi-Fi console now?'; then
            iwctl <&3
        fi
    elif have nmtui && have systemctl; then
        if ask 'Start NetworkManager for interactive Wi-Fi setup?'; then
            sudo systemctl enable --now NetworkManager <&3
            nmtui connect <&3
        fi
    elif have iwctl; then
        if ask 'Open iwd Wi-Fi console now?'; then
            iwctl <&3
        fi
    else
        info 'No Wi-Fi setup tool available. Connect using Arch installation tools or Ethernet.'
    fi
    if network_detected; then
        info 'An active network route is now available.'
    else
        info 'No active network route detected. Bootstrap package downloads require Internet access.'
    fi
fi

missing=()
for tool in git chezmoi; do
    have "$tool" || missing+=("$tool")
done
if ((${#missing[@]})); then
    printf '\nMissing bootstrap packages: %s\n' "${missing[*]}"
    info 'The next step performs a full pacman system upgrade and installs the missing packages.'
    ask 'Run sudo pacman -Syu --needed for bootstrap packages?' || fail 'Bootstrap cancelled; nothing installed.'
    sudo pacman -Syu --needed "${missing[@]}" <&3
else
    info 'Git and chezmoi are already available.'
fi

if [[ -r "$source_root/.chezmoiroot" ]]; then
    source_root=$(cd -- "$source_root" && pwd -P)
    info "Using local dotfiles checkout: $source_root"
else
    have git || fail 'git is still unavailable after bootstrap.'
    target=${HOME:?}/.local/share/chezmoi-bootstrap
    if [[ -e $target ]]; then
        fail "Cannot clone: $target exists. Pass --source PATH for an existing checkout."
    fi
    info "Cloning $remote_repository into $target"
    git clone --depth 1 -- "$remote_repository" "$target"
    source_root=$target
fi

have chezmoi || fail 'chezmoi is unavailable after bootstrap.'
info 'Initializing chezmoi: answer the Git identity and machine-role prompts.'
chezmoi --source "$source_root" init <&3
info 'Previewing file changes. No files or scripts have been applied yet.'
chezmoi --no-pager diff
chezmoi apply --dry-run --verbose
if $skip_apply; then
    info 'Initialization completed. Use chezmoi diff / chezmoi apply manually.'
    exit 0
fi
if ask 'Apply configuration files only (no scripts or package installation)?'; then
    chezmoi apply --exclude=scripts --verbose <&3
else
    info 'Files not applied.'
fi
if ask 'Run enabled chezmoi scripts now (may upgrade packages and tune this Chromebook)?'; then
    chezmoi apply --verbose <&3
else
    info 'Provisioning skipped. Run chezmoi apply --verbose later when ready.'
fi
info 'Setup complete. Your dotfiles and machine-local chezmoi config are managed by chezmoi.'
