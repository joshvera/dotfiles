
" =============== Vundle Initialization ===============
" This loads all the plugins into ~/.vim/bundle
source ~/.vim/bundles.vim


" Set spacing and ruby complete
autocmd FileType ruby,eruby,yaml set tw=80 ai sw=2 sts=2 et
if has("autocmd")
    autocmd FileType ruby set omnifunc=rubycomplete#Complete
    autocmd FileType ruby let g:rubycomplete_buffer_loading=1
    autocmd FileType ruby let g:rubycomplete_classes_in_global=1
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

" Turn on syntax highlighting
syntax on 

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
set gdefault " search/replace "globally" (on a line) by default

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

"Automatically change the current working directory
set autochdir

set title "Show the filename in the window titlebar

set nosplitbelow "Don't do it.

set noswapfile

