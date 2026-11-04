# Install Arch Linux + Hyprland + Noctalia v5 on an Acer CB3-431 (EDGAR) — Full ChromeOS Replacement

*Updated 4 November 2026 and integrated with the [rigerc/dotfiles](https://github.com/rigerc/dotfiles) chezmoi Chromebook role. Hardware and firmware steps apply **only** to Acer CB3-431 with confirmed ChromeOS board/HWID `EDGAR`; the post-install desktop is managed by the repository.*

> **Stop before flashing if the device label says `C83-431` rather than `CB3-431` and you cannot confirm `EDGAR` in its ChromeOS hardware ID.** The model identification is still an assumption until checked on the actual device. If the HWID is not EDGAR, do not follow these firmware or screw instructions.

## What changes from the generic guide

| Item | CB3-431 / EDGAR choice |
|---|---|
| Board / architecture | `EDGAR` / Intel Braswell x86_64 |
| Firmware | MrChromebox **UEFI Full ROM** is supported; RW_LEGACY is EOL |
| Firmware write-protect (WP) | **Remove one physical motherboard screw**; no CR50, Ti50, `gsctool`, SuzyQ or battery-disconnect sequence |
| Internal storage | **eMMC** (often `/dev/mmcblk0`; verify actual disk, never assume) |
| CPU microcode | `intel-ucode` |
| Boot | GPT + FAT32 EFI System Partition (ESP) + ext4 root + `systemd-boot` |
| Desktop / shell | **Hyprland** (Wayland compositor) + **Noctalia v5** from existing chezmoi dotfiles, no XFCE/Xorg desktop |
| Audio | `sof-firmware`, PipeWire/WirePlumber; troubleshoot with Chromebook Linux Audio **after** installation |
| Recovery | On this EOL model, MrChromebox **blocks its normal stock-firmware restoration menu**. Keep a stock firmware backup; physical SPI programming may be necessary if bricked. |

**Feasibility warning:** EDGAR uses an older Intel Braswell GPU and comes with limited RAM/eMMC. Arch packages exist for Hyprland and Noctalia, but successful acceleration, smooth rendering, suspend and Noctalia responsiveness **have not been verified on this particular Chromebook**. Start with blur/shadows/animations disabled, and keep a TTY available to troubleshoot. A 2 GB unit may struggle, especially with a browser.

**This wipes the device:** Developer Mode erases user data, and repartitioning removes ChromeOS and its recovery partitions. Firmware flashing can brick the Chromebook. Full ROM removes ChromeOS boot and ChromeOS Recovery Mode. Allow a few hours and have another computer available. This is not a dual-boot plan.

## 1. Eligibility and verification — do not skip

- [ ] Device is personally owned and not school-/employer-managed.
- [ ] Model label actually reads **Acer Chromebook 14 CB3-431**, not merely an approximately matching model number.
- [ ] With ChromeOS booting, open `chrome://system` and locate `HWID`; confirm it **begins with `EDGAR`**. From a developer terminal, `crossystem hwid` is another possible check.
- [ ] Review [MrChromebox Supported Devices](https://docs.mrchromebox.tech/docs/supported-devices.html). The **Acer Chromebook 14 (CB3-431) / EDGAR** row shows UEFI Full ROM supported and WP method `screw`.
- [ ] Accept that sound, microphone, suspend and top-row keys may require fixes, and are not guaranteed merely because the firmware is supported.
- [ ] Check actual RAM and internal disk capacity. This product came in multiple configurations; **16 GB storage requires especially careful space management**. For Hyprland/Noctalia, 4 GB RAM is preferable to 2 GB; both are untested on this specific device.

## 2. Preparation

- [ ] Copy all important data off the Chromebook (Developer Mode will erase it).
- [ ] Charge the Chromebook, and have its **own compatible AC adapter** plugged in for the flash (do not assume it charges over USB-C).
- [ ] Have **USB A: firmware backup**, preferably formatted with a normal filesystem and enough free space.
- [ ] Have **USB B: 8 GB+ bootable Arch ISO**, separately from the backup stick.
- [ ] Have a second computer for downloading/verifying the latest [Arch ISO](https://archlinux.org/download/), writing it to USB, and consulting recovery instructions.
- [ ] Verify the ISO checksum/signature against the official Arch instructions.
- [ ] Have appropriate small screwdrivers, ESD precautions and the official [EDGAR write-protect screw photo](https://docs.mrchromebox.tech/images/wp/Edgar_wp.jpg) available on another screen.
- [ ] Understand that **EDGAR is an EOL Chromebook**. MrChromebox will not offer its normal “Restore Stock Firmware” function for EOL devices. A saved backup is still vital for potential specialist/manual SPI recovery.

## 3. Enable Developer Mode and remove the EDGAR write-protect screw

### 3A. Enable Developer Mode

1. Start from a fully powered-off Chromebook with its battery connected.
2. Press **Esc + Refresh + Power** to open ChromeOS Recovery Mode.
3. Press **Ctrl + D**, confirm with **Enter**, and follow the on-screen prompts.
4. After the wipe and reboot, continue to the ChromeOS login screen in Developer Mode. The “OS verification is OFF” screen is expected until you replace firmware.
5. Do **not** turn on optional ChromeOS debugging features.

### 3B. Remove the physical WP screw

1. Shut down completely and **unplug AC power**.
2. Remove the lower cover carefully. Follow appropriate anti-static precautions; avoid pulling on internal cables.
3. Identify the **single WP screw circled in red** in the [official EDGAR photo](https://docs.mrchromebox.tech/images/wp/Edgar_wp.jpg). It is not an arbitrary case or motherboard mounting screw.
4. Remove **only that WP screw**, keep it in a labeled bag, and reassemble the device.
5. Boot to the ChromeOS login screen. Press **Ctrl + Alt + F2** (the F2/top-row forward key on the Chromebook keyboard); log in as `chronos` with no password.
6. Verify:

```sh
crossystem wpsw_cur
```

**Expected: `0`.** If the result is `1`, stop; the correct screw may not have been removed or the model/board may differ. **Do not run `gsctool` commands. Do not manually disable software WP; the firmware script handles it.**

## 4. Flash MrChromebox UEFI Full ROM

> **Irreversible in normal use on this EOL model.** Do not proceed without a second computer and a reliable stock firmware backup plan.

1. In the **VT2 `chronos` shell** opened above (not ChromeOS crosh, not the Linux container), run the official command **as `chronos`**, not from a `sudo su`/root shell:

```sh
cd; curl -LOf https://mrchromebox.tech/firmware-util.sh && sudo bash firmware-util.sh
```

2. Inspect the detected device and board. **It must report EDGAR**. If not, stop.
3. Select **Install/Update UEFI (Full ROM) Firmware** (typically menu option 2; use the displayed name rather than trusting numbering).
4. When prompted, **back up the stock firmware onto USB A**. Later copy the `.rom` backup to another computer or a separate safe location. Keep the **entire original, unmodified file**.
5. Confirm all warnings and continue only if the utility detects WP disabled and the correct board.
6. If flashing succeeds with **no errors**, choose the script's **power-off** menu option.
7. On first boot, wait at least a minute for the display. If there is still no display after **two full minutes**, try **Refresh + Power** once.

**If the flash reports any error: do not shut down, reboot or unplug the device.** Preserve the log, use the script's supported recovery instructions and seek MrChromebox help while the machine is still running. Do not assume the EOL device's ordinary “Restore Stock Firmware” feature is available.

- [ ] Stock firmware backup saved safely **off the Chromebook**.
- [ ] Flash script finished without errors.
- [ ] UEFI/coreboot screen appears on startup.

## 5. Boot the Arch ISO in UEFI mode

1. Insert **USB B** and power on.
2. Press **Esc** at the coreboot/UEFI splash, then choose the Arch USB entry.
3. At the Arch shell:

```sh
cat /sys/firmware/efi/fw_platform_size
```

Expected output: **`64`**. If not, stop and resolve the boot mode before partitioning.

Optional baseline checks before committing to the install:

```sh
uname -m
lsblk -o NAME,SIZE,TYPE,RM,MODEL,FSTYPE,MOUNTPOINTS
ip link
```

`uname -m` should be `x86_64`. Keyboard and touchpad may work differently from ChromeOS; a USB mouse is a useful fallback.

## 6. Install Arch Linux on the internal eMMC (UEFI)

### 6A. Get internet and set the clock

For Wi-Fi, first identify the interface; **do not assume its name is `wlan0`**:

```sh
iwctl
# Within iwctl:
device list
station YOUR_WIFI_INTERFACE scan
station YOUR_WIFI_INTERFACE get-networks
station YOUR_WIFI_INTERFACE connect YOUR_SSID
exit
```

Replace the Wi-Fi interface and SSID placeholders with actual values. After exiting `iwctl`:

```sh
ping -c 3 archlinux.org
timedatectl set-ntp true
timedatectl status
```

USB Ethernet or USB tethering is a fallback if Wi-Fi does not work in the live installer.

### 6B. Identify the *internal* eMMC — destructive steps begin after this checkpoint

```sh
lsblk -p -o NAME,SIZE,TYPE,RM,MODEL,FSTYPE,MOUNTPOINTS
```

EDGAR normally has an eMMC device such as **`/dev/mmcblk0`**, but the enumeration **may differ**. The USB installer and backup stick must **not** be selected. Also **never** format eMMC hardware boot areas such as `/dev/mmcblk0boot0` or `/dev/mmcblk0boot1`.

The example below assumes you **personally verified** that the **whole internal eMMC disk** is `/dev/mmcblk0`. If yours is `/dev/mmcblk1`, substitute that name **everywhere** — including after entering the chroot.

```sh
# EXAMPLE ONLY — confirm the device path using lsblk first.
DISK=/dev/mmcblk0
lsblk "$DISK"
```

If you are not certain the disk is internal, **stop here** rather than guessing.

### 6C. Partition and format (erases ChromeOS)

```sh
cfdisk "$DISK"
```

Inside `cfdisk`:

1. Choose a **new GPT partition table** (all existing ChromeOS partitions will be removed).
2. Partition 1: **1 GiB**, type **EFI System**.
3. Partition 2: **all remaining usable space**, type **Linux filesystem**.
4. Review device path and layout before choosing **Write**; type confirmation and quit.

Then (only after checking that `p1` and `p2` are the intended new partitions):

```sh
lsblk "$DISK"
mkfs.fat -F 32 "${DISK}p1"
mkfs.ext4 "${DISK}p2"
mount "${DISK}p2" /mnt
mount --mkdir "${DISK}p1" /mnt/boot
findmnt /mnt
findmnt /mnt/boot
```

**No dedicated swap partition:** particularly on 16 GB eMMC, use optional compressed RAM swap (`zram`) after installation instead. Hibernation to disk is not included.

### 6D. Base system

```sh
pacstrap -K /mnt base linux linux-firmware sof-firmware intel-ucode \
  networkmanager sudo nano git

genfstab -U /mnt > /mnt/etc/fstab
cat /mnt/etc/fstab
arch-chroot /mnt
```

Check that `/boot` in the fstab refers to the FAT32 ESP and `/` to the ext4 root. If `pacstrap` fails because the eMMC is full, resolve that first; do not continue with a partial installation.

### 6E. Configure installed system (inside `arch-chroot`)

The timezone below is **Europe/Amsterdam**; change it if needed. The sample login name is `archuser` — you can replace it with your desired Unix username.

```sh
ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf
printf 'edgar-arch\n' > /etc/hostname
passwd
useradd -m -G wheel -s /bin/bash archuser
passwd archuser
EDITOR=nano visudo
systemctl enable NetworkManager
```

Inside `visudo`, enable the line:

```text
%wheel ALL=(ALL:ALL) ALL
```

Do not leave it commented out; save and close the editor.

### 6F. Install systemd-boot — **use actual root UUID**

With the EFI partition mounted at `/boot`:

```sh
bootctl install
```

Find the UUID of your **ext4 root partition**, not the FAT32 EFI partition. Example below assumes the confirmed internal disk was `/dev/mmcblk0`:

```sh
blkid -s UUID -o value /dev/mmcblk0p2
```

If you selected `/dev/mmcblk1` in step 6B, this must instead be `/dev/mmcblk1p2`. Write down the exact UUID printed.

Create `/boot/loader/loader.conf`:

```ini
default arch.conf
timeout 3
```

Create `/boot/loader/entries/arch.conf`:

```ini
title Arch Linux (EDGAR)
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=UUID=REPLACE_WITH_ACTUAL_EXT4_ROOT_UUID rw
```

Use `nano` to edit these files if needed:

```sh
nano /boot/loader/loader.conf
nano /boot/loader/entries/arch.conf
```

**Replace** `REPLACE_WITH_ACTUAL_EXT4_ROOT_UUID` with the actual UUID **before rebooting**. Then check:

```sh
cat /boot/loader/entries/arch.conf
bootctl status
ls -l /boot/EFI/BOOT/BOOTX64.EFI
```

`bootctl install` normally installs the UEFI fallback bootloader at `EFI/BOOT/BOOTX64.EFI`. If it did not, troubleshoot before rebooting.

### 6G. Finish initial boot

```sh
exit
umount -R /mnt
reboot
```

Remove USB B when the device restarts. Confirm systemd-boot loads Arch and that you can log in as `archuser`.

- [ ] Internal eMMC device positively identified.
- [ ] `/boot` is the FAT32 EFI partition; `/` is ext4.
- [ ] `/etc/fstab` generated and reviewed.
- [ ] `intel-ucode` is installed and listed in boot entry.
- [ ] **Real root UUID** in `arch.conf`; no placeholder remains.
- [ ] First boot completes and login works.

## 7. Post-install: managed Hyprland + Noctalia v5, audio, Wi-Fi and keyboard

The firmware, partitions, Arch base, network service, bootloader and user account
in sections 1–6 are **manual installation steps**. After successful first boot,
use the existing [rigerc/dotfiles](https://github.com/rigerc/dotfiles) chezmoi
source for user configuration, packages and optional Chromebook tuning.
**Do not manually recreate** Hyprland Lua modules, Noctalia autostart, themes
or keybindings from older generic desktop tutorials: those files are managed
by chezmoi and may be replaced by a future `chezmoi apply`.

Do **not** add XFCE, LightDM, Waybar, Rofi, a separate Xorg desktop or the
old Quickshell-based Noctalia v4 shell. Use the official Arch `noctalia`
(v5) and `hyprland` packages. Avoid a display manager until the TTY and
GPU path have been verified.

### 7A. Network and minimal graphics smoke test

Log in as the **normal user** on the local installed Arch text console.
NetworkManager was enabled in section 6E. If necessary:

```sh
nmcli device wifi list
nmcli device wifi connect 'YOUR_SSID' --ask
ping -c 3 archlinux.org
```

Check baseline storage and GPU before any significant package installation:

```sh
free -h
df -h /
lspci -nnk | grep -A3 -Ei 'VGA|Display|3D'
ls -l /dev/dri
```

For an initial Wayland compositor smoke test, install **only** the minimal
graphics/terminal packages and launch from the local TTY (not root or SSH):

```sh
sudo pacman -Syu --needed hyprland mesa foot
start-hyprland
```

A first-run autogenerated Hyprland Lua config is only a *temporary test*.
Do not manually turn it into a second configuration source. If Hyprland
fails or the system becomes unresponsive, switch back to a TTY and inspect
`journalctl -b`, `/dev/dri` and the kernel GPU driver. Stop before
installing the full desktop if basic acceleration is unavailable.

### 7B. Initialize the existing chezmoi source

Once Arch boots and basic graphics/networking work, return to the local
TTY and run:

```sh
sudo pacman -Syu --needed git chezmoi
chezmoi init rigerc/dotfiles
chezmoi data
chezmoi --no-pager diff
chezmoi apply --dry-run --verbose
chezmoi apply --exclude=scripts --verbose
```

Choose:
- `machineRole = "chromebook"` (**required** for the EDGAR overrides).
- `packageProfile = "desktop"` (includes Hyprland, Noctalia and PipeWire).
- `installPackages = false` initially, so only dotfiles are applied.
- `chromebookTuning = false` until the dependency and RAM checks pass.

These choices are stored **locally** in
`~/.config/chezmoi/chezmoi.toml` rather than committed as personal data.
Do not commit Wi-Fi credentials, Git identity, firmware backups or account
secrets to the dotfiles repository.

The repo's read-only preflight is at `scripts/chromebook-preflight.sh` in
the checkout root, *one level above* the chezmoi source-state directory
because this repository uses `.chezmoiroot` with `home/`:

```sh
bash "$(dirname "$(chezmoi source-path)")/scripts/chromebook-preflight.sh"
```

Review the report; it checks memory/storage, UEFI, GPU, power devices, swap
and the presence of desktop/zram packages without changing firmware or /etc.
If your source checkout is elsewhere, run the script from that checkout.

### 7C. Install the managed desktop packages and optional system tuning

After reviewing the generated `chezmoi diff`, disk capacity and package
list in `home/.chezmoidata/packages.toml`, set
`data.installPackages = true` in the **local** chezmoi config and review
again:

```sh
nano ~/.config/chezmoi/chezmoi.toml
chezmoi apply --dry-run --verbose
chezmoi apply --verbose
```

A full `chezmoi apply` with this option can perform a complete
`pacman -Syu --needed` transaction after checking for missing packages.
It never runs AUR installers. The desktop package group provides Hyprland,
Noctalia v5, PipeWire/WirePlumber, portals and essential utilities; the
Chromebook supplement adds `foot`, Intel Mesa support, audio UCM/SOF tools,
hardware inspection utilities, fonts, networking and `zram-generator`.
The package list also includes Ghostty for parity with the other desktop
roles; **check available eMMC space** before choosing the whole profile.

The shared Hyprland Lua config automatically imports `chromebook.lua`
to disable blur/shadows/animations and use smaller gaps/scrolling columns.
Its `terminal.lua` module uses **foot** on Chromebook while retaining
Ghostty on desktop/laptop. The `layers.lua` module omits compositor blur
rules on Chromebook while preserving them on other graphical roles.
The existing shared `session.lua` autostarts Noctalia and conditionally
Vicinae, while `binds.lua` contains launcher, held Alt+Tab, window,
workspace and brightness bindings.

**Do not add duplicate `hl.on("hyprland.start", ...)` callbacks or
desktop-specific `hl.bind` definitions to the generated configuration.**
A standalone session manager or heavyweight launcher is unnecessary for
first boot. Some shared application shortcuts are optional and only work
if the corresponding applications were installed separately.

For optional compressed RAM swap, first check that `zram-generator` is
installed. Then set `data.chromebookTuning = true` in the local chezmoi
config, preview and apply:

```sh
pacman -Q zram-generator
chezmoi apply --dry-run --verbose
chezmoi apply --verbose
```

The opt-in tuner manages its **own** zram, sysctl and journald drop-ins
without overwriting unmanaged files. It uses compressed RAM swap up to
half RAM (capped at 4 GiB) with `zstd`; it is **not hibernation to disk**.
The tuner refuses real-host application when `zram-generator` is absent
(the `core` profile omits that package). Reboot, then check
`swapon --show` and `zramctl`.

For manual preview or rollback, see
[docs/CHROMEBOOK.md](CHROMEBOOK.md#optional-automatic-tuning-new).
**Do not also create the manual zram config from older standalone guides**,
as that would yield competing zram-generator configuration.

### 7D. Start the managed Hyprland / Noctalia session

From a local TTY logged in as your normal user:

```sh
start-hyprland
```

The dotfiles manage `~/.config/hypr/hyprland.lua` and import its modules.
If the compositor runs but the Noctalia interface is absent, open
`foot` and try:

```sh
noctalia
noctalia msg --help
```

Keep TTY access as the rescue path. Verify the mapped Chromebook Search/Super
key with `wev` before changing keybindings. The role retains your Rosé Pine
theme and shared Noctalia configuration rather than installing a second shell.
Use Noctalia settings to disable optional widgets/effects **only if**
performance on Braswell is poor. Any such setting must be checked against
the installed Noctalia version before committing it as a new role-specific
override.

### 7E. Space, performance and rollback checkpoints

- Check `df -h /`, `free -h` and `journalctl -b` after the package
  transaction and after first desktop login.
- Expect limited multitasking on 2 GiB RAM and limited package cache space
  on 16 GiB eMMC. Do not install AUR-heavy or duplicate desktop stacks.
- Apply subsequent dotfile updates only after inspecting
  `chezmoi --no-pager diff`. If settings break the desktop, return to
  TTY and use `chezmoi` to revert or correct the source.
- Firmware, eMMC partitioning, bootloader and potentially unsafe Chromebook
  audio topology changes are **outside** the dotfiles lifecycle.

### 7F. Audio — verify first, then use the Chromebook-specific script

Sound is a known risk on Chromebook Linux installations. `sof-firmware` was installed with the base system and PipeWire/WirePlumber with Hyprland. After booting Hyprland, check:

```sh
wpctl status
systemctl --user status pipewire wireplumber --no-pager
```

If speakers/headphones do not work, read the current project instructions and run the Chromebook Linux Audio setup script **only on the installed OS**:

```sh
sudo pacman -S --needed git
# Review the README and script before execution.
git clone --depth 1 https://github.com/WeirdTreeThing/chromebook-linux-audio.git
cd chromebook-linux-audio
./setup-audio
```

Follow the script's prompts and reboot. Independently test speakers, headphones and microphone at **low volume**. Do **not** force unsupported AVS modes; a Chrultrabook warning notes risk of speaker damage on some devices with `max98357a`. The EDGAR microphone has historically been problematic; current results require hands-on verification.

### 7G. Chromebook keys, brightness, Wi-Fi and storage

- **Top-row shortcuts:** review [cros-keyboard-map](https://github.com/WeirdTreeThing/cros-keyboard-map) if function keys do not match their Chromebook legends. Check actual key names first using a Wayland key event tool such as `wev`.
- **Brightness:** Noctalia's UI may require access to `/sys/class/backlight/`. Inspect `brightnessctl -l` before assuming it works automatically. Avoid changing udev permissions without checking the project's guidance.
- **Wi-Fi:** use `nmcli` for troubleshooting; confirm auto-reconnection after reboot.
- **Touchpad:** if problematic, see the [EDGAR ArchWiki page](https://wiki.archlinux.org/title/Acer_Chromebook_14_CB3-431_(Edgar)) for historical quirks; only apply fixes to symptoms actually observed.
- **eMMC/TRIM:** check `lsblk -D` before enabling `fstrim.timer`. Do not assume eMMC exposes discard support.
- **Storage:** check `df -h /` and `du -sh /var/cache/pacman/pkg`; avoid large desktop bundles and redundant compositors on 16 GB eMMC.

### 7H. Final verification

- [ ] TTY login works before entering Hyprland; recovery console remains available.
- [ ] `start-hyprland` launches and remains usable with Intel GPU acceleration; `foot` opens on Chromebook via shared bindings.
- [ ] `noctalia` launches, autostarts and its launcher/control-center and held Alt+Tab shortcuts work.
- [ ] Terminal (`foot`), touchpad, keyboard, brightness and Wi-Fi work.
- [ ] Speakers, headphones and microphone checked separately at low volume.
- [ ] Suspend/resume and battery behavior tested before daily use.
- [ ] `free -h`, `df -h /` and `journalctl -b` checked for resource pressure or recurring errors.
- [ ] Regular Arch updates and external firmware-backup copies maintained.

## Troubleshooting / stop conditions

| Symptom | Action |
|---|---|
| HWID does not begin `EDGAR` | **Stop.** The firmware/screw guidance may be for the wrong device. |
| `crossystem wpsw_cur` returns `1` | **Stop.** Re-check the official photo and hardware ID. Do not force a flash. |
| Firmware script shows another board or WP enabled | **Stop.** Do not choose the flash option. |
| Firmware flash reports an error | **Do not power off**. Preserve log and use script/support recovery instructions while running. |
| Black screen after successful flash | Wait 2 full minutes; then try Refresh + Power. Persistent failure may require external SPI recovery. |
| ISO does not boot in UEFI (`fw_platform_size` not `64`) | Reboot and select the UEFI USB option. Do not partition yet. |
| Cannot find internal eMMC | Stop; inspect `lsblk`, `dmesg` and storage hardware. **Never guess the device name.** |
| Boot returns to UEFI shell | Confirm `/boot` ESP is mounted; re-enter Arch from ISO/chroot and check `bootctl install`, fallback EFI file and root UUID. |
| “Dummy Output” / no sound | Check `wpctl status`; install/test PipeWire and SOF, run the current Chromebook audio script on installed Arch, reboot; consult EDGAR reports if still failing. |
| Internal mic fails | A historical EDGAR ArchWiki note mentions microphone limitations; test with a current kernel and treat any persistent problem as hardware-specific. |
| Hyprland exits or shows a black screen | Return to TTY. Check `journalctl -b`, `/dev/dri`, Mesa and Intel driver; do not blindly force unsupported renderers or drivers. |
| Noctalia bar/launcher absent | From Hyprland run `noctalia`, inspect `~/.cache/noctalia/noctalia.log`, confirm Lua autostart and `pacman -Q noctalia`. |
| Poor animation or UI responsiveness | Disable blur, shadows and animations; inspect `free -h`, CPU load and graphics errors; 2 GB RAM may be insufficient for comfortable browser use. |
| eMMC fills up | Remove unnecessary package cache or unused packages; avoid installing heavy desktop packages. Do not wipe other partitions to recover space. |

## Reverting or recovering

**EDGAR is EOL.** The normal MrChromebox **Restore Stock Firmware** menu is intentionally disabled on EOL hardware, even if you saved a backup. The original generic guide was overly optimistic on this point. Keep the original ROM file in case **manual firmware recovery with a compatible SPI programmer** is ever needed; do not assume SuzyQ recovery is applicable to this pre-GSC USB-A-era board. A failed flash may require opening the laptop and using an external programmer.

If you only need to reinstall Arch, boot the Arch USB again; that does not require restoring ChromeOS firmware.

## References (checked 4 November 2026; recheck upstream before performing destructive steps)

- [MrChromebox — Supported Devices (EDGAR and screw/photo)](https://docs.mrchromebox.tech/docs/supported-devices.html)
- [MrChromebox — Official EDGAR WP-screw photo](https://docs.mrchromebox.tech/images/wp/Edgar_wp.jpg)
- [MrChromebox — Developer Mode](https://docs.mrchromebox.tech/docs/boot-modes/developer.html)
- [MrChromebox — Disabling Firmware Write Protection](https://docs.mrchromebox.tech/docs/firmware/wp/disabling.html)
- [MrChromebox — Flashing Firmware](https://docs.mrchromebox.tech/docs/firmware/flashing-firmware.html)
- [MrChromebox — Firmware Utility Script, including EOL restrictions](https://docs.mrchromebox.tech/docs/fwscript)
- [Chrultrabook — Installing Linux and audio](https://docs.chrultrabook.com/docs/installing/installing-linux.html)
- [Chrultrabook — Post Install](https://docs.chrultrabook.com/docs/installing/post-install.html)
- [Chromebook Linux Audio script](https://github.com/WeirdTreeThing/chromebook-linux-audio)
- [ArchWiki — Acer Chromebook 14 CB3-431 (Edgar)](https://wiki.archlinux.org/title/Acer_Chromebook_14_CB3-431_(Edgar))
- [ArchWiki — Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
- [Arch package — hyprland](https://archlinux.org/packages/extra/x86_64/hyprland/)
- [Arch package — noctalia](https://archlinux.org/packages/extra/x86_64/noctalia/)
- [Hyprland — Installation](https://wiki.hypr.land/Getting-Started/Installation/)
- [Hyprland — Lua configuration](https://wiki.hypr.land/Configuring/Start/)
- [Hyprland — Launching / Master Tutorial](https://wiki.hypr.land/Getting-Started/Master-Tutorial/)
- [Noctalia v5 — Installation](https://docs.noctalia.dev/noctalia/getting-started/installation/)
- [Noctalia v5 — Autostart](https://docs.noctalia.dev/noctalia/getting-started/running-the-shell/)
- [Noctalia v5 — Hyprland integration](https://docs.noctalia.dev/noctalia/compositor-settings/hyprland/)

**Scope:** Firmware support and WP method are documented for EDGAR; Hyprland and Noctalia are available as official Arch packages, **but their performance and graphics compatibility on this individual Chromebook are not verified**. The exact HWID, RAM, eMMC device name/size, individual Wi-Fi hardware, speaker, mic and touchpad behavior still require checking.
## Repository integration

- [Chromebook role and optional tuning](CHROMEBOOK.md)
- [Dotfiles bootstrap](BOOTSTRAP.md)
- [Disposable Podman rendering tests](CONTAINER.md)
- [Dotfiles repository](https://github.com/rigerc/dotfiles)
