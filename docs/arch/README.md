# Arch Linux Host Tweaks

These notes document machine-level Arch Linux changes that are not managed by
GNU Stow because they live under `/etc` or affect boot generation. They are
currently specific to the ThinkPad P16 Gen 2 setup.

## VIA Browser Access For HID Keyboards

VIA needs browser access to `hidraw` devices so it can communicate with a
compatible keyboard through WebHID. On this machine, the default Arch device
permissions exposed `/dev/hidraw*` as root-only:

```sh
ls -l /dev/hidraw*
```

Expected restricted permissions before the rule:

```text
crw------- 1 root root ... /dev/hidraw0
```

Create a udev rule:

```sh
sudo vim /etc/udev/rules.d/99-hidraw-via.rules
```

Rule contents:

```udev
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0666"
```

Reload and apply the rule:

```sh
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Confirm the permissions changed:

```sh
ls -l /dev/hidraw*
```

Expected permissions after the rule:

```text
crw-rw-rw- 1 root root ... /dev/hidraw0
```

This rule is intentionally broad: it grants read/write access to every
`hidraw` device on the machine. That is simple and works for this personal
laptop, but it is wider than a per-keyboard rule using vendor and product IDs.
Use a narrower rule if this setup is reused on a shared or higher-risk system.

## Kernel Command Line

This machine uses a unified kernel image (UKI). Kernel parameters are stored in:

```text
/etc/kernel/cmdline
```

Current command line:

```text
root=PARTUUID=ec5fa138-75c5-4615-95e1-be0d2db3691f zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs nvidia-drm.modeset=1 split_lock_detect=off
```

The host-specific tweaks are:

- `nvidia-drm.modeset=1`: enables DRM kernel modesetting for the NVIDIA driver.
  This is commonly needed for better Wayland integration, early display
  handoff, and modern graphics stack behavior.
- `split_lock_detect=off`: disables x86 split-lock detection. This avoids
  kernel enforcement or warnings for software that triggers split locks, at the
  cost of losing that diagnostic and protection mechanism.

After editing `/etc/kernel/cmdline`, rebuild the UKI:

```sh
sudo mkinitcpio -P
```

The expected output should include creation of the unified kernel image, for
example:

```text
==> Creating unified kernel image: '/boot/EFI/Linux/arch-linux.efi'
==> Unified kernel image generation successful
```

Reboot after rebuilding so the new kernel command line is active.
