# QEMU Arch virtual-machine test harness

The QEMU harness is designed to exercise the **full interactive Arch bootstrap
in a disposable installed Arch guest**, plus safe smoke checks from the live
Arch ISO. QEMU does *not* emulate Chromebook board firmware, Wi-Fi, audio amps,
or battery. Hardware-specific effects must be reviewed separately on a real
Chromebook.

## Host prerequisites

Install QEMU (`qemu-system-x86_64` and `qemu-img`) on your host, and download
and verify an official **Arch Linux x86_64 ISO** from
https://archlinux.org/download/. The harness never downloads an ISO or modifies
the host configuration. It allocates a 20 GiB qcow2 disk on first launch,
4 GiB RAM, and 2 vCPUs by default. If KVM is available, it is enabled.

## 1. Boot the live ISO

From the repository root:

```sh
bash vm/launch.sh --iso /path/to/archlinux-x86_64.iso
```

The VM has user-mode NAT Ethernet networking and a **read-only 9p share** of
this repository. In the guest's Arch live environment, mount the share:

```sh
mkdir -p /mnt/dotfiles
mount -t 9p -o trans=virtio,version=9p2000.L,ro dotfiles /mnt/dotfiles
bash /mnt/dotfiles/vm/guest-smoke.sh
```

The smoke script exercises `install.sh --dry-run` and applies Chromebook tuning
to an isolated **temporary directory**, then rolls it back. If `python` and
`chezmoi` are available, it also runs the unit tests and chezmoi file-only
sandbox tests. Otherwise it prints installation instructions; it never
installs packages automatically. The Arch ISO's root account is suitable for
smoke tests but **not** for the interactive installer (which refuses root).

## 2. Try the complete interactive installer

Use `archinstall` in the guest to install Arch to the attached virtual disk.
Create a normal user with sudo privileges. No real laptop disk is attached to
the VM. After installation, shut down the guest and boot the installed disk:

```sh
bash vm/launch.sh --boot-disk
```

Log in as your normal test user. Mount the read-only repo and **copy it** to a
writable location first (because chezmoi may initialize its Git source):

```sh
sudo mkdir -p /mnt/dotfiles
sudo mount -t 9p -o trans=virtio,version=9p2000.L,ro dotfiles /mnt/dotfiles
mkdir -p "$HOME/src"
cp -a /mnt/dotfiles "$HOME/src/dotfiles-test"
bash "$HOME/src/dotfiles-test/install.sh" --source "$HOME/src/dotfiles-test"
```

Use a throwaway Git identity and select `chromebook` to exercise prompts,
file rendering, preview, and opt-in package profiles. QEMU uses **virtual
Ethernet**, so the installer should offer to preserve existing network access;
Wi-Fi setup can only be truly tested on hardware with a Wi-Fi device. If you
opt in to tuning, its hardware check skips real `/etc` mutations inside a VM;
use the staging tests to inspect generated files.

To use a fresh VM disk, pass `--disk /path/to/new.qcow2` with `--iso`. **Never
point the VM at a real block device.** To discard the experiment, shut down
QEMU and delete only its qcow2 disk image.

## Local offline tests (no QEMU required)

```sh
bash install.sh --dry-run
python3 -m unittest discover -s tests -v
bash home/.chezmoitemplates/chromebook-tune.sh --dry-run --root /tmp
```

Live rendering tests are skipped if chezmoi is unavailable. Running these
checks on Debian or macOS does not apply the Arch configuration.
