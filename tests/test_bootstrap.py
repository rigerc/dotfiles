"""No privileged operations: exercise installer preview and staged Chromebook tune."""
import os
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
INSTALL = ROOT / "install.sh"
TUNER = ROOT / "home/.chezmoitemplates/chromebook-tune.sh"


def run_shell(*args, cwd=ROOT):
    return subprocess.run(
        ["bash", *map(str, args)], cwd=cwd,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, timeout=20,
    )


class BootstrapTests(unittest.TestCase):
    def test_syntax_all_scripts(self):
        for rel in (
            "install.sh", "vm/launch.sh", "vm/download-iso.sh", "vm/guest-smoke.sh",
            "scripts/chromebook-preflight.sh",
            "home/.chezmoitemplates/chromebook-tune.sh",
        ):
            with self.subTest(script=rel):
                proc = subprocess.run(["bash", "-n", str(ROOT / rel)], capture_output=True)
                self.assertEqual(proc.returncode, 0, proc.stderr.decode())

    def test_bootstrap_dry_run_never_changes_home(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "home"
            home.mkdir()
            cmd = subprocess.run(
                ["bash", str(INSTALL), "--dry-run", "--source", str(ROOT)],
                env={**os.environ, "HOME": str(home)},
                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                timeout=15,
            )
            self.assertEqual(cmd.returncode, 0, cmd.stderr)
            self.assertIn("DRY RUN", cmd.stdout)
            self.assertIn("Wi-Fi", cmd.stdout)
            self.assertIn("sudo pacman -Syu --needed", cmd.stdout)
            self.assertEqual(list(home.iterdir()), [])

    def test_preview_options_without_iso(self):
        launcher = run_shell(ROOT / "vm/launch.sh", "--help")
        self.assertEqual(launcher.returncode, 0, launcher.stderr)
        self.assertIn("--iso", launcher.stdout)
        missing = run_shell(ROOT / "vm/launch.sh", "--iso", "/missing/not-real.iso")
        self.assertNotEqual(missing.returncode, 0)

    def test_network_detection_and_pipe_mode(self):
        with tempfile.TemporaryDirectory() as td:
            binaries = Path(td)
            ip = binaries / "ip"
            ip.write_text(
                '#!/bin/sh\n'
                'if [ "${TEST_ROUTE:-0}" = 1 ] && [ "$1 $2 $3 $4" = "-4 route show default" ]; then\n'
                '  echo "default via 192.0.2.1 dev eth0"\n'
                'fi\n'
            )
            ip.chmod(0o755)
            nmcli = binaries / "nmcli"
            nmcli.write_text('#!/bin/sh\necho disconnected\n')
            nmcli.chmod(0o755)
            env = {**os.environ, "PATH": f"{binaries}:{os.environ.get('PATH', '')}"}
            online = subprocess.run(
                ["bash", str(INSTALL), "--check-network"],
                capture_output=True, text=True, env={**env, "TEST_ROUTE": "1"},
            )
            self.assertEqual(online.returncode, 0, online.stderr)
            self.assertIn("Network detected", online.stdout)
            offline = subprocess.run(
                ["bash", str(INSTALL), "--check-network"],
                capture_output=True, text=True, env={**env, "TEST_ROUTE": "0"},
            )
            self.assertEqual(offline.returncode, 1)
            self.assertIn("No active network", offline.stdout)
            piped = subprocess.run(
                ["bash", "-s", "--", "--dry-run"], input=INSTALL.read_text(),
                capture_output=True, text=True, env=env,
            )
            self.assertEqual(piped.returncode, 0, piped.stderr)
            self.assertIn("DRY RUN", piped.stdout)

    @staticmethod
    def make_mock_mirror(root):
        mirror = root / "mirror"
        mirror.mkdir()
        payload = b"fake Arch ISO payload for local tests only"
        (mirror / "archlinux-x86_64.iso").write_bytes(payload)
        digest = hashlib.sha256(payload).hexdigest()
        (mirror / "sha256sums.txt").write_text(
            f"{digest}  archlinux-x86_64.iso\n"
        )
        binaries = root / "bin"
        binaries.mkdir()
        curl = binaries / "curl"
        curl.write_text(
            '#!/bin/sh\n'
            'out=; url=\n'
            'while [ "$#" -gt 0 ]; do\n'
            '  if [ "$1" = --output ]; then out=$2; shift 2; continue; fi\n'
            '  url=$1; shift\n'
            'done\n'
            'file=${url##*/}\n'
            'cp -- "$FAKE_MIRROR/$file" "$out"\n'
        )
        curl.chmod(0o755)
        env = {**os.environ, "FAKE_MIRROR": str(mirror),
               "PATH": f"{binaries}:{os.environ.get('PATH', '')}"}
        return mirror, payload, env

    def test_iso_download_verified_cached_and_refreshed(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            mirror, payload, env = self.make_mock_mirror(root)
            out = root / "cache" / "archlinux-x86_64.iso"
            cmd = ["bash", str(ROOT / "vm/download-iso.sh"),
                   "--output", str(out)]
            first = subprocess.run(cmd, capture_output=True, text=True, env=env)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(out.read_bytes(), payload)
            second = subprocess.run(cmd, capture_output=True, text=True, env=env)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertIn("Cached Arch ISO verified", second.stdout)
            out.write_bytes(b"outdated or corrupt")
            third = subprocess.run(cmd, capture_output=True, text=True, env=env)
            self.assertEqual(third.returncode, 0, third.stderr)
            self.assertEqual(out.read_bytes(), payload)
            self.assertFalse(list(out.parent.glob("*.partial.*")))
            (mirror / "sha256sums.txt").write_text(
                "0" * 64 + "  archlinux-x86_64.iso\n"
            )
            failed = subprocess.run(cmd, capture_output=True, text=True, env=env)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn("checksum mismatch", failed.stderr)
            self.assertEqual(out.read_bytes(), payload)
            self.assertFalse(list(out.parent.glob("*.partial.*")))
            insecure = subprocess.run(cmd + ["--mirror", "http://bad"],
                                      capture_output=True, text=True, env=env)
            self.assertNotEqual(insecure.returncode, 0)
            self.assertIn("HTTPS", insecure.stderr)

    def test_vm_download_only_never_launches_qemu(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            mirror, payload, env = self.make_mock_mirror(root)
            env["XDG_CACHE_HOME"] = str(root / "cache")
            result = subprocess.run(["bash", str(ROOT / "vm/launch.sh"),
                                     "--download-only"], capture_output=True,
                                    text=True, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Verified Arch ISO", result.stdout)
            self.assertEqual(
                (root / "cache/dotfiles-arch-vm/archlinux-x86_64.iso").read_bytes(),
                payload,
            )

    def test_tuning_staged_idempotent_and_rollback(self):
        with tempfile.TemporaryDirectory() as td:
            dest = Path(td)
            preview = run_shell(TUNER, "--dry-run", "--root", dest)
            self.assertEqual(preview.returncode, 0, preview.stderr)
            self.assertFalse((dest / "etc").exists())
            first = run_shell(TUNER, "--apply", "--root", dest)
            self.assertEqual(first.returncode, 0, first.stderr)
            zram = dest / "etc/systemd/zram-generator.conf.d/50-chezmoi-chromebook.conf"
            sysctl = dest / "etc/sysctl.d/90-chezmoi-chromebook.conf"
            journal = dest / "etc/systemd/journald.conf.d/50-chezmoi-chromebook.conf"
            for cfg in (zram, sysctl, journal):
                self.assertTrue(cfg.exists())
                self.assertTrue(cfg.read_text().startswith("# Managed by"))
            self.assertIn("min(ram / 2, 4096)", zram.read_text())
            self.assertIn("vm.swappiness = 80", sysctl.read_text())
            self.assertIn("SystemMaxUse=200M", journal.read_text())
            contents = [p.read_bytes() for p in (zram, sysctl, journal)]
            second = run_shell(TUNER, "--apply", "--root", dest)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(contents, [p.read_bytes() for p in (zram, sysctl, journal)])
            rollback = run_shell(TUNER, "--rollback", "--root", dest)
            self.assertEqual(rollback.returncode, 0, rollback.stderr)
            self.assertFalse(any(p.exists() for p in (zram, sysctl, journal)))

    def test_unmanaged_files_protected(self):
        with tempfile.TemporaryDirectory() as td:
            dest = Path(td)
            zram = dest / "etc/systemd/zram-generator.conf.d/50-chezmoi-chromebook.conf"
            zram.parent.mkdir(parents=True)
            zram.write_text("existing user's configuration\n")
            run = run_shell(TUNER, "--apply", "--root", dest)
            self.assertNotEqual(run.returncode, 0)
            self.assertIn("Refusing to overwrite", run.stderr)
            self.assertEqual(zram.read_text(), "existing user's configuration\n")
            self.assertFalse((dest / "etc/sysctl.d").exists())

    def test_tuning_opt_in_template(self):
        conf = (ROOT / "home/.chezmoi.toml.tmpl").read_text()
        self.assertIn('promptBoolOnce . "chromebookTuning"', conf)
        self.assertIn('false -}}', conf)
        template = (ROOT / "home/run_onchange_after_40-chromebook-tune.sh.tmpl").read_text()
        self.assertIn('eq .machineRole "chromebook"', template)
        self.assertIn(".chromebookTuning", template)
        self.assertIn('include ".chezmoitemplates/chromebook-tune.sh"', template)

    def test_vm_guest_never_emulates_chromebook_hardware(self):
        script = (ROOT / "vm/guest-smoke.sh").read_text()
        self.assertIn("--root", script)
        self.assertIn("QEMU|KVM|Virtual", script)
        self.assertIn("--dry-run", script)
        self.assertNotIn("sudo pacman", script)


if __name__ == "__main__":
    unittest.main()
