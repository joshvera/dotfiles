# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/vera/.docker/bin"
# End of Docker Desktop section.

# macOS path_helper runs after .zshenv for login shells. Reapply the shared
# policy here so login and non-login shells keep the same stable prefix.
source "$HOME/github/dotfiles/zsh/path.zsh"

if (( $+commands[rustc] )); then
  export RUST_SRC_PATH="$(rustc --print sysroot)/lib/rustlib/src/rust/src"
fi

export ZSH_CUSTOM=~/github/dotfiles/zsh
# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

export PATH="$HOME/.elan/bin:$PATH"
eval "$(/opt/homebrew/bin/brew shellenv)"
