#!/usr/bin/env zsh

source "${HOME}/.zshrc"

if (( ${+functions[syswatch]} )); then
  syswatch
else
  print -u2 'syswatch extension: syswatch function was not loaded from ~/.zshrc'
fi

exec zsh -i
