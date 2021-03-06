" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side
" effect.
set nocompatible
filetype off

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

Bundle "morhetz/gruvbox"
Bundle "airblade/vim-gitgutter"
Bundle "markschabacker/cocoa.vim"
Bundle "tpope/vim-dispatch"
Bundle "Valloric/YouCompleteMe"
Bundle "AndrewRadev/splitjoin.vim"
Bundle "sjl/gundo.vim"
Bundle "vim-scripts/colorizer"
Bundle "Specky"
Bundle "aaronjensen/vim-sass-status"
Bundle "IndexedSearch"
Bundle "vim-scripts/SearchComplete"
Bundle "SirVer/ultisnips"
Bundle "kana/vim-arpeggio"
Bundle "rgarver/Kwbd.vim"
Bundle "Syntastic"
Bundle "YankRing.vim"
Bundle "bitc/vim-hdevtools"
Bundle "tpope/vim-foreplay"
Bundle "spolu/dwm.vim"
Bundle "Lokaltog/vim-easymotion"
Bundle "Lokaltog/vim-powerline"
Bundle "Markdown"
Bundle "ack.vim"
Bundle "altercation/vim-colors-solarized"
Bundle "austintaylor/vim-indentobject"
Bundle "b4winckler/vim-objc"
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
Bundle "surround.vim"
Bundle "tComment"
Bundle "taglist.vim"
Bundle "tmhedberg/matchit"
Bundle "tpope/vim-endwise"
Bundle "tpope/vim-fugitive"
Bundle "tpope/vim-rails"
Bundle "tpope/vim-rake"
Bundle "vim-ruby/vim-ruby"
Bundle "vim-scripts/a.vim"
Bundle "tpope/vim-sensible"
Bundle "sessionman.vim"
Bundle "godlygeek/csapprox"
Bundle "mbbill/undotree"
Bundle "nathanaelkane/vim-indent-guides"
Bundle "tpope/gem-ctags"
Bundle "tpope/vim-classpath"
Bundle "tpope/vim-git"
Bundle "tpope/vim-sleuth"

filetype plugin indent on
