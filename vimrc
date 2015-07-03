"-------------------------------------------------
" Vundle
set nocompatible
filetype off " set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

" List installed plugins here
Plugin 'altercation/vim-colors-solarized'
Plugin 'scrooloose/syntastic'
Plugin 'ervandew/supertab'
Plugin 'tomtom/tcomment_vim'
Plugin 'tpope/vim-fugitive'
Plugin 'bling/vim-airline'
Plugin 'sudar/vim-arduino-syntax'
Plugin 'jmcantrell/vim-virtualenv'
Plugin 'gregsexton/MatchTag'

" Required closing lines
call vundle#end()
filetype plugin indent on

"-------------------------------------------------
" Usability & Appearance Options

syntax enable
set background=light
let g:solarized_termcolors=16
let g:solarized_termtrans = 1 " Set to 0 for urxvt
colorscheme solarized
call togglebg#map("<F5>")

" Turn on line numbering (turn off with "set nonu")
set nu

" Wrap lines and navigate accordingly
set wrap
set linebreak
set showbreak=>\ 
imap <silent> <Down> <C-o>gj
imap <silent> <Up> <C-o>gk
nmap <silent> <Down> gj
nmap <silent> <Up> gk
nmap k gk
nmap j gj

" Use case insensitive search, except when using capital letters
set ignorecase
set smartcase

" Highlight searches
set hlsearch
set incsearch

" Fast editing of the .vimrc
map <leader>e :e! ~/.vimrc<cr>

" When vimrc is edited, reload it
autocmd! bufwritepost vimrc source ~/.vimrc

" Splits
set splitbelow
set splitright

"" Mapping making splits
nnoremap <leader>w <C-w>v<C-w>l
nnoremap <leader>W <C-w>s<C-w>j

"" Mapping split movement
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Buffers
set hidden
" When closing buffer, try not to close a split
nmap ,d :b#<bar>bd#<CR>
" Mappings to access buffers (don't use "\p" because a
" delay before pressing "p" would accidentally paste).
" \l       : list buffers
" \b \f \g : go back/forward/last-used
" \1 \2 \3 : go to buffer 1/2/3 etc
nnoremap <Leader>l :ls<CR>
nnoremap <Leader>b :bp<CR>
nnoremap <Leader>f :bn<CR>
nnoremap <Leader>g :e#<CR>
nnoremap <Leader>1 :1b<CR>
nnoremap <Leader>2 :2b<CR>
nnoremap <Leader>3 :3b<CR>
nnoremap <Leader>4 :4b<CR>
nnoremap <Leader>5 :5b<CR>
nnoremap <Leader>6 :6b<CR>
nnoremap <Leader>7 :7b<CR>
nnoremap <Leader>8 :8b<CR>
nnoremap <Leader>9 :9b<CR>
nnoremap <Leader>0 :10b<CR>

"-------------------------------------------------
" Indentation Options
set smarttab
set autoindent 
set si "Smart indent
set shiftwidth=2
set softtabstop=2
set expandtab
set pastetoggle=<F12>
set backspace=indent,eol,start

"-------------------------------------------------
" Mapping

" Map Ctrl-C to copy to clipboard
map <C-c> "+y<CR> 
cmap w!! w !sudo tee %
iabbrev </ </<C-X><C-O>

"-------------------------------------------------
"Plugin Settings

"Zen Coding Plugin
  let g:user_zen_settings = {
    \  'indentation' : '  ',
    \  'perl' : {
    \    'aliases' : {
    \      'req' : 'require '
    \    },
    \    'snippets' : {
    \      'use' : "use strict\nuse warnings\n\n",
    \      'warn' : "warn \"|\";",
    \    }
    \  }
    \}

    let g:user_zen_expandabbr_key = '<c-e>'

    let g:use_zen_complete_tag = 1

"-------------------------------------------------
"Handling swap and backup files
set backupdir=~/.backup/vim-backup//
set nowritebackup
set directory=~/.backup/vim-swap//

set mouse=a

"Supertab
let g:SuperTabDefaultCompletionType = "context"

"airline
set laststatus=2
let g:airline_powerline_fonts = 1
set noshowmode
