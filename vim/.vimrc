" .vimrc — sensible defaults for stock Vim, no plugins
" Based on vim-sensible by Tim Pope

" Disable vi compatibility
set nocompatible
scriptencoding utf-8

" --- Editing behaviour ---
set backspace=indent,eol,start   " Backspace over everything in insert mode
set complete-=i                  " Don't scan included files for completion
set hidden                       " Allow modified buffers to be hidden
set smarttab                     " Tab key respects shiftwidth/tabstop/softtabstop
set shiftround                   " Round indent changes to shiftwidth
set nrformats-=octal             " Don't treat 007 as octal when incrementing

" --- Appearance ---
set number                       " Show line numbers
set laststatus=2                 " Always show the status line
set ruler                        " Show cursor position in status line
set showcmd                      " Show incomplete commands in the status area
set showmode                     " Show the current mode
set display+=lastline            " Show as much of a long last line as possible
set display+=truncate            " Show @@@ when last line is truncated (Vim 7.4.2109+)
set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
set splitbelow                   " New horizontal splits open below
set splitright                   " New vertical splits open to the right

if exists('+signcolumn')
  set signcolumn=yes             " Avoid layout shifts when signs appear
endif

if has('termguicolors')
  set termguicolors
endif

" --- Search ---
set hlsearch                     " Highlight search matches
set ignorecase                   " Case-insensitive search by default
set incsearch                    " Highlight matches as you type
set smartcase                    " Case-sensitive search when pattern has capitals

" Clear search highlight and run :diffupdate with <C-L>
nnoremap <silent> <C-L> :nohlsearch<C-R>=has('diff')?'<Bar>diffupdate':''<CR><CR><C-L>

" --- Scrolling ---
set scrolloff=1                  " Keep 1 line visible above/below cursor
set sidescroll=1                 " Scroll horizontally one column at a time
set sidescrolloff=2              " Keep 2 columns visible left/right of cursor

" --- Responsiveness ---
set timeout
set timeoutlen=500               " Keep mapped sequences responsive
set ttimeout
set ttimeoutlen=50               " Faster escape sequence detection (e.g. arrow keys)
set updatetime=500               " Faster swap writes and CursorHold events

" --- History and sessions ---
set history=1000                 " Remember more command history
set tabpagemax=50                " Allow more tabs via -p flag or :tab all
set autoread                     " Reload files changed outside Vim
set viminfo^=!                   " Persist g:UPPERCASE plugin vars in .viminfo
set sessionoptions-=options      " Don't save options in sessions
set viewoptions-=options         " Don't save options in views

" --- State and recovery ---
function! s:EnsureDirectory(path, mode) abort
  if isdirectory(a:path)
    return 1
  endif

  try
    call mkdir(a:path, 'p', a:mode)
  catch
    echohl WarningMsg
    echomsg 'vimrc: failed to create state directory ' . string(a:path) . ': ' . v:exception
    echohl None
    return 0
  endtry

  if !isdirectory(a:path)
    echohl WarningMsg
    echomsg 'vimrc: state directory is unavailable: ' . string(a:path)
    echohl None
    return 0
  endif

  return 1
endfunction

let s:vim_state_dir = expand('~/.vim')
if s:EnsureDirectory(s:vim_state_dir . '/swap', 0700)
  let &directory = s:vim_state_dir . '/swap//,' . &directory
endif

if s:EnsureDirectory(s:vim_state_dir . '/backup', 0700)
  let &backupdir = s:vim_state_dir . '/backup//,' . &backupdir
  set writebackup
endif

if has('persistent_undo') && s:EnsureDirectory(s:vim_state_dir . '/undo', 0700)
  let &undodir = s:vim_state_dir . '/undo//,' . &undodir
  set undofile
endif

if s:EnsureDirectory(s:vim_state_dir . '/view', 0700)
  let &viewdir = s:vim_state_dir . '/view'
endif
unlet s:vim_state_dir

" --- Command-line completion ---
set wildmenu
set wildmode=longest:full,full
set wildignore+=*.o,*.obj,*.pyc,*.class,*.swp
set wildignore+=.git,.hg,.svn
set wildignore+=node_modules,target,dist,build

" --- Formatting ---
set formatoptions+=j             " Remove comment leader when joining lines (Vim 7.3.541+)

" --- Project search ---
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case
  set grepformat=%f:%l:%c:%m
endif

" --- Tag search ---
" Search ancestor directories for tags file, not just parent
if has('path_extra') && (',' . &g:tags . ',') =~# ',\./tags,'
  setglobal tags-=./tags tags-=./tags; tags^=./tags;
endif

" --- Terminal colours ---
if &t_Co == 8 && $TERM !~# '^Eterm'
  set t_Co=16                    " Let colour schemes use bright colours without bold
endif

" --- Shell compatibility ---
if &shell =~# 'fish$' && (v:version < 704 || v:version == 704 && !has('patch276'))
  set shell=/usr/bin/env\ bash   " Fall back to bash if Vim doesn't support fish
endif

" Disable legacy langmap behaviour that can break mappings
if has('langmap') && exists('+langremap') && &langremap
  set nolangremap
endif

" --- Filetype and syntax ---
filetype plugin indent on
if has('syntax') && !exists('g:syntax_on')
  syntax enable
endif

" --- Insert-mode undo breakpoints ---
" <C-U> and <C-W> create an undo point before deleting, so you can undo just
" the deletion rather than the entire insert session.
inoremap <C-U> <C-G>u<C-U>
inoremap <C-W> <C-G>u<C-W>

" --- Diff helper ---
if exists(":DiffOrig") != 2
  command DiffOrig vertical new | setlocal buftype=nofile bufhidden=wipe noswapfile | read ++edit # | 0delete _
        \ | diffthis | wincmd p | diffthis
endif

" --- Shell syntax ---
" Treat sh filetype as POSIX by default (enables $() highlighting, etc.)
if !exists('g:is_posix') && !exists('g:is_bash') && !exists('g:is_kornshell') && !exists('g:is_dash')
  let g:is_posix = 1
endif

" --- Built-in extras (no plugins needed) ---
" Load matchit.vim (extends % to match if/else/end etc.) — ships with Vim
if !exists('g:loaded_matchit')
  runtime! macros/matchit.vim
endif

" Enable :Man command (ships with Vim's man filetype plugin)
if exists(':Man') != 2 && !exists('g:loaded_man') && &filetype !=? 'man'
  runtime ftplugin/man.vim
endif
