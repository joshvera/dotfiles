# macOS path_helper runs after .zshenv for login shells. Reapply the shared
# policy here so login and non-login shells keep the same stable prefix.
source "$HOME/github/dotfiles/zsh/path.zsh"

export RUST_SRC_PATH="$(rustc --print sysroot)/lib/rustlib/src/rust/src"

export ZSH_CUSTOM=~/github/dotfiles/zsh
# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

export PATH="$HOME/.elan/bin:$PATH"
