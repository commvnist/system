# system

Vim-first shell and editor configuration for macOS and Linux, including WSL2.
The pinned Nix flake installs the tools and Zsh plugins with Home Manager.
Home Manager also installs every dotfile; the files in this repository are
their sources, and `flake.lock` pins the tool and plugin versions.

The [keyboard shortcut guide](docs/keybindings.md) explains Vim, tmux, and
Zsh navigation in one place.

## Managed configuration

- `zsh`: shell configuration and pinned plugins.
- `starship`: prompt configuration.
- `tmux`: terminal multiplexer configuration.
- `vim`: editor configuration.

## Fresh-host setup

Clone this repository and run these commands from its root as your normal user.
If Nix is already installed, skip the first two commands. The [guided installer](bootstrap/install-nix.sh)
prints its plan and checks build-account IDs before it changes the host; see
the [installation notes](docs/nix/README.md) for macOS and WSL2 details.

```sh
bash bootstrap/install-nix.sh --dry-run
bash bootstrap/install-nix.sh
# Open a new shell after Nix installation.
bash bootstrap/home.sh doctor
bash bootstrap/home.sh check
bash bootstrap/home.sh switch
```

`doctor` reports the selected user, home, platform, Nix version, and broken
links without downloading anything. `check` builds the pinned configuration
and previews managed-file conflicts without changing your home. `switch`
activates through the pinned Home Manager command. It leaves conflicting
unmanaged files alone and tells you which paths to inspect. To see or restore
Home Manager generations, run `bash bootstrap/home.sh status` or
`bash bootstrap/home.sh rollback`. A rollback needs a previous generation.

If you used this repository's former Stow setup, run
`stow -D --target="$HOME" --no-folding zsh starship tmux vim` once before
switching. The `check` command identifies any links still owned by another
source.
The former plugin helper may leave a broken `~/.local/bin/zsh-plugin-sync`
symlink; remove it if it points into this repository.
Nix-managed dotfiles are copied into the Nix store, so edit the repository and
run `switch` again to apply changes. Changing your login shell is a separate
host setting. The wrapper uses `--impure` only for the current username and
home path; packages and plugins come from the committed `flake.lock`.

The pinned 26.05 package set evaluates on Intel macOS, but [Nixpkgs warns](https://nixos.org/manual/nixpkgs/unstable/release-notes#x86_64-darwin-26.05)
that 26.05 is its last release supporting `x86_64-darwin`. Keep that constraint
in mind when updating the lock file on an Intel Mac.

## Updating and verification

`bash bootstrap/update.sh [input ...]` updates selected flake inputs (or all
inputs when none are named), builds the native Home Manager check, and
evaluates all supported systems. Review changes to `flake.lock` before running
`switch`. The update command does not activate your home. The [validation guide](docs/nix/README.md#validation-and-recovery)
covers tests, first-host smoke checks, and rollback.

Package notes are indexed in [docs/README.md](docs/README.md).
