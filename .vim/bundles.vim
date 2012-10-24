" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side
" effect.
set nocompatible
filetype off

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

Bundle "Shougo/vimproc"
Bundle "Shougo/neocomplcache"
Bundle "lukerandall/haskellmode-vim"
Bundle "ujihisa/neco-ghc"
Bundle "eagletmt/ghcmod-vim"
Bundle "Lokaltog/vim-easymotion"
Bundle "Lokaltog/vim-powerline"
Bundle "Markdown"
Bundle "YankRing.vim"
Bundle "ack.vim"
Bundle "altercation/vim-colors-solarized"
Bundle "austintaylor/vim-indentobject"
Bundle "b4winckler/vim-objc"
Bundle "bufkill.vim"
Bundle "delimitMate.vim"
Bundle "gmarick/vundle"
Bundle "kana/vim-textobj-user"
Bundle "kchmck/vim-coffee-script"
Bundle "kien/ctrlp.vim"
Bundle "nelstrom/vim-textobj-rubyblock"
Bundle "pangloss/vim-javascript"
Bundle "ragtag.vim"
Bundle "repeat.vim"
Bundle "scratch.vim"
Bundle "scrooloose/nerdtree"
Bundle "scrooloose/snipmate-snippets"
Bundle "scrooloose/syntastic"
Bundle "surround.vim"
Bundle "tComment"
Bundle "taglist.vim"
Bundle "tmhedberg/matchit"
Bundle "tpope/vim-bundler"
Bundle "tpope/vim-endwise"
Bundle "tpope/vim-fugitive"
Bundle "tpope/vim-haml"
Bundle "tpope/vim-rails"
Bundle "tpope/vim-rake"
Bundle "vim-ruby/vim-ruby"
Bundle "vim-scripts/a.vim"
Bundle 'alfredodeza/jacinto.vim'
Bundle 'ricardovaleriano/vim-github-theme'

filetype plugin indent on
