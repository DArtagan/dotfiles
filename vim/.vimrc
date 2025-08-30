"NOTE: I may be deprecating this file, in deference to putting it all in nix.


"" Vim-Plug for plugin management
"call plug#begin('~/.vim/plugged')
"Plug 'andymass/vim-matchup'
"Plug 'ap/vim-css-color'
"Plug 'chrisbra/Recover.Vim'
""Plug 'ervandew/supertab'
"Plug 'godlygeek/tabular'
"Plug 'grafana/vim-alloy'
"Plug '/usr/local/opt/fzf'
"Plug 'jpalardy/vim-slime'
"Plug 'junegunn/fzf.vim'
"Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
"Plug 'jparise/vim-graphql'
"Plug 'jvirtanen/vim-hcl'
"Plug 'leafOfTree/vim-svelte-plugin'
"Plug 'lervag/vimtex'
"Plug 'lifepillar/vim-solarized8'
"Plug 'machakann/vim-highlightedyank'
"Plug 'mbbill/undotree'
"Plug 'mhinz/vim-signify'
"Plug 'michaeljsmith/vim-indent-object'
"Plug 'neoclide/coc.nvim', {'branch': 'release'}
"Plug 'plasticboy/vim-markdown'
"" Plug 'TabbyML/vim-tabby'
"Plug 'tomtom/tcomment_vim'
"Plug 'tpope/vim-repeat'
"Plug 'tpope/vim-sensible'  " Sensible defaults, considered an rc starting point
"Plug 'tpope/vim-sleuth'
"Plug 'tpope/vim-surround'
"Plug 'vim-airline/vim-airline'
"Plug 'vim-airline/vim-airline-themes'
"Plug 'vim-test/vim-test'
"Plug 'wincent/ferret'
"
"call plug#end()


"-------------------------------------------------
"Handling swap and backup files
set backupdir=~/.vim/backup//
set nowritebackup
set directory=~/.vim/swap//
let g:RecoverPlugin_Delete_Unmodified_Swapfile=1

"-------------------------------------------------
" Usability & Appearance Options
set mouse=a
if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif
set background=light
colorscheme solarized8

" Turn on line numbering
set number
set relativenumber

" Wrap lines and navigate accordingly
set wrap
set linebreak
set showbreak=>\

" Use case insensitive search, except when using capital letters
set ignorecase
set smartcase

" Highlight searches
set hlsearch

" Spellcheck
set spelllang=en
set spellfile=$HOME/.vim/spell/en.utf-8.add
set spell

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

"-------------------------------------------------
" Filetype
au BufNewFile,BufRead *.txt set filetype=mkd
au BufNewFile,BufRead *.tf set filetype=hcl
"set nofoldenable

"-------------------------------------------------
" Indentation Options
set autoindent
set si "Smart indent
set shiftwidth=2
set softtabstop=2
set expandtab
set pastetoggle=<F12>

autocmd BufNewFile,BufReadPost * if &filetype == "python" | set indentkeys-=0# | endif
autocmd BufNewFile,BufReadPost * if &filetype == "yaml" | set expandtab shiftwidth=2 indentkeys-=0# | endif

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

"-------------------------------------------------
"Plugin Settings

"airline
set noshowmode
let g:airline_detect_spell=0
let g:airline_powerline_fonts = 1
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#branch#displayed_head_limit = 10
let g:airline#extensions#virtualenv#enabled = 0


" coc.nvim
set signcolumn=yes
" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" use <tab> to trigger completion and navigate to the next complete item
function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

inoremap <silent><expr> <Tab>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr> <S-Tab> coc#pum#visible() ? coc#pum#prev(1) : "\<S-Tab>"

inoremap <expr> <cr> coc#pum#visible() ? coc#pum#confirm() : "\<CR>"

" Use <c-space> to trigger completion
inoremap <silent><expr> <c-@> coc#refresh()

" GoTo code navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" FZF
nnoremap <leader>f :Files<CR>

" Signify
let g:signify_vcs_list = [ 'git' ]
let g:signify_disable_by_default = 0

" Tabby
let g:tabby_keybinding_accept = '<Tab>'

" vim-markdown
let g:vim_markdown_folding_disabled = 1
autocmd BufNewFile,BufRead *.txt setlocal filetype=markdown

" vim-slime
let g:slime_target = "tmux"
let g:slime_preserve_curpos = 1
let g:slime_bracketed_paste = 1
let g:slime_debug = 0
let g:slime_python_ipython = 0

" vim-test
let test#strategy = "dispatch"
let test#python#runner = 'pytest'
nmap <silent> t<C-n> :TestNearest<CR>
nmap <silent> t<C-f> :TestFile<CR>
nmap <silent> t<C-s> :TestSuite<CR>
nmap <silent> t<C-l> :TestLast<CR>
nmap <silent> t<C-g> :TestVisit<CR>
