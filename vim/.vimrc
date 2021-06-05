set nocompatible
" Vim-Plug for plugin management
call plug#begin('~/.vim/plugged')
Plug 'altercation/vim-colors-solarized'
Plug 'andymass/vim-matchup'
Plug 'ap/vim-css-color'
Plug 'ervandew/supertab'
Plug 'godlygeek/tabular'
Plug 'janko/vim-test'
Plug 'jmcantrell/vim-virtualenv'
Plug '/usr/local/opt/fzf'
Plug 'junegunn/fzf.vim'
Plug 'jvirtanen/vim-hcl'
" Plug 'lervag/vimtex'
Plug 'lifepillar/vim-solarized8'
Plug 'machakann/vim-highlightedyank'
Plug 'mbbill/undotree'
Plug 'mhinz/vim-signify'
Plug 'michaeljsmith/vim-indent-object'
Plug 'mileszs/ack.vim'
Plug 'plasticboy/vim-markdown'
"Plug 'scrooloose/syntastic'
Plug 'tomtom/tcomment_vim'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-ragtag'
Plug 'tpope/vim-sleuth'
Plug 'tpope/vim-surround'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'w0rp/ale'

call plug#end()

let $VIMHOME=expand('<sfile>:p:h:h')

"-------------------------------------------------
"Handling swap and backup files
set backupdir=~/.backup/vim-backup//
set nowritebackup
set directory=~/.backup/vim-swap//

"-------------------------------------------------
" Usability & Appearance Options

syntax enable
if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif
set background=light
let g:solarized_termcolors=16
"let g:solarized_visibility="flat"
let g:solarized_termtrans = 1 " Set to 0 for urxvt
"colorscheme solarized
colorscheme solarized8
"call togglebg#map("<F5>")
set mouse=a

" Turn on line numbering (turn off with "set nonu")
set nu
set relativenumber

" Wrap lines and navigate accordingly
set wrap
set linebreak
set showbreak=>\ 
"imap <silent> <Down> <C-o>gj
"imap <silent> <Up> <C-o>gk
"nmap <silent> <Down> gj
"nmap <silent> <Up> gk
"nmap k gk
"nmap j gj
"onoremap <silent> j gj
"onoremap <silent> k gk
"noremap k gk
"noremap j gj
nnoremap <expr> j v:count ? 'j' : 'gj'
nnoremap <expr> k v:count ? 'k' : 'gk'

" Use case insensitive search, except when using capital letters
set ignorecase
set smartcase

" Highlight searches
set hlsearch
set incsearch

" Spellcheck
set spelllang=en
set spellfile=$VIMHOME/spell/en.utf-8.add
set spell

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
" Filetype
au BufNewFile,BufRead *.txt set filetype=mkd
set nofoldenable

"-------------------------------------------------
" Tags
" set tags=tags

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
"map <C-c> "+y<CR> 
"cmap w!! w !sudo tee %
"iabbrev </ </<C-X><C-O>

"-------------------------------------------------
"Plugin Settings

" Ack.vim (using for ag support)
if executable('ag')
  let g:ackprg = 'ag --vimgrep'
endif


"airline
set laststatus=2
set noshowmode
let g:airline_powerline_fonts = 1
let g:airline#extensions#virtualenv#enabled = 0
let g:airline#extensions#ale#enabled = 1


" ALE
let g:ale_python_auto_pipenv = 1
let g:ale_python_flake8_options = '--ignore=E501'
let $PIPENV_MAX_DEPTH = 5


" FZF
"" Search lines in all open vim buffers
function! s:line_handler(l)
  let keys = split(a:l, ':\t')
  exec 'buf' keys[0]
  exec keys[1]
  normal! ^zz
endfunction

function! s:buffer_lines()
  let res = []
  for b in filter(range(1, bufnr('$')), 'buflisted(v:val)')
    call extend(res, map(getbufline(b,0,"$"), 'b . ":\t" . v:name . (v:key + 1) . ":\t" . v:val '))
  endfor
  return res
endfunction

command! FZFLines call fzf#run({
\   'source':  <sid>buffer_lines(),
\   'sink':    function('<sid>line_handler'),
\   'options': '--extended --nth=3..',
\   'down':    '60%'
\})

" Signify
let g:signify_vcs_list = [ 'git' ]
let g:signify_disable_by_default = 1

"Supertab
let g:SuperTabDefaultCompletionType = "context"

" Syntastic
"let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [],'passive_filetypes': [] }
"nnoremap <C-w>E :SyntasticCheck<CR> :SyntasticToggleMode<CR>


" vim-markdown
let g:vim_markdown_folding_disabled = 1
autocmd BufNewFile,BufRead *.txt setlocal filetype=markdown


" vim-test
let test#strategy = "dispatch"
nmap <silent> t<C-n> :TestNearest<CR>
nmap <silent> t<C-f> :TestFile<CR>
nmap <silent> t<C-s> :TestSuite<CR>
nmap <silent> t<C-l> :TestLast<CR>
nmap <silent> t<C-g> :TestVisit<CR>
