"""Exercise temporary homes; package commands and account changes are stubbed."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("chezmoi"), "chezmoi is required")
class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-install-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.state = self.root / "state"
        self.calls = self.root / "package-calls"
        self.shell_calls = self.root / "shell-calls"
        self.shell_state = self.root / "login-shell"
        self.shell_state.write_text("/usr/bin/fish\n")
        binaries = self.root / "bin"
        binaries.mkdir()
        # An accidental package command must never reach the host package manager.
        for name in ("sudo", "pacman"):
            stub = binaries / name
            stub.write_text(
                '#!/bin/sh\nprintf "%s\\n" "$*" >> "$INSTALL_TEST_CALLS"\n'
            )
            stub.chmod(0o755)
        # Never read or change the real user's account during installation tests.
        account_stub = binaries / "getent"
        account_stub.write_text(
            '#!/bin/sh\nIFS= read -r login_shell < "$INSTALL_TEST_SHELL_STATE"\n'
            'printf "%s:x:1000:1000:Test User:%s:%s\\n" "$2" "$HOME" "$login_shell"\n'
        )
        account_stub.chmod(0o755)
        shell_stub = binaries / "chsh"
        shell_stub.write_text(
            '#!/bin/sh\n'
            'if [ "$1" = --list-shells ]; then\n'
            '    printf "%s\\n" /bin/bash\n'
            '    [ "${INSTALL_TEST_UNREGISTERED_FISH:-0}" = 1 ] || printf "%s\\n" /usr/bin/fish\n'
            '    exit 0\n'
            'fi\n'
            'printf "%s\\n" "$*" >> "$INSTALL_TEST_SHELL_CALLS"\n'
            '[ "${INSTALL_TEST_CHSH_FAIL:-0}" = 1 ] && exit 1\n'
            'printf "%s\\n" "$2" > "$INSTALL_TEST_SHELL_STATE"\n'
        )
        shell_stub.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(
            HOME=str(self.home),
            XDG_CONFIG_HOME=str(self.home / ".config"),
            XDG_STATE_HOME=str(self.state),
            XDG_DATA_HOME=str(self.home / ".local/share"),
            XDG_CACHE_HOME=str(self.root / "cache"),
            INSTALL_TEST_CALLS=str(self.calls),
            INSTALL_TEST_SHELL_CALLS=str(self.shell_calls),
            INSTALL_TEST_SHELL_STATE=str(self.shell_state),
            PATH=str(binaries) + os.pathsep + self.env["PATH"],
        )
        self.write(".config/fish/config.fish", "original fish config\n")
        self.write(".config/fish/conf.d/local.fish", "unmanaged local settings\n")
        self.write(".atuin/data/history.db", "history must survive\n")
        self.write(".atuin/data/key", "private fixture\n")
        self.write(".local/share/chezmoi/keep.txt", "old source must survive\n")
        # This would fail if the installer read the old chezmoi configuration.
        self.write(".config/chezmoi/chezmoi.toml", "not valid TOML [\n")

    def write(self, relative, content):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def snapshot(self):
        return {
            str(path.relative_to(self.home)): path.read_bytes()
            for path in self.home.rglob("*")
            if path.is_file()
        }

    def run_install(self, *args, success=True):
        result = subprocess.run(
            [str(REPO / "install.sh"), *args],
            cwd=self.root,  # The installer must work outside the checkout.
            env=self.env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_default_preview_and_package_preview_do_not_modify_home(self):
        before = self.snapshot()
        result = self.run_install("--packages")
        self.assertIn("Preview only", result.stdout)
        self.assertIn("sudo pacman -Syu --needed", result.stdout)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(self.calls.exists())
        self.assertFalse(self.state.exists())
        self.assertFalse(self.shell_calls.exists())

    def test_package_preview_works_before_chezmoi_is_installed(self):
        before = self.snapshot()
        minimal_path = self.root / "minimal-bin"
        minimal_path.mkdir()
        for name in ("bash", "realpath", "dirname", "sed", "id"):
            (minimal_path / name).symlink_to(shutil.which(name))
        (minimal_path / "getent").symlink_to(self.root / "bin/getent")
        self.env["PATH"] = str(minimal_path)
        result = self.run_install("--packages")
        self.assertIn("sudo pacman -Syu --needed", result.stdout)
        self.assertIn("Install chezmoi to preview", result.stdout)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(self.calls.exists())

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    def test_apply_backups_preserves_private_data_and_is_idempotent(self):
        before = self.snapshot()
        self.run_install("--apply")
        backups = list((self.state / "dotfiles/backups").iterdir())
        self.assertEqual(len(backups), 1)
        backup = backups[0]
        self.assertEqual(backup.stat().st_mode & 0o777, 0o700)
        self.assertEqual(
            (backup / "files/.config/fish/config.fish").read_text(),
            "original fish config\n",
        )
        self.assertEqual(
            (backup / "existing.txt").read_text().splitlines(),
            [".config/fish/config.fish"],
        )
        created = (backup / "created.txt").read_text().splitlines()
        self.assertEqual(len(created), 8)
        self.assertIn(".config/hypr/session.lua", created)
        for target, original in before.items():
            if target != ".config/fish/config.fish":
                self.assertEqual((self.home / target).read_bytes(), original)
        self.assertEqual(
            (self.home / ".config/hypr/binds.lua").read_bytes(),
            (REPO / "home/dot_config/hypr/binds.lua").read_bytes(),
        )
        self.assertFalse(self.calls.exists())
        result = self.run_install("--apply")
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(list((self.state / "dotfiles/backups").iterdir()), backups)

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    def test_existing_symlink_is_backed_up_without_editing_its_source(self):
        original = self.write("linked-source.fish", "source must survive\n")
        target = self.home / ".config/fish/config.fish"
        target.unlink()
        target.symlink_to(original)
        self.run_install("--apply")
        backup = next((self.state / "dotfiles/backups").iterdir())
        saved = backup / "files/.config/fish/config.fish"
        self.assertTrue(saved.is_symlink())
        self.assertEqual(saved.readlink(), original)
        self.assertFalse(target.is_symlink())
        self.assertEqual(original.read_text(), "source must survive\n")

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    def test_package_install_is_explicit_and_keeps_prompts(self):
        self.run_install("--apply", "--packages")
        args = self.calls.read_text().split()
        self.assertEqual(args[:3], ["pacman", "-Syu", "--needed"])
        self.assertIn("noctalia", args)
        self.assertNotIn("--noconfirm", args)

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    def test_staged_destination_does_not_touch_user_home(self):
        self.shell_state.write_text("/bin/bash\n")
        before = self.snapshot()
        destination = self.root / "staged home"
        self.run_install("--apply", "--destination", str(destination))
        self.assertTrue((destination / ".config/hypr/session.lua").is_file())
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(self.state.exists())
        self.assertFalse(self.shell_calls.exists())

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    @unittest.skipUnless(Path("/usr/bin/fish").is_file(), "system Fish is required")
    def test_apply_switches_login_shell_and_does_not_repeat_chsh(self):
        self.shell_state.write_text("/bin/bash\n")
        self.env["SHELL"] = "/usr/bin/fish"  # An existing session can have a stale value.
        self.run_install("--apply")
        self.assertEqual(self.shell_calls.read_text().splitlines(), ["--shell /usr/bin/fish"])
        self.assertEqual(self.shell_state.read_text(), "/usr/bin/fish\n")
        self.run_install("--apply")
        self.assertEqual(len(self.shell_calls.read_text().splitlines()), 1)

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    def test_bin_fish_alias_does_not_trigger_shell_change(self):
        self.shell_state.write_text("/bin/fish\n")
        self.env["SHELL"] = "/bin/bash"
        self.run_install("--apply")
        self.assertFalse(self.shell_calls.exists())

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    @unittest.skipUnless(Path("/usr/bin/fish").is_file(), "system Fish is required")
    def test_up_to_date_files_still_switch_login_shell(self):
        self.run_install("--apply", "--no-shell")
        backups = list((self.state / "dotfiles/backups").iterdir())
        self.shell_state.write_text("/bin/bash\n")
        result = self.run_install("--apply")
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.shell_calls.read_text().strip(), "--shell /usr/bin/fish")
        self.assertEqual(list((self.state / "dotfiles/backups").iterdir()), backups)

    def test_preview_describes_shell_change_without_changing_account(self):
        self.shell_state.write_text("/bin/bash\n")
        result = self.run_install()
        self.assertIn("Would run: chsh --shell /usr/bin/fish", result.stdout)
        self.assertEqual(self.shell_state.read_text(), "/bin/bash\n")
        self.assertFalse(self.shell_calls.exists())

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    def test_no_shell_option_preserves_login_shell(self):
        self.shell_state.write_text("/bin/bash\n")
        self.run_install("--apply", "--no-shell")
        self.assertEqual(self.shell_state.read_text(), "/bin/bash\n")
        self.assertFalse(self.shell_calls.exists())

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    @unittest.skipUnless(Path("/usr/bin/fish").is_file(), "system Fish is required")
    def test_failed_shell_change_is_reported_and_can_be_retried(self):
        self.shell_state.write_text("/bin/bash\n")
        self.env["INSTALL_TEST_CHSH_FAIL"] = "1"
        result = self.run_install("--apply", success=False)
        self.assertIn("shell change failed", result.stderr)
        self.assertTrue((self.home / ".config/fish/config.fish").is_file())
        self.env.pop("INSTALL_TEST_CHSH_FAIL")
        self.run_install("--apply")
        self.assertEqual(self.shell_state.read_text(), "/usr/bin/fish\n")

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    @unittest.skipUnless(Path("/usr/bin/fish").is_file(), "system Fish is required")
    def test_unregistered_fish_fails_before_dotfiles_are_changed(self):
        self.shell_state.write_text("/bin/bash\n")
        self.env["INSTALL_TEST_UNREGISTERED_FISH"] = "1"
        before = self.snapshot()
        result = self.run_install("--apply", success=False)
        self.assertIn("not registered in /etc/shells", result.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(self.shell_calls.exists())

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally rejects root apply")
    def test_directory_conflict_fails_before_applying(self):
        conflict = self.home / ".config/fish/config.fish"
        conflict.unlink()
        conflict.mkdir()
        before = self.snapshot()
        result = self.run_install("--apply", success=False)
        self.assertIn("found a directory", result.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(self.state.exists())

    def test_invalid_options_fail_without_changes(self):
        before = self.snapshot()
        self.run_install("--unknown", success=False)
        self.run_install("--destination", success=False)
        self.run_install("--destination", "/", success=False)
        self.run_install("--dry-run", "--apply", success=False)
        self.run_install("--apply", "--dry-run", success=False)
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
