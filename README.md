# Arch dotfiles (native chezmoi)

This is a native [chezmoi](https://www.chezmoi.io/) source repository for
Arch Linux. It manages Fish, Atuin, Ghostty, Hyprland Lua, Noctalia, and Git.
It uses chezmoi directly, without a custom installer, migration process, AUR
helper, or automatic login-shell change.

## First-time installation

Install chezmoi and Git:

```sh
sudo pacman -Syu --needed git chezmoi
```

Initialize the repo; this runs the interactive prompts but does not apply:

```sh
chezmoi init rigerc/dotfiles
```

Prompts cover Git name/email, personal/work machine, desktop/laptop/server role,
package profile, and whether to install packages. Package installation is
**disabled by default**. Leave it disabled during initial review.

Review what chezmoi will do before installing any files:

```sh
chezmoi doctor
chezmoi data
chezmoi --no-pager diff
chezmoi apply --dry-run --verbose
chezmoi apply --exclude=scripts --verbose
```

The last command applies managed files only and does not execute any scripts.
When ready to run any enabled provisioning scripts, use:

```sh
chezmoi apply --verbose
```

To enable package provisioning later, change `data.installPackages` to
`true` in your **machine-local** `~/.config/chezmoi/chezmoi.toml`.
Preview the diff again before applying. Chezmoi's package script uses
`sudo pacman -Syu --needed`, which may upgrade the **entire system**.

## Package profiles

The only package manifest is `home/.chezmoidata/packages.toml`.

| Profile | Contents |
| --- | --- |
| `core` | Git, chezmoi, Fish, Atuin |
| `desktop` (default) | Core plus Ghostty, Hyprland, Noctalia, Wayland portals, PipeWire, clipboard, brightness, and screenshot tools |
| `developer` | Desktop plus jq, ripgrep, fd, fzf, Neovim, tmux |

Provisioning runs through a templated `run_onchange_before_` script only after
you opt in. It checks missing packages first, retains pacman's interactive
confirmation, and refuses non-Arch hosts. No AUR packages or additional package
repositories are installed automatically.

A `server` role ignores Ghostty, Hyprland, and Noctalia configs; use the
`core` package profile for servers.

## Managed configurations

Chezmoi uses the `home/` source subtree via `.chezmoiroot`.

| Source | Target |
| --- | --- |
| `home/dot_config/fish/config.fish` | `~/.config/fish/config.fish` |
| `home/dot_atuin/config.toml` | `~/.atuin/config.toml` |
| `home/dot_config/ghostty/config` | `~/.config/ghostty/config` |
| `home/dot_config/hypr/*.lua` | `~/.config/hypr/*.lua` |
| `home/dot_config/noctalia/config.toml` | `~/.config/noctalia/config.toml` |
| `home/dot_gitconfig.tmpl` | `~/.gitconfig` |
| `home/dot_config/git/ignore` | `~/.config/git/ignore` |
| `home/dot_config/dotfiles/machine.toml.tmpl` | `~/.config/dotfiles/machine.toml` |

Your machine-specific answers reside in the local chezmoi configuration and
are **not** committed to Git. The source requires chezmoi 2.72.0 or newer.

Hyprland uses a scrolling layout and starts Noctalia at session startup, plus
Vicinae if installed. Some keybindings reference optional applications:
`hyprsummon`, `vicinae`, `zen-browser`, `nautilus`,
`spotify-launcher`, `feishin`, and `fladder`. Those apps are not covered
by the package profiles. Configure GPU drivers and your login/display manager
separately. Atuin sync also requires authentication per machine.

Ghostty launches Fish directly; changing your login shell is optional:

```sh
chsh --shell /usr/bin/fish
```

## Updates and verification

```sh
chezmoi --no-pager diff
chezmoi apply --dry-run --verbose
chezmoi apply --verbose
chezmoi update
python3 -m unittest discover -s tests -v
```

Offline tests never modify your home or install packages. When chezmoi is
installed, additional integration tests use a temporary home and exclude
scripts. Always review changes before `chezmoi apply`; do not use
`chezmoi apply --force` without understanding overwrites.

Docs: [init](https://www.chezmoi.io/reference/commands/init/),
[scripts](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/),
[package management](https://www.chezmoi.io/user-guide/advanced/install-packages-declaratively/).
