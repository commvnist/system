# Documentation

This repository contains GNU Stow packages for shell and editor configuration.
Each package mirrors paths under `$HOME`. From the repository root, use
`stow -n -v --target="$HOME" --no-folding <package>` to preview links before
installing a package.

For a pinned Nix setup, use [the fresh-host steps](../README.md#fresh-host-setup).
The [keyboard shortcut guide](keybindings.md) covers Vim, tmux, and Zsh.

## Package notes

- [zsh](zsh/README.md)
- [starship](starship/README.md)
- [tmux](tmux/README.md)
- [vim](vim/README.md)

## Bootstrap

- [Guided Nix installation](nix/README.md)
