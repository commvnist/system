# dotfiles

## quirks

### syswatch

A zsh function sourced via `.zshrc` — *probably* only works on a ThinkPad P16 Gen 2.

#### Dependencies

| Package | Purpose |
|---|---|
| `lm-sensors` | CPU, GPU (EC), fan, NVMe, RAM, and WiFi temperatures |
| `nvidia-smi` (NVIDIA driver) | GPU clock, utilization, power, VRAM, and temp |

#### Setup

**1. Configure lm-sensors**

```
sudo sensors-detect
```

Say YES to everything. This detects hardware monitor chips and loads the appropriate kernel modules.

**2. Fix RAPL permissions (CPU power reporting)**

By default, Linux restricts access to CPU energy counters. Create a udev rule to make them readable:

```
echo 'SUBSYSTEM=="powercap", ATTR{name}=="*", RUN+="/bin/chmod o+r /sys%p/energy_uj"' | sudo tee /etc/udev/rules.d/70-rapl.rules
sudo udevadm trigger --subsystem-match=powercap
```

To revert: `sudo rm /etc/udev/rules.d/70-rapl.rules && sudo udevadm trigger --subsystem-match=powercap`

**3. Source the function**

The function is loaded automatically if `.zsh_user_functions/` is sourced in your `.zshrc`. Run `syswatch` to start.
