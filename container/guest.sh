#!/usr/bin/env bash
# Guest-side runner. Invoked only inside a disposable Arch container.
set -euo pipefail
umask 077
role=all
prompt=false
shell=false
fail() { printf 'Error: %s\n' "$*" >&2; exit 2; }
while (($#)); do
    case $1 in
        --role) (($# >= 2)) || fail '--role needs an argument'; role=$2; shift ;;
        --prompt) prompt=true ;;
        --shell) shell=true ;;
        *) fail "Unexpected guest option: $1" ;;
    esac
    shift
done
case $role in all|desktop|laptop|chromebook|server) ;; *) fail "Unknown role: $role" ;; esac
[[ -r /etc/os-release ]] || fail 'Arch Linux container required'
# shellcheck disable=SC1091
. /etc/os-release
[[ ${ID:-} == arch ]] || fail 'This test runner expects an Arch Linux container'
[[ $(id -u) -eq 0 ]] || fail 'Container root is required to install test tools INSIDE the guest'
[[ -f /repo/.chezmoiroot ]] || fail 'Read-only repository is not mounted at /repo'

printf '\n== Installing test tools inside the disposable Arch container ==\n'
pacman -Syu --needed --noconfirm git chezmoi python

# Never edit the host checkout: even init has a private, writable source copy.
work=$(mktemp -d /tmp/dotfiles-container.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
source_dir=$work/source
mkdir -p "$source_dir"
cp -a /repo/. "$source_dir/"
export HOME=$work/home
mkdir -p "$HOME"
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CACHE_HOME=$work/cache
export XDG_STATE_HOME=$work/state

if $prompt; then
    [[ -t 0 && -t 1 ]] || fail '--prompt requires a terminal'
    printf '\n== Interactive init; choose your machine role and profiles ==\n'
    # The init template stores answers within this disposable container only.
    chezmoi --source "$source_dir" init
    chezmoi --no-pager diff
    chezmoi apply --dry-run --exclude=scripts --verbose
    chezmoi apply --exclude=scripts --verbose
    echo 'File-only apply completed. Provisioning scripts were NOT run.'
else
    printf '\n== Repository Python checks (includes isolated chezmoi smoke tests) ==\n'
    (cd "$source_dir" && python -m unittest discover -s tests -v)
    roles=(desktop laptop chromebook server)
    [[ $role != all ]] && roles=("$role")
    for name in "${roles[@]}"; do
        printf '\n== File-only chezmoi smoke: %s ==\n' "$name"
        dest=$work/targets/$name
        mkdir -p "$dest"
        config=$work/$name.toml
        python - "$source_dir" "$name" > "$config" <<'PY'
import json, sys
source, role = sys.argv[1:]
print('sourceDir = ' + json.dumps(source))
print('[data]')
for key, value in {
    'gitName': 'Container Test',
    'gitEmail': 'container@example.invalid',
    'machineType': 'personal',
    'machineRole': role,
    'packageProfile': 'core',
    'installPackages': False,
    'chromebookTuning': False,
}.items():
    print(f'{key} = {json.dumps(value)}')
PY
        cm=(chezmoi --source "$source_dir" --destination "$dest"
            --config "$config" --cache "$work/cache-$name"
            --persistent-state "$work/state-$name.boltdb"
            --no-tty --no-pager)
        "${cm[@]}" apply --dry-run --exclude=scripts --verbose
        "${cm[@]}" apply --exclude=scripts --verbose
        test -f "$dest/.config/fish/config.fish"
        test -f "$dest/.gitconfig"
        grep -q 'container@example.invalid' "$dest/.gitconfig"
        case $name in
            server)
                test ! -e "$dest/.config/hypr/hyprland.lua"
                test ! -e "$dest/.config/ghostty/config" ;;
            chromebook)
                test -f "$dest/.config/hypr/chromebook.lua"
                test -f "$dest/.config/gtk-3.0/settings.ini"
                grep -q 'require("chromebook")' "$dest/.config/hypr/hyprland.lua" ;;
            *)
                test -f "$dest/.config/hypr/hyprland.lua"
                test ! -e "$dest/.config/hypr/chromebook.lua" ;;
        esac
        echo "PASS: $name (scripts excluded)"
    done
    printf '\n== Chromebook tuning in a disposable staging directory ==\n'
    tuner="$source_dir/home/.chezmoitemplates/chromebook-tune.sh"
    staging=$work/chromebook-system
    bash "$tuner" --dry-run --root "$staging"
    bash "$tuner" --apply --root "$staging"
    test -f "$staging/etc/systemd/zram-generator.conf.d/50-chezmoi-chromebook.conf"
    bash "$tuner" --rollback --root "$staging"
    test ! -e "$staging/etc/systemd/zram-generator.conf.d/50-chezmoi-chromebook.conf"
    echo 'PASS: Chromebook tuner staging and rollback'
fi

if $shell; then
    printf '\nDisposable container shell. HOME=%s\n' "$HOME"
    printf 'Private source copy: %s\n' "$source_dir"
    printf 'Inspect changes; exit to discard the entire container.\n'
    cd "$source_dir"
    bash -i
fi
printf '\nArch container checks completed. No host configuration was modified.\n'
