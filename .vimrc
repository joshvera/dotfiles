" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

"Turning off filetype for vundle.
filetype off

" =============== Vundle Initialization ===============
" This loads all the plugins into ~/.vim/bundle
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
Bundle "vundle"
Bundle "kana/vim-textobj-user"
Bundle "bufkill.vim"
Bundle "YankRing.vim"
Bundle "Solarized"
Bundle "Markdown"
Bundle "UltiSnips"
Bundle "ragtag.vim"
Bundle "pangloss/vim-javascript"
Bundle "surround.vim"
Bundle "scrooloose/snipmate-snippets"
Bundle "ruby.vim"
Bundle "git.zip"
Bundle "tpope/vim-fugitive"
Bundle "cocoa.vim"
Bundle "scrooloose/nerdtree"
Bundle "Lokaltog/vim-easymotion"
Bundle "vim-scripts/a.vim"
Bundle "kien/ctrlp.vim"
Bundle "tpope/vim-rails.git"
Bundle "taglist.vim"
Bundle "ack.vim"
Bundle "tpope/vim-endwise"
Bundle "tComment"
Bundle "scrooloose/syntastic"
Bundle "kchmck/vim-coffee-script"
Bundle "leshill/vim-json"
Bundle "delimitMate.vim"
Bundle "ZoomWin"
Bundle "ragtag.vim"
Bundle "repeat.vim"
Bundle "ervandew/SuperTab"
Bundle "austintaylor/vim-indentobject"
Bundle "shemerey/vim-peepopen"
 
" ================ General Config ====================
set number                      "Line numbers are good
set backspace=indent,eol,start  "Allow backspace in insert mode
set history=1000                "Store lots of :cmdline history
set showcmd                     "Show incomplete cmds down the bottom
set showmode                    "Show current mode down the bottom
set gcr=a:blinkon0              "Disable cursor blink

set autoread                    "Reload files changed outside vim

" This makes vim act like all other editors, buffers can
" exist in the background without being in a window. 
" http://items.sjbach.com/319/configuring-vim-right
set hidden

" ======================= Style ==========================
set guifont=Inconsolata:h18
set background=dark


" ================ Search Settings  =================

set incsearch        "Find the next match as we type the search
set hlsearch         "Hilight searches by default
set viminfo="100,f1  "Save up to 100 marks, enable capital marks

" ================ Turn Off Swap Files ==============

set noswapfile
set nobackup
set nowb

" ================ Persistent Undo ==================
" Keep undo history across sessions, by storing in file.
" Only works in MacVim (gui) mode.

if has("gui_running")
  set undodir=~/.vim/backups
  set undofile
endif

" ================ Indentation ======================

set autoindent
set smartindent
set smarttab
set shiftwidth=4
set softtabstop=4
set tabstop=4
set expandtab

filetype plugin on

" Display tabs and trailing spaces visually
set list listchars=tab:\ \ ,trail:·

set linebreak    "Wrap lines at convenient points

" ================ Folds ============================

set foldmethod=indent   "fold based on indent
set foldnestmax=3       "deepest fold is 3 levels
set nofoldenable        "dont fold by default

" ================ Completion =======================

set wildmode=list:longest
set wildmenu "enable ctrl-n and ctrl-p to scroll thru matches
set wildignore=*.o,*.obj,*~ "stuff to ignore when tab completing

set wildchar=<TAB> "Character for CLI expansion (TAB-completion)

" ================ Scrolling ========================

set scrolloff=3 "Start scrolling when we"re 3 lines away from margins
set sidescrolloff=15
set sidescroll=1


nnoremap // :TComment<CR>
vnoremap // :TComment<CR>
noremap <leader>o :ZoomWin<CR>
vnoremap <leader>o <C-C>:ZoomWin<CR>
inoremap <leader>o <C-O>:ZoomWin<CR>

noremap <C-W>+o :ZoomWin<CR>



" Change mapleader from \ to ,
let mapleader=","

set shortmess=atI " Abbreviate prompts and disable intro
syntax on " Turn on syntax highlighting
syntax sync minlines=256 " I don't know what it does but it makes it fast

set timeoutlen=250
set pastetoggle=<F8>

set nojoinspaces

set expandtab " Expand tabs to spaces
set shiftround " Use multiple of shiftwidth when indenting '>' and '<'
set autoindent " always set autoindenting
set copyindent " copy the previous indentation on autoindenting
set showmatch " Set show matching parenthesis
set ignorecase " Ignore case when searching
set smartcase " Ignore case if search pattern is all lower case
set smarttab " Insert tabs on the start of a line according to shiftwidth not tab stop
set gdefault " search/replace "globally" (on a line) by default
set listchars=tab:▸\ ,trail:·,extends:#,nbsp:·

set nolist " Don't show invisible characters by default
set fileformats="unix,dos,mac"
set formatoptions+=1 " Don't wrap paragraphs after 1 letter words

" Editor Layout
set encoding=utf-8
set laststatus=2 " Always show a status line

