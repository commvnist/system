# starship

Home Manager installs Starship and links `starship/.config/starship.toml` to
`~/.config/starship.toml` (or your configured XDG config directory). Run
`bash bootstrap/home.sh switch` from the repository root after editing it.
The prompt uses Nerd Font symbols. Select a Nerd Font in the outer terminal,
including Windows Terminal for WSL2, if any glyphs appear as boxes. Starship
shows the current directory, Git state, command duration/status, and a Vim-mode
aware prompt character.

The Zsh cursor widget is registered before Starship initialization, so
Starship can wrap it and redraw the prompt when Vim mode changes. `❯` marks
insert mode; `❮` marks command mode. If this stops updating, inspect the
active `zle-keymap-select` widget in an interactive Zsh session.

The unused network-namespace module is disabled because it added about 12 ms
to a WSL2 prompt while showing no output. Run `starship timings` in a normal
repository and a `/mnt/c` directory before changing the remaining modules;
Git status on a Windows-mounted path may behave differently. The prompt's
existing layout was retained after measuring module timings in the repository
and on `/mnt/c`; both were responsive, so broad module changes would remove
useful language and environment indicators without a measured benefit.
