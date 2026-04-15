# GNOME extensions

This is a GNU Stow package for local GNOME Shell extensions.

## Syswatch

Stow the package from the repository root:

```sh
stow gnome-extensions
```

Then reload GNOME Shell or log out and back in, and enable the extension:

```sh
gnome-extensions enable syswatch@commvnist
gnome-extensions enable netwatch@commvnist
```

The extension adds a compact top-bar monitor for CPU usage/temp/frequency, GPU
usage/temp, and RAM usage. Numeric fields are padded and monospace so updates do
not resize the widget.

Clicking the widget opens `kitty` and starts `syswatch`.

The network extension sits on the left side of the top bar and shows the local
IPv4 address plus download and upload speeds.
