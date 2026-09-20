#!/usr/bin/env python3
"""Regenerate the dependency-free Stow plugin helper from flake.lock."""

import argparse
import json
import os
from pathlib import Path
import re
import tempfile


ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "flake.lock"
HELPER = ROOT / "zsh" / ".local" / "bin" / "zsh-plugin-sync"
PLUGINS = (
    "fzf-tab",
    "zsh-autosuggestions",
    "zsh-autopair",
    "zsh-history-substring-search",
    "zsh-syntax-highlighting",
)
START = "# BEGIN LOCKED PLUGINS -- generated from flake.lock by bootstrap/sync-plugin-pins.py"
END = "# END LOCKED PLUGINS"


def generated_block() -> str:
    lock = json.loads(LOCK.read_text())
    root_inputs = lock["nodes"][lock["root"]]["inputs"]
    lines = [START]
    for name in PLUGINS:
        node = lock["nodes"][root_inputs[name]]
        original, locked = node["original"], node["locked"]
        if original.get("type") != "github" or locked.get("type") != "github":
            raise ValueError(f"{name}: expected a locked GitHub input")
        owner, repo, revision = original["owner"], original["repo"], locked["rev"]
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            raise ValueError(f"{name}: invalid locked revision {revision!r}")
        lines.append(f"sync_plugin {name} https://github.com/{owner}/{repo}.git {revision}")
    return "\n".join((*lines, END))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true", help="fail if the helper differs from flake.lock")
    group.add_argument("--write", action="store_true", help="update the generated helper block")
    args = parser.parse_args()

    original = HELPER.read_text()
    if original.count(START) != 1 or original.count(END) != 1:
        raise ValueError("zsh-plugin-sync is missing its unique generated markers")
    before, tail = original.split(START, 1)
    _, after = tail.split(END, 1)
    updated = before + generated_block() + after
    if updated == original:
        print("Stow plugin pins match flake.lock")
        return 0
    if args.check:
        print("Stow plugin pins differ from flake.lock; run bootstrap/sync-plugin-pins.py --write")
        return 1

    with tempfile.NamedTemporaryFile("w", dir=HELPER.parent, delete=False) as output:
        temporary = Path(output.name)
        output.write(updated)
    try:
        temporary.chmod(HELPER.stat().st_mode)
        os.replace(temporary, HELPER)
    finally:
        temporary.unlink(missing_ok=True)
    print("Updated Stow plugin pins from flake.lock")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
