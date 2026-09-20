"""Behavior checks for cross-pane Vim navigation and pinned plugin clones."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
VIMRC = ROOT / "vim" / ".vimrc"


class VimNavigationTest(unittest.TestCase):
    def run_vim(self, commands: str, use_tmux: bool = False) -> tuple[str, str]:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            result = directory / "result"
            log = directory / "tmux.log"
            script = directory / "test.vim"
            script.write_text(
                "set nomore\n"
                + commands
                + f"\ncall writefile([string(winnr()), maparg('<Space>v', 'n')], '{result}')\nqa!\n"
            )
            env = dict(os.environ, HOME=temporary, TERM="xterm-256color", TMUX="")
            if use_tmux:
                binary = directory / "tmux"
                binary.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$MOCK_TMUX_LOG"\n')
                binary.chmod(0o755)
                env.update(TMUX="mock", MOCK_TMUX_LOG=str(log), PATH=f"{temporary}:{env['PATH']}")
            process = subprocess.run(
                ["vim", "-Nu", str(VIMRC), "-n", "-es", "-S", str(script)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertTrue(result.exists(), "Vim did not write its test result")
            return result.read_text(), log.read_text() if log.exists() else ""

    def test_all_ctrl_directions_move_between_vim_splits(self) -> None:
        cases = (
            ("h", "vsplit", "wincmd l", "1"),
            ("l", "vsplit", "wincmd h", "2"),
            ("j", "split", "wincmd k", "2"),
            ("k", "split", "wincmd j", "1"),
        )
        for key, split, start, expected in cases:
            with self.subTest(direction=key):
                commands = f'{split}\n{start}\ncall feedkeys("\\<C-{key}>", "xt")'
                result, tmux_calls = self.run_vim(commands, use_tmux=True)
                self.assertEqual(result.splitlines()[0], expected)
                self.assertIn(":vsplit", result)
                self.assertEqual(tmux_calls, "")

    def test_all_ctrl_directions_cross_to_tmux_at_edges(self) -> None:
        for key, tmux_direction in (("h", "L"), ("j", "D"), ("k", "U"), ("l", "R")):
            with self.subTest(direction=key):
                result, tmux_calls = self.run_vim(
                    f'call feedkeys("\\<C-{key}>", "xt")', use_tmux=True
                )
                self.assertEqual(result.splitlines()[0], "1")
                self.assertEqual(tmux_calls, f"select-pane -{tmux_direction}\n")

    def test_ctrl_backslash_selects_previous_tmux_pane_at_edge(self) -> None:
        result, tmux_calls = self.run_vim(
            "call feedkeys(nr2char(28), 'xt')", use_tmux=True
        )
        self.assertEqual(result.splitlines()[0], "1")
        self.assertEqual(tmux_calls, "select-pane -l\n")


class PluginPinsTest(unittest.TestCase):
    def test_stow_fallback_matches_flake_lock(self) -> None:
        lock = json.loads((ROOT / "flake.lock").read_text())
        helper = (ROOT / "zsh" / ".local" / "bin" / "zsh-plugin-sync").read_text()
        pins = re.findall(
            r"^sync_plugin ([\w-]+) (https://[^ ]+) ([0-9a-f]{40})$",
            helper,
            re.MULTILINE,
        )
        self.assertEqual(len(pins), 5)
        for name, url, revision in pins:
            node = lock["nodes"][name]
            self.assertEqual(revision, node["locked"]["rev"])
            self.assertEqual(
                url,
                f"https://github.com/{node['original']['owner']}/{node['original']['repo']}.git",
            )


if __name__ == "__main__":
    unittest.main()
