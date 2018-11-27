#!/usr/bin/env zsh
# Checks if there's a frame open
emacsclient -n -e "(if (>= (length (frame-list)) 1) 't)" 2> /dev/null | grep t &> /dev/null
if [ "$?" -eq "1" ]; then
  emacsclient -a '' -nqc "$@" &> /dev/null
else
  if [ "$#" -eq "0" ]; then
      emacsclient --eval '(progn (select-frame-set-input-focus (selected-frame)))'
  else
      emacsclient -nq "$@" &> /dev/null
  fi
fi
