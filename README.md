# Arch dotfiles (chezmoi)

A native [chezmoi](https://www.chezmoi.io/) source repository for Arch Linux.
It manages Fish, Atuin, Ghostty, Hyprland (Lua), Noctalia, and Git settings.
Application configuration is kept as regular source files; machine-specific
choices are stored locally, not committed.

**A small optional bootstrap installer is provided; daily management remains native chezmoi. No automatic AUR helper or login-shell change.**
No dotfiles or packages are installed merely by cloning this repository.

## Guided first-time setup (recommended on Arch)

If you already have this checkout on your installed Arch machine:

```sh
bash install.sh --dry-run
bash install.sh
```

The installer detects an active network route first and **skips Wi-Fi setup**
when one is available (including QEMU virtual Ethernet). Otherwise it offers
NetworkManager (`nmtui connect`) or the interactive iwd fallback. It asks
before installing Git and chezmoi via
`pacman`, and runs interactive `chezmoi init` prompts. It separately asks before
applying files or running provisioning scripts. Wi-Fi passwords never enter
chezmoi data or the Git repository. See [bootstrap details](docs/BOOTSTRAP.md).

To bootstrap a fresh Arch machine **using curl without cloning first**:

```sh
bootstrap=$(mktemp)
curl -fsSLo "$bootstrap" \
  https://raw.githubusercontent.com/rigerc/dotfiles/main/install.sh
less "$bootstrap"  # Review downloaded code before execution
bash "$bootstrap"
rm -f -- "$bootstrap"
```

For a direct interactive one-liner (review remote scripts before trusting them):

```sh
curl -fsSL https://raw.githubusercontent.com/rigerc/dotfiles/main/install.sh | bash
```

The installer uses `/dev/tty` to collect responses in piped mode, never the
pipeline itself. The machine must already run Arch and have enough initial
network access to download the script. `bash install.sh --check-network` reports
route detection without making changes.

## First setup (native chezmoi commands)

Install Git and chezmoi on Arch:

```sh
sudo pacman -Syu --needed git chezmoi
```

Initialize from GitHub. This clones the source and asks for local machine
settings, but **does not deploy your dotfiles**:

```sh
chezmoi init rigerc/dotfiles
```

The prompts request your Git name/email, personal/work machine type,
desktop/laptop/chromebook/server role, package profile, package-installation
opt-in and Chromebook tuning opt-in.
**Package installation defaults to `false`.** For a first run, leave it off.

Review the changes and apply only configuration files:

```sh
chezmoi doctor
chezmoi data
chezmoi --no-pager diff
chezmoi apply --dry-run --verbose
chezmoi apply --exclude=scripts --verbose
```

Once you're ready to run chezmoi's enabled provisioning scripts:

```sh
chezmoi apply --verbose
```

With `installPackages=false`, the package script renders empty and has no
installation action. To enable it, change `data.installPackages` to `true` in
`~/.config/chezmoi/chezmoi.toml`, preview again, then run `chezmoi apply`.
The package script may perform a **full pacman system upgrade**.

## Package profiles

`home/.chezmoidata/packages.toml` is the single source of truth for pacman
package choices:

| Profile | Packages |
| --- | --- |
| `core` | `git`, `chezmoi`, `fish`, `atuin` |
| `desktop` (default) | Core plus `ghostty`, `hyprland`, `noctalia`, the Wayland desktop portals, PipeWire, clipboard/brightness and screenshot utilities |
| `chromebook` role | Desktop/developer packages plus an official pacman supplement; optional opt-in zram, sysctl and journal tuning |
| `developer` | Desktop plus `jq`, `ripgrep`, `fd`, `fzf`, `neovim`, `tmux` |

Package installation is a templated `run_onchange_before_` script. When enabled,
it checks for missing packages and runs `pacman -Syu --needed` with normal pacman
confirmation. It requires an interactive terminal and refuses non-Arch hosts.
It never invokes AUR helpers or adds third-party package repositories.

Choose `core` for a server. Setting machine role to `server` also ignores
Ghostty, Hyprland, and Noctalia configurations.

## Chromebook tuning

The Chromebook role inherits your regular Fish, Atuin, Ghostty, Hyprland
bindings and rules, Noctalia and Git configuration. If you opt in to
`chromebookTuning` during `chezmoi init`, an `run_onchange_after_` script writes
its own small systemd zram-generator, sysctl and journald drop-ins with root
confirmation. Existing unmanaged files are protected; virtual machines are
recognized and skipped. The tuning can be rolled back using the script in
`home/.chezmoitemplates/`. Full details: [Chromebook guide](docs/CHROMEBOOK.md).

## QEMU virtual-machine rehearsal

`vm/launch.sh` **automatically downloads and SHA-256 verifies** the current Arch
ISO when no `--iso` path is provided, then boots a disposable qcow2 disk,
virtual Ethernet, and a read-only checkout share. The guest smoke test checks
the installer preview, runs the test suite if its tools are present, and
stages/rolls back tuning without modifying the real `/etc`. For an interactive
installer rehearsal, install Arch in the VM and log in as a normal test user.
Fetch the ISO without launching QEMU using `bash vm/launch.sh --download-only`;
reuse a local ISO via `--iso /path/to/archlinux.iso`. See [VM test guide](docs/VM.md).

## Managed files

| Source | Target | Purpose |
| --- | --- | --- |
| `home/dot_config/fish/config.fish` | `~/.config/fish/config.fish` | Fish PATH and Atuin integration |
| `home/dot_atuin/config.toml` | `~/.atuin/config.toml` | Search and history sync preferences |
| `home/dot_config/ghostty/config` | `~/.config/ghostty/config` | Fish, Rosé Pine, fonts and keys |
| `home/dot_config/hypr/*.lua{,.tmpl}` | `~/.config/hypr/*.lua` | Hyprland 0.57+ layout, binds, rules and startup |
| `home/dot_config/noctalia/config.toml` | `~/.config/noctalia/config.toml` | Noctalia v5 panel and theme |
| `home/dot_gitconfig.tmpl` | `~/.gitconfig` | Git identity from local prompts |
| `home/dot_config/git/ignore` | `~/.config/git/ignore` | Shared Git ignore patterns |
| `home/dot_config/dotfiles/machine.toml.tmpl` | `~/.config/dotfiles/machine.toml` | Local machine settings summary |

`.chezmoiroot` makes `home/` the chezmoi source-state directory.
`.chezmoiversion` declares a minimum chezmoi version of 2.72.0.
The generated local config is outside Git, normally at
`~/.config/chezmoi/chezmoi.toml`.

Hyprland starts Noctalia and, when installed, Vicinae at session startup.
Some optional keybindings reference `hyprsummon`, `vicinae`, `zen-browser`,
`nautilus`, `spotify-launcher`, `feishin`, and `fladder`; these are **not**
installed by the package profiles. GPU drivers, display-manager sessions and
application accounts are machine-specific.

Atuin sync requires authenticating separately on each machine. Credentials,
private keys, history databases and generated state must not be committed.
Ghostty launches Fish directly; changing your login shell is optional:

```sh
chsh --shell /usr/bin/fish
```

## Daily use

```sh
chezmoi --no-pager diff              # Preview changes
chezmoi apply --dry-run --verbose   # Preview file and script operations
chezmoi apply --verbose             # Apply enabled operations
chezmoi update                      # Pull latest Git changes and apply
chezmoi source-path ~/.gitconfig    # Locate the source for a managed file
```

`chezmoi apply` can replace managed targets. Inspect the diff first; never use
`--force` without understanding its consequences. Changes made to a target
file directly may be lost on a later apply.

## Validation

```sh
python3 -m unittest discover -s tests -v
fish --no-config --no-execute home/dot_config/fish/config.fish
for file in home/dot_config/hypr/*.lua; do luac -p "$file" || break; done
```

Offline tests never invoke pacman or change your home directory. If the
`chezmoi` executable is installed, additional smoke tests use a temporary home
and exclude all scripts.

References: [chezmoi init](https://www.chezmoi.io/reference/commands/init/),
[chezmoi scripts](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/),
[package provisioning](https://www.chezmoi.io/user-guide/advanced/install-packages-declaratively/).
