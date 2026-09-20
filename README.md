# system

Vim-first shell and editor configuration for macOS and Linux, including WSL2.
The pinned Nix flake installs the tools and Zsh plugins with Home Manager.
GNU Stow provides a config-only fallback when Nix is unavailable.

The [keyboard shortcut guide](docs/keybindings.md) explains Vim, tmux, and
Zsh navigation in one place.

## Packages

- `zsh`: shell configuration and optional plugin sync helper.
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

If you previously linked these packages with Stow, unlink them with
`stow -D --target="$HOME" --no-folding zsh starship tmux vim` before switching.
Nix-managed dotfiles are copied into the Nix store, so edit the repository and
run `switch` again to apply changes. Changing your login shell is a separate
host setting. The wrapper uses `--impure` only for the current username and
home path; packages and plugins come from the committed `flake.lock`.

The pinned 26.05 package set evaluates on Intel macOS, but [Nixpkgs warns](https://nixos.org/manual/nixpkgs/unstable/release-notes#x86_64-darwin-26.05)
that 26.05 is its last release supporting `x86_64-darwin`. Keep that constraint
in mind when updating the lock file on an Intel Mac.

## Stow fallback

Install Git, GNU Stow, zsh, Starship, tmux, and Vim with your platform's package
manager. `fzf` is optional; the Zsh configuration uses it when available.

From the repository root, preview and then stow the packages you want:

```sh
stow -n -v --target="$HOME" --no-folding zsh starship tmux vim
stow --target="$HOME" --no-folding zsh starship tmux vim
```

The Zsh package includes a plugin sync helper pinned to the revisions in
`flake.lock`. Run `./zsh/.local/bin/zsh-plugin-sync` after linking. Stow links
the configuration but does not pin the platform packages themselves. Changes
to the linked files take effect without a Nix switch. See the [Zsh notes](docs/zsh/README.md).

## Updating and verification

`bash bootstrap/update.sh [input ...]` updates selected flake inputs (or all
inputs when none are named), regenerates the Stow plugin pins, builds the native
Home Manager check, and evaluates all supported systems. Review the changes to
`flake.lock` and the helper before running `switch`. The update command does
not activate your home and needs Python 3. The [validation guide](docs/nix/README.md#validation-and-recovery)
covers tests, first-host smoke checks, and rollback.

Package notes are indexed in [docs/README.md](docs/README.md).
