# Documentation

This directory documents the `system` repository, its top-level package areas,
and host-specific Arch Linux GNOME setup notes. The repository is designed for
GNU Stow: package directories contain files laid out as they should appear under
`$HOME`.

## Common Dependencies

Install the base tools used across the repository:

```sh
sudo pacman -S --needed stow zsh kitty starship tmux vim python
```

GNOME extension build work additionally needs:

```sh
sudo pacman -S --needed nodejs npm typescript glib2 gnome-shell make
```

No AUR package is required for the current repository workflow. Use `yay` only
for optional applications you personally want outside this repository.

## Stow Workflow

From the repository root:

```sh
stow <package>
```

Examples:

```sh
stow zsh
stow gnome-extensions
```

Run a dry run before changing links:

```sh
stow -n -v <package>
```

## Documentation Areas

- [arch](arch/README.md)
- [gnome-extension-sources](gnome-extension-sources/README.md)
- [gnome-extensions](gnome-extensions/README.md)
- [kitty](kitty/README.md)
- [scripts](scripts/README.md)
- [starship](starship/README.md)
- [tmux](tmux/README.md)
- [vim](vim/README.md)
- [zsh](zsh/README.md)
