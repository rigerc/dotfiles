"""EDGAR/Chromebook role regression checks; never touches host disks or firmware."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parent.parent
HOME_SOURCE = ROOT / "home"


class ChromebookIntegrationTests(unittest.TestCase):
    def test_edgar_install_plan_is_complete_and_reuses_dotfiles(self):
        doc = (ROOT / "docs/EDGAR.md").read_text()
        for checkpoint in (
            "EDGAR", "Developer Mode", "write-protect screw",
            "UEFI Full ROM", "stock firmware", "internal eMMC",
            "systemd-boot", "arch-chroot", "chezmoi init rigerc/dotfiles",
            "start-hyprland", "chromebookTuning", "noctalia", "Audio",
            "Reverting or recovering",
        ):
            with self.subTest(checkpoint=checkpoint):
                self.assertIn(checkpoint, doc)
        self.assertIn("Do not manually recreate", doc)
        self.assertTrue((ROOT / "docs/CHROMEBOOK.md").exists())

    def test_terminal_is_role_specific_and_in_official_packages(self):
        packages = tomllib.loads(
            (HOME_SOURCE / ".chezmoidata/packages.toml").read_text()
        )["packages"]["pacman"]
        self.assertIn("foot", packages["chromebook"])
        self.assertIn("ghostty", packages["desktop"])
        terminal = (HOME_SOURCE / "dot_config/hypr/terminal.lua.tmpl").read_text()
        self.assertIn('eq .machineRole "chromebook"', terminal)
        self.assertIn('command = "foot"', terminal)
        self.assertIn('command = "ghostty"', terminal)
        binds = (HOME_SOURCE / "dot_config/hypr/binds.lua").read_text()
        self.assertIn('require("terminal")', binds)
        self.assertIn("terminal.command", binds)
        self.assertIn("terminal.class", binds)
        self.assertIn("window-switcher hold reverse", binds)
        self.assertIn("window-switcher hold", binds)

    def test_chromebook_blur_policy_does_not_change_desktop_rules(self):
        base = (HOME_SOURCE / "dot_config/hypr/hyprland.lua.tmpl").read_text()
        self.assertIn('require("layers")', base)
        self.assertIn('require("chromebook")', base)
        layers = (HOME_SOURCE / "dot_config/hypr/layers.lua.tmpl").read_text()
        self.assertIn('eq .machineRole "chromebook"', layers)
        self.assertIn("blur_popups = true", layers)
        self.assertIn("no_anim = true", layers)
        self.assertNotIn(
            "hl.layer_rule(",
            (HOME_SOURCE / "dot_config/hypr/rules.lua").read_text(),
        )

    def test_preflight_read_only_and_tuning_dep_guard(self):
        preflight = (ROOT / "scripts/chromebook-preflight.sh").read_text()
        self.assertIn("lsblk -D", preflight)
        self.assertIn("fw_platform_size", preflight)
        self.assertIn("zram-generator", preflight)
        self.assertNotIn("sudo ", preflight)
        for prohibited in ("mkfs.", "flashrom", "pacman -S"):
            self.assertNotIn(prohibited, preflight)
        tuner = (
            HOME_SOURCE / ".chezmoitemplates/chromebook-tune.sh"
        ).read_text()
        self.assertIn("pacman -Qq zram-generator", tuner)
        self.assertIn("zram-generator is missing", tuner)


@unittest.skipUnless(shutil.which("chezmoi"), "requires chezmoi executable")
class ChezmoiChromebookRenderTests(unittest.TestCase):
    def render(self, role, target):
        with tempfile.TemporaryDirectory(prefix="chromebook-render-") as td:
            root = Path(td)
            home = root / "home"
            home.mkdir()
            cfg = root / "chezmoi.toml"
            cfg.write_text(
                'sourceDir = "' + str(ROOT) + '"\n'
                '[data]\n'
                'gitName = "Fixture"\n'
                'gitEmail = "fixture@example.invalid"\n'
                'machineType = "personal"\n'
                f'machineRole = "{role}"\n'
                'packageProfile = "desktop"\n'
                'installPackages = false\n'
                'chromebookTuning = false\n'
            )
            cmd = [
                "chezmoi", "--source", str(ROOT),
                "--destination", str(home),
                "--config", str(cfg),
                "--cache", str(root / "cache"),
                "--persistent-state", str(root / "state.boltdb"),
                "--no-tty", "--no-pager",
                "cat", str(home / target),
            ]
            env = dict(os.environ)
            env.update(
                HOME=str(home),
                XDG_CONFIG_HOME=str(home / ".config"),
                XDG_DATA_HOME=str(root / "data"),
                XDG_CACHE_HOME=str(root / "cache-home"),
                XDG_STATE_HOME=str(root / "state-home"),
            )
            result = subprocess.run(
                cmd, env=env, capture_output=True, text=True, timeout=30
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout

    def test_terminal_and_layers_render_per_role(self):
        target_terminal = ".config/hypr/terminal.lua"
        target_layers = ".config/hypr/layers.lua"
        cb_terminal = self.render("chromebook", target_terminal)
        self.assertIn('command = "foot"', cb_terminal)
        self.assertNotIn('command = "ghostty"', cb_terminal)
        cb_layers = self.render("chromebook", target_layers)
        self.assertIn("no_anim = true", cb_layers)
        self.assertNotIn("blur_popups = true", cb_layers)

        for role in ("desktop", "laptop"):
            with self.subTest(role=role):
                terminal = self.render(role, target_terminal)
                layers = self.render(role, target_layers)
                self.assertIn('command = "ghostty"', terminal)
                self.assertNotIn('command = "foot"', terminal)
                self.assertIn("blur_popups = true", layers)


if __name__ == "__main__":
    unittest.main()
