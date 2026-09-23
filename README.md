# system

Vim-style shell and Neovim configuration for macOS and Linux, including WSL2.
The pinned Nix flake installs the tools, language servers, syntax parsers, and
Zsh/Neovim plugins with Home Manager.
Home Manager also installs every dotfile; the files in this repository are
their sources. `flake.lock` pins most tool and plugin versions; mise 2026.9.12
is pinned by release checksum in `nix/home.nix`.

The [keyboard shortcut guide](docs/keybindings.md) explains Neovim, tmux, and
Zsh navigation in one place. The [CLI tools guide](docs/tools/README.md)
covers project tasks, the shell utilities, and local command history.

## Managed configuration

- `zsh`: shell configuration, PATH setup, and pinned plugins.
- `starship`: prompt configuration.
- `tmux`: terminal multiplexer configuration and sesh session picker.
- `nvim`: Neovim configuration; `vi` and `vim` invoke Neovim.
- `mise.toml`: project commands (`mise tasks ls` lists them).

## Fresh-host setup

Install Git and the [installer prerequisites](docs/nix/README.md#prerequisites)
with your host package manager, then clone this repository and run these
commands from its root as your normal user. On a new WSL2 distro, first choose
the [default user and systemd mode](docs/nix/README.md#wsl2-first-run).
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

Once Home Manager is active, review `mise.toml` and run `mise trust mise.toml`
once per checkout. Then use `mise run doctor`, `mise run check`, and
`mise run switch` as shorter project commands. `mise run test` and
`mise run lint` cover the repo checks.

Check `nix flake metadata path:$PWD` in the new shell; Home Manager enables
flakes for ordinary Nix commands. Neovim yanks and puts use the host clipboard
when its native copy and paste tools are available. In tmux, copy mode also
copies to the host through `~/.local/bin/clipboard-copy` or OSC 52. See the
[clipboard notes](docs/neovim/README.md#clipboard) for platform details.

Git identity and authentication are host-specific. Before your first commit,
set `git config --global user.name "Your Name"` and
`git config --global user.email "you@example.com"` if they are not already set.
Run `gh auth login` if you use GitHub CLI. Keep credentials out of this repo.

`doctor` reports the selected user, home, platform, Nix version, and missing or
broken files from the active Home Manager generation without downloading
anything. `check` builds the pinned configuration and previews managed-file
conflicts without changing your home. Existing
unmanaged files must be moved even when their contents match, so Home Manager
can own their paths. `switch` activates through the pinned Home Manager
command. It leaves conflicting
unmanaged files alone and tells you which paths to inspect. To see or restore
Home Manager generations, run `bash bootstrap/home.sh status` or
`bash bootstrap/home.sh rollback`. A rollback needs a previous generation.

If you used this repository's former Stow setup, run
`stow -D --target="$HOME" --no-folding zsh starship tmux` once before
switching. Unlink the old `~/.vimrc` if it points to this repository's retired
`vim/.vimrc`. The `check` command identifies links still owned by another
source.
The former plugin helper may leave a broken `~/.local/bin/zsh-plugin-sync`
symlink; remove it if it points into this repository.
Nix-managed dotfiles are copied into the Nix store, so edit the repository and
run `switch` again to apply changes. Changing your login shell is a separate
host setting. The wrapper uses `--impure` only for the current username and
home path; packages and plugins come from the committed `flake.lock` and the
mise release hashes in `nix/home.nix`.

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
