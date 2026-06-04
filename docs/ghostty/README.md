# Ghostty

GNU Stow package for Ghostty terminal configuration.

## Dependencies

```sh
sudo pacman -S --needed ghostty
```

No AUR package is required.

## Install

From the repository root:

```sh
stow -n -v ghostty
stow ghostty
```

This links `ghostty/.config/ghostty/config.ghostty` to
`~/.config/ghostty/config.ghostty`.

If `~/.config/ghostty/config.ghostty` already exists as a real file, Stow will
refuse to overwrite it. Move or remove the unmanaged file first, or use
`stow --adopt ghostty` only when you intentionally want to import the existing
target into this repository.

## Configuration

The package intentionally ports only the Kitty shell and font choices:

- `command = zsh`
- `font-family = "FiraCode Nerd Font Mono"`

Ghostty also reads the legacy `~/.config/ghostty/config` file. If that file
exists, it may override values from `config.ghostty`; remove or fold it into
this Stow package before relying on this package as the single source of truth.
