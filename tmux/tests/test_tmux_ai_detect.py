"""Regression tests with isolated process, pane-output, and tmux-cache fixtures."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash", path="/opt/homebrew/bin:" + os.environ["PATH"])
FAKE_COMMAND = """#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ['AI_TEST_ROOT'])
data = json.loads((root / 'fixture.json').read_text())
if pathlib.Path(sys.argv[0]).name == 'ps':
    print(data['processes'])
elif sys.argv[1] == 'show-option':
    print('claude,codex')
elif sys.argv[1] == 'display-message':
    print('test-server:123')
elif sys.argv[1] == 'list-panes':
    print(data['panes'])
elif sys.argv[1] == 'capture-pane':
    pane = sys.argv[sys.argv.index('-t') + 1]
    with (root / 'captures').open('a') as log:
        log.write(pane + '\\n')
    print(data['content'][pane])
else:
    sys.exit('Unexpected fake tmux command: ' + repr(sys.argv))
"""


class AgentDetectionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("tmux", "ps"):
            command = self.root / name
            command.write_text(FAKE_COMMAND)
            command.chmod(0o755)
        self.env = dict(os.environ, AI_TEST_ROOT=str(self.root),
                        TMPDIR=str(self.root), PATH=f"{self.root}:{os.environ['PATH']}")
        self.data = {
            "processes": "100 1 zsh\n101 100 codex",
            "panes": "P\t100\t%1\tmain:5\tg1\th0\t100\t30",
            "content": {"%1": self.screen()},
        }

    @staticmethod
    def screen(marker="", prompt="› Ask Codex to do anything"):
        return f"Previous response\n\n{marker}\n\n{prompt}\n\n  Model · context 20%\n"

    def detect(self, mode="panes"):
        (self.root / "fixture.json").write_text(json.dumps(self.data))
        result = subprocess.run([BASH, str(ROOT / "tmux-ai-detect.sh"), "--mode", mode],
                                env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(result.stderr, "")
        return dict(line.split("\t") for line in result.stdout.splitlines())

    def test_running_survives_unchanged_polls_without_recapturing(self):
        self.data["content"]["%1"] = self.screen("• Working (51m 49s • esc to interrupt)")
        for _ in range(4):
            self.assertEqual(self.detect(), {"%1": "working"})
        self.assertEqual((self.root / "captures").read_text().splitlines(), ["%1"])

    def test_running_survives_older_tmux_without_generation_fields(self):
        self.data["panes"] = self.data["panes"].replace("g1", "g")
        self.data["content"]["%1"] = self.screen("• Thinking (4s • esc to interrupt)")
        for _ in range(3):
            self.assertEqual(self.detect(), {"%1": "working"})

    def test_completion_returns_to_idle(self):
        self.data["content"]["%1"] = self.screen("• Working (4s • esc to interrupt)")
        self.assertEqual(self.detect(), {"%1": "working"})
        self.data["panes"] = self.data["panes"].replace("g1", "g2")
        self.data["content"]["%1"] = self.screen()
        self.detect()  # The final response still counts as output activity.
        self.assertEqual(self.detect(), {"%1": "idle"})

    def test_claude_spinner_remains_working(self):
        self.data["processes"] = "100 1 zsh\n101 100 claude"
        self.data["content"]["%1"] = self.screen("✻ Thinking… (12s · ↓ 20 tokens)", "❯ ")
        for _ in range(3):
            self.assertEqual(self.detect(), {"%1": "working"})

    def test_user_typing_does_not_count_as_output(self):
        self.assertEqual(self.detect(), {"%1": "idle"})
        self.data["panes"] = self.data["panes"].replace("g1", "g2")
        self.data["content"]["%1"] = self.screen(prompt="› • Working (4s • esc to interrupt)")
        self.assertEqual(self.detect(), {"%1": "idle"})

    def test_old_running_marker_in_transcript_is_ignored(self):
        self.data["content"]["%1"] = (
            "• Working (4s • esc to interrupt)\n" + "response\n" * 20 + self.screen())
        self.assertEqual(self.detect(), {"%1": "idle"})

    def test_shell_tool_and_running_pane_override_idle_window(self):
        self.data["processes"] += "\n102 101 bash\n200 1 zsh\n201 200 codex"
        self.data["panes"] += "\nP\t200\t%2\tmain:5\tg1\th0\t100\t30"
        self.data["content"]["%2"] = self.screen()
        self.assertEqual(self.detect(), {"%1": "working", "%2": "idle"})
        self.assertEqual(self.detect("windows"), {"main:5": "working"})

    def test_exited_agent_drops_cached_running_state(self):
        self.data["content"]["%1"] = self.screen("• Working (4s • esc to interrupt)")
        self.assertEqual(self.detect(), {"%1": "working"})
        self.data["processes"] = "100 1 zsh"
        self.assertEqual(self.detect(), {})
        self.assertEqual(next(self.root.glob("tmux-ai-detect-*.tsv")).read_text(), "")


if __name__ == "__main__":
    unittest.main()