" Vim Behavior
set switchbuf=useopen           " reveal already opened files from the
                                " quickfix window instead of opening new
                                " buffers
set undolevels=1000             " use many muchos levels of undo

set ruler " show the cursor position at all times
set undofile
set nomodeline

set textwidth=80
set formatoptions=rco1 " Don't wrap paragraphs after 1 letter words
set equalalways

set autochdir

set nocursorcolumn
set nocursorline



" Don't use the shitty search regex
nnoremap / /\v
vnoremap / /\v

" Use Q for formatting the current paragraph (or visual selection)
vmap Q gq
nmap Q gqap

" make p in Visual mode replace the selected text with the yank register
vnoremap p <Esc>:let current_reg = @"<CR>gvdi<C-R>=current_reg<CR><Esc>

" Swap implementations of ` and ' jump to markers
" By default, ' jumps to the marked line, ` jumps to the marked line and
" column, so swap them
nnoremap ' `
nnoremap ` '

" Remap j and k to act as expected when used on long, wrapped, lines
nnoremap j gj
nnoremap k gk

" YankRing stuff
let g:yankring_history_dir = "$HOME/.vim/.tmp"
nmap <leader>r :YRShow<CR>

inoremap jj <ESC>
" Open corresponding header
let g:alternateExtensions_h = "m,mm,c,cpp"
let g:alternateExtensions_m = "h"
noremap <silent> <C-^> :A<CR>
noremap <silent> <C-o> :AV<CR>


noremap <leader>p "0p
noremap <leader>P "0P

noremap <silent> <C-Down>  <ESC><C-w>j
noremap <silent> <C-Up>    <ESC><C-w>k
noremap <silent> <C-Left>  <ESC><C-w>h
noremap <silent> <C-Right> <ESC><C-w>l
nnoremap <silent> <C-n> :noh<CR>
noremap ;; ; "Double semicolon takes us to Ex mode
map ; :

" Disable highlight after a search
nnoremap <silent> <C-l> :nohl<CR><C-l>
nnoremap <leader><space> :noh<CR>
nmap <silent> <leader>/ :nohlsearch<CR>

" Go to corresponding frame
nnoremap <Down> <C-w>j
nnoremap <Up> <C-w>k
nnoremap <Left> <C-w>h
nnoremap <Right> <C-w>l
" Split window vertically
nnoremap <leader>w <C-w>v<C-w>l
" Make buffer windows equal size
nnoremap <leader>= <C-W>=
" Search/replace
nnoremap <leader>s :%s/\v

" Open .vimrc
nnoremap <leader>` :e ~/.vimrc<CR>
nnoremap <leader>_ <C-w>_
nnoremap <leader>h :noh<CR>
nnoremap <leader>H :syntax sync fromstart<CR>

"  <Tab> to move back and forth matching pair
"nnoremap <tab> %
"vnoremap <tab> %

" Reselect text that was just pasted with ,v
nnoremap <leader>v V`]

" Scratch
nmap <leader><tab> :Sscratch<CR><C-W>x<C-J>

" Speed up viewport scrolling
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

nnoremap <C-x>o <C-w>w
nnoremap <C-x>0 <C-w>q

" Sudo to write
cmap w!! w !sudo tee % >/dev/null

" Strip all trailing whitespace from a file, using ,W
nnoremap <leader>W :%s/\s\+$//<CR>:let @/=''<CR>

map <F1> :NERDTreeToggle<CR><CR>

noremap <leader>a :Ack<Space>

set history=1000 " Increase history from 20 default to 1000
set undolevels=1000
set title " Show the filename in the window titlebar
set noerrorbells " Don't beep
set visualbell " Don't beep

autocmd FocusLost * :wa " Save when losing focus


set nosplitbelow " Don't do it.

autocmd BufWinEnter,BufNewFile * silent tabo

set undodir=~/.vimundo

" Conflict markers {{{
" highlight conflict markers
match ErrorMsg "<<<<<<<\\|=======\\|>>>>>>>"

" shortcut to jump to next conflict marker
nnoremap <leader>c /<<<<<<<\\|=======\\|>>>>>>><CR>

" visual shifting (builtin-repeat)
vnoremap < <gv
vnoremap > >gv

autocmd BufWritePre *.m :%s/\s\+$//e
autocmd BufWritePre *.m :retab!
autocmd BufWritePre *.h :retab!
autocmd BufWritePre *.h :%s/\s\+$//e

inoremap <ctrl-D> 
nnoremap <leader>t :PeepOpen<CR>

let g:EasyMotion_mapping_f = "<leader>f"
let g:EasyMotion_mapping_F = "<leader>F"

"Auto commands
"
au BufRead,BufNewFile {Gemfile,Rakefile,Capfile,*.rake,config.ru}     set ft=ruby
" 
au BufRead,BufNewFile {*.md,*.mkd,*.markdown}                         set ft=markdown
" gitcommit 
au BufRead,BufNewFile {COMMIT_EDITMSG}                                set ft=gitcommit

au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | execute "normal g'\"" | endif " restore position in file

" CtrlP
let g:ctrlp_working_path_mode = 2
