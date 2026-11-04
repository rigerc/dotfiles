# Dotfiles

Minimal configuration for Arch machines using Fish, Atuin, Ghostty, Hyprland,
and Noctalia. Independent of the previous chezmoi setup, with Hyprland bindings
and rules adapted from the active desktop configuration.

Cloning the repository leaves your system unchanged. Installation requires
running the installer explicitly with `--apply`.

## Install

On Arch or an Arch derivative, clone the repository as your normal user:

```sh
git clone https://github.com/rigerc/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"

# Preview the package command and file changes; does not change your home.
./install.sh --packages

# Install core packages, back up/apply dotfiles, and use Fish as the login shell.
./install.sh --apply --packages
```

Git is needed to clone. The installer can bootstrap chezmoi with the core
packages; without chezmoi, preview shows the package command and setup guidance.
Package installation uses `sudo pacman -Syu --needed` and retains pacman's
normal prompts. The core list is in [packages/arch.txt](packages/arch.txt).
No AUR packages or third-party repositories are installed automatically.

If the dependencies are already installed, use `./install.sh --apply`.
The installer sets `/usr/bin/fish` as your account's login shell using `chsh`,
which may ask for your password. It checks the account database rather than
`$SHELL`, and also checks this on reruns when the dotfiles already match.
Log out and back in for the new shell to take effect. Use
`./install.sh --apply --no-shell` to keep your current login shell.
The change follows [Arch's chsh behavior](https://man.archlinux.org/man/chsh.1.en).

Running `./install.sh` or passing `--dry-run` previews changes. To render into
a separate home directory, use `./install.sh --apply --destination /tmp/dotfiles-demo`.
Custom destinations never change your login shell, even with `--apply`.
Package installation, when requested, always affects the host system.

Before writing changes, the installer saves replaced files under
`${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/` with private permissions.
Each backup includes `existing.txt`, `created.txt`, and original files under
`files/`; symlinks are preserved. Keep the backup path printed during install.
For manual rollback, review those manifests, restore originals from `files/`,
and remove only the new files listed in `created.txt` that you want to undo.
Packages, your account's login shell, and unrelated legacy settings are outside
this file backup. To revert the shell change, use `chsh --shell OLD_SHELL` with
your previous shell's full path.

The installer uses this checkout explicitly and isolates its chezmoi config,
cache, and state. It does not change the previous chezmoi source or register
this checkout as its default. For updates, run `git pull`, preview again with
`./install.sh`, then run `./install.sh --apply`.

After installation, choose the packaged **Hyprland** session at your next login.
The configuration starts Noctalia and, when installed, Vicinae at compositor
startup. The installer does not restart your current session, configure a login
manager or perform Atuin authentication. Select a
session that loads `~/.config/hypr/hyprland.lua`; a custom session loading the
old `hypr/noctalia/` root will continue to use that old configuration.

Remove conflicting old shell autostarts and review Noctalia GUI overrides
before switching sessions. GPU/driver setup remains machine-specific. These
files target the standard `~/.config` path and require Hyprland 0.57+ and
Noctalia v5.

## Files

Chezmoi reads `home/` through `.chezmoiroot`. Its `dot_` prefix represents a
leading dot in the eventual destination filename.

- `home/dot_config/fish/config.fish`: quiet greeting, user binary paths, and
  optional Atuin integration on Ctrl-R.
- `home/dot_atuin/config.toml`: global history search and five-minute sync.
  This targets `~/.atuin/config.toml`, as reported by the installed Atuin 18.24.1.
  Check `atuin info` before deploying to a machine with a different version.
- `home/dot_config/ghostty/config`: Fish, Rosé Pine, padding, and basic bindings.
- `home/dot_config/hypr/hyprland.lua`: native Lua for Hyprland 0.57+ and automatic
  monitor placement/scaling. Loads `scrolling.lua`, `binds.lua`, and `rules.lua`
  from the same directory, plus `session.lua` for next-login startup.
- `home/dot_config/noctalia/config.toml`: Noctalia v5, a bottom bar, and Rosé Pine.

## Inspect without applying

Run these from the project directory with the corresponding tools installed:

```sh
fish --no-config --no-execute home/dot_config/fish/config.fish
for file in home/dot_config/hypr/*.lua; do luac -p "$file" || break; done
Hyprland --verify-config --config "$PWD/home/dot_config/hypr/hyprland.lua"
ghostty +validate-config --config-file="$PWD/home/dot_config/ghostty/config"
noctalia config validate "$PWD/home/dot_config/noctalia/config.toml"
```

Session startup runs Noctalia and an optional Vicinae server. Noctalia controls
require its running instance. Generated theme integration remains deferred.

Optional application bindings use `hyprsummon`, `vicinae`, `zen-browser`,
`nautilus`, `spotify-launcher`, `feishin`, and `fladder` on the desktop session's
PATH. Install the apps you use separately. `hyprsummon` provides run-or-raise;
without it, Enter/B launches Ghostty/Zen directly. Super+Space falls back to
Noctalia's launcher when Vicinae is not installed. The other app shortcuts need
their corresponding application. The core installer covers the five main
applications and desktop utilities, not this optional app set.

## Defaults and later setup

Hyprland uses the built-in scrolling layout with centered 90% columns. Zen,
Zed, Spotify, and Feishin start at 80% width. The adapted rules retain floating
utilities, Steam notification behavior, Noctalia settings sizing, and
Noctalia/Vicinae layer effects.

- Super+Enter runs or raises Ghostty; Super+T starts a new Ghostty window.
  Super+B runs or raises Zen; E/M/N launch Nautilus/Spotify/Feishin;
  Super+Shift+V launches Fladder.
- Super+Space toggles Vicinae or Noctalia's launcher; Super+S opens the control center;
  Super+comma opens settings; Alt+Tab opens the window switcher.
- Super+Alt+L locks; Super+Shift+E logs out. Super+L focuses right.
- Super+Q closes; Super+Shift+T toggles floating; Super+F toggles fullscreen;
  Super+Shift+F toggles maximized fullscreen; Super+W toggles grouping.
- Super+H/J/K/L focuses windows; adding Shift moves them. Left/right arrows
  also focus windows. Adding Ctrl to H/J/K/L focuses monitors; Ctrl+Shift moves
  windows between monitors.
- Super+Up/Down changes workspaces; adding Alt moves a window there.
  Super+U/I and PageDown/PageUp cycle existing workspaces; Shift+U/I moves a
  window. Super+1–0 selects workspaces 1–10; adding Shift moves a window there.
- Super+[ / ] cycles column width; Super+R centers the current column. These
  replace the old dwindle-only preselect/togglesplit actions.
- Super+minus/equal resizes width; adding Shift resizes height. Super+mouse
  drag moves/resizes windows; Super+Shift+P toggles display power.
- Media/brightness keys use Noctalia. Print captures a region; Ctrl+Print
  captures all displays. A three-finger horizontal swipe changes workspaces.

Atuin synchronization needs a separate login on each machine using the same
account and encryption key. Authentication, history import, and key transfer
are deferred. Databases, identities, credentials, and generated files stay out
of this repository. Secret filtering does not replace keeping credentials out
of command lines.

Before applying later, define hardware-specific settings and account for legacy
Fish snippets, desktop autostarts, and Noctalia GUI overrides. Applying these
files alone would not remove those leftovers.

Configuration references: [chezmoi source layout](https://www.chezmoi.io/user-guide/advanced/customize-your-source-directory/),
[Fish](https://fishshell.com/docs/current/tutorial.html),
[Atuin](https://docs.atuin.sh/18.19/configuration/config/),
[Ghostty](https://ghostty.org/docs/config/reference),
[Hyprland](https://wiki.hypr.land/configuring/), and
[Noctalia](https://docs.noctalia.dev/noctalia/configuration/).

Scrolling settings and layout actions follow the [Hyprland scrolling reference](https://wiki.hypr.land/configuring/layouts/scrolling-layout/).
Session startup follows [Noctalia's Hyprland setup](https://docs.noctalia.dev/noctalia/compositor-settings/hyprland/).

## Installer checks

With chezmoi, Python 3, and ShellCheck installed:

```sh
bash -n install.sh
shellcheck install.sh
python3 -m unittest discover -s tests -v
```

The integration checks use temporary homes, the real chezmoi renderer, and
stubbed package/account commands. They do not install packages, change your
login shell, or modify your home.
