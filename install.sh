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

# Keep this bootstrap self-contained for curl | bash. Color is decoration only.
prompt_title='' prompt_accent='' prompt_muted='' prompt_reset=''
if [[ -t 2 && -n ${TERM:-} && ${TERM:-} != dumb && -z ${NO_COLOR:-} ]]; then
    prompt_title=$'\e[1;36m' prompt_accent=$'\e[1m'
    prompt_muted=$'\e[2m' prompt_reset=$'\e[0m'
fi

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run] [--check-network] [--no-wifi] [--no-apply] [--source PATH]

  --dry-run      No prompts or modifications; describe first-run actions.
  --check-network  Report whether an active default network route exists; no changes.
  --no-wifi      Do not offer to configure Wi-Fi.
  --no-apply     Initialize chezmoi but do not apply any files or scripts.
  --source PATH  Use an existing local checkout as the chezmoi source.
  -h, --help     Show this help.

Run as an ordinary user on an Arch installation, not as root.
An active network route skips Wi-Fi setup automatically, including in VMs.
NetworkManager or iwd connections are preserved. Wi-Fi secrets are entered
through their interfaces, never through shell arguments or dotfile prompts.
A controlling terminal is required; piped installers read answers from /dev/tty.
Optional actions default to No. Set NO_COLOR=1 to disable terminal colors.
EOF
}
fail() { printf '\nError: %s\n' "$*" >&2; exit 1; }
section() { printf '\n%s%s%s\n' "$prompt_title" "$*" "$prompt_reset" >&2; }
info() { printf '  %s\n' "$*"; }
ask() {
    # Defaults to No; invalid input retries instead of silently skipping a step.
    local answer
    printf '\n' >&2
    [[ -z ${2:-} ]] || printf '  %s\n' "$2" >&2
    while true; do
        printf '  %s%s%s %s[y/N]%s: ' "$prompt_accent" "$1" "$prompt_reset" \
            "$prompt_muted" "$prompt_reset" >&2
        if ! read -r answer <&3; then printf '\n' >&2; return 1; fi
        case ${answer,,} in
            y|yes) return 0 ;;
            ''|n|no) return 1 ;;
            *) printf '  Enter yes or no; press Enter to skip.\n' >&2 ;;
        esac
    done
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
     package profile, Herdr/LAN SSH opt-ins, and opt-in Chromebook tuning.
  5. Preview chezmoi's diff and file-only dry run.
  6. With separate consent, apply files and run enabled chezmoi scripts.
  7. Optionally sign in to GitHub and register this machine's SSH public key.
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

section 'Dotfiles setup'
info 'Choose settings, review changes, then apply the steps you want.'
info 'Optional actions default to No. Press Ctrl+C to exit.'
section '[1/6] Network'
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

section '[2/6] Bootstrap tools'
missing=()
for tool in git chezmoi; do
    have "$tool" || missing+=("$tool")
done
if ((${#missing[@]})); then
    info "Missing bootstrap packages: ${missing[*]}"
    ask 'Install bootstrap tools?' \
        'Runs sudo pacman -Syu --needed; this may upgrade the entire system.' || fail 'Bootstrap cancelled; nothing installed.'
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
section '[3/6] Machine settings'
info 'Saved answers are reused. Package installation, Herdr and LAN SSH are opt-in.'
chezmoi --source "$source_root" init <&3
section '[4/6] Review and apply files'
info 'Previewing file changes. No files or scripts have been applied yet.'
chezmoi --no-pager diff
chezmoi apply --dry-run --verbose
if $skip_apply; then
    info 'Initialization completed. Use chezmoi diff / chezmoi apply manually.'
    exit 0
fi
if ask 'Apply configuration files?' 'Writes the files shown above. No provisioning scripts run in this step.'; then
    chezmoi apply --exclude=scripts --verbose <&3
else
    info 'Files not applied.'
fi
section '[5/6] Optional provisioning'
if ask 'Run enabled setup scripts?' \
    'Runs only opted-in tasks: package upgrades, Herdr installation, LAN SSH and Chromebook tuning.'; then
    chezmoi apply --include=scripts --verbose <&3
else
    info 'Provisioning skipped. Run chezmoi apply --verbose later when ready.'
fi
section '[6/6] GitHub authentication'
github_setup=${HOME:?}/.local/bin/dotfiles-github-auth
if [[ -x $github_setup ]] && have gh && have ssh-keygen; then
    if ask 'Set up GitHub now?' 'Browser/device login, Git over SSH, and optional SSH key registration.'; then
        "$github_setup" <&3
    else
        info 'Skipped. Run dotfiles-github-auth whenever you are ready.'
    fi
else
    info 'Apply the helper and install github-cli/openssh, then run dotfiles-github-auth.'
fi
section 'Setup finished'
info 'Review or change saved choices: chezmoi edit-config'
info 'Preview future changes: chezmoi diff'
