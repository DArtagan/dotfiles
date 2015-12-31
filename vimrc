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
Plugin 'Shougo/unite.vim'
Plugin 'tmhedberg/matchit'
Plugin 'tpope/vim-surround'
Plugin 'tpope/vim-ragtag'

" Required closing lines
call vundle#end()
filetype plugin indent on

"-------------------------------------------------
"Handling swap and backup files
set backupdir=~/.backup/vim-backup//
set nowritebackup
set directory=~/.backup/vim-swap//

"-------------------------------------------------
" Usability & Appearance Options

syntax enable
set background=light
let g:solarized_termcolors=16
let g:solarized_termtrans = 1 " Set to 0 for urxvt
colorscheme solarized
call togglebg#map("<F5>")
set mouse=a

" Turn on line numbering (turn off with "set nonu")
set nu
set relativenumber

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

" Unite.vim
call unite#filters#matcher_default#use(['matcher_fuzzy'])
nnoremap <leader>u :<C-u>Unite -no-split -start-insert -buffer-name=unite<CR>
nnoremap <leader>f :<C-u>Unite -no-split -buffer-name=files -start-insert file_rec<CR>
nnoremap <leader>b :<C-u>Unite -start-insert -buffer-name=buffers buffer<CR>
" <C-u> clears any selection input on the command line (:'<,'>)
" -no-split opens the unite dialog in the current window (not a new split)
" -start-insert starts the unite dialog in insert mode
" -buffer-name for easy closing of vim (no unnamed buffer warning), amongst other things

" Custom mappings for the unite buffer
autocmd FileType unite call s:unite_settings()
function! s:unite_settings()
  " Play nice with supertab
  let b:SuperTabDisabled=1
  " Enable navigation with control-j and control-k in insert mode
  imap <buffer> <C-j>   <Plug>(unite_select_next_line)
  imap <buffer> <C-k>   <Plug>(unite_select_previous_line)
endfunction


"Supertab
let g:SuperTabDefaultCompletionType = "context"


"airline
set laststatus=2
let g:airline_powerline_fonts = 1
set noshowmode


" Syntastic
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [],'passive_filetypes': [] }
nnoremap <C-w>E :SyntasticCheck<CR> :SyntasticToggleMode<CR>
