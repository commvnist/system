# Tactiler

Tactiler is a fork of [Tactile](https://gitlab.com/lundal/tactile), the GNOME Shell window tiling extension by Lasse Lundal.

## System repository build

This directory is the source and build workspace. It is not stowed directly.

Build and stage the loadable extension into the stow package with:

```sh
make stow
```

The staged extension is written to:

```sh
../../gnome-extensions/.local/share/gnome-shell/extensions/tactiler@commvnist
```

From the repository root, `stow gnome-extensions` then links that staged
directory into `~/.local/share/gnome-shell/extensions/tactiler@commvnist`.

> Tile windows on a custom grid using your keyboard. Type Super-T to show the grid,
> then type two tiles (or the same tile twice) to move the active window.
>
> The grid can be up to 7x5 and each row/column can be weighted to take up more
> or less space.

https://extensions.gnome.org/extension/4548/tactile/

## Examples

![Animation of a window being moved around with Tactile](examples/usage.gif)

![Animation showing the customization features of Tactile](examples/highly-customizable.gif)

![Animation showing the preferences of Tactile](examples/preferences.gif)

## Common issues

- **The window extends to the right and/or bottom of the selected tile(s)**

  Most likely, the window's minimum width or height is larger than the target tile(s).
  If so, there is nothing Tactile can do. Parts of the window will overflow to the right and/or bottom.
  You can test this with LibreOffice Writer, which has no minimum size.

- **The window resizes but does not move, or moves but does not resize**

  New versions of GNOME tend to introduce bugs in the window handling on Wayland.
  These are normally fixed after a couple of weeks. Check if the issue disappears on Xorg.
  If so, it likely can't be fixed in Tactile, but please file an issue to let me know.

- **Tactile fails to start after an update and shows 'Error'**

  There seems to be a bug in GNOME's extension updater that can corrupt the extension when multiple versions are released in a short time span.
  Try to uninstall Tactiler (delete `~/.local/share/gnome-shell/extensions/tactiler@commvnist/`), reboot your machine, and then install it again.
  If the issue persists, please file an issue.

## License

Tactile is distributed under the terms of the GNU General Public License v3.0 or later.
See the [license](LICENSE) file for details.
