# dotfiles

## quirks

### syswatch

A zsh function sourced via `.zshrc` — *probably* only works on a ThinkPad P16 Gen 2.

#### Dependencies

| Package | Purpose |
|---|---|
| `nvidia-smi` (NVIDIA driver) | GPU clock, utilization, power, VRAM, and temp |

#### Setup

**1. Fix RAPL permissions (CPU power reporting)**

`syswatch` reads Intel RAPL energy counters from `/sys/class/powercap/intel-rapl:0/energy_uj`.
Those files are root-owned by default, so CPU package power stays unavailable unless the
permissions are adjusted at boot.

Use a `systemd-tmpfiles` rule to set the access mode and group on the sysfs node:

```
echo 'z /sys/class/powercap/intel-rapl:0/energy_uj 0440 root rapl -' | sudo tee /etc/tmpfiles.d/rapl.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/rapl.conf
```

If the `rapl` group does not exist yet, create it and add your user before running `syswatch`.
The rule is re-applied on boot, which is why this is preferred over an ad hoc `chmod` or udev rule.
For example:

```
sudo groupadd --system rapl
sudo usermod -aG rapl "$USER"
```

Log out and back in after changing group membership.

To revert:

```
sudo rm /etc/tmpfiles.d/rapl.conf
sudo chmod 0400 /sys/class/powercap/intel-rapl:0/energy_uj
```

**2. Source the function**

The function is loaded automatically if `.zsh_user_functions/` is sourced in your `.zshrc`. Run `syswatch` to start.
