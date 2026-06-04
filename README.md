# system

Personal Arch Linux GNOME system configuration, managed as GNU Stow packages.
This repository contains the dotfiles, local GNOME Shell extensions, scripts,
and host notes I use on my GNOME Arch install.

Most top-level package directories mirror paths relative to `$HOME`. For example,
`kitty/.config/kitty/kitty.conf` becomes `~/.config/kitty/kitty.conf` after
stowing the `kitty` package. Root-target packages are explicitly documented.
Boot-critical systemd packages must be copied as real files onto `/` rather
than left as symlinks into this repository.

## Install

Install the common tooling:

```sh
sudo pacman -S --needed stow zsh kitty ghostty starship tmux vim python
```

Stow user packages from the repository root:

```sh
stow zsh
stow kitty
stow ghostty
stow mangohud
stow starship
stow tmux
stow vim
stow scripts
stow gnome-extensions
```

Install the RAPL power limit package using its documented copy-based procedure:

```sh
cd /home/naek/system
less docs/rapl-power-limit/README.md
```

Use `stow -n -v <package>` for a dry run before linking a user package, or
the package-specific install documentation before changing machine-level files.

## Layout

- `gnome-extensions`: stowable GNOME Shell extension runtime files.
- `gnome-extension-sources`: source and build tooling for generated GNOME Shell
  extensions.
- `docs/arch`: host-level Arch Linux setup notes that are not managed by Stow.
- `ghostty`: Ghostty terminal configuration.
- `kitty`: Kitty terminal configuration.
- `mangohud`: MangoHud overlay configuration.
- `rapl-power-limit`: root-target systemd units and script to restore and
  monitor CPU MMIO RAPL package limits on the ThinkPad P16 Gen 2.
- `scripts`: user scripts and shell functions.
- `starship`: Starship prompt configuration.
- `tmux`: tmux configuration.
- `vim`: Vim configuration.
- `zsh`: zsh shell configuration.
- `docs`: concise documentation for the repository and each package area.

## Documentation

Start with [docs/README.md](docs/README.md). Package-specific documentation is
kept under `docs/<package>/`.
