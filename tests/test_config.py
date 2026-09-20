"""Behavior checks for Neovim startup and cross-pane navigation."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INIT_LUA = ROOT / "nvim" / "init.lua"
DATA_HOME = os.environ.get("NVIM_TEST_DATA_HOME", str(Path.home() / ".local" / "share"))


class NeovimNavigationTest(unittest.TestCase):
    def run_nvim(
        self, commands: str, use_tmux: bool = False, tmux_session: bool = True
    ) -> tuple[str, str]:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            result = directory / "result"
            log = directory / "tmux.log"
            script = directory / "test.vim"
            script.write_text(
                "set nomore\n"
                + commands
                + f"\ncall writefile([string(winnr()), maparg('<Space>v', 'n'), getline(1), get(g:, 'surrounded', ''), get(g:, 'commented', '')], '{result}')\nqa!\n"
            )
            env = dict(
                os.environ,
                HOME=temporary,
                XDG_DATA_HOME=DATA_HOME,
                XDG_STATE_HOME=str(directory / "state"),
                XDG_CACHE_HOME=str(directory / "cache"),
                TERM="xterm-256color",
                TMUX="",
            )
            if use_tmux:
                binary = directory / "tmux"
                binary.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$MOCK_TMUX_LOG"\n')
                binary.chmod(0o755)
                env.update(
                    TMUX="mock" if tmux_session else "",
                    MOCK_TMUX_LOG=str(log),
                    PATH=f"{temporary}:{env['PATH']}",
                )
            process = subprocess.run(
                ["nvim", "--headless", "-u", str(INIT_LUA), "-n", "-S", str(script)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertNotIn("Error in ", process.stderr)
            self.assertNotIn("Error detected", process.stderr)
            self.assertTrue(result.exists(), "Neovim did not write its test result")
            return result.read_text(), log.read_text() if log.exists() else ""

    def test_all_ctrl_directions_move_between_nvim_splits(self) -> None:
        cases = (
            ("h", "vsplit", "wincmd l", "1"),
            ("l", "vsplit", "wincmd h", "2"),
            ("j", "split", "wincmd k", "2"),
            ("k", "split", "wincmd j", "1"),
        )
        for key, split, start, expected in cases:
            with self.subTest(direction=key):
                commands = f'{split}\n{start}\ncall feedkeys("\\<C-{key}>", "xt")'
                result, tmux_calls = self.run_nvim(commands, use_tmux=True)
                self.assertEqual(result.splitlines()[0], expected)
                self.assertIn("vsplit", result)
                self.assertEqual(tmux_calls, "")

    def test_pinned_plugins_and_language_tools_load(self) -> None:
        checks = (
            "assert(package.loaded['fzf-lua'])",
            "assert(package.loaded['gitsigns'])",
            "assert(package.loaded['mini.completion'])",
            "assert(package.loaded['mini.clue'])",
            "assert(vim.fn.executable('bash-language-server') == 1)",
            "assert(vim.fn.executable('lua-language-server') == 1)",
            "assert(vim.fn.executable('nixd') == 1)",
            "assert(vim.fn.executable('pyright-langserver') == 1)",
            "assert(vim.treesitter.language.add('lua'))",
        )
        commands = "\n".join(f"lua {check}" for check in checks)
        self.run_nvim(commands)

    def test_surround_and_comment_editing(self) -> None:
        result, _ = self.run_nvim(
            "set filetype=lua\n"
            "call setline(1, 'word')\n"
            "call cursor(1, 1)\n"
            "call feedkeys('ysiw\"', 'xt')\n"
            "let g:surrounded = getline(1)\n"
            "call feedkeys('ds\"', 'xt')\n"
            "call feedkeys('gcc', 'xt')\n"
            "let g:commented = getline(1)"
        )
        lines = result.splitlines()
        self.assertEqual(lines[3], '"word"')
        self.assertEqual(lines[4], "-- word")

    def test_all_ctrl_directions_cross_to_tmux_at_edges(self) -> None:
        for key, tmux_direction in (("h", "L"), ("j", "D"), ("k", "U"), ("l", "R")):
            with self.subTest(direction=key):
                result, tmux_calls = self.run_nvim(
                    f'call feedkeys("\\<C-{key}>", "xt")', use_tmux=True
                )
                self.assertEqual(result.splitlines()[0], "1")
                self.assertEqual(tmux_calls, f"select-pane -{tmux_direction}\n")

    def test_ctrl_backslash_selects_previous_tmux_pane_at_edge(self) -> None:
        result, tmux_calls = self.run_nvim(
            "call feedkeys(nr2char(28), 'xt')", use_tmux=True
        )
        self.assertEqual(result.splitlines()[0], "1")
        self.assertEqual(tmux_calls, "select-pane -l\n")

    def test_no_tmux_call_outside_session(self) -> None:
        result, tmux_calls = self.run_nvim(
            'call feedkeys("\\<C-h>", "xt")', use_tmux=True, tmux_session=False
        )
        self.assertEqual(result.splitlines()[0], "1")
        self.assertEqual(tmux_calls, "")


if __name__ == "__main__":
    unittest.main()
