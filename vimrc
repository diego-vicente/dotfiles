" Author: Diego Vicente Martin (diegovicente@protonmail.com - diegovicen.me)
" Description: My own vimrc, built from ground up.

" VIM MUST HAVE FEATURES
" Make it work without funny stuff everywhere
set nocompatible
" Determine the type of a file with its title and contents + autoindent
filetype indent plugin on
" Syntax highlighting
syntax on
" Allows to use history and multiple tabs, and swap files
set hidden
" Better command-line completion
set wildmenu
" Show partial commands in the last line of the screen
set showcmd
" utf8 should be useful someday
set encoding=utf-8
" Use the system clipboard
" set clipboard=unnamed

" USABILITY
" Ignores cases when searching except when using caps
set ignorecase
set smartcase
" Allow backspacing over autoindent, line breaks and start of insert action
set backspace=indent,eol,start
" If there is no filetype indent specific, keep the same indent
set autoindent
" It doesn't always go to the start of the line when moving (more natural)
set nostartofline
" Displays the cursor in the status line
set ruler
set laststatus=2
" Instead of exploding, ask for save changes when executing a command
set confirm
" No more beep.
set visualbell
set t_vb=
" Enable mouse
set mouse=a
" It's better to have a quite larger command window
set cmdheight=2
" Time out on keycodes, not on mappings (not sure why but it's recommended)
set notimeout ttimeout ttimeoutlen=200
" zsh FTW, however...
set shell=/bin/bash
" Show invisible characters (tabs and trailing spaces)
exec "set listchars=tab:\uBB\uBB,trail:\uB7,nbsp:~"
    set list

" TAB & SPLIT NAVIGATION
" map [1;5D <C-Left>
" map [1;5C <C-Right>
" nnoremap <C-Left>       :tabprevious<CR>
" nnoremap <C-Right>      :tabnext<CR>
" nnoremap <C-t>          :tabnew<CR>
" inoremap <C-Left>       <Esc>:tabprevious<CR>i
" inoremap <C-Right>      <Esc>:tabnext<CR>i
" inoremap <C-t>          <Esc>:tabnew<CR>
" map <C-w>               :tabclose<CR>]]

" Don't really know why this is not the default behaviour
set splitbelow
set splitright

" More intuitive navigation accross the splits, ctrl+h/j/k/l
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" SEARCH NAVIGATION
" This method is taken form Damien Conway's @ More Instantly Better Vim (2013)
" It enables search highlighting and hides everything but the current result
" for a brief second
set hlsearch

nnoremap <silent> n n:call HLNext(0.4)<cr>
nnoremap <silent> N N:call HLNext(0.4)<cr>

function! HLNext (blinktime)
    highlight WhiteOnMagenta ctermfg=white ctermbg=magenta
    let [bufnum, lnum, col, off] = getpos('.')
    let matchlen = strlen(matchstr(strpart(getline('.'),col-1),@/))
    let target_pat = '\c\%#'.@/
    let ring = matchadd('WhiteOnMagenta', target_pat, 101)
    redraw
    exec 'sleep ' . float2nr(a:blinktime * 1000) . 'm'
    call matchdelete(ring)
    redraw
endfunction

"This unsets the last search pattern by with :C
:command C let @/=""

" IDENTATION & WRAPPING
" Soft tabs of 4 spaces ALWAYS.
set shiftwidth=4
set softtabstop=4
set expandtab
" In some cases like LaTeX files I want to be automatically wrapped
function! SetHardWrap()
    setlocal textwidth=79
endfunction
" Call it in these filetypes:
autocmd Filetype tex call SetHardWrap()

" Automatically show a different color for the cursor line until 80 chars
set cursorline
hi CursorLine cterm=NONE ctermbg=238
let &colorcolumn=join(range(80,999),",")
highlight ColorColumn ctermbg=black

