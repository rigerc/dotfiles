# Disposable Arch container tests (Podman)

This is the recommended way to test the **chezmoi file configuration** without
installing Arch in a VM. The test runner uses the official Arch Linux OCI image
and **rootless Podman**, without root access to the host.

## Host prerequisites

Install Podman using your host distribution's package manager; on Arch:

```sh
sudo pacman -Syu --needed podman
```

Configure Podman for **rootless** use as your regular user. Do not run the test
runner with `sudo` or with `podman --privileged`. Network access is required to
pull the container image and install its disposable test tools. This uses host
storage for the container image/cache, but **not** a 20 GiB VM disk or Arch ISO.

## Run tests

From the dotfiles checkout root:

```sh
bash container/run.sh                    # Full suite plus all four roles
bash container/run.sh --role chromebook  # Test only Chromebook file rendering
bash container/run.sh --role desktop --shell  # Inspect results interactively
bash container/run.sh --prompt           # Test real first-run chezmoi questions
bash container/run.sh --prompt --shell   # Prompts, apply files, inspect shell
```

The role-specific automatic test uses dummy Git identity and local data with
`installPackages=false` and `chromebookTuning=false`. It checks rendered Git,
Fish and GUI files in separate disposable target directories for `desktop`,
`laptop`, `chromebook`, and `server`.

`--prompt` calls the **real** `chezmoi init`, accepts answers in the terminal,
shows the diff, and applies *files only* into an isolated container home. It
**never runs provisioning scripts**, even if you answer Yes to the package or
Chromebook-tuning questions. This lets you experiment safely with the prompts.

The container also runs the repository's Python unit tests (including native
chezmoi checks) and stages Chromebook system-tuning files under `/tmp`, then
rolls them back. It does **not** alter the container's real `/etc` tuning.

## Isolation and cleanup

- Uses `podman run --rm` (container automatically deleted after exit).
- Mounts the host repository as `/repo:ro` and makes a **writable copy inside**
  the disposable container before testing initialization and application.
- Does not mount the host home, `/etc`, `/run`, disks, devices, or Podman socket.
- Does not use `--privileged` or start a systemd service manager.
- Installs `git`, `chezmoi`, and `python` with pacman **inside the container only**.
- Uses `chezmoi apply --exclude=scripts` for all file deployment tests.
- The Chromebook tuner is tested with its `--root` option in a temporary tree.

The Arch image persists in Podman's image cache after the container exits.
To inspect host space consumed by images, run `podman system df`. Remove an
unneeded image with `podman image rm docker.io/library/archlinux:latest`, but
check for other dependent containers first. Podman image caching is distinct
from your host `/etc` and chezmoi destination.

## What cannot be tested in a container

This does not test actual Chromebook firmware, Wi-Fi hardware, audio routing,
battery, lid-close/suspend, kernel drivers, bootloader, or functioning systemd
units. It also does not run the **real host bootstrap installation** from
`install.sh`, since that needs a normal installed-Arch user, sudo and a
working package manager. It only dry-runs that installer and checks its
network-detection logic in the unit tests.

Use a real device for Chromebook hardware acceptance checks. A full VM is
optional for system boot behavior but is no longer maintained by this repo.

References: [Podman run](https://docs.podman.io/en/stable/markdown/podman-run.1.html),
[Arch Linux OCI images](https://github.com/archlinux/archlinux-docker).
