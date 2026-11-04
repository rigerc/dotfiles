"""Offline source-state checks plus optional sandboxed chezmoi smoke tests."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "home"


class SourceChecks(unittest.TestCase):
    def test_native_layout(self):
        self.assertEqual((ROOT / ".chezmoiroot").read_text(), "home\n")
        self.assertTrue((ROOT / ".chezmoiversion").is_file())
        self.assertTrue((SOURCE / ".chezmoi.toml.tmpl").is_file())
        self.assertTrue((SOURCE / ".chezmoidata/packages.toml").is_file())
        self.assertFalse((ROOT / "install.sh").exists())
        self.assertFalse((ROOT / "packages/arch.txt").exists())

    def test_managed_configs_exist(self):
        targets = (
            "dot_config/fish/config.fish", "dot_atuin/config.toml",
            "dot_config/ghostty/config", "dot_config/hypr/hyprland.lua",
            "dot_config/hypr/binds.lua", "dot_config/hypr/rules.lua",
            "dot_config/hypr/scrolling.lua", "dot_config/hypr/session.lua",
            "dot_config/noctalia/config.toml", "dot_gitconfig.tmpl",
        )
        for target in targets:
            with self.subTest(target=target):
                self.assertTrue((SOURCE / target).is_file())

    def test_package_profiles(self):
        groups = tomllib.loads(
            (SOURCE / ".chezmoidata/packages.toml").read_text()
        )["packages"]["pacman"]
        self.assertEqual(set(groups), {"core", "desktop", "developer"})
        self.assertIn("chezmoi", groups["core"])
        self.assertIn("hyprland", groups["desktop"])
        self.assertIn("neovim", groups["developer"])
        for items in groups.values():
            self.assertEqual(len(items), len(set(items)))
            for item in items:
                self.assertRegex(item, r"^[a-z0-9][a-z0-9@._+-]*$")

    def test_init_prompts_are_opt_in(self):
        config = (SOURCE / ".chezmoi.toml.tmpl").read_text()
        for key in (
            "gitName", "gitEmail", "machineType", "machineRole",
            "packageProfile", "installPackages",
        ):
            self.assertIn('"' + key + '"', config)
        self.assertIn("promptBoolOnce", config)
        self.assertIn("false -}}", config)

    def test_pacman_script_safety(self):
        script = (
            SOURCE / "run_onchange_before_20-install-packages.sh.tmpl"
        ).read_text()
        self.assertTrue(script.startswith("{{- if .installPackages -}}"))
        for expected in (
            "pacman -Q", "pacman -Syu --needed", "[ -t 0 ]",
            ".chezmoi.os", "shellQuote .",
        ):
            self.assertIn(expected, script)
        for forbidden in ("--noconfirm", "yay -S", "paru -S", "curl | sh"):
            self.assertNotIn(forbidden, script)
        self.assertNotRegex(script, r"(?m)^\s*(?:sudo\s+)?pacman -Sy\s")

    def test_no_destructive_source_directives(self):
        for path in SOURCE.rglob("*"):
            self.assertFalse(path.name.startswith(("exact_", "remove_")), path)
        self.assertFalse((SOURCE / ".chezmoiremove").exists())

    def test_server_ignores_desktop(self):
        rules = (SOURCE / ".chezmoiignore").read_text()
        self.assertIn('eq .machineRole "server"', rules)
        for pattern in (
            ".config/ghostty/**", ".config/hypr/**", ".config/noctalia/**"
        ):
            self.assertIn(pattern, rules)


@unittest.skipUnless(shutil.which("chezmoi"), "requires chezmoi executable")
class LiveChezmoiSmoke(unittest.TestCase):
    """Run a file-only apply with disposable paths. Never run package scripts."""
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="chezmoi-arch-test-")
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.cfg = self.tmp / "chezmoi.toml"
        self.cfg.write_text(
            "sourceDir = " + repr(str(ROOT)).replace("'", '"') + "\n"
            "[data]\n"
            'gitName = "Test User"\n'
            'gitEmail = "test@example.invalid"\n'
            'machineType = "personal"\n'
            'machineRole = "desktop"\n'
            'packageProfile = "core"\n'
            'installPackages = false\n'
        )
        self.env = {
            **os.environ,
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_DATA_HOME": str(self.tmp / "xdg-data"),
            "XDG_CACHE_HOME": str(self.tmp / "xdg-cache"),
            "XDG_STATE_HOME": str(self.tmp / "xdg-state"),
        }
        self.cmd = [
            "chezmoi", "--source", str(ROOT), "--destination", str(self.home),
            "--config", str(self.cfg),
            "--persistent-state", str(self.tmp / "state.boltdb"),
            "--cache", str(self.tmp / "cache"), "--no-pager", "--no-tty",
        ]

    def run_chezmoi(self, *args):
        return subprocess.run(
            [*self.cmd, *args], capture_output=True, text=True,
            env=self.env, timeout=30,
        )

    def test_render_and_apply_without_scripts(self):
        rendered = self.run_chezmoi("cat", str(self.home / ".gitconfig"))
        self.assertEqual(rendered.returncode, 0, rendered.stderr)
        self.assertIn("test@example.invalid", rendered.stdout)
        preview = self.run_chezmoi("apply", "--dry-run", "--exclude=scripts")
        self.assertEqual(preview.returncode, 0, preview.stderr)
        applied = self.run_chezmoi("apply", "--exclude=scripts")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertEqual(
            (self.home / ".config/fish/config.fish").read_bytes(),
            (SOURCE / "dot_config/fish/config.fish").read_bytes(),
        )

    def test_server_role_excludes_gui(self):
        self.cfg.write_text(
            self.cfg.read_text().replace(
                'machineRole = "desktop"', 'machineRole = "server"'
            )
        )
        applied = self.run_chezmoi("apply", "--exclude=scripts")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertFalse((self.home / ".config/hypr/hyprland.lua").exists())
        self.assertTrue((self.home / ".config/fish/config.fish").exists())


if __name__ == "__main__":
    unittest.main()
