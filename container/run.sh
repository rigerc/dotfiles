#!/usr/bin/env bash
# Host-side launcher for isolated, disposable Arch/chezmoi tests.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
image=${ARCH_TEST_IMAGE:-docker.io/library/archlinux:latest}
role=all
mode=check
keep_shell=false
usage() {
    cat <<'HELP'
Usage: bash container/run.sh [--role all|desktop|laptop|chromebook|server] [--prompt] [--shell]

  Default     Run automated tests and file-only chezmoi checks in all four roles.
  --role      Limit tests to one role (default: all). Required for --shell.
  --prompt    Answer real chezmoi init questions in an interactive disposable home.
  --shell     Stay in the disposable container after testing to inspect results.
  -h, --help  Show this help.

Requirements: rootless Podman, network access for the container image/pacman.
No host sudo, privileged mode, devices, or dotfiles writes. The checkout is
bind-mounted read-only. The container is removed on exit (--rm).
HELP
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 2; }
while (($#)); do
    case $1 in
        --role) (($# >= 2)) || fail '--role requires a value'; role=$2; shift ;;
        --prompt) mode=prompt ;;
        --shell) keep_shell=true ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
    shift
done
case $role in all|desktop|laptop|chromebook|server) ;; *) fail "Unknown role: $role";; esac
if [[ $mode == prompt && $role != all ]]; then
    fail 'For --prompt, choose the role interactively (omit --role).'
fi
if $keep_shell && [[ $role == all && $mode != prompt ]]; then
    fail 'For --shell, select a role with --role ROLE.'
fi
if [[ $mode == prompt || $keep_shell == true ]]; then
    [[ -t 0 && -t 1 ]] || fail '--prompt/--shell requires an interactive terminal'
fi
[[ -f $repo/.chezmoiroot && -f $repo/home/.chezmoi.toml.tmpl ]] || fail 'Not a chezmoi checkout'
command -v podman >/dev/null 2>&1 || fail 'Install Podman on your host first'
# Rootless Podman: container root maps into the invoking user's namespace.
# This allows pacman only inside the disposable guest, never on the host.
flags=(run --rm --pull=missing --volume "$repo:/repo:ro" --workdir /repo)
if [[ -t 0 && -t 1 ]]; then flags+=(-it); else flags+=(-i); fi
args=(--role "$role")
[[ $mode == prompt ]] && args+=(--prompt)
$keep_shell && args+=(--shell)
exec podman "${flags[@]}" "$image" bash /repo/container/guest.sh "${args[@]}"
