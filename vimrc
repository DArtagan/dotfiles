"-------------------------------------------------
" Necessary Options

" Enable filetype plugin
filetype plugin on
filetype indent plugin on
runtime macros/matchit.vim

"Pathogen
call pathogen#infect()

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

" Wrap lines
set wrap
set linebreak
set showbreak=>\ 

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
set directory=~/.backup/vim-swap//

set mouse=a

"Supertab
let g:SuperTabDefaultCompletionType = "context"
let g:jedi#popup_on_dot = 0

"jedi-vim
autocmd FileType python setlocal completeopt-=preview
