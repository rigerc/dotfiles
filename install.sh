#!/usr/bin/env bash
# Interactive first-run bootstrap for a new Arch Linux installation.
# Day-to-day dotfile and package management belongs to chezmoi.
set -euo pipefail
umask 077

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source_root=$project_root
remote_repository=https://github.com/rigerc/dotfiles.git
preview=false
skip_wifi=false
skip_apply=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run] [--no-wifi] [--no-apply] [--source PATH]

  --dry-run      No prompts or modifications; describe first-run actions.
  --no-wifi      Do not offer to configure Wi-Fi.
  --no-apply     Initialize chezmoi but do not apply any files or scripts.
  --source PATH  Use an existing local checkout as the chezmoi source.
  -h, --help     Show this help.

Run as an ordinary user on an Arch installation, not as root. Existing
NetworkManager or iwd connections are preserved. Wi-Fi secrets are entered
through NetworkManager's UI, never through shell arguments or dotfile prompts.
EOF
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '\n%s\n' "$*"; }
ask() {
    # Defaults to No. No destructive step may be approved by empty input.
    local answer
    printf '%s [y/N]: ' "$1" >&2
    IFS= read -r answer || return 1
    [[ $answer == [yY] || $answer == [yY][eE][sS] ]]
}
have() { command -v "$1" >/dev/null 2>&1; }
is_arch() {
    [[ -r /etc/os-release ]] || return 1
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ ${ID:-} == arch ]] || [[ " ${ID_LIKE:-} " == *' arch '* ]]
}

while (($#)); do
    case $1 in
        --dry-run) preview=true ;;
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

if $preview; then
    cat <<'EOF'
DRY RUN — this script will not modify your system.
  1. Verify Arch and require a normal user with sudo.
  2. Offer interactive Wi-Fi configuration via nmtui (or iwctl if needed).
     No password is read, printed, or stored by this installer.
  3. With explicit consent, use sudo pacman -Syu --needed to install
     missing git, chezmoi and networkmanager tools (full system upgrade).
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
[[ -t 0 && -t 1 ]] || fail 'This installer needs an interactive terminal. Use --dry-run for a preview.'
is_arch || fail 'This installer supports Arch Linux and Arch derivatives only.'
have pacman || fail 'pacman is required; run on an installed Arch system, not ChromeOS.'
have sudo || fail 'sudo is required. Install/configure sudo for your normal user first.'

if ! $skip_wifi; then
    info 'Network setup'
    if have nmcli && nmcli -t -f TYPE device status 2>/dev/null | grep -qx wifi; then
        if ask 'Open NetworkManager Wi-Fi setup now?'; then
            if systemctl is-active --quiet NetworkManager; then
                nmtui connect
            elif systemctl is-active --quiet iwd 2>/dev/null; then
                info 'iwd is active; will not start NetworkManager over it.'
                have iwctl && iwctl || info 'Connect with your existing network manager first.'
            elif ask 'NetworkManager is stopped. Start it for Wi-Fi configuration?'; then
                sudo systemctl enable --now NetworkManager
                nmtui connect
            fi
        fi
    elif have iwctl; then
        if ask 'NetworkManager is unavailable. Open iwd Wi-Fi setup?'; then
            iwctl
        fi
    else
        info 'No Wi-Fi setup tool detected. If offline, connect using Arch installation media or Ethernet first.'
        info 'On an Arch ISO, iwctl can connect before git/chezmoi are installed.'
    fi
fi

missing=()
for tool in git chezmoi nmcli; do
    case $tool in
        nmcli) have nmcli || missing+=(networkmanager) ;;
        *) have "$tool" || missing+=("$tool") ;;
    esac
done
if ((${#missing[@]})); then
    printf '\nMissing bootstrap packages: %s\n' "${missing[*]}"
    info 'The next step performs a full pacman system upgrade and installs the missing packages.'
    ask 'Run sudo pacman -Syu --needed for bootstrap packages?' || fail 'Bootstrap cancelled; nothing installed.'
    sudo pacman -Syu --needed "${missing[@]}"
else
    info 'Git, chezmoi, and NetworkManager are already available.'
fi

# Enable NetworkManager only when not competing with an active iwd service.
if have systemctl && ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
    if systemctl is-active --quiet iwd 2>/dev/null; then
        info 'iwd is active; preserving it rather than switching network managers.'
    elif ask 'Enable and start NetworkManager at boot?'; then
        sudo systemctl enable --now NetworkManager
    fi
fi
if ! $skip_wifi && have nmtui && have nmcli; then
    if nmcli -t -f TYPE device status 2>/dev/null | grep -qx wifi; then
        if ask 'Configure or verify Wi-Fi in NetworkManager now?'; then
            if systemctl is-active --quiet NetworkManager 2>/dev/null; then
                nmtui connect
            else
                info 'NetworkManager is not running; keeping your existing network setup.'
            fi
        fi
    fi
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
chezmoi --source "$source_root" init
info 'Previewing file changes. No files or scripts have been applied yet.'
chezmoi --no-pager diff
chezmoi apply --dry-run --verbose
if $skip_apply; then
    info 'Initialization completed. Use chezmoi diff / chezmoi apply manually.'
    exit 0
fi
if ask 'Apply configuration files only (no scripts or package installation)?'; then
    chezmoi apply --exclude=scripts --verbose
else
    info 'Files not applied.'
fi
if ask 'Run enabled chezmoi scripts now (may upgrade packages and tune this Chromebook)?'; then
    chezmoi apply --verbose
else
    info 'Provisioning skipped. Run chezmoi apply --verbose later when ready.'
fi
info 'Setup complete. Your dotfiles and machine-local chezmoi config are managed by chezmoi.'
