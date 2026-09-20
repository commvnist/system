# zsh

Home Manager installs `zsh/.zshenv` and `zsh/.zshrc` in your home and links three plugins
from pinned flake inputs under `~/.local/share/zsh/plugins`. Run
`bash bootstrap/home.sh switch` after changing the configuration or updating
the lock file. `bash bootstrap/home.sh doctor` reports how many plugins are
present in the home directory.

`.zshenv` adds the Home Manager profile and `~/.local/bin` to PATH for every
Zsh process, including noninteractive commands launched by an app. Interactive
keybindings and plugins remain in `.zshrc`.

The plugins provide fzf completion tabs, extra command completions, and syntax
highlighting. Atuin supplies history search at `Ctrl-r` and Up Arrow in both
Vim modes; `k`, `/`, and `?` keep their Vim behavior. Existing Zsh history can
be imported once with `atuin import zsh`. The old `~/.zsh_history` remains in
place. Atuin's automatic sync and update checks are disabled.

Nix also installs `zoxide`: use `z` to jump to a frequently used directory and
`zi` to choose one interactively.
Autosuggestions and automatic bracket pairing were removed because their
upstreams no longer met this repository's active-maintenance rule.

To see individual missing plugin names during shell startup, set
`ZSH_PLUGIN_DEBUG=1` temporarily.
To make Zsh your login shell, choose a stable OS-installed path listed in
`/etc/shells` (typically `/bin/zsh` or `/usr/bin/zsh` on Linux), then run
`chsh -s /that/path`. Do not use `$(command -v zsh)` here: after activation it
may point into a Nix profile that changes with Home Manager generations.
macOS already uses Zsh as its default shell.
The shell uses Vim editing mode. See the [shortcut guide](../keybindings.md)
for its bindings.
