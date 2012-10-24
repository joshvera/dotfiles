
" ========================================
"
"
" Change leader to a comma because the backslash is too far away
" That means all \x commands turn into ,x
let mapleader=","

" alias yw to yank the entire word 'yank inner word'
" even if the cursor is halfway inside the word
" FIXME: will not properly repeat when you use a dot (tie into repeat.vim)
nnoremap ,yw yiww

" ,ow = 'overwrite word', replace a word with what's in the yank buffer
" FIXME: will not properly repeat when you use a dot (tie into repeat.vim)
nnoremap ,ow "_diwhp

"make Y consistent with C and D
nnoremap Y y$

" ,# Surround a word with #{ruby interpolation}
map ,# ysiw#
vmap ,# c#{<C-R>"}<ESC>

" ," Surround a word with "quotes"
map ," ysiw"
vmap ," c"<C-R>""<ESC>

" ,' Surround a word with 'single quotes'
map ,' ysiw'
vmap ,' c'<C-R>"'<ESC>

" ,) or ,( Surround a word with (parens)
" The difference is in whether a space is put in
map ,( ysiw(
map ,) ysiw)
vmap ,( c( <C-R>" )<ESC>
vmap ,) c(<C-R>")<ESC>

" ,[ Surround a word with [brackets]
map ,] ysiw]
map ,[ ysiw[
vmap ,[ c[ <C-R>" ]<ESC>
vmap ,] c[<C-R>"]<ESC>

" ,{ Surround a word with {braces}
map ,} ysiw}
map ,{ ysiw{
vmap ,} c{ <C-R>" }<ESC>
vmap ,{ c{<C-R>"}<ESC>

" gary bernhardt's hashrocket
imap <c-l> <space>=><space>

" Change inside various enclosures with Cmd-" and Cmd-'
" The f makes it find the enclosure so you don't have
" to be standing inside it
nnoremap <D-'> f'ci'
nnoremap <D-"> f"ci"
nnoremap <D-(> f(ci(
nnoremap <D-)> f)ci)
nnoremap <D-[> f[ci[
nnoremap <D-]> f]ci]

" Emacs keybindings for insert mode
imap <C-f> <esc>la
imap <C-b> <esc>ha
imap <C-e> <esc>$a
imap <C-a> <esc>^a
inoremap <C-d> <Del>

" ==== NERD tree
" Cmd-Shift-N for nerd tree
nmap <D-N> :NERDTreeToggle<CR>

" Open the project tree and expose current file in the nerdtree with Ctrl-\
nnoremap <silent> <C-\> :NERDTreeFind<CR>

" ,q to toggle quickfix window (where you have stuff like GitGrep)
" ,oq to open it back up (rare)
nmap <silent> ,qc :CloseSingleConque<CR>:cclose<CR>
nmap <silent> ,qo :copen<CR>

" move up/down quickly by using Cmd-j, Cmd-k
" which will move us around by functions
nnoremap <silent> <D-j> }
nnoremap <silent> <D-k> {
autocmd FileType ruby map <buffer> <D-j> ]m
autocmd FileType ruby map <buffer> <D-k> [m
autocmd FileType rspec map <buffer> <D-j> }
autocmd FileType rspec map <buffer> <D-k> {

" Command-/ to toggle comments
map <D-/> :TComment<CR>
imap <D-/> <Esc>:TComment<CR>i

"GitGrep - open up a git grep line, with a quote started for the search
nnoremap ,gg :GitGrep ""<left>
"GitGrep Current Partial
nnoremap ,gcp :GitGrepCurrentPartial<CR>
"GitGrep Current File
nnoremap ,gcf :call GitGrep(expand("%:t:r"))<CR>

" hit ,f to find the definition of the current class
" this uses ctags. the standard way to get this is Ctrl-]
nnoremap <silent> ,f <C-]>

"Move back and forth through previous and next buffers
"with ,z and ,x
nnoremap <silent> ,z :bp<CR>
nnoremap <silent> ,x :bn<CR>

" Search/replace
nnoremap <leader>s :%s/\v
vnoremap <leader>s :s/\v

" Make buffer windows equal size
nnoremap <leader>= <C-W>=

" Open .vimrc
nnoremap <leader>` :e ~/.vimrc<CR>

nnoremap <leader>_ <C-w>_

" Reselect text that was just pasted with ,v
nnoremap <leader>v V`]

" Speed up viewport scrolling
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

nnoremap <C-x>o <C-w>w
nnoremap <C-x>0 <C-w>q

" Sudo to write
cmap w!! w !sudo tee % >/dev/null

" Strip all trailing whitespace from a file, using ,W
nnoremap <leader>W :%s/\s\+$//<CR>:let @/=''<CR>

noremap <leader>a :Ack<Space>

" Semicolon takes us to Ex mode
map ; :

noremap <leader>p "0p
noremap <leader>P "0P

noremap <silent> <C-^> :A<CR>
noremap <silent> <C-o> :AV<CR>

" Open corresponding header
let g:alternateExtensions_h = "m,mm,c,cpp"
let g:alternateExtensions_m = "h"

" YankRing stuff
let g:yankring_history_dir = "$HOME/.vim/.tmp"
nmap <leader>r :YRShow<CR>

" Remap j and k to act as expected when used on long, wrapped, lines
nnoremap j gj
nnoremap k gk

inoremap jj <ESC>

" make p in Visual mode replace the selected text with the yank register
vnoremap p <Esc>:let current_reg = @"<CR>gvdi<C-R>=current_reg<CR><Esc>

" TODO: Where to put the buffer deletion function?
" Use Q for formatting the current paragraph (or visual selection)
vmap Q gq
nmap Q gqap

" Don't use the shitty search regex
nnoremap / /\v
vnoremap / /\v


" ==============================
" Window/Tab/Split Manipulation
" ==============================
" Move between split windows by using the four directions H, L, I, N
" (note that  I use I and N instead of J and K because  J already does
" line joins and K is mapped to GitGrep the current word
nnoremap <silent> <left> <C-w>h
nnoremap <silent> <right> <C-w>l
nnoremap <silent> <up> <C-w>k
nnoremap <silent> <down> <C-w>j

" Zoom in and out of current window with ,gz
map <silent> ,gz <C-w>o

" Use numbers to pick the tab you want (like iTerm)
map <silent> <D-1> :tabn 1<cr>
map <silent> <D-2> :tabn 2<cr>
map <silent> <D-3> :tabn 3<cr>
map <silent> <D-4> :tabn 4<cr>
map <silent> <D-5> :tabn 5<cr>
map <silent> <D-6> :tabn 6<cr>
map <silent> <D-7> :tabn 7<cr>
map <silent> <D-8> :tabn 8<cr>
map <silent> <D-9> :tabn 9<cr>

" Create window splits easier. The default
" way is Ctrl-w,v and Ctrl-w,s. I remap
" this to vv and ss
nnoremap <silent> vv <C-w>v
nnoremap <silent> ss <C-w>s

" Resize windows with arrow keys
nnoremap <D-Up> <C-w>+
nnoremap <D-Down> <C-w>-
nnoremap <D-Left> <C-w><
nnoremap <D-Right>  <C-w>>

autocmd BufLeave,FocusLost * silent! wall

let notabs = 1
nnoremap <silent> <F7> :let notabs=!notabs<Bar>:if notabs<Bar>:tabo<Bar>:else<Bar>:tab ball<Bar>:tabn<Bar>:endif<CR>

" " Conflict markers {{{
" " highlight conflict markers
match ErrorMsg "<<<<<<<\\|=======\\|>>>>>>>"
" 
" " shortcut to jump to next conflict marker
nnoremap <leader>c /<<<<<<<\\|=======\\|>>>>>>>/<CR>

" visual shifting (builtin-repeat)
vnoremap < <gv
vnoremap > >gv

nnoremap <leader>t :PeepOpen<CR>

let g:EasyMotion_mapping_f = "<space>"

"Auto commands
au BufRead,BufNewFile {Gemfile,Rakefile,Capfile,*.rake,config.ru}     set ft=ruby
" 
au BufRead,BufNewFile {*.md,*.mkd,*.markdown}                         set ft=markdown
" gitcommit 
au BufRead,BufNewFile {COMMIT_EDITMSG}                                set ft=gitcommit

au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | execute "normal g'\"" | endif " restore position in file

let g:syntastic_ruby_exec = 'ruby'
let g:syntastic_ruby_exec = '~/.rbenv/versions/1.9.2-p320/bin/ruby'

" CtrlP local directory to nearest .git
let g:ctrlp_working_path_mode = 2

" ============================
" Shortcuts for everyday tasks
" ============================

" CtrlP
nnoremap <C-b> :CtrlPBuffer<CR>

" copy current filename into system clipboard - mnemonic: (c)urrent(f)ilename
" this is helpful to paste someone the path you're looking at
nnoremap <silent> ,cf :let @* = expand("%:~")<CR>
nnoremap <silent> ,cn :let @* = expand("%:t")<CR>

"Clear current search highlight by double tapping //
nmap <silent> // :nohlsearch<CR>

"(v)im (r)eload
nmap <silent> ,vr :so %<CR>

" CMD-* Highlight all occurrences of current word (like '*' but without moving)
" http://vim.wikia.com/wiki/Highlight_all_search_pattern_matches
nnoremap <D-*> :let @/='\<<C-R>=expand("<cword>")<CR>\>'<CR>:set hls<CR>

" These are very similar keys. Typing 'a will jump to the line in the current
" file marked with ma. However, `a will jump to the line and column marked
" with ma.  It’s more useful in any case I can imagine, but it’s located way
" off in the corner of the keyboard. The best way to handle this is just to
" swap them: http://items.sjbach.com/319/configuring-vim-right
nnoremap ' `
nnoremap ` '

" ============================
" Tabularize - alignment
" ============================
" Hit Cmd-Shift-A then type a character you want to align by
nmap <D-A> :Tabularize /
vmap <D-A> :Tabularize /

" Get the current highlight group. Useful for then remapping the color
map ,hi :echo "hi<" . synIDattr(synID(line("."),col("."),1),"name") . '> trans<' . synIDattr(synID(line("."),col("."),0),"name") . "> lo<" . synIDattr(synIDtrans(synID(line("."),col("."),1)),"name") . ">" . " FG:" . synIDattr(synIDtrans(synID(line("."),col("."),1)),"fg#")<CR>

let g:haddock_browser = "open"
let g:haddock_browser_callformat = "%s %s"
