" .vimrc — sensible defaults for stock Vim, no plugins
" Based on vim-sensible by Tim Pope

" Disable vi compatibility
set nocompatible

" --- Editing behaviour ---
set backspace=indent,eol,start   " Backspace over everything in insert mode
set complete-=i                  " Don't scan included files for completion
set smarttab                     " Tab key respects shiftwidth/tabstop/softtabstop
set nrformats-=octal             " Don't treat 007 as octal when incrementing

" --- Appearance ---
set number                       " Show line numbers
set laststatus=2                 " Always show the status line
set ruler                        " Show cursor position in status line
set display+=lastline            " Show as much of a long last line as possible
set display+=truncate            " Show @@@ when last line is truncated (Vim 7.4.2109+)
set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+

" --- Search ---
set incsearch                    " Highlight matches as you type

" Clear search highlight and run :diffupdate with <C-L>
nnoremap <silent> <C-L> :nohlsearch<C-R>=has('diff')?'<Bar>diffupdate':''<CR><CR><C-L>

" --- Scrolling ---
set scrolloff=1                  " Keep 1 line visible above/below cursor
set sidescroll=1                 " Scroll horizontally one column at a time
set sidescrolloff=2              " Keep 2 columns visible left/right of cursor

" --- Responsiveness ---
set ttimeout
set ttimeoutlen=100              " Faster escape sequence detection (e.g. arrow keys)

" --- History and sessions ---
set history=1000                 " Remember more command history
set tabpagemax=50                " Allow more tabs via -p flag or :tab all
set autoread                     " Reload files changed outside Vim
set viminfo^=!                   " Persist g:UPPERCASE plugin vars in .viminfo
set sessionoptions-=options      " Don't save options in sessions
set viewoptions-=options         " Don't save options in views

" --- Formatting ---
set formatoptions+=j             " Remove comment leader when joining lines (Vim 7.3.541+)

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
  command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_
        \ | diffthis | wincmd p | diffthis
endif

" --- Shell syntax ---
" Treat sh filetype as POSIX by default (enables $() highlighting, etc.)
if !exists('g:is_posix') && !exists('g:is_bash') && !exists('g:is_kornshell') && !exists('g:is_dash')
  let g:is_posix = 1
endif

" --- Built-in extras (no plugins needed) ---
" Load matchit.vim (extends % to match if/else/end etc.) — ships with Vim
if !exists('g:loaded_matchit') && findfile('plugin/matchit.vim', &rtp) ==# ''
  runtime! macros/matchit.vim
endif

" Enable :Man command (ships with Vim's man filetype plugin)
if exists(':Man') != 2 && !exists('g:loaded_man') && &filetype !=? 'man'
  runtime ftplugin/man.vim
endif
