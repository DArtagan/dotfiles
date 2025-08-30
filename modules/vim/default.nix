{ pkgs, ... }:
{
  programs = {
    vim = {
      enable = true;
      defaultEditor = true;
      plugins = with pkgs.vimPlugins; [
        coc-nvim # LSP client for vim (needs node installed)
        coc-basedpyright # python LSP for coc
        ferret # search across files
        fzf-vim # fuzzy file search
        Recover-vim # compare and clean-up vim swap files
        # Helpful command to clean out all swap files that match their original
        #  uv run --with 'psutil==4.4.2' /nix/store/ks70pjpb6lx5ii2kicrs7x4dkxxpx6a8-vimplugin-Recover.vim-2022-09-07/contrib/cvim ~/.vim/swap/
        #tabular  # text auto-alignment (used by vim-markdown)
        tcomment_vim # toggle commenting for a block of text, file-type aware
        undotree # undo history visualizer
        vim-airline # smart status/tabline
        vim-airline-themes # For solarized colors
        vim-css-color # display color names/hex in the terminal
        vim-highlightedyank # highlight what you're yanking
        vim-indent-object # quickly select lines based on indentation (`ii`)
        vim-matchup # extends vim's % key to language-specific words
        vim-repeat # makes hitting '.' work for more plugins
        vim-sensible # tpope's sensible vim defaults
        vim-signify # indicate what lines have been edited
        vim-sleuth # set shiftwidth and expandtab based on the current file/folder context
        vim-slime # send/execute selected text to another tmux split/REPL/etc.
        vim-solarized8 # Solarized colorscheme for vim 8+
        vim-surround # Edit surrounding things (e.g. parentheses, brackets, quotes, etc. `cs"'`)
        vim-test # Run tests.  Run the nearest test.  Run any language's test.

        # Language specific packages & syntax highlighting
        vim-hcl
        vim-graphql
        vim-markdown # (requires tabular vim plugin for table formatting)
        vim-nix
        vimtex
        # grafana/vim-alloy
        # leafOfTree/vim-svelte-plugin or evanleck/vim-svelte
      ];
      extraConfig = ''
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
      '';
    };
  };
}
