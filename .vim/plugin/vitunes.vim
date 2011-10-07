" Vim script that add ability to search and play iTunes tracks from Vim
" Maintainer:	Daniel Choi <dhchoi@gmail.com>
" License: MIT License (c) 2011 Daniel Choi

if exists("g:ViTunesLoaded") || &cp || version < 700
  finish
endif
let g:vitunes_tool = '/Users/joshvera/.rbenv/versions/1.9.2-p290/lib/ruby/gems/1.9.1/gems/vitunes-0.4.8/lib/vitunes-tool-objc '
source /Users/joshvera/.rbenv/versions/1.9.2-p290/lib/ruby/gems/1.9.1/gems/vitunes-0.4.8/lib/vitunes.vim

