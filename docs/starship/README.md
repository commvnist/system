# starship

GNU Stow package for the Starship prompt configuration. Install Starship and
GNU Stow with your platform's package manager, then from the repository root:

```sh
stow -n -v --target="$HOME" --no-folding starship
stow --target="$HOME" --no-folding starship
```

This links `starship/.config/starship.toml` to `~/.config/starship.toml`.
The prompt uses Nerd Font symbols. Select a Nerd Font in the outer terminal,
including Windows Terminal for WSL2, if any glyphs appear as boxes. Starship
shows the current directory, Git state, command duration/status, and a Vim-mode
aware prompt character.

The unused network-namespace module is disabled because it added about 12 ms
to a WSL2 prompt while showing no output. Run `starship timings` in a normal
repository and a `/mnt/c` directory before changing the remaining modules;
Git status on a Windows-mounted path may behave differently.
