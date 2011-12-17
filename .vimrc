" Use Vim settings
set nocompatible
filetype off

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
Bundle 'gmarick/vundle'
Bundle 'Solarized'
Bundle 'tpope/vim-fugitive'
Bundle 'cocoa.vim'


set guifont=Inconsolata:h18
set background=dark

filetype plugin indent on " Enable detection, plugins and indenting

" Change mapleader from \ to ,
let mapleader=","

set shortmess=atI " Abbreviate prompts and disable intro
syntax on " Turn on syntax highlighting
syntax sync minlines=256 " I don't know what it does but it makes it fast



set nojoinspaces

set tabstop=4 " A tab is four spaces
set shiftwidth=4 " Number of spaces to use for autoindenting
set softtabstop=4 " When hitting <BS>, pretend like a tab is removed
set expandtab " Expand tabs to spaces
set shiftround " Use multiple of shiftwidth when indenting '>' and '<'
set backspace=indent,eol,start " Allow backspacing over everything in insert mode
set autoindent " always set autoindenting
set copyindent " copy the previous indentation on autoindenting
set number " Always show line numbers
set showmatch " Set show matching parenthesis
set ignorecase " Ignore case when searching
set smartcase " Ignore case if search pattern is all lower case
set smarttab " Insert tabs on the start of a line according to shiftwidth not tab stop
set scrolloff=3 "Keep 3 lines above and below cursor at all times
set hlsearch " Highlight search terms
set incsearch " Show search matches as you type
set gdefault " search/replace "globally" (on a line) by default
set listchars=tab:▸\ ,trail:·,extends:#,nbsp:·

set nolist " Don't show invisible characters by default
set fileformats="unix,dos,mac"
set formatoptions+=1 " Don't wrap paragraphs after 1 letter words

" Editor Layout
set encoding=utf-8
set laststatus=2 " Always show a status line

" Vim Behavior
set hidden "Hide buffers instead of closing them
set switchbuf=useopen           " reveal already opened files from the
                                " quickfix window instead of opening new
                                " buffers
set history=1000                " remember more commands and search history
set undolevels=1000             " use many muchos levels of undo
if v:version >= 730
    set undofile                " keep a persistent backup file
    set undodir=~/.vim/.undo,~/tmp,/tmp
endif
set nobackup                    " do not keep backup files, it's 70's style cluttering
set noswapfile                  " do not write annoying intermediate swap files,
                                "    who did ever restore from swap files anyway?
set directory=~/.vim/.tmp,~/tmp,/tmp
                                " store swap files in one of these directories
                                "    (in case swapfile is ever turned on)

set wildchar=<TAB> "Character for CLI expansion (TAB-completion)
set wildmenu " Make tab completion act like bash
set wildmode=list:longest "Complete only until point of ambiguity

set ruler " show the cursor position at all times
set undofile
set nomodeline

set textwidth=80
set formatoptions=rco1 " Don't wrap paragraphs after 1 letter words
set equalalways
set autoread

set foldmethod=syntax "Fold based on syntax
set nofoldenable "Start off with folds open
set foldopen=block,hor,insert,jump,mark,percent,quickfix,search,tag,undo " which commands trigger auto-unfold

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
let g:yankring_history_dir = '$HOME/.vim/.tmp'
nmap <leader>r :YRShow<CR>

inoremap jj <ESC>
" Open corresponding header
let g:alternateExtensions_h = "m,mm,c,cpp"
let g:alternateExtensions_m = "h"
noremap <silent> <C-^> :A<CR>
noremap <silent> <C-o> :AV<CR>


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
nnoremap <leader>b :CommandTBuffer<CR>
nnoremap <leader>f :CommandT<CR>
let g:CommandTMaxHeight=5

" <Tab> to move back and forth matching pair
nnoremap <tab> %
vnoremap <tab> %

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
noremap <leader>e :e<Space>

set history=1000 " Increase history from 20 default to 1000
set undolevels=1000
set title " Show the filename in the window titlebar
set noerrorbells " Don't beep
set visualbell " Don't beep

set nobackup " Don't keep backup files
set noswapfile " Don't keep swap files
set nobackup

autocmd FocusLost * :wa " Save when losing focus


set nosplitbelow " Don't do it.

autocmd BufWinEnter,BufNewFile * silent tabo

set undodir=~/.vimundo

" Conflict markers {{{
" highlight conflict markers
match ErrorMsg '<<<<<<<\\|=======\\|>>>>>>>'

" shortcut to jump to next conflict marker
nnoremap <leader>c /<<<<<<<\\|=======\\|>>>>>>><CR>

" visual shifting (builtin-repeat)
vnoremap < <gv
vnoremap > >gv

autocmd BufWritePre *.m :%s/\s\+$//e
autocmd BufWritePre *.m :retab!
autocmd BufWritePre *.h :retab!
autocmd BufWritePre *.h :%s/\s\+$//e

nnoremap <leader>t :PeepOpen<CR>

