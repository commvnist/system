# CLI tools

Home Manager installs these tools from the pinned `flake.lock`. It also links
Atuin's local-only settings and the nix-direnv helper. After a switch, open a
new Zsh session to load the Atuin and direnv hooks.

| Use | Commands |
| --- | --- |
| Find and navigate | `fd`, `rg`, `fzf`, `zoxide` (`z`, `zi`), `eza` |
| Read and transform | `bat`, `jq`, `yq`, `tldr` (tealdeer) |
| Git and GitHub | `git`, `delta`, `difft`, `gh`, `lazygit` |
| Inspect and measure | `dust`, `btm` (bottom), `hyperfine`, `watchexec` |
| Shell interaction | `atuin`, `gum`, `starship`, `tmux`, `sesh` |
| Projects and environments | `mise`, `direnv`, `nix-direnv` |
| Repo checks | `shellcheck`, `shfmt`, `actionlint`, `python3` |

## Project commands

Review `mise.toml` and run `mise trust mise.toml` once per checkout. Then run
`mise tasks ls` to see the commands in that file. The
common flow is `mise run doctor`, `mise run check`, then `mise run switch`.
Use `mise run test` and `mise run lint` after activation. Mise runs tasks
without a Zsh hook; project tool versions can be added to individual
`mise.toml` files when needed. `mise exec -- command` runs a project command
with its selected tools without changing the interactive shell.

## Terminal sessions

Use `sesh connect .` from a project directory to create or attach to its tmux
session. Inside tmux, press `Ctrl-a p` to find another session or a directory
you have visited with zoxide. Each session can contain several windows and
panes; sesh does not require Git worktrees. See the
[tmux guide](../tmux/README.md) for the session keys.

## Environment loading

Direnv is hooked into Zsh. For a project with a Nix dev shell, place
`use flake` in that project's `.envrc`, then run `direnv allow` after
reviewing the file. nix-direnv caches the dev shell. Projects without an
`.envrc` do not trigger a Nix evaluation. Keep mise task and tool definitions
in `mise.toml`; do not enable the old direnv `use mise` integration.

## History

Atuin records new commands locally. To bring in prior Zsh history once, run
`atuin import zsh` after switching. `Ctrl-r` and Up Arrow search history in
insert or command mode. Atuin does not sync without a separate account setup;
this configuration also disables automatic sync and update checks. The
existing `~/.zsh_history` stays available for Zsh's native history commands.