" LINE NUMBERS
" I want to have relative numbers to move and absolute numbers to tests and
" compilers, so I decided that the best thing was to enable a shortcut to
" toggle one or another
set number
set relativenumber
function! NumberToggle()
    set relativenumber!
endfunc

" I don't use ctrl+n to autocomplete anyway, so...
noremap <C-n> :call NumberToggle()<cr>

" MAPPINGS
" Make y work like a normal keystroke (y$ for copy until eol)
map Y y$

" I honestly don't know what ; does, so let's put : in there.
nnoremap ; :

" PLUGINS
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#rc()
" call vundle#begin()
" required, Vundle has to manage itself
Plugin 'gmarik/Vundle.vim'

" Git wrapper for vim
Bundle 'tpope/vim-fugitive'

" Airline is a Powerline status bar derivative
Plugin 'vim-airline/vim-airline' " {'rtp': 'airline/bindings/vim/'}'}
Plugin 'vim-airline/vim-airline-themes'
let g:airline_theme='base16_eighties'
let g:airline_powerline_fonts=1
set t_Co=256
" Bundle 'Nextil/vim-airline', 'eighties-theme'
" let g:Powerline_symbols = 'unicode'

" Snippets are separated from the engine. Add this if you want them:
Bundle 'ervandew/supertab'
Bundle 'Valloric/YouCompleteMe'
Bundle 'honza/vim-snippets'
Bundle 'SirVer/ultisnips'

" make YCM compatible with UltiSnips (using supertab)
let g:ycm_key_list_select_completion = ['<C-n>', '<Down>']
let g:ycm_key_list_previous_completion = ['<C-p>', '<Up>']
let g:SuperTabDefaultCompletionType = '<C-n>'

" better key bindings for UltiSnipsExpandTrigger
let g:UltiSnipsExpandTrigger = "<tab>"
let g:UltiSnipsJumpForwardTrigger = "<tab>"
let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

" I don't really need ID completions most of the time, so...
let g:ycm_min_num_of_chars_for_completion = 99

" The NERDcommenter allows us to comment lines quickly
Plugin 'scrooloose/nerdcommenter'

" Markdown + text alignment
Plugin 'godlygeek/tabular'
Plugin 'plasticboy/vim-markdown'
" I don't really know how to use fold in markdown
let g:vim_markdown_folding_disabled = 1

" Base16 color schemes are love
Plugin 'chriskempson/base16-vim'
let base16colorspace=256  " Access colors present in 256 colorspace

" Damien Conway developed this kickass plugin
Plugin 'shinokada/dragvisuals.vim'
runtime plugin/dragvisuals.vim

vmap   <expr> <LEFT>   DVB_Drag('left')
vmap   <expr> <RIGHT>  DVB_Drag('right')
vmap   <expr> <DOWN>   DVB_Drag('down')
vmap   <expr> <UP>     DVB_Drag('up')
vmap   <expr> D        DVB_Duplicate()

" Remove any introduced trailing whitespace after moving...
let g:DVB_TrimWS = 1

" NERDtree is a project tree for vim
Plugin 'scrooloose/nerdtree'
Plugin 'Xuyuanp/nerdtree-git-plugin'

let g:NERDTreeIndicatorMapCustom = {
    \ "Modified"  : "✹",
    \ "Staged"    : "✚",
    \ "Untracked" : "✭",
    \ "Renamed"   : "➜",
    \ "Unmerged"  : "═",
    \ "Deleted"   : "✗",
    \ "Dirty"     : "✖",
    \ "Clean"     : "✔︎",
    \ "Unknown"   : "?"
    \ }

" Autoclose parenthesis and other characters. Plus, no more cyan in
" matching parenthesis, please
Plugin 'Raimondi/delimitMate'
let delimitMate_expand_cr = 1
hi MatchParen cterm=none ctermbg=darkgrey

" No room for the weak.
Plugin 'kbarrette/mediummode'
