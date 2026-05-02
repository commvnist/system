# RAPL MMIO Power Limit Restore

This package restores the CPU package MMIO RAPL limits used on the ThinkPad P16 Gen 2 when firmware or resume state leaves the long-term package limit at 25 W.

The observed failure mode is that the MSR-backed package limit remains high while the MMIO-backed package limit is reset to a low value. In that state, `turbostat` reports low CPU temperature and no thermal throttle flag, but package power remains pinned near 25 W. Reapplying the MMIO package limits restores normal performance.

## Installed files

```text
/usr/local/sbin/restore-cpu-rapl-limits
/etc/systemd/system/restore-cpu-rapl-limits.service
/etc/systemd/system/restore-cpu-rapl-limits-resume.service
/usr/share/doc/system/rapl-power-limit.md
```

The installed script writes these package limits:

```text
long-term package limit: 55 W
short-term package limit: 157 W
peak package limit: 234 W
```

The long-term value is 55 W because this host exposes 55 W as the maximum for the long-term MMIO package constraint. Short-term and peak limits remain higher so transient boost still works.

## Enable

After stowing this package into `/`, reload systemd and enable both units:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now restore-cpu-rapl-limits.service
sudo systemctl enable restore-cpu-rapl-limits-resume.service
```

The first unit runs at boot. The second unit runs after resume targets and reapplies the same limits after wake.

## Manual run

```sh
sudo bash /usr/local/sbin/restore-cpu-rapl-limits
```

Verify the MMIO long-term package limit:

```sh
cat /sys/class/powercap/intel-rapl-mmio:0/constraint_0_power_limit_uw
```

Expected value:

```text
55000000
```

Use `turbostat` under load to confirm package power can rise above 25 W:

```sh
sudo turbostat --Summary --interval 1
```
