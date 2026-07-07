# zsh

GNU Stow package for zsh configuration.

## Dependencies

```sh
sudo pacman -S --needed git stow zsh zsh-completions starship fzf
```

The `.zshrc` can load plugins from user-managed git clones, Homebrew, or distro
packages. On Arch, use the repo helper to install the complete plugin set under
`${XDG_DATA_HOME:-~/.local/share}/zsh/plugins`:

```sh
./zsh/.local/bin/zsh-plugin-sync
```

This avoids requiring an AUR helper for plugins that are not in the official
repositories.

## Install

From the repository root:

```sh
stow --target="$HOME" --no-folding zsh scripts starship
```

This links:

- `zsh/.zshrc` to `~/.zshrc`
- `zsh/.local/bin/zsh-plugin-sync` to `~/.local/bin/zsh-plugin-sync`
- script helpers under `~/.scripts`
- Starship prompt configuration under `~/.config/starship.toml`

The shell configuration is expected to load user functions and scripts from the
stowed system packages as configured in `.zshrc`.

To make zsh the login shell:

```sh
chsh -s "$(command -v zsh)"
```
