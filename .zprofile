# PATH Configuration moved to .zshenv for better shell compatibility
# (All PATH exports are now in .zshenv to ensure availability across all shell contexts)

export RUST_SRC_PATH="$(rustc --print sysroot)/lib/rustlib/src/rust/src"

export ZSH_CUSTOM=~/github/dotfiles/zsh