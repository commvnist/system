# zsh

Home Manager installs `zsh/.zshrc` as `~/.zshrc` and links the five plugins
from pinned flake inputs under `~/.local/share/zsh/plugins`. Run
`bash bootstrap/home.sh switch` after changing the configuration or updating
the lock file. `bash bootstrap/home.sh doctor` reports how many plugins are
present in the home directory.

To see individual missing plugin names during shell startup, set
`ZSH_PLUGIN_DEBUG=1` temporarily.
To make zsh your login shell where supported, run `chsh -s "$(command -v zsh)"`.
The shell uses Vim editing mode. See the [shortcut guide](../keybindings.md)
for its bindings.
