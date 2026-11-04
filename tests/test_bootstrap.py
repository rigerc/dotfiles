"""No privileged operations: exercise installer preview and staged Chromebook tune."""
import os
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
            "install.sh", "container/run.sh", "container/guest.sh",
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

    def test_container_launcher_and_roles(self):
        host = ROOT / "container/run.sh"
        guest = ROOT / "container/guest.sh"
        self.assertTrue(host.is_file())
        self.assertTrue(guest.is_file())
        help_result = run_shell(host, "--help")
        self.assertEqual(help_result.returncode, 0, help_result.stderr)
        self.assertIn("--role", help_result.stdout)
        self.assertIn("--prompt", help_result.stdout)
        invalid = run_shell(host, "--role", "desktop;rm")
        self.assertNotEqual(invalid.returncode, 0)
        self.assertIn("Unknown role", invalid.stderr)

        # Stub podman: inspect argv without pulling an image or privileged calls.
        with tempfile.TemporaryDirectory() as td:
            fake = Path(td) / "podman"
            output = Path(td) / "podman-argv.txt"
            fake.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$PODMAN_CAPTURE"\n')
            fake.chmod(0o755)
            env = {**os.environ,
                   "PATH": f"{td}:{os.environ.get('PATH', '')}",
                   "PODMAN_CAPTURE": str(output)}
            result = subprocess.run(
                ["bash", str(host), "--role", "chromebook"],
                env=env, capture_output=True, text=True, timeout=15,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            args = output.read_text().splitlines()
            self.assertIn("--rm", args)
            self.assertIn(f"{ROOT}:/repo:ro", args)
            self.assertIn("docker.io/library/archlinux:latest", args)
            self.assertIn("/repo/container/guest.sh", args)
            self.assertIn("chromebook", args)
            self.assertNotIn("--privileged", args)
            self.assertNotIn("--device", args)

    def test_container_guest_never_applies_provisioning_scripts(self):
        guest = (ROOT / "container/guest.sh").read_text()
        self.assertIn("apply --exclude=scripts", guest)
        self.assertIn("--root", guest)
        self.assertIn("--rollback", guest)
        self.assertIn("cp -a /repo/. ", guest)
        self.assertNotIn("--privileged", guest)
        self.assertNotIn("sudo pacman", guest)
        self.assertFalse((ROOT / "vm").exists())
        self.assertFalse((ROOT / "docs/VM.md").exists())

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



if __name__ == "__main__":
    unittest.main()
