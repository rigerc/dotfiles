# Dotfiles

Minimal configuration for Arch machines using Fish, Atuin, Ghostty, Hyprland,
and Noctalia. Independent of the previous chezmoi setup, with Hyprland bindings
and rules adapted from the active desktop configuration.

These are source files only. Nothing has been installed, linked, applied, or
registered with the existing chezmoi configuration.

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
  from the same directory.
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

The files contain no installation hooks, service definitions, or session
autostarts. Noctalia controls require a running Noctalia instance; Super+Space
requires a running Vicinae server. Starting those services and integrating
generated themes are deferred.

Application bindings expect `hyprsummon`, `vicinae`, `zen-browser`, `nautilus`,
`spotify-launcher`, `feishin`, and `fladder` on the desktop session's PATH.
`hyprsummon` provides the existing run-or-raise behavior for Ghostty and Zen;
Super+T launches Ghostty directly. Dependencies are not installed here. Fladder
was not on this machine's PATH during the review, so its retained shortcut
needs that application installed before use.

## Defaults and later setup

Hyprland uses the built-in scrolling layout with centered 90% columns. Zen,
Zed, Spotify, and Feishin start at 80% width. The adapted rules retain floating
utilities, Steam notification behavior, Noctalia settings sizing, and
Noctalia/Vicinae layer effects.

- Super+Enter runs or raises Ghostty; Super+T starts a new Ghostty window.
  Super+B runs or raises Zen; E/M/N launch Nautilus/Spotify/Feishin;
  Super+Shift+V launches Fladder.
- Super+Space toggles Vicinae; Super+S opens Noctalia's control center;
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
