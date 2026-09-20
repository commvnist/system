# zsh

GNU Stow package for zsh configuration. Install zsh and GNU Stow with your
platform's package manager. Starship and `fzf` are optional; `.zshrc` loads
them only when available.

The pinned Nix setup provides the plugins automatically. For Stow-only setup,
the configuration loads plugins from user-managed Git clones at the exact
revisions in `flake.lock`. It does not load arbitrary Homebrew or distribution
plugin versions. To install those revisions under
`~/.local/share/zsh/plugins`, run:

```sh
./zsh/.local/bin/zsh-plugin-sync
```

The helper requires Git and network access. Its revisions are generated from
`flake.lock`, and it leaves symlinked Nix-managed plugins alone. From the
repository root, preview
and install the package with:

```sh
stow -n -v --target="$HOME" --no-folding zsh
stow --target="$HOME" --no-folding zsh
```

This links `.zshrc` and `~/.local/bin/zsh-plugin-sync` into your home directory.
Set `ZSH_PLUGIN_DIR` before running the helper and starting Zsh if you want a
different plugin directory.
`bash bootstrap/home.sh doctor` reports how many pinned plugins are present.
To see individual missing plugin names during shell startup, set
`ZSH_PLUGIN_DEBUG=1` temporarily.
To make zsh your login shell where supported, run `chsh -s "$(command -v zsh)"`.
The shell uses Vim editing mode. See the [shortcut guide](../keybindings.md)
for its bindings.
