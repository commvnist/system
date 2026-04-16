# zsh

GNU Stow package for zsh configuration.

## Dependencies

```sh
sudo pacman -S --needed zsh
```

No AUR package is required.

## Install

From the repository root:

```sh
stow zsh
```

This links `zsh/.zshrc` to `~/.zshrc`.

The shell configuration is expected to load user functions and scripts from the
stowed system packages as configured in `.zshrc`.
