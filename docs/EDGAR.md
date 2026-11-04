# Acer Chromebook 14 CB3-431 (EDGAR): Arch / Hyprland / Noctalia

This is the **EDGAR-specific handoff** between a *manual* Arch Linux installation
and the shared [rigerc/dotfiles](../README.md) configuration. The general
[Chromebook role guide](CHROMEBOOK.md) explains chezmoi's opt-in behavior.

**This is not a complete firmware-flashing or disk-partitioning guide.**
Follow the current [MrChromebox documentation](https://docs.mrchromebox.tech/)
and [Arch installation guide](https://wiki.archlinux.org/title/Installation_guide)
for those steps; do not run automated firmware or partitioning commands from
dotfiles.

## Stop conditions before changing ChromeOS or firmware

- Confirm the *physical* model label reads **Acer CB3-431** and ChromeOS
  `HWID` begins with **EDGAR**. Stop if the device says C83-431 or the HWID
  is not EDGAR. Do not infer the board from appearance alone.
- Confirm it is a personally owned, unmanaged device and back up user data.
  Developer Mode erases data; repartitioning removes ChromeOS.
- Confirm [EDGAR support and screw-based hardware write protection](https://docs.mrchromebox.tech/docs/supported-devices.html).
  Use the [official EDGAR WP-screw photo](https://docs.mrchromebox.tech/images/wp/Edgar_wp.jpg);
  do not use GSC/CR50/SuzyQ procedures on this legacy board.
- Save the original firmware ROM **off the Chromebook** before flashing.
  On an EOL board, normal stock-firmware restoration may be unavailable and
  external SPI programming may be required. Do not reboot after a flash error.
- Check the actual RAM and eMMC capacity. A 2 GiB RAM or 16 GiB eMMC unit is
  especially constrained; Hyprland/Noctalia performance on this hardware is
  not guaranteed. Keep another computer and a recovery USB available.

## Installation boundaries

1. Perform the EDGAR firmware and physical write-protection procedure manually,
   and only after identifying the board. Keep the original ROM backup.
2. Boot the official Arch ISO in **64-bit UEFI** mode and positively identify
   the *internal* eMMC with `lsblk`. Never assume `/dev/mmcblk0`; never
   format eMMC `boot0` / `boot1` hardware regions.
3. Install a bootable minimal Arch system first (UEFI/GPT, ESP, root filesystem,
   `intel-ucode`, networking and a working regular user with sudo). Verify
   the real root filesystem UUID in the systemd-boot entry before rebooting.
4. Boot into an ordinary TTY. Confirm networking, available storage and
   graphics driver detection **before** deploying desktop dotfiles.
5. Use the existing chezmoi configuration rather than hand-authoring
   `~/.config/hypr/hyprland.lua`, Noctalia startup commands, or a second
   set of keyboard shortcuts. This prevents a future `chezmoi apply` from
   overwriting a separately configured session.

These checkpoints are intentionally manual. The repo's `install.sh` and
chezmoi scripts are **post-install tools**; they do not flash firmware,
partition storage, install a bootloader, or resolve Chromebook audio topology.

## Apply the existing dotfiles on a working Arch TTY

With a functioning internet connection:

```sh
sudo pacman -Syu --needed git chezmoi
chezmoi init rigerc/dotfiles
bash "$(chezmoi source-path)/scripts/chromebook-preflight.sh"
chezmoi data
chezmoi --no-pager diff
chezmoi apply --dry-run --verbose
chezmoi apply --exclude=scripts --verbose
```

Choose `machineRole = "chromebook"` and the normal `desktop` package profile.
The `core` profile intentionally omits all desktop and Chromebook packages.
For the **first** run, leave `installPackages = false` and
`chromebookTuning = false` until you have inspected the configuration and
checked `df -h /` / `free -h`. File-only apply is not package installation.

When ready, set `data.installPackages = true` in the local
`~/.config/chezmoi/chezmoi.toml`, preview again and explicitly run:

```sh
chezmoi apply --dry-run --verbose
chezmoi apply --verbose
```

Package provisioning may run a **full pacman upgrade**. The desktop profile
includes Ghostty for parity with other machines, while the Chromebook package
supplement installs **foot**. The same shared Hyprland shortcuts select foot on
Chromebook and Ghostty on desktop/laptop. Noctalia and Vicinae behavior is
shared; the Chromebook omits compositor blur-layer rules.

Start Hyprland from the local TTY as your regular user, for example with
`start-hyprland`. Keep TTY login available for recovery. Test `foot`,
Noctalia's launcher/control center and Alt+Tab in both directions before
considering a graphical login manager.

## Optional tuning and hardware acceptance

Only after `zram-generator` has been installed, consider
`data.chromebookTuning = true` and `chezmoi apply --verbose`.
The tuner manages **only** zram, swappiness and journald drop-ins, protects
unmanaged files, and offers `--dry-run` / `--rollback`. It refuses tuning on
a real host without the generator package; the `core` profile does not install
that package.

Check these individually on the real EDGAR device:

- GPU acceleration (`/dev/dri`, `lspci -nnk`), usable terminal and shell,
  Noctalia responsiveness and free RAM/eMMC space.
- Wi-Fi reconnect, backlight controls, the Chromebook top-row keys (`wev`),
  touchpad, suspend/resume and battery behavior.
- Audio endpoints, speakers, headphones and microphone at **low volume**.
  Consult [Chromebook Linux Audio](https://github.com/WeirdTreeThing/chromebook-linux-audio)
  and [Chrultrabook post-install documentation](https://docs.chrultrabook.com/docs/installing/post-install.html)
  for hardware-specific support. **Do not** enable an unknown amplifier
  topology or blindly force unsupported AVS modes.
- `swapon --show`, `zramctl` and `df -h /` after optional tuning.

Troubleshoot symptoms individually. Do not put firmware writes, driver
overrides or unreviewed audio scripts inside the chezmoi apply lifecycle.

## Further references

- [ArchWiki: Acer Chromebook 14 CB3-431 (Edgar)](https://wiki.archlinux.org/title/Acer_Chromebook_14_CB3-431_(Edgar))
- [MrChromebox: supported devices](https://docs.mrchromebox.tech/docs/supported-devices.html)
- [MrChromebox: firmware utility](https://docs.mrchromebox.tech/docs/fwscript)
- [Arch: installation guide](https://wiki.archlinux.org/title/Installation_guide)
- [Hyprland Lua configuration](https://wiki.hypr.land/Configuring/Start/)
- [Noctalia v5: Hyprland integration](https://docs.noctalia.dev/noctalia/compositor-settings/hyprland/)
