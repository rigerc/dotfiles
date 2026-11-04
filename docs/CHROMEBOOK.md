# Chromebook role (Arch Linux, x86_64)

This role **extends** the existing Arch dotfiles. It does not replace the
shared Fish, Atuin, Ghostty, Hyprland bindings/rules, or Noctalia settings
with the standalone configuration in `arch-chromebook-rosepine-v2.zip`.
The role is intended for a Chromebook that **already boots a supported Arch
Linux installation**, not for a Chromebook still running ChromeOS or Crostini.

## What the role changes

- First-run prompt allows `machineRole = "chromebook"`, keeping the standard
  `desktop` package profile by default.
- The existing Hyprland Lua config continues to load the shared scrolling,
  rule, binding, and session modules, and additionally loads `chromebook.lua`.
  This override disables animations/blur/shadows, reduces gaps and scrolling
  column width, and adjusts touchpad scroll behavior.
- Monitor scale remains `auto`, and the shared keyboard/keybindings remain
  unchanged. Hardware-specific resolutions, Search/Super mapping, camera,
  audio topology, suspend and GPU-specific environment variables are **not**
  guessed. Check your keys with `wev` before changing shortcuts.
- Includes the supplied low-animation GTK 3/4 settings **only** on Chromebook.
- Adds an official-repository Chromebook pacman supplement to the selected
  `desktop` or `developer` profile. Selecting `core` deliberately skips it.
- The shell and Noctalia theme remain the shared Rosé Pine defaults. The
  alternate Rose Pine Moon / Shelly / AUR-based stack in the supplied ZIP is
  **not installed**, preserving your current general configuration.

The supplement installs tools such as `alsa-ucm-conf`, `sof-firmware`,
`upower`, `wev`, `mesa`, `networkmanager`, fonts, and `zram-generator`.
Installing `zram-generator` alone does not activate compressed swap. With
explicit `chromebookTuning=true`, chezmoi configures zram, sysctl and journal
limits. The optional bootstrap separately offers to enable NetworkManager; it
never flashes firmware, installs AUR packages or partitions disks.

## Before running chezmoi on the Chromebook

1. Confirm the Chromebook's exact HWID/board and that it is x86_64.
2. Verify Linux support for its firmware, graphics, Wi-Fi, keyboard, touchpad,
   storage, and especially **audio amplifier topology** with the board-specific
   documentation. Do not enable unknown audio topologies: some Chromebook
   combinations can damage speakers.
3. If firmware/ChromeOS changes are planned, follow the device-specific
   recovery and firmware documentation **separately** and back up data.
4. On a *working Arch installation*, run the read-only preflight:

   ```sh
   bash scripts/chromebook-preflight.sh
   ```

5. Use `chezmoi init rigerc/dotfiles`, answer role **chromebook**, then review:

   ```sh
   chezmoi data
   chezmoi ignored
   chezmoi --no-pager diff
   chezmoi apply --dry-run --verbose
   chezmoi apply --exclude=scripts --verbose
   ```

Package installation is off by default. Enabling it runs a full
`pacman -Syu --needed` transaction only after you review the command;
that may upgrade packages across the machine. Do not install AUR packages or apply hardware-specific tuning from the
supplied Chromebook bundle automatically; only the documented, managed opt-in
tuning is supported.

## Archive material intentionally not deployed

- Entire alternate Hyprland keybindings, Fish abbreviations, Ghostty font/color
  choices, and Noctalia/Shelly bar configuration (would conflict with shared
  configs).
- Google Chrome, Helium, Zen AUR installers and Shelly AUR bootstrap.
- Unreviewed `/etc` tuning and service changes from the supplied archive. The
  separately documented opt-in managed zram/sysctl/journald profile is used.
  Firmware or disk operations are never managed here.
- Any forced driver parameters or audio codec/topology overrides.

References: [ArchWiki Chromebook](https://wiki.archlinux.org/title/Chromebook),
[MrChromebox supported devices](https://docs.mrchromebox.tech/docs/supported-devices),
[Chrultrabook supported devices](https://docs.chrultrabook.com/docs/devices.html).

## Optional automatic tuning (new)

Chromebook system tuning is **not** triggered just by selecting the role. During
`chezmoi init`, choose **Yes** for `chromebookTuning` to enable a native chezmoi
`run_onchange_after_` step; otherwise it renders empty. A full `chezmoi apply`
will run it after package provisioning, if that has also been enabled.

When enabled on a genuine **x86_64 Arch Chromebook**, the script:

- Writes a managed zram-generator drop-in using up to half RAM (max 4 GiB),
  `zstd` compression and swap priority 100. This needs the `zram-generator`
  package (included in the Chromebook desktop/developer profile).
- Writes `vm.swappiness=80` and `vm.page-cluster=0` under `/etc/sysctl.d/`.
- Limits persistent systemd journal use to 200 MiB.

It never replaces a matching path if the contents lack its own marker, and
requires root/sudo for actual system changes. It refuses non-Chromebooks, non-
x86_64 hardware and non-Arch systems, and **skips real system tuning in VMs**.
Zram takes effect at the next reboot; the sysctl adjustments are applied
immediately when possible. No firmware, sound drivers/topologies, Wi-Fi power
policy, storage partitions, or boot settings are modified.

To preview without changing anything:

```sh
bash "$(chezmoi source-path)/home/.chezmoitemplates/chromebook-tune.sh" --dry-run
```

To roll back the managed `/etc` files **on the Chromebook**, run:

```sh
sudo bash "$(chezmoi source-path)/home/.chezmoitemplates/chromebook-tune.sh" --rollback
```

Then set `chromebookTuning=false` in your local chezmoi configuration to avoid
reapplying the configuration. Reboot to restore runtime defaults. Other tuning
or existing unmanaged files are never deleted.

For isolated chezmoi checks, including this role's file rendering and staged
system-tuning rollback, see the [Podman container guide](CONTAINER.md).
