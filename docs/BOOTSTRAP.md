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
bash install.sh                 # interactive first-run setup on Arch
bash install.sh --no-wifi       # keep existing network setup
bash install.sh --no-apply      # initialize chezmoi without deploying anything
bash install.sh --source PATH   # use another existing source checkout
```

The interactive steps are deliberately separate:

1. Optionally configure Wi-Fi via `nmtui connect` or `iwctl`. If iwd is active,
   the installer does not stop it or switch the network backend automatically.
2. Ask before `sudo pacman -Syu --needed` installs missing `git`, `chezmoi`,
   or `networkmanager`. **`-Syu` may upgrade the entire host.**
3. Ask before starting and enabling NetworkManager when it is not competing
   with an active iwd service.
4. Run `chezmoi init`, which prompts for Git identity, machine role, package
   profile, package-installation opt-in, and Chromebook tuning opt-in.
5. Display `chezmoi diff` and `chezmoi apply --dry-run --verbose`.
6. Ask separately before a file-only `chezmoi apply --exclude=scripts` and
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
