"""Exercise remote setup in temporary homes; no network, sudo, or real services."""
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "home"


class Sandbox(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="dotfiles-remote-test-")
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.log = self.tmp / "commands"
        self.env = {k: v for k, v in os.environ.items() if k not in (
            "SSH_TTY", "SSH_CONNECTION", "HERDR_ENV", "HERDR_PANE_ID", "TMUX", "STY",
            "DOTFILES_NO_HERDR", "GH_TOKEN", "GITHUB_TOKEN",
        )}
        self.env.update(HOME=str(self.home), PATH=f"{self.bin}:/usr/bin:/bin",
                        XDG_CONFIG_HOME=str(self.home / ".config"),
                        XDG_DATA_HOME=str(self.tmp / "data"),
                        XDG_CACHE_HOME=str(self.tmp / "cache"),
                        XDG_STATE_HOME=str(self.tmp / "state"),
                        TERM="xterm-256color", TEST_LOG=str(self.log))

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\nset -eu\n" + body + "\n")
        path.chmod(0o755)

    def terminal(self, cmd, env=None, answers=b""):
        master, slave = pty.openpty()
        try:
            # All tested commands emit little output; no PTY buffer can fill.
            proc = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave,
                                    env=env or self.env)
            try:
                if answers:
                    os.write(master, answers)
                return proc.wait(timeout=10)
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
        finally:
            os.close(master)
            os.close(slave)


