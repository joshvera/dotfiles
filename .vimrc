let g:ruby_path = system('echo $HOME/.rbenv/shims')

" =============== Vundle Initialization ===============
" Turn on syntax highlighting
syntax on
filetype on
filetype plugin indent on

" This loads all the plugins into ~/.vim/bundle
"
source ~/.vim/bundles.vim

" Set spacing and ruby complete
if has("autocmd")
    autocmd FileType ruby set omnifunc=rubycomplete#Complete
    autocmd FileType ruby let g:rubycomplete_buffer_loading=1
    autocmd FileType ruby let g:rubycomplete_classes_in_global=1

    autocmd FileType clojure setlocal shiftwidth=2 softtabstop=2
    autocmd FileType ruby,eruby,yaml set tw=80 ai sw=2 sts=2 et
    autocmd FileType puppet setlocal shiftwidth=2 softtabstop=2
    autocmd FileType c,c++,cpp,objc setlocal noexpandtab comments-=:// comments+=:/// comments+=:// suffixesadd+=.m,.h,.c,.pch,.mm,.cc,.cpp,.hh,.hpp
    autocmd FileType swift setlocal noexpandtab comments-=:// comments+=:/// comments+=://
    autocmd FileType markdown setlocal textwidth=80 formatoptions+=t
    autocmd FileType javascript setlocal shiftwidth=2 softtabstop=2
    autocmd FileType cabal setlocal shiftwidth=2 softtabstop=2
endif

let g:syntastic_enable_signs=1
let g:syntastic_auto_loc_list=1


" ================ General Config ====================

set number                      "Line numbers are good
set history=1000                "Store lots of :cmdline history
set showmode                    "Show current mode down the bottom
set gcr=a:blinkon0              "Disable cursor blink
set visualbell                  "No sounds
set noerrorbells                "Don't beep
set autochdir

" This makes vim act like all other editors, buffers can
" exist in the background without being in a window.
" http://items.sjbach.com/319/configuring-vim-right
set hidden

" ======================= Style ==========================
set guifont=Inconsolata:h18
set background=dark

" ================ Search Settings  =================

set hlsearch         "Hilight searches by default
set viminfo='100,f1,%  "Save up to 100 marks, enable capital marks,buffers

" ================ Persistent Undo ==================
" Keep undo history across sessions, by storing in file.
" Only works all the time.

silent !mkdir ~/.vim/backups > /dev/null 2>&1

" ================ Indentation ======================

set copyindent " copy the previous indentation on autoindenting
set noautoindent
set smartindent
set shiftwidth=4
set softtabstop=4
set tabstop=4

" Display tabs and trailing spaces visually
set listchars=tab:▸\ ,trail:·,extends:#,nbsp:·
set nolist " Don't show invisible characters by default

set formatoptions=qrco1 " Don't wrap paragraphs after 1 letter words
set linebreak    "Wrap lines at convenient points

" ================ Folds ============================

set foldmethod=indent   "fold based on indent
set foldnestmax=3       "deepest fold is 3 levels
set nofoldenable        "dont fold by default

" ================ Completion =======================

set wildmode=list:longest
set wildignore=*.o,*.obj,*~ "stuff to ignore when tab completing
set wildignore+=*vim/backups*
set wildignore+=*sass-cache*
set wildignore+=*DS_Store*
set wildignore+=vendor/rails/**
set wildignore+=vendor/cache/**
set wildignore+=*.gem
set wildignore+=log/**
set wildignore+=tmp/**
set wildignore+=*.png,*.jpg,*.gif

" ================ Scrolling ========================

"Start scrolling when we're 8 lines away from margins
set scrolloff=8
set sidescrolloff=15
set sidescroll=1

" Abbreviate prompts and disable intro
set shortmess=atI

" Wait 250ms for a keystroke to complete
set timeoutlen=250
set pastetoggle=<F6>

set nojoinspaces

" ================ Searching ========================
set ignorecase " Ignore case when searching
set wildignorecase
set smartcase
set infercase
set gdefault " search/replace "globally" (on a line) by default

set wildmenu

"Editor Layout
set encoding=utf-8

"Vim Behavior
set switchbuf=useopen           "Reveal already opened files from the
                                "quickfix window instead of opening new
                                "buffers
set undolevels=1000             "Use many muchos levels of undo

"Turn on persistent undo
set undofile

set undodir=~/.vim/undodir

set textwidth=80

"Split windows evenly
set equalalways


set title "Show the filename in the window titlebar

set nosplitbelow "Don't do it.

set noswapfile

set tags+=tags;$HOME
nnoremap <leader>. :CtrlPTag<cr>

"Automatically change the current working directory
set autochdir

let c_no_curly_error = 1

if has('gui_running')
    colorscheme solarized
else
    colorscheme Gruvbox
endif

cnoremap help vert help

let g:Powerline_theme = 'solarized256'

let g:clang_use_library = 1
let g:clang_library_path = '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib'

let g:syntastic_objc_checkers=['ycm']
let g:ycm_confirm_extra_conf = 0
nnoremap <F5> :YcmForceCompileAndDiagnostics<CR>

nnoremap ,n :lopen<CR><CR>

" Python mode
let g:pymode_rope = 0

" Documentation
let g:pymode_doc = 1
let g:pymode_doc_key = 'K'

"Linting
let g:pymode_lint = 1
let g:pymode_lint_checker = "pyflakes,pep8"
" Auto check on save
let g:pymode_lint_write = 1

" Support virtualenv
let g:pymode_virtualenv = 1

" Enable breakpoints plugin
let g:pymode_breakpoint = 1
let g:pymode_breakpoint_key = '<leader>b'

" syntax highlighting
let g:pymode_syntax = 1
let g:pymode_syntax_all = 1
let g:pymode_syntax_indent_errors = g:pymode_syntax_all
let g:pymode_syntax_space_errors = g:pymode_syntax_all

" Don't autofold code
let g:pymode_folding = 0

let maplocalleader = "\\"

au FileType haskell nnoremap <buffer> <F1> :HdevtoolsType<CR>
au FileType haskell nnoremap <buffer> <silent> <F2> :HdevtoolsClear<CR>

au! FileType idris  setlocal <silent> <\/><\/> :tComment<CR>
au! FileType idris  setlocal commentstring=--\ %s

let g:netrw_list_hide='.*\.idc$' "Dont show .idc files

syntax on
filetype on
filetype plugin indent on

highlight clear SignColumn "Remove weird git gutter color bug with solarized

set guioptions-=m  "remove menu bar
set guioptions-=T  "remove toolbar
set guioptions-=r  "remove right-hand scroll bar
set guioptions-=L  "remove left-hand scroll bar
