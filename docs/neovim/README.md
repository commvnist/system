# Neovim

Home Manager installs Neovim, links the generated configuration to
`~/.config/nvim/init.lua`, and supplies all plugins from the pinned Nixpkgs
flake input. Run `bash bootstrap/home.sh switch` from the repository root after
editing `nvim/init.lua` or `nix/home.nix`. `vi` and `vim` invoke Neovim; both
`EDITOR` and `VISUAL` are `nvim`. No plugin manager downloads code at editor
startup. To update plugins, review and update the Nix lock file with
`bash bootstrap/update.sh nixpkgs`, then build and switch.

The maintained plugin set is [fzf-lua](https://github.com/ibhagwan/fzf-lua)
for file and text search, [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)
for Git changes, [mini.nvim](https://github.com/nvim-mini/mini.nvim) for
completion, comments, surrounding text, pairs, and key hints, and
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) for built-in LSP
server defaults. [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
supplies a small set of parsers. Nix also installs `fd`, `fzf`, `rg`, and the
Bash, Lua, Nix, and Python language servers. A language server starts only
when its filetype and project root match. Other languages continue to work
with native Neovim editing and highlighting.

`Space` is the leader key. Press it and wait briefly to see available keys;
`Space f k` searches all keybindings. The existing split keys and tmux crossing
are preserved. See the [shortcut guide](../keybindings.md) for editing, search,
Git, and LSP keys. Persistent undo lives under Neovim's XDG state directory.

For a standalone Neovim configuration outside Nix, [lazy.nvim](https://github.com/folke/lazy.nvim)
is a well-supported plugin manager. This repository uses Home Manager as its
plugin manager so the editor and all external tools share one lock file.
Neovim's built-in `vim.pack` is still marked experimental in its
[documentation](https://neovim.io/doc/user/pack/).

To inspect plugin and LSP health, use `:checkhealth`, `:checkhealth vim.lsp`,
and `:set runtimepath?`. If a plugin update breaks startup, run
`bash bootstrap/home.sh rollback` to activate the previous generation.
