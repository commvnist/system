# Guided Nix installation

## Prerequisites

Install Git before cloning this repository. The guide also needs `curl`,
`sudo`, `tar`, and `sha256sum` or `shasum`; Linux additionally needs `xz`.
Use the host package manager for these tools. Git and Python are installed by
Home Manager after Nix is ready, but the initial clone needs Git already
available.

## WSL2 first run

Some WSL distributions start as `root`. For a fresh Nix install, create a
normal user with your distribution's account tools and make it the default in
`/etc/wsl.conf`:

```ini
[user]
default=your-user-name

[boot]
systemd=true
```

Set up `sudo` for that user with the distribution's supported procedure. Run
`wsl --shutdown` from Windows PowerShell and reopen the distro before the
installer; systemd must actually be running for multi-user mode. The
[Microsoft WSL configuration guide](https://learn.microsoft.com/windows/wsl/wsl-config)
documents both settings. If Nix is already installed in a root-run WSL distro,
skip the installer and run `bootstrap/home.sh` as the intended Home Manager
user; do not reinstall Nix over `/nix`. Keep this repository in the Linux
filesystem, such as `/home/your-user-name/repos/system`.

Run this from a fresh macOS, Linux, or WSL2 host **as your normal user**:

```sh
bash bootstrap/install-nix.sh --dry-run
bash bootstrap/install-nix.sh
```

The first command checks existing accounts and prints the proposed install.
The second command asks before downloading the Nix 2.35.2 release script from
`https://releases.nixos.org/nix/nix-2.35.2/install`. The wrapper compares its
SHA-256 with the pinned value before execution. The upstream installer requests
`sudo` and shows its own changes before applying them. The guide does not install
Home Manager or apply this repository's dotfiles. Once Nix is available, use
the [fresh-host setup](../../README.md#fresh-host-setup).

The dry run checks the prerequisites before installation. To update the Nix
installer itself, choose a versioned release, copy its published `install.sha256`
value into `bootstrap/install-nix.sh`, verify the downloaded script locally,
and run the installer tests. Do not replace the pinned URL with the moving
`nixos.org/nix/install` alias.

## Build-account collisions

The multi-user installer creates a `nixbld` group and 32 build users by
default. Current upstream defaults are:

| Platform | Build user names | First UID | Group GID |
| --- | --- | ---: | ---: |
| Linux, including WSL2 with systemd | `nixbld1` ... `nixbld32` | 30001 | 30000 |
| macOS | `_nixbld1` ... `_nixbld32` | 351 | 350 |

The guide queries the host's account service for occupied UIDs and GIDs. It
reports each collision, looks for a free contiguous UID block and a free GID,
then lets you accept or change the suggestions. These are separate ID spaces:
an occupied GID need not shift the UID range, and vice versa. To choose IDs
yourself, for example:

```sh
bash bootstrap/install-nix.sh --dry-run --first-uid 31001 --group-gid 31000
bash bootstrap/install-nix.sh --first-uid 31001 --group-gid 31000
```

The installer receives `NIX_FIRST_BUILD_UID`, `NIX_BUILD_GROUP_ID`, and
`NIX_USER_COUNT` from the guide. The group name remains `nixbld`; the guide
stops if that name or any expected build-user name already exists, as it may
indicate a partial installation. It also stops when `/nix`, `/etc/nix`, or a
`nix` command already exists. Investigate or repair an existing install
instead of reinstalling over it. The guide never deletes users, changes
existing UIDs/GIDs, or removes Nix files.

For macOS, upstream Nix describes a role-user range around 200-400, with 351
as the present default. The guide searches 351-399 for a free block; a custom
range outside that area should be evaluated before use. If you later manage
Nix with nix-darwin, make its account settings match the values chosen here:

```nix
ids.uids.nixbld = 350; # first build UID minus one
ids.gids.nixbld = 350;
nix.nrBuildUsers = 32;
```

Change those example numbers to your actual first UID minus one, GID, and
user count. A mismatch can prevent nix-darwin activation.

## Installation mode

The guide chooses multi-user installation on macOS and on Linux/WSL2 with
running systemd. Without systemd, Linux/WSL2 defaults to upstream's
single-user mode, which creates no `nixbld` accounts. For WSL2, enable
systemd first if you want the multi-user daemon and its build-account
isolation; then restart the distro and rerun the guide. You can choose
`--mode multi` or `--mode single` explicitly. UID/GID options apply only to
multi-user mode.

The account check is a preflight, not a reservation. Another process could
claim an ID before the upstream installer creates its users. The guide checks
again immediately before handing off; upstream remains the final authority.
On Linux it uses keyed NSS lookups (including directory accounts supported by
`getent`). On macOS it enumerates accounts through `dscl /Search`.

## Other installation conflicts

- An existing Nix installation or partial `/nix` setup needs repair or
  uninstall instructions appropriate to the installer that created it.
- On macOS 15 Sequoia, an *existing* install with missing `_nixbld` users has
  an upstream migration procedure. A fresh install is not the repair path.
- Linux multi-user mode needs running systemd in this guide. The upstream
  shell installer can run without it, but daemon setup then needs manual init
  configuration.
- The upstream multi-user shell installer rejects enforcing SELinux. The newer
  [NixOS community installer](https://github.com/NixOS/nix-installer) supports
  SELinux and has a reviewable plan and installation receipt. It is currently
  marked beta and lists Apple Silicon, rather than Intel, macOS support; this
  guide uses the broadly supported upstream shell installer by default.
- The wrapper checks download and unpack prerequisites before starting the
  installer. Missing tools must be installed with the host package manager.

## Validation and recovery

After opening a new shell, run `nix --version`, then
`bash bootstrap/home.sh doctor`, `check`, and `switch` in that order. A
conflict from `check` means an existing path is owned outside Home Manager;
inspect it and move or unlink it deliberately. See the
[one-time Stow migration](../../README.md#fresh-host-setup) if you used this
repository before Home Manager became its sole configuration manager.
After switching, `nix flake metadata path:$PWD` should work without extra
feature flags because Home Manager links `~/.config/nix/nix.conf`.

Use `bash bootstrap/home.sh status` to list generations and
`bash bootstrap/home.sh rollback` to activate the previous one. Rollback works
from the installed Home Manager command even if the current flake no longer
builds. For a partially installed Nix daemon, follow the repair instructions
for the installer that created it; this repository will not overwrite `/nix`.
For this pinned shell installer, start with the [official Nix uninstall and
recovery guide](https://nix.dev/manual/nix/2.35/installation/uninstall.html)
and compare its default build-account examples with the IDs and user count you
actually selected. The separate NixOS community installer has its own receipt
and `repair` command.

For a disposable fresh user or VM, validate an actual install and switch, then
change one config, switch again, and roll back. Check a deliberate
`~/.config/nvim/init.lua`
collision before the first switch. On WSL2, test with and without systemd if
both modes matter to you; on macOS, test on the architecture you own. Also
verify Zsh Vim mode and Starship's mode indicator, Neovim/tmux pane navigation,
and clipboard copy/paste inside and outside tmux. Clipboard tests in CI use
mock providers; only the terminal you use can confirm its real clipboard
permissions and OSC 52 behavior.
Automated checks run on Linux, Apple Silicon macOS, and Intel macOS in
`.github/workflows/check.yml`; WSL2 installation remains a manual smoke test.

Run the bootstrap checks without activating your home:

```sh
bash tests/test_install_nix.sh
bash tests/test_home.sh
nix --extra-experimental-features 'nix-command flakes' flake check --no-update-lock-file "path:$PWD"
```

The Neovim navigation tests need the built plugin directory. CI supplies it
from the activation package before running
`python3 -m unittest discover -s tests -p test_config.py`. After `switch`, that
command works directly in a new shell.

The flake's `checks` output builds an activation package with a fixed test
identity. The actual `homeConfigurations` use your current `USER` and `HOME`
through `bootstrap/home.sh`. Keep `home.stateVersion` at its initial value
when updating Nixpkgs or Home Manager; changing it can alter migration defaults.

Nixpkgs 26.05 is the last supported release for Intel macOS, with maintenance
ending at the end of 2026. This repository keeps its 26.05 pin and tests Intel
macOS while supported. A future Nixpkgs branch upgrade must either retain a
separate 26.05 Intel pin or retire Intel Nix support explicitly.

Sources: [nix.dev installation guide](https://nix.dev/install-nix),
[Linux installer defaults](https://github.com/NixOS/nix/blob/master/scripts/install-systemd-multi-user.sh),
[macOS installer defaults and UID history](https://github.com/NixOS/nix/blob/master/scripts/install-darwin-multi-user.sh),
[upstream account and environment handling](https://github.com/NixOS/nix/blob/master/scripts/install-multi-user.sh),
[macOS Sequoia migration](https://github.com/NixOS/nix/issues/10892), and
[nix-darwin build-account configuration](https://github.com/nix-darwin/nix-darwin/blob/master/modules/nix/default.nix).
