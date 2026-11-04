# Chromebook role: shared Arch dotfiles

Use this role on an **x86_64 Chromebook already running a working Arch Linux
installation**. The configuration is adapted from the attached
`arch-chromebook-rosepine-v2.zip`, but intentionally **reuses the general
Fish, Atuin, Ghostty, Hyprland rules/bindings, Noctalia, and Git configs**.

## What changes in the Chromebook role

- Choose `chromebook` at the first-run `machineRole` prompt. The regular
  `desktop` package profile remains the default.
- The existing `hyprland.lua` continues to load shared scrolling, window
  rules, keybindings and session startup, plus a small `chromebook.lua`
  override. It disables animations, blur and shadows, reduces gaps, sets 65%
  scrolling columns and adjusts touchpad behavior.
- Monitor resolution and scaling stay automatic. The Search/Super key mapping,
  GPU drivers, audio topology and lid/suspend behavior are not guessed.
- GTK 3/4 prefer dark mode and disabled animations on Chromebook only.
- `desktop`/`developer` pacman profiles add official packages for Chromebook
  graphics/audio diagnostics, fonts and basic laptop functions. `core` leaves
  these supplements out. Package installation remains **opt-in**.

The shared Rosé Pine theme and existing bindings are preserved. The alternative
Noctalia Moon/Shelly configuration, Fish abbreviations and browser AUR installers
from the uploaded bundle are **not** deployed. The optional package
`zram-generator` is installed but no zram configuration is activated.

## Hardware gate (important)

A retail model name is not enough to identify a Chromebook's support status.
Check the exact **board/HWID**, CPU, firmware, Wi-Fi, display, touchpad,
battery, storage and audio amplifier before changing system settings.

Chromebook audio topologies are board-specific; using the wrong driver or
topology may damage speakers. No firmware flash, disk partition operation,
audio override, power-management service enablement, systemd configuration,
zram tuning or AUR build is performed by this role.

Run the **read-only** hardware inventory on working Arch:

```sh
bash "$(chezmoi source-path)/scripts/chromebook-preflight.sh"
```

Review compatibility:
- [MrChromebox supported devices](https://docs.mrchromebox.tech/docs/supported-devices)
- [Chrultrabook device list](https://docs.chrultrabook.com/docs/devices.html)
- [ArchWiki Chromebook](https://wiki.archlinux.org/title/Chromebook)

If the Chromebook still runs ChromeOS, follow device-specific firmware and
data-recovery instructions separately, and do not apply this Arch setup yet.

## First-time chezmoi setup

```sh
sudo pacman -Syu --needed git chezmoi
chezmoi init rigerc/dotfiles
# Choose machineRole = chromebook; leave installPackages = false initially.
chezmoi data
chezmoi ignored
chezmoi --no-pager diff
chezmoi apply --dry-run --verbose
chezmoi apply --exclude=scripts --verbose
```

To enable package installation later, edit your **local**
`~/.config/chezmoi/chezmoi.toml`, set `data.installPackages = true`, preview,
then run `chezmoi apply --verbose`. This may invoke an interactive
`pacman -Syu --needed` transaction that upgrades the whole system.
The `chromebook` role's package script refuses non-x86_64 architectures.
No automatic AUR packages or custom installers are included.

Original research bundle's `system/` examples and browser installers are kept
out of managed source state because they are optional and may be
hardware-specific.
