"""Exercise completion acknowledgement and polling against an isolated tmux server."""

import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
TMUX = shutil.which("tmux")
BASH = shutil.which("bash", path="/opt/homebrew/bin:" + os.environ["PATH"])


@unittest.skipUnless(TMUX, "tmux is required")
class AgentStatusTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.env = dict(os.environ, TMUX="", AI_TEST_ROOT=str(self.root),
                        TMUX_AI_DETECT_SCRIPT=str(self.root / "detect"),
                        PATH=f"{self.root}:{os.environ['PATH']}")
        wrapper = self.root / "tmux"
        wrapper.write_text(f"#!/bin/sh\nexec {shlex.quote(TMUX)} -S {shlex.quote(self.socket)} \"$@\"\n")
        wrapper.chmod(0o755)
        detector = self.root / "detect"
        detector.write_text(
            '#!/bin/sh\nprintf "scan\\n" >> "$AI_TEST_ROOT/scans"\n'
            '[ ! -e "$AI_TEST_ROOT/fail" ] || exit 1\n'
            'cat "$AI_TEST_ROOT/states"\n')
        detector.chmod(0o755)
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test", "-n", "first")
        self.addCleanup(lambda: self.tmux("kill-server"))
        self.tmux("new-window", "-d", "-t", "test:1", "-n", "second")
        config_lines = (ROOT / "tmux.conf").read_text().splitlines()
        self.status_job_format = next(shlex.split(line)[-1] for line in config_lines
                                      if line.startswith("set -ga status-right "))
        # Install the actual acknowledgement hooks from the project config.
        for line in config_lines:
            if line.startswith("set-hook "):
                self.tmux(*shlex.split(line))

    def tmux(self, *args):
        return subprocess.run([TMUX, "-S", self.socket, *args], env=self.env,
                              text=True, capture_output=True, check=True).stdout.strip()

    def scan(self, state, force=True):
        (self.root / "states").write_text(f"test:1\t{state}\n" if state else "")
        if force:
            self.tmux("set-option", "-gu", "@ai_status_last_poll")
        subprocess.run([BASH, str(ROOT / "tmux-ai-status.sh")], env=self.env,
                       text=True, capture_output=True, check=True)

    def value(self, option):
        return self.tmux("show-option", "-wqv", "-t", "test:1", option)

    def test_idle_agent_is_not_a_completion(self):
        self.scan("idle")
        self.assertEqual(self.value("@ai_state"), "idle")
        self.assertEqual(self.value("@ai_finished"), "")

    def test_completion_persists_until_window_is_visited(self):
        self.scan("working")
        self.scan("idle")
        self.assertEqual(self.value("@ai_finished"), "1")
        self.scan("idle")
        self.assertEqual(self.value("@ai_finished"), "1")
        self.tmux("select-window", "-t", "test:1")
        self.assertEqual(self.value("@ai_finished"), "")
        self.scan("idle")
        self.assertEqual(self.value("@ai_finished"), "")

    def test_new_work_clears_unseen_completion(self):
        self.scan("working")
        self.scan("idle")
        self.scan("working")
        self.assertEqual(self.value("@ai_finished"), "")
        self.assertEqual(self.value("@ai_state"), "working")

    def test_exited_agent_clears_both_flags(self):
        self.scan("working")
        self.scan("idle")
        self.scan("")
        self.assertEqual(self.value("@ai_finished"), "")
        self.assertEqual(self.value("@ai_state"), "")

    def test_failed_detection_preserves_previous_state(self):
        self.scan("working")
        (self.root / "fail").touch()
        self.scan("idle")
        self.assertEqual(self.value("@ai_state"), "working")
        self.assertEqual(self.value("@ai_finished"), "")

    def test_rapid_redraws_do_not_rescan(self):
        self.scan("working")
        self.scan("idle", force=False)
        self.assertEqual((self.root / "scans").read_text().splitlines(), ["scan"])
        self.assertEqual(self.value("@ai_state"), "working")

    def test_format_gate_waits_five_seconds_before_launching_job(self):
        gate = self.status_job_format.replace("#(~/.config/tmux/tmux-ai-status.sh)", "due")
        for age, expected in ((0, ""), (4, ""), (5, "due"), (10, "due")):
            self.tmux("set-option", "-g", "@ai_status_last_poll", str(int(time.time()) - age))
            self.assertEqual(self.tmux("display-message", "-p", gate), expected)
        self.tmux("set-option", "-gu", "@ai_status_last_poll")
        self.assertEqual(self.tmux("display-message", "-p", gate), "due")

    def test_idle_and_finished_share_tab_colors_and_have_no_alert_suffix(self):
        subprocess.run([BASH, str(ROOT / "tmux-ai-colors.sh")], env=self.env, check=True)
        self.scan("idle")
        idle = self.tmux("display-message", "-p", "-t", "test:1", "#{E:window-status-format}")
        self.scan("working")
        self.scan("idle")
        finished = self.tmux("display-message", "-p", "-t", "test:1", "#{E:window-status-format}")
        self.assertEqual(idle.replace("fg=#79dce8] 󰚩", "fg=#f38ba8] 󰚩"), finished)
        self.assertIn("󰚩", idle)
        self.assertNotIn("!", finished)
        self.assertNotIn("window_bell_flag", self.tmux("show-option", "-gv", "window-status-format"))

    def test_native_spinner_animates_without_extra_scans(self):
        subprocess.run([BASH, str(ROOT / "tmux-ai-colors.sh")], env=self.env, check=True)
        self.scan("working")
        for key in ("PATH", "AI_TEST_ROOT", "TMUX_AI_DETECT_SCRIPT"):
            self.tmux("set-environment", "-g", key, self.env[key])
        self.tmux("set-option", "-g", "status-right", self.status_job_format)
        master, slave = pty.openpty()
        client = subprocess.Popen([TMUX, "-S", self.socket, "attach-session", "-t", "test"],
                                  env=dict(self.env, TERM="xterm-256color"),
                                  stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        try:
            output = b""
            deadline = time.monotonic() + 1.2
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    output += os.read(master, 65536)
            frames = {frame for frame in "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏" if frame.encode() in output}
            self.assertGreaterEqual(len(frames), 3, output)
            self.assertEqual((self.root / "scans").read_text().splitlines(), ["scan"])
            self.tmux("select-window", "-t", "test:1")
            self.scan("idle")
            self.assertEqual(self.value("@ai_finished"), "")
        finally:
            client.terminate()
            client.wait(timeout=5)
            os.close(master)


if __name__ == "__main__":
    unittest.main()
