# Arch dotfiles (chezmoi)

A native [chezmoi](https://www.chezmoi.io/) source repository for Arch Linux.
It manages Fish, Atuin, Ghostty, Hyprland (Lua), Noctalia, Git and SSH settings,
with optional Herdr installation and LAN SSH serving.
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
when one is available (including container/virtual Ethernet). Otherwise it offers
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
desktop/laptop/chromebook/server role, package profile, package-installation,
Herdr, LAN SSH serving and Chromebook tuning opt-ins.
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
| `core` | `git`, `chezmoi`, `fish`, `atuin`, `github-cli` (`gh`), `openssh`, `curl` |
| `desktop` (default) | Core plus `ghostty`, `hyprland`, `noctalia`, the Wayland desktop portals, PipeWire, clipboard/brightness and screenshot utilities |
| `chromebook` role | Desktop/developer packages plus an official pacman supplement; optional opt-in zram, sysctl and journal tuning |
| `developer` | Desktop plus `jq`, `ripgrep`, `fd`, `fzf`, `neovim`, `tmux` |

Package installation is a templated `run_onchange_before_` script. When enabled,
it checks for missing packages and runs `pacman -Syu --needed` with normal pacman
confirmation. It requires an interactive terminal and refuses non-Arch hosts.
It never invokes AUR helpers or adds third-party package repositories.

Choose `core` for a server. Setting machine role to `server` also ignores
Ghostty, Hyprland, and Noctalia configurations.

## GitHub and LAN SSH

After applying files and installing packages, run:

```sh
dotfiles-github-auth
# Or select an existing custom private key:
dotfiles-github-auth ~/.ssh/my_github_key
```

The helper checks for an existing GitHub.com login, otherwise starts
[browser/device authentication](https://cli.github.com/manual/gh_auth_login),
and selects SSH for Git operations. It reuses standard SSH keys, offers to
generate a per-machine Ed25519 key if none exists, and asks before uploading
the selected public key to GitHub. `ssh-keygen` prompts for your passphrase.
For a custom identity, add `IdentityFile` under `Host github.com` in
`~/.ssh/config.d/github.conf`. Load passphrase-protected keys into your existing
agent with `ssh-add PATH_TO_KEY`. Tokens, keys and `authorized_keys` are unmanaged.

For incoming SSH, opt in to `enableSshd` on each machine you want to reach.
Existing installations can add these choices under `[data]` in
`~/.config/chezmoi/chezmoi.toml` (or rerun `chezmoi init`):

```toml
enableSshd = true
installHerdr = true
```

Preview with `chezmoi apply --dry-run --verbose`, then `chezmoi apply --verbose`.
These are independent opt-ins: they run even when `installPackages=false`, so
install their dependencies first. SSH setup needs OpenSSH, sudo and systemd;
Herdr needs curl. The SSH script generates missing host keys, installs
`/etc/ssh/sshd_config.d/00-chezmoi-lan.conf`, validates effective settings, and
enables/reloads `sshd`. It refuses to overwrite an unmanaged drop-in and restores
the previous file if validation fails.

The SSH policy allows only your local username from private IPv4, IPv6 ULA,
link-local and loopback source addresses. It disables root login and enables
public-key and password authentication so you can bootstrap a client key.
This is an SSH authentication restriction; the daemon still listens on its
configured interfaces. Router, VPN and firewall rules are machine-specific;
no ports are forwarded or firewall rules changed. A LAN with globally routed
IPv6 should use the machine's private IPv4 address with this policy.

On the receiving machine, find its LAN IP and SSH host-key fingerprint:

```sh
ip -brief address
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

From another machine on your network, substitute that IP and username:

```sh
ssh your-user@192.168.1.100
# Compare the first-connection fingerprint with the receiving machine.
ssh-copy-id your-user@192.168.1.100
```

For an alias, copy `~/.config/dotfiles/ssh-lan.conf.example` to
`~/.ssh/config.d/lan.conf` (create the directory with mode 700), edit its values,
and use `ssh lan-box`. The managed `~/.ssh/config` includes local `config.d`
files before shared defaults. Preview existing SSH config changes before apply;
move custom host blocks into these local files. Host-key checking stays enabled
and agent forwarding defaults to off.

`installHerdr=true` uses [Herdr's official stable installer](https://herdr.dev/tui/docs/install/)
to install into `~/.local/bin` if Herdr is missing; later updates are manual
with `herdr update` for direct installs. Existing installations are preserved.
In interactive SSH **login** shells, Fish starts or reattaches Herdr. Local
terminals, noninteractive SSH commands, SCP/SFTP, Herdr panes and existing
tmux/screen sessions skip it. Herdr's [pane environment variables](https://herdr.dev/tui/docs/add-herdr-support/)
prevent recursion. Detach with `Ctrl+B`, then `Q` to return to the SSH shell;
the remote panes keep running, and your next SSH login reattaches.

Fish must be your receiving account's login shell for automatic attachment:
`chsh --shell /usr/bin/fish` (optional and manual). For a plain recovery shell:

```sh
ssh -t lan-box 'DOTFILES_NO_HERDR=1 fish --interactive --login'
```

Setting either opt-in to `false` stops future provisioning; it does not undo
installation or disable a running daemon. To remove this SSH policy, run
`sudo systemctl disable --now sshd`, remove only the managed drop-in above,
and set `enableSshd=false`. Set `installHerdr=false` and apply to disable
automatic attachment. For a direct install, remove `~/.local/bin/herdr` manually
if desired; run `herdr server stop` first if you intend to end its panes.

## Chromebook tuning

The Chromebook role inherits your regular Fish, Atuin, shared Hyprland
bindings/rules, Noctalia and Git configuration. The rendered terminal module
selects lightweight `foot` on Chromebook while retaining Ghostty on other
graphical roles, and disables compositor blur-layer rules only for Chromebook. If you opt in to
`chromebookTuning` during `chezmoi init`, an `run_onchange_after_` script writes
its own small systemd zram-generator, sysctl and journald drop-ins with root
confirmation. Existing unmanaged files are protected; virtual machines are
recognized and skipped. The tuning can be rolled back using the script in
`home/.chezmoitemplates/`. Full details: [Chromebook guide](docs/CHROMEBOOK.md) and the [EDGAR-specific Arch installation handoff](docs/EDGAR.md).

## Disposable Arch container rehearsal

Use the [Podman container harness](docs/CONTAINER.md) to test the **real**
chezmoi source and all machine roles without installing Arch in a VM:

```sh
bash container/run.sh                    # All roles + Python/chezmoi tests
bash container/run.sh --role chromebook  # Chromebook-specific file rendering
bash container/run.sh --prompt           # Interactive first-run chezmoi prompts
bash container/run.sh --role desktop --shell  # Inspect a disposable test home
```

The runner mounts the checkout read-only, installs test tools **inside** an
isolated, disposable Arch container, applies *files only* (never scripts), and
stages/rolls back Chromebook system tuning under a temporary directory. It
never changes your real dotfiles or `/etc`. Rootless Podman and network access
are needed. Containers do **not** emulate Chromebook firmware, Wi-Fi devices,
or systemd boot. No ISO download or QEMU image is needed.

## Managed files

| Source | Target | Purpose |
| --- | --- | --- |
| `home/dot_config/fish/config.fish` | `~/.config/fish/config.fish` | Fish PATH and Atuin integration |
| `home/dot_config/fish/functions/dotfiles_remote_session.fish.tmpl` | `~/.config/fish/functions/dotfiles_remote_session.fish` | Opt-in Herdr attachment on SSH login |
| `home/private_dot_ssh/config` | `~/.ssh/config` | Shared SSH defaults and local host includes |
| `home/dot_local/bin/executable_dotfiles-github-auth` | `~/.local/bin/dotfiles-github-auth` | Interactive GitHub login and SSH key setup |
| `home/dot_atuin/config.toml` | `~/.atuin/config.toml` | Search and history sync preferences |
| `home/dot_config/ghostty/config` | `~/.config/ghostty/config` | Fish, Rosé Pine, fonts and keys |
| `home/dot_config/hypr/*.lua{,.tmpl}` | `~/.config/hypr/*.lua` | Hyprland 0.57+ layout, binds, rules, role-specific terminal/layer effects and startup |
| `home/dot_config/noctalia/config.toml` | `~/.config/noctalia/config.toml` | Noctalia v5 panel and theme |
| `home/dot_gitconfig.tmpl` | `~/.gitconfig` | Git identity from local prompts |
| `home/dot_config/git/ignore` | `~/.config/git/ignore` | Shared Git ignore patterns |
| `home/dot_config/dotfiles/machine.toml.tmpl` | `~/.config/dotfiles/machine.toml` | Local machine settings summary |

`.chezmoiroot` makes `home/` the chezmoi source-state directory.
`.chezmoiversion` declares a minimum chezmoi version of 2.72.0.
The generated local config is outside Git, normally at
`~/.config/chezmoi/chezmoi.toml`.

Hyprland starts Noctalia and, when installed, Vicinae at session startup.
Noctalia Alt+Tab uses held-modifier switching, including reverse selection
with Shift+Alt+Tab. The Chromebook supplement installs `foot` without removing
Ghostty from the shared desktop package list; confirm available eMMC space.

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
