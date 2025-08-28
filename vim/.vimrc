set nocompatible
" Vim-Plug for plugin management
call plug#begin('~/.vim/plugged')
Plug 'andymass/vim-matchup'
Plug 'ap/vim-css-color'
"Plug 'Exafunction/codeium.vim', { 'tag': '1.8.49' }
"Plug 'ervandew/supertab'
Plug 'godlygeek/tabular'
Plug 'grafana/vim-alloy'
"Plug 'jmcantrell/vim-virtualenv'
Plug '/usr/local/opt/fzf'
Plug 'jpalardy/vim-slime'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'jparise/vim-graphql'
Plug 'jvirtanen/vim-hcl'
Plug 'leafOfTree/vim-svelte-plugin'
"Plug 'lervag/vimtex'
Plug 'lifepillar/vim-solarized8'
Plug 'machakann/vim-highlightedyank'
Plug 'mbbill/undotree'
Plug 'metakirby5/codi.vim'
Plug 'mgedmin/coverage-highlight.vim'
Plug 'mhinz/vim-signify'
Plug 'michaeljsmith/vim-indent-object'
Plug 'mileszs/ack.vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'peitalin/vim-jsx-typescript'
Plug 'plasticboy/vim-markdown'
" Plug 'ruanyl/coverage.vim'
" Plug 'TabbyML/vim-tabby'
Plug 'tomtom/tcomment_vim'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-ragtag'
Plug 'tpope/vim-sleuth'
Plug 'tpope/vim-surround'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'vim-test/vim-test'
"Plug 'w0rp/ale'

call plug#end()

let $VIMHOME=expand('<sfile>:p:h:h')

"-------------------------------------------------
"Handling swap and backup files
set backupdir=~/.vim/backup//
set nowritebackup
set directory=~/.vim/swap//

"-------------------------------------------------
" Usability & Appearance Options

syntax enable
if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif
set background=light
"let g:solarized_termtrans = 1 " Set to 0 for urxvt
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
set spellfile=$HOME/.vim/spell/en.utf-8.add
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
au BufNewFile,BufRead *.tf set filetype=hcl
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

autocmd BufNewFile,BufReadPost * if &filetype == "python" | set indentkeys-=0# | endif
autocmd BufNewFile,BufReadPost * if &filetype == "yaml" | set expandtab shiftwidth=2 indentkeys-=0# | endif

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=300

"-------------------------------------------------
" Mapping

" Map Ctrl-C to copy to clipboard
"map <C-c> "+y<CR>
"cmap w!! w !sudo tee %
"iabbrev </ </<C-X><C-O>


command! -bar DuplicateTabpane
  \ let s:sessionoptions = &sessionoptions |
  \ try |
  \   let &sessionoptions = 'blank,help,folds,winsize,localoptions' |
  \   let s:file = tempname() |
  \   execute 'mksession ' . s:file |
  \   tabnew |
  \   execute 'source ' . s:file |
  \ finally |
  \   silent call delete(s:file) |
  \   let &sessionoptions = s:sessionoptions |
  \   unlet! s:file s:sessionoptions |
  \ endtry

"-------------------------------------------------
"Plugin Settings

" Ack.vim (using for ripgrep support)
if executable('rg')
  let g:ackprg = 'rg --vimgrep'
endif


"airline
set laststatus=2
set noshowmode
let g:airline_detect_spell=0
let g:airline_powerline_fonts = 1
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#branch#displayed_head_limit = 10
let g:airline#extensions#virtualenv#enabled = 0
"let g:airline#extensions#codeium#enabled = 1


" ALE
let g:ale_python_auto_pipenv = 1
let g:ale_python_flake8_options = '--ignore=E501'
let g:ale_disable_lsp = 1
let g:ale_hover_cursor = 1
" let g:ale_set_balloons = 1
let $PIPENV_MAX_DEPTH = 5

" coc.nvim
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

" Coverage.vim
" " Specify the path to `coverage.json` file relative to your current working directory.
" let g:coverage_json_report_path = 'coverage/coverage.json'
" " Define the symbol display for covered lines
" let g:coverage_sign_covered = '⦿'
" " Define the interval time of updating the coverage lines
" let g:coverage_interval = 5000
" " Do not display signs on covered lines
" let g:coverage_show_covered = 0
" " Display signs on uncovered lines
" let g:coverage_show_uncovered = 0

" Codeium
"let g:codeium_server_config = {
"    \'portal_url': 'https://codeium.dev-tools.ginkgo.zone',
"    \'api_url': 'https://codeium.dev-tools.ginkgo.zone/_route/api_server' }

" coverage-highlight.vim
let g:coverage_script = 'pipenv run coverage'

" GoTo code navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" FZF
nnoremap <leader>f :Files<CR>

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
\   'options': '--extended --nth=3..',jjjj
\   'down':    '60%'
\})

" Signify
let g:signify_vcs_list = [ 'git' ]
let g:signify_disable_by_default = 1

"Supertab
"let g:SuperTabDefaultCompletionType = "context"

" Syntastic
"let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [],'passive_filetypes': [] }
"nnoremap <C-w>E :SyntasticCheck<CR> :SyntasticToggleMode<CR>

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


" Git diff branches
let s:git_status_dictionary = {
            \ "A": "Added",
            \ "B": "Broken",
            \ "C": "Copied",
            \ "D": "Deleted",
            \ "M": "Modified",
            \ "R": "Renamed",
            \ "T": "Changed",
            \ "U": "Unmerged",
            \ "X": "Unknown"
            \ }
function! s:get_diff_files(rev)
  let gitroot = system('git rev-parse --show-toplevel')[:-2]
  let list = map(split(system(
              \ 'git diff --name-status '.a:rev), '\n'),
              \ '{"filename":"' . fnameescape(gitroot)
              \ . '/" . matchstr(v:val, "\\S\\+$"),"text":s:git_status_dictionary[matchstr(v:val, "^\\w")]}'
              \ )
  call setqflist(list)
  copen
endfunction

command! -nargs=1 DiffRev call s:get_diff_files(<q-args>)
