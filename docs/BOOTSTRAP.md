# Interactive Arch bootstrap

The optional root-level `install.sh` is a **bootstrap only**. Once chezmoi is
installed, all dotfiles, declarative packages, and Chromebook tuning are handled
by native chezmoi. This does not replace `chezmoi init` or `chezmoi apply`.

## Requirements

- Arch Linux or Arch derivative **already installed**; not ChromeOS.
- Ordinary user with `sudo` rights, `pacman` and a terminal.
- Networking through Ethernet, an existing Wi-Fi connection, NetworkManager,
  or `iwctl` from the Arch ISO. Installing NetworkManager requires a network
  connection first. The script cannot bootstrap an unavailable Wi-Fi driver.
- An extracted local checkout, or a separately downloaded `install.sh` with
  network access for its optional Git clone.

The script **never asks for, logs, passes on a command line, or commits a
Wi-Fi password**. NetworkManager's `nmtui connect` UI (or interactive `iwctl`)
requests Wi-Fi credentials directly. Connection profiles are managed by the
OS, not by chezmoi. Do not enable shell tracing (`bash -x`) around credentials.

## Usage

```sh
bash install.sh --dry-run       # no change, no prompt, safe on any OS
bash install.sh --check-network # check for an active default route, no changes
bash install.sh                 # interactive first-run setup on Arch
bash install.sh --no-wifi       # keep existing network setup
bash install.sh --no-apply      # initialize chezmoi without deploying anything
bash install.sh --source PATH   # use another existing source checkout
```

## Bootstrap directly with curl

On an **already installed Arch Linux system**, you can fetch the bootstrap
without cloning the repository. Prefer downloading and reviewing it first:

```sh
bootstrap=$(mktemp)
curl -fsSLo "$bootstrap" \
  https://raw.githubusercontent.com/rigerc/dotfiles/main/install.sh
less "$bootstrap"
bash "$bootstrap"
rm -f -- "$bootstrap"
```

Alternatively, if you have already inspected and trust the GitHub source:

```sh
curl -fsSL https://raw.githubusercontent.com/rigerc/dotfiles/main/install.sh | bash
```

The pipe mode keeps prompts and interactive tools attached to `/dev/tty`, not
stdin. Run in an interactive terminal, not a non-interactive SSH job. No
passwords or identity answers are passed as CLI flags. Before the curl command
can work, you need some initial networking (e.g., existing Ethernet or a
connection established using the Arch ISO's `iwctl`). If the installer detects
an active default route or connected NetworkManager state, it **automatically
skips all Wi-Fi setup**, preserving the active network manager. A route does
not guarantee DNS/Internet access, so verify connectivity if package downloads
fail.

The interactive steps are deliberately separate:

1. Check for an existing active network route and skip Wi-Fi configuration if
   one exists. Otherwise optionally use `nmtui connect` or `iwctl`. If iwd is
   active, the installer does not stop it or switch backends automatically.
2. Ask before `sudo pacman -Syu --needed` installs missing `git` and `chezmoi`.
   **`-Syu` may upgrade the entire host.** NetworkManager is not installed
   merely because it is missing when an existing network already works.
3. Run `chezmoi init`, which prompts for Git identity, machine role, package
   profile, package-installation opt-in, and Chromebook tuning opt-in.
4. Display `chezmoi diff` and `chezmoi apply --dry-run --verbose`.
5. Ask separately before a file-only `chezmoi apply --exclude=scripts` and
   before any full `chezmoi apply` that runs provisioning scripts.

If you select `machineRole=chromebook`, you can enable automatic zram, sysctl,
and journal tuning; the opt-in defaults to **No**. The system tuner also
checks x86_64 architecture, virtualization and DMI before touching real `/etc`.
It does not change firmware, audio topology, storage layout, bootloader,
network power-saving settings, or GPU drivers.

## Git configuration

`chezmoi init` asks for Git author name and email and stores them in the
**machine-local** chezmoi data. Applying files renders `~/.gitconfig`. It does
not issue `git config --global`, replace an existing `.gitconfig` without a
preview, or push private identity into your public repo.

If this script is run outside the repository, it clones the public source
into `~/.local/share/chezmoi-bootstrap`. It will not overwrite an existing
path. You may instead pass `--source` and use an extracted checkout.

To inspect or edit later:

```sh
chezmoi data
chezmoi --no-pager diff
chezmoi source-path ~/.gitconfig
chezmoi apply --exclude=scripts
```

## Isolated test environment

To rehearse chezmoi first-run prompts and file deployment safely, use
`bash container/run.sh --prompt` instead of installing Arch in a VM. See
[Podman container guide](CONTAINER.md). The guest always excludes scripts.
