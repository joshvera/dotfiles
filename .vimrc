set nocompatible " Make vim more useful
filetype plugin indent off

runtime bundle/vim-pathogen/autoload/pathogen.vim
call pathogen#infect()

set backspace=indent,eol,start

set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab "Expand tabs to spaces
set autoindent " Copy the indentation from the last line when starting new line
set hidden "When a buffer is brought to the foreground, remember undo history and marks.

set encoding=utf-8
set scrolloff=3
set wildchar=<TAB> "Character for CLI expansion (TAB-completion)
set wildmenu "Hitting TAB in command mode will show possible completions above command line
set wildmode=list:longest "Complete only until point of ambiguity
set cursorline " Highlight the current line
"set ttyfast "Send more characters at a give time.
set ruler " show the cursor position at all times
set laststatus=2
set undofile

set textwidth=80
set formatoptions=rcn1
set equalalways
set autoread
set number
set foldmethod=syntax
set foldlevelstart=0
set autochdir

set nocursorcolumn
set nocursorline

syntax on " Turn on syntax highlighting
syntax sync minlines=256 " I don't know what it does but it makes it fast

let mapleader=","

" Don't use the shitty search regex
nnoremap / /\v
vnoremap / /\v

set ignorecase
set smartcase
set gdefault
set incsearch
set showmatch
set hls is ic scs

nnoremap <leader><space> :noh<CR>
nmap <silent> <leader>/ :nohlsearch<CR>
inoremap jj <ESC>
noremap <silent> <C-o> :FSSplitRight<CR>
noremap <silent> <C-Down>  <ESC><C-w>j
noremap <silent> <C-Up>    <ESC><C-w>k
noremap <silent> <C-Left>  <ESC><C-w>h
noremap <silent> <C-Right> <ESC><C-w>l
nnoremap <silent> <C-n> :noh<CR>
nnoremap ; :
nnoremap <Down> <C-w>j
nnoremap <Up> <C-w>k
nnoremap <Left> <C-w>h
nnoremap <Right> <C-w>l
nnoremap <leader>w <C-w>v<C-w>l
nnoremap <leader>= <C-W>=
nnoremap <leader>e :e
nnoremap <leader>s :%s/\v
nnoremap <leader>` :e ~/.vimrc<CR>
nnoremap <leader>_ <C-w>_
nnoremap <leader>h :noh<CR>
nnoremap <leader>H :syntax sync fromstart<CR>
nnoremap <leader>b :FufBuffer<CR>
nnoremap <leader>f :FufFile<CR>
nnoremap <tab> %
vnoremap <tab> %

:nnoremap <silent> <F5> :let _s=@/<Bar>:%s/\s\+$//e<Bar>:let @/=_s<Bar>:nohl<CR>

nmap <leader>y "+y
nmap <leader>Y "+yy
nmap <leader>p "+p
nmap <leader>P "+P

" Speed up viewport scrolling
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

" Sudo write (,W)
noremap <leader>W :w !sudo tee %<CR>

map <F1> :NERDTreeToggle<CR><CR>
nnoremap <silent> <F3> :YRShow<cr>
inoremap <silent> <F3> <ESC>:YRShow<cr>

set history=1000 " Increase history from 20 default to 1000
set undolevels=1000
set title " Show the filename in the window titlebar
set noerrorbells "Disable error bells
set visualbell

set nobackup
set noswapfile

autocmd FocusLost * :wa " Save when losing focus

colorscheme solarized
set background=dark

set guifont=Inconsolata:h18
noremap <leader>a :Ack<Space>
set nosplitbelow

autocmd BufWinEnter,BufNewFile * silent tabo

set undodir=~/.vimundo

nnoremap <leader>c /<<<<<<<\\|=======\\|>>>>>>><CR>

" visual shifting (builtin-repeat)
vnoremap < <gv
vnoremap > >gv
