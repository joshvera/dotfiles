# Git aliases
alias gsb="git submodule "
alias g="git "
alias grc='git rebase --continue'
alias gra='git rebase --abort'
alias gs='git status '
alias gst='git status '
alias ga='git add'
alias gb='git branch'
alias gba='git branch -a'
alias gc='git commit -v'
gcm() {
  if [[ $1 = "--amend" ]]
  then
    git commit -v --amend -m "$2"
  else
    git commit -v -m "$@"
  fi
}
alias gcM='git commit -v -m'
alias gmc='git commit -v -m'
alias gca='git commit -v -a'
alias gd='git diff --color'
alias gc='git checkout'
alias gl='git log --stat'
alias gll='git ll'
alias gls='git log --stat'
alias glg='git log --graph'
alias gld='git log --decorate'
gla() {
  git log --author="$1"
}
gg() {
  git grep --heading -i -C 3 --all-match "$1" $(git rev-list --all)
}
alias got='git '
alias get='git '
