-- Vim-style editing with a small, Nix-pinned Neovim plugin set.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local opt = vim.opt
opt.number = true
opt.signcolumn = 'yes'
opt.termguicolors = true
opt.splitbelow = true
opt.splitright = true
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.scrolloff = 3
opt.sidescrolloff = 2
opt.timeoutlen = 500
opt.updatetime = 500
opt.history = 1000
opt.autoread = true
opt.smarttab = true
opt.shiftround = true
opt.nrformats:remove('octal')
opt.listchars = { tab = '> ', trail = '-', extends = '>', precedes = '<', nbsp = '+' }
opt.wildmode = { 'longest:full', 'full' }
opt.wildignore:append({ '*.o', '*.obj', '*.pyc', '*.class', '*.swp', 'node_modules', 'target', 'dist', 'build' })
opt.sessionoptions:remove('options')
opt.viewoptions:remove('options')
opt.formatoptions:append('j')

-- Keep undo history between sessions using Neovim's XDG state directory.
local undo_dir = vim.fn.stdpath('state') .. '/undo'
if vim.fn.isdirectory(undo_dir) == 0 then
  vim.fn.mkdir(undo_dir, 'p', 448) -- 0700
end
if vim.fn.isdirectory(undo_dir) == 0 then
  error('Neovim could not create its undo directory: ' .. undo_dir)
end
opt.undodir = undo_dir
opt.undofile = true

if vim.fn.executable('rg') == 1 then
  opt.grepprg = 'rg --vimgrep --smart-case'
  opt.grepformat = '%f:%l:%c:%m'
end

local map = vim.keymap.set
map('n', '<leader>h', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlighting' })
map('i', '<C-u>', '<C-g>u<C-u>', { desc = 'Delete to start of line with undo break' })
map('i', '<C-w>', '<C-g>u<C-w>', { desc = 'Delete word with undo break' })

local tmux_directions = { h = 'L', j = 'D', k = 'U', l = 'R', p = 'l' }
local direction_names = { h = 'left', j = 'down', k = 'up', l = 'right' }
local function navigate_window(direction)
  local before = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(direction)
  if vim.api.nvim_get_current_win() ~= before
    or not vim.env.TMUX
    or vim.env.TMUX == ''
    or vim.fn.executable('tmux') == 0 then
    return
  end
  vim.fn.system({ 'tmux', 'select-pane', '-' .. tmux_directions[direction] })
  if vim.v.shell_error ~= 0 then
    vim.notify('tmux pane navigation failed', vim.log.levels.WARN)
  end
end

for _, direction in ipairs({ 'h', 'j', 'k', 'l' }) do
  map('n', '<C-' .. direction .. '>', function() navigate_window(direction) end,
    { desc = 'Move ' .. direction_names[direction] .. ' across splits and tmux panes' })
end
map('n', [[<C-\>]], function() navigate_window('p') end, { desc = 'Previous split or tmux pane' })
map('n', '<leader>v', '<cmd>vsplit<cr>', { desc = 'Vertical split' })
map('n', '<leader>s', '<cmd>split<cr>', { desc = 'Horizontal split' })
map('n', '<leader>w', '<cmd>write<cr>', { desc = 'Write buffer' })
map('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit window' })
map('n', '[b', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
map('n', ']b', '<cmd>bnext<cr>', { desc = 'Next buffer' })

vim.api.nvim_create_user_command('DiffOrig', function()
  vim.cmd('vertical new')
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'wipe'
  vim.bo.swapfile = false
  vim.cmd('read ++edit #')
  vim.cmd('0delete _')
  vim.cmd.diffthis()
  vim.cmd.wincmd('p')
  vim.cmd.diffthis()
end, { desc = 'Compare current buffer with its saved file' })

-- All plugins below are supplied by Home Manager from the pinned flake.
local fzf = require('fzf-lua')
fzf.setup({})
map('n', '<leader>ff', fzf.files, { desc = 'Find files' })
map('n', '<leader>fg', fzf.live_grep, { desc = 'Search project text' })
map('n', '<leader>fb', fzf.buffers, { desc = 'Find buffers' })
map('n', '<leader>fr', fzf.oldfiles, { desc = 'Recent files' })
map('n', '<leader>fh', fzf.helptags, { desc = 'Find help' })
map('n', '<leader>fk', fzf.keymaps, { desc = 'Find keybindings' })

local gitsigns = require('gitsigns')
gitsigns.setup({
  on_attach = function(bufnr)
    local opts = { buffer = bufnr }
    map('n', ']h', function() gitsigns.nav_hunk('next') end,
      vim.tbl_extend('force', opts, { desc = 'Next Git change' }))
    map('n', '[h', function() gitsigns.nav_hunk('prev') end,
      vim.tbl_extend('force', opts, { desc = 'Previous Git change' }))
    map('n', '<leader>gh', gitsigns.preview_hunk,
      vim.tbl_extend('force', opts, { desc = 'Preview Git change' }))
    map('n', '<leader>gb', gitsigns.blame_line,
      vim.tbl_extend('force', opts, { desc = 'Blame current line' }))
  end,
})

require('mini.comment').setup()
require('mini.pairs').setup()
require('mini.completion').setup()
require('mini.surround').setup({
  mappings = {
    add = 'ys',
    delete = 'ds',
    replace = 'cs',
    find = '',
    find_left = '',
    highlight = '',
  },
})

-- Language servers are installed into Neovim's PATH by Home Manager.
vim.lsp.config('lua_ls', { settings = { Lua = { diagnostics = { globals = { 'vim' } } } } })
for _, server in ipairs({ 'bashls', 'lua_ls', 'nixd', 'pyright' }) do
  vim.lsp.enable(server)
end
map('n', '<leader>ca', vim.lsp.buf.code_action, { desc = 'Code action' })
map('n', '<leader>cr', vim.lsp.buf.rename, { desc = 'Rename symbol' })
map('n', '<leader>cf', function() vim.lsp.buf.format({ async = true }) end, { desc = 'Format buffer' })
map('n', '<leader>cd', vim.diagnostic.open_float, { desc = 'Show diagnostics' })

-- Nix provides matching parsers. Other filetypes retain normal syntax highlighting.
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'sh', 'bash', 'json', 'lua', 'markdown', 'nix', 'python', 'toml', 'vim', 'vimdoc', 'yaml' },
  callback = function(args)
    local ok, err = pcall(vim.treesitter.start, args.buf)
    if not ok then
      vim.notify('Tree-sitter could not start for ' .. args.match .. ': ' .. tostring(err), vim.log.levels.WARN)
    end
  end,
})

local clue = require('mini.clue')
clue.setup({
  triggers = {
    { mode = { 'n', 'x' }, keys = '<Leader>' },
    { mode = 'n', keys = '[' },
    { mode = 'n', keys = ']' },
    { mode = { 'n', 'x' }, keys = 'g' },
    { mode = 'n', keys = '<C-w>' },
  },
  clues = {
    { mode = 'n', keys = '<Leader>f', desc = '+Find' },
    { mode = 'n', keys = '<Leader>g', desc = '+Git' },
    { mode = 'n', keys = '<Leader>c', desc = '+Code' },
    clue.gen_clues.square_brackets(),
    clue.gen_clues.g(),
    clue.gen_clues.windows(),
  },
})