@unittest.skipUnless(shutil.which("chezmoi"), "requires chezmoi")
class RemoteRenderingTests(Sandbox):
    def setUp(self):
        super().setUp()
        self.cfg = self.tmp / "chezmoi.toml"
        self.cfg.write_text(
            '[data]\ngitName = "Test"\ngitEmail = "test@example.invalid"\n'
            'machineType = "personal"\nmachineRole = "server"\n'
            'packageProfile = "core"\ninstallPackages = false\nchromebookTuning = false\n'
        )
        self.cmd = ["chezmoi", "--source", str(ROOT), "--destination", str(self.home),
                    "--config", str(self.cfg), "--persistent-state", str(self.tmp / "state.db"),
                    "--cache", str(self.tmp / "chezmoi-cache"), "--no-tty", "--no-pager"]

    def render(self, relative):
        text = (SOURCE / relative).read_text()
        result = subprocess.run([*self.cmd, "execute-template"], input=text,
                                capture_output=True, text=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_existing_configs_default_to_no_provisioning(self):
        for relative in ("run_onchange_after_30-install-herdr.sh.tmpl",
                         "run_onchange_after_35-enable-sshd.sh.tmpl"):
            self.assertFalse(self.render(relative).strip())
        function = self.render("dot_config/fish/functions/dotfiles_remote_session.fish.tmpl")
        self.assertNotIn("command herdr", function)

    def test_opt_ins_render_independently_of_package_installation(self):
        with self.cfg.open("a") as config:
            config.write("installHerdr = true\nenableSshd = true\n")
        for relative in ("run_onchange_after_30-install-herdr.sh.tmpl",
                         "run_onchange_after_35-enable-sshd.sh.tmpl"):
            script = self.render(relative)
            result = subprocess.run(["bash", "-n"], input=script, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            if shutil.which("shellcheck"):
                result = subprocess.run(["shellcheck", "-s", "bash", "-"], input=script,
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout)

    def test_herdr_installer_skips_existing_binary(self):
        with self.cfg.open("a") as config:
            config.write("installHerdr = true\n")
        self.stub("herdr", ":")
        self.stub("curl", 'echo unexpected-network >> "$TEST_LOG"; exit 1')
        result = subprocess.run(["sh"], input=self.render("run_onchange_after_30-install-herdr.sh.tmpl"),
                                capture_output=True, text=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already installed", result.stdout)
        self.assertFalse(self.log.exists())

    def test_files_apply_without_credentials_or_server_side_effects(self):
        result = subprocess.run([*self.cmd, "apply", "--exclude=scripts"],
                                capture_output=True, text=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / ".ssh").stat().st_mode & 0o777, 0o700)
        self.assertTrue(os.access(self.home / ".local/bin/dotfiles-github-auth", os.X_OK))
        self.assertFalse((self.home / ".ssh/id_ed25519").exists())
        local = self.home / ".ssh/config.d"
        local.mkdir()
        (local / "lan.conf").write_text("Host lan-test\n HostName 192.168.1.8\n User lan-user\n")
        result = subprocess.run(["ssh", "-G", "-F", str(self.home / ".ssh/config"), "lan-test"],
                                capture_output=True, text=True, env=self.env)
        # OpenSSH expands ~ using the OS account, so inspect defaults here and
        # separately test the local include with an absolute sandbox path.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("forwardagent no", result.stdout)
        config = self.home / ".ssh/config"
        config.write_text(config.read_text().replace("~/.ssh/", str(self.home / ".ssh") + "/"))
        result = subprocess.run(["ssh", "-G", "-F", str(config), "lan-test"],
                                capture_output=True, text=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("hostname 192.168.1.8", result.stdout)
        self.assertIn("user lan-user", result.stdout)

    @unittest.skipUnless(shutil.which("fish"), "requires fish")
    def test_herdr_only_attaches_to_interactive_ssh_logins(self):
        with self.cfg.open("a") as config:
            config.write("installHerdr = true\n")
        function = self.tmp / "remote.fish"
        function.write_text(self.render("dot_config/fish/functions/dotfiles_remote_session.fish.tmpl"))
        self.stub("herdr", 'echo attach >> "$TEST_LOG"')
        command = ["fish", "--no-config", "--interactive", "--login", "--command",
                   f"source {function}; dotfiles_remote_session"]
        ssh_env = {**self.env, "SSH_CONNECTION": "192.168.1.2 50000 192.168.1.3 22",
                   "SSH_TTY": "/dev/pts/1"}
        self.assertEqual(self.terminal(command, ssh_env), 0)
        self.assertEqual(self.log.read_text(), "attach\n")
        self.log.unlink()
        for var in ("HERDR_ENV", "HERDR_PANE_ID", "TMUX", "STY", "DOTFILES_NO_HERDR"):
            with self.subTest(guard=var):
                self.terminal(command, {**ssh_env, var: "1"})
                self.assertFalse(self.log.exists())
        self.terminal(command, self.env)  # Local terminal.
        self.assertFalse(self.log.exists())
        self.terminal([arg for arg in command if arg != "--login"], ssh_env)
        self.assertFalse(self.log.exists())
        # SSH commands, piped sessions, and missing Herdr must all remain usable.
        result = subprocess.run(command, env=ssh_env, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())
        self.terminal([arg for arg in command if arg != "--interactive"], ssh_env)
        self.assertFalse(self.log.exists())
        (self.bin / "herdr").unlink()
        self.assertEqual(self.terminal(command, ssh_env), 0)


class GithubAuthTests(Sandbox):
    @unittest.skipUnless(shutil.which("ssh-keygen"), "requires ssh-keygen")
    def test_reuses_key_and_uploads_only_public_material(self):
        key = self.home / ".ssh/id_ed25519"
        key.parent.mkdir()
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(key)],
                       check=True, capture_output=True)
        before = key.read_bytes()
        self.stub("gh", '''[[ "$GH_HOST" == github.com ]]
printf '%s\\n' "$*" >> "$TEST_LOG"
if [[ "$1 $2" == "ssh-key add" ]]; then
    cp "$3" "$HOME/uploaded.pub"
fi''')
        helper = SOURCE / "dot_local/bin/executable_dotfiles-github-auth"
        result = self.terminal(["bash", str(helper)],
                               env={**self.env, "GH_HOST": "enterprise.example.invalid"}, answers=b"y\n")
        self.assertEqual(result, 0)
        self.assertEqual(key.read_bytes(), before)
        self.assertTrue((self.home / "uploaded.pub").read_text().startswith("ssh-ed25519 "))
        self.assertNotIn("PRIVATE KEY", (self.home / "uploaded.pub").read_text())
        self.assertNotIn("auth login", self.log.read_text())
        self.assertIn("config set git_protocol ssh --host github.com", self.log.read_text())

    def test_device_flow_and_declining_generation(self):
        self.stub("gh", '''printf '%s\\n' "$*" >> "$TEST_LOG"
if [[ "$1 $2" == "auth status" ]]; then exit 1; fi''')
        helper = SOURCE / "dot_local/bin/executable_dotfiles-github-auth"
        self.assertEqual(self.terminal(["bash", str(helper)], answers=b"n\n"), 0)
        self.assertIn("auth login --hostname github.com --web --git-protocol ssh --skip-ssh-key",
                      self.log.read_text())
        self.assertFalse((self.home / ".ssh").exists())


class SshServerTests(Sandbox):
    def run_server_stage(self, conflict=False, real_sshd=False):
        # Run the privileged heredoc against a sandbox path and fake commands.
        # No sudo, system service, host-key generation, or real /etc writes occur.
        script = (SOURCE / ".chezmoitemplates/sshd-lan.sh").read_text()
        script = script.split("<<'ROOT'\n", 1)[1].rsplit("\nROOT", 1)[0]
        directory = self.tmp / "sshd_config.d"
        script = script.replace("/etc/ssh/sshd_config.d", str(directory))
        self.target = directory / "00-chezmoi-lan.conf"
        self.stub("ssh-keygen", ":")
        self.stub("systemctl", 'echo "$*" >> "$TEST_LOG"')
        self.stub("sshd", '''if [[ "$1" == -T ]]; then
    if [[ "$TEST_CONFLICT" == 1 ]]; then echo 'permitrootlogin yes'; else
        awk '{$1=tolower($1); print}' "$TEST_SERVER_CONFIG"
    fi
fi''')
        if real_sshd:
            key = self.tmp / "hostkey"
            subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(key)],
                           check=True, capture_output=True)
            main = self.tmp / "sshd_config"
            main.write_text(f"HostKey {key}\nInclude {self.target}\n")
            self.env.update(TEST_REAL_SSHD=shutil.which("sshd"), TEST_SSHD_MAIN=str(main))
            self.stub("sshd", 'exec "$TEST_REAL_SSHD" -f "$TEST_SSHD_MAIN" "$@"')
        return subprocess.run(["bash", "-s", "--", "lanuser"], input=script, text=True,
                              capture_output=True, env={**self.env,
                                  "TEST_SERVER_CONFIG": str(self.target),
                                  "TEST_CONFLICT": str(int(conflict))}, timeout=10)

    def test_lan_policy_validated_before_service_start_and_idempotent(self):
        result = self.run_server_stage()
        self.assertEqual(result.returncode, 0, result.stderr)
        config = self.target.read_text()
        self.assertIn("lanuser@192.168.0.0/16", config)
        self.assertIn("lanuser@fc00::/7", config)
        self.assertIn("PermitRootLogin no", config)
        self.assertEqual(self.log.read_text(), "enable --now sshd\nreload sshd\n")
        result = self.run_server_stage()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.target.read_text(), config)

    @unittest.skipUnless(shutil.which("sshd") and shutil.which("ssh-keygen"), "requires OpenSSH")
    def test_policy_passes_real_openssh_validation(self):
        result = self.run_server_stage(real_sshd=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("enable --now sshd", self.log.read_text())

    def test_conflicts_roll_back_without_starting_service(self):
        result = self.run_server_stage(conflict=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.target.exists())
        self.assertFalse(self.log.exists())
        self.assertEqual(self.run_server_stage().returncode, 0)
        previous = self.target.read_bytes()
        self.log.unlink()
        self.assertNotEqual(self.run_server_stage(conflict=True).returncode, 0)
        self.assertEqual(self.target.read_bytes(), previous)
        self.assertFalse(self.log.exists())

    def test_unmanaged_drop_in_protected(self):
        directory = self.tmp / "sshd_config.d"
        directory.mkdir()
        target = directory / "00-chezmoi-lan.conf"
        target.write_text("# My existing policy\n")
        result = self.run_server_stage()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing to overwrite", result.stderr)
        self.assertEqual(target.read_text(), "# My existing policy\n")
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
