#!/usr/bin/env bash
set -euo pipefail
umask 077

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
destination=${HOME:?HOME must be set}
apply=false
dry_run_requested=false
packages=false
login_shell=true
custom_destination=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run | --apply] [--packages] [--no-shell] [--destination DIR]

  --dry-run          Preview file changes (the default); never install packages.
  --apply            Back up/apply dotfiles and set Fish as your login shell.
  --packages         Also install packages/arch.txt using sudo pacman -Syu --needed.
  --no-shell         Keep your current login shell.
  --destination DIR  Target another home directory, e.g. for a staged install.
  --help             Show this help.

Run as your normal user. Package installation keeps pacman's interactive prompts.
Custom destinations never change your login shell. chsh may ask for your password.
No service restarts or Atuin authentication are performed.
EOF
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

while (($#)); do
    case $1 in
        --dry-run)
            $apply && die '--dry-run cannot be combined with --apply'
            dry_run_requested=true
            ;;
        --apply)
            $dry_run_requested && die '--apply cannot be combined with --dry-run'
            apply=true
            ;;
        --packages) packages=true ;;
        --no-shell) login_shell=false ;;
        --destination)
            (($# >= 2)) || die '--destination needs a directory'
            destination=$2
            custom_destination=true
            shift
            ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1 (see --help)" ;;
    esac
    shift
done

[[ $destination = /* ]] || die '--destination must be an absolute path'
destination=$(realpath -m -- "$destination")
[[ $destination != / ]] || die 'The destination must be a home directory, not /'
if $apply && ((EUID == 0)); then
    die 'Run as your normal user; only package installation uses sudo'
fi
if [[ $destination = "$(realpath -m -- "$HOME")" && -n ${XDG_CONFIG_HOME:-} ]]; then
    [[ $(realpath -m -- "$XDG_CONFIG_HOME") = "$destination/.config" ]] ||
        die 'These dotfiles target ~/.config; custom XDG_CONFIG_HOME is not supported yet'
fi

printf 'Source: %s\nDestination: %s\n' "$repo_dir" "$destination"
if $packages; then
    mapfile -t package_names < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$repo_dir/packages/arch.txt")
    ((${#package_names[@]})) || die 'The package manifest is empty'
    for package in "${package_names[@]}"; do
        [[ $package =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || die "Invalid package name: $package"
    done
    if $apply; then
        command -v pacman >/dev/null || die '--packages requires Arch Linux and pacman'
        command -v sudo >/dev/null || die '--packages requires sudo'
        sudo pacman -Syu --needed "${package_names[@]}"
    else
        printf 'Would run:'
        printf ' %q' sudo pacman -Syu --needed "${package_names[@]}"
        printf '\n'
    fi
fi

shell_change_needed=false
fish_shell=/usr/bin/fish
if $login_shell && ! $custom_destination; then
    shell_user=$(id -un)
    account=$(getent passwd "$shell_user") || die "Cannot read account details for $shell_user"
    IFS=: read -r _ _ _ _ _ account_home current_shell <<< "$account"
    [[ -n $account_home && -n $current_shell ]] || die 'Account home or login shell is missing'
    [[ $destination = "$(realpath -m -- "$account_home")" ]] ||
        die 'Destination does not match your account home; use --destination or --no-shell'
    if [[ $(realpath -m -- "$current_shell") = "$(realpath -m -- "$fish_shell")" ]]; then
        printf 'Fish is already your login shell.\n'
    else
        shell_change_needed=true
        if $apply; then
            [[ -x $fish_shell ]] || die 'Install Fish first, or use --apply --packages'
            command -v chsh >/dev/null || die 'chsh is required to change your login shell'
            registered_shells=$(chsh --list-shells) || die 'Cannot read the registered login shells'
            grep -Fxq -- "$fish_shell" <<< "$registered_shells" ||
                die "$fish_shell is not registered in /etc/shells; reinstall the fish package"
        else
            printf 'Would run: chsh --shell %s (current shell: %s)\n' "$fish_shell" "$current_shell"
        fi
    fi
fi

change_login_shell() {
    if $apply && $shell_change_needed; then
        printf 'Setting Fish as the login shell for %s (was %s).\n' "$shell_user" "$current_shell"
        if ! chsh --shell "$fish_shell"; then
            die "Dotfiles are installed, but the shell change failed. Retry: chsh --shell $fish_shell"
        fi
        printf 'Fish is now your login shell. Log out and back in for new login sessions.\n'
    fi
}

if ! command -v chezmoi >/dev/null; then
    if $apply; then
        die 'Install chezmoi first, or use --apply --packages'
    fi
    printf 'Install chezmoi to preview file changes, or use --apply --packages.\n'
    exit 0
fi

# Never read or rewrite the previous chezmoi source/configuration/state.
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
: > "$work_dir/chezmoi.toml"
cm=(chezmoi --source "$repo_dir" --destination "$destination"
    --config "$work_dir/chezmoi.toml" --cache "$work_dir/cache"
    --persistent-state "$work_dir/state.boltdb" --no-tty --no-pager --color=false)

status=$("${cm[@]}" status --include=files --path-style=relative)
changed=()
while IFS= read -r line; do
    # The second status column describes changes apply would make.
    [[ -n $line && ${line:1:1} != ' ' ]] || continue
    target=${line:3}
    [[ $target != /* && $target != ../* && $target != */../* ]] || die 'Invalid target path'
    [[ ! -d $destination/$target || -L $destination/$target ]] ||
        die "Expected a file but found a directory: $destination/$target"
    changed+=("$target")
    printf '%s\n' "$line"
done <<< "$status"

if ((${#changed[@]} == 0)); then
    printf 'Dotfiles are already up to date.\n'
    change_login_shell
    exit 0
fi
if ! $apply; then
    printf '\nPreview only. Run ./install.sh --apply to back up and write these files.\n'
    exit 0
fi

# Backups are private, preserve symlinks, and record newly created paths too.
backup_root=$destination/.local/state/dotfiles/backups
if [[ $destination = "$(realpath -m -- "$HOME")" ]]; then
    backup_root=${XDG_STATE_HOME:-$destination/.local/state}/dotfiles/backups
fi
mkdir -p -- "$backup_root"
backup_dir=$(mktemp -d "$backup_root/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")
printf '%s\n' "$destination" > "$backup_dir/destination.txt"
: > "$backup_dir/existing.txt"
: > "$backup_dir/created.txt"
for target in "${changed[@]}"; do
    if [[ -e $destination/$target || -L $destination/$target ]]; then
        mkdir -p -- "$backup_dir/files/$(dirname -- "$target")"
        cp -a -- "$destination/$target" "$backup_dir/files/$target"
        printf '%s\n' "$target" >> "$backup_dir/existing.txt"
    else
        printf '%s\n' "$target" >> "$backup_dir/created.txt"
    fi
done
printf 'Backup: %s\n' "$backup_dir"
for target in "${changed[@]}"; do
    mkdir -p -- "$destination/$(dirname -- "$target")"
done
if ! "${cm[@]}" apply --include=files --force; then
    die "Apply failed; inspect the backup at $backup_dir before retrying"
fi
printf '\nDotfiles applied. No services have been restarted.\n'
change_login_shell
printf 'At your next login, choose the packaged Hyprland session.\n'
printf 'Set up shared history separately with: atuin login -u YOUR_USERNAME\n'
