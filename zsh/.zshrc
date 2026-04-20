# Editor
export EDITOR=vim

# Local user tools
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# Prompt
if command -v starship >/dev/null 2>&1 && [[ "${TERM:-}" != dumb ]]; then
  eval "$(starship init zsh)"
fi

# word jumping
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# For some others (tmux alters sequences)
bindkey "^[Od" backward-word
bindkey "^[Oc" forward-word

# ls
alias ls='ls --color=auto --group-directories-first'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alFh'
alias lh='ls -lhF'
alias lt='ls -alht'
alias lS='ls -alhS'
alias lr='ls -alhR'
alias l.='ls -ld .*'

# git
alias ga='git add'
alias gaa='git add --all'
alias gau='git add -u'
alias gb='git branch'
alias gco='git checkout'
alias gc='git commit'
alias gca='git commit --amend'
alias gcm='git commit -m'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate --all'
alias gp='git push'
alias gpl='git pull --rebase'
alias gs='git status -sb'
alias gsw='git switch'

gacp() {
  local msg="$*"
  [[ -n "$msg" ]] || {
    print -u2 "usage: gacp <commit message>"
    return 1
  }
  git add -u && git commit -m "$msg" && git push
}

# History
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000
setopt INC_APPEND_HISTORY   # write to HISTFILE immediately, not on shell exit
setopt HIST_IGNORE_DUPS     # don't record consecutive duplicates
setopt HIST_IGNORE_SPACE    # don't record commands prefixed with a space
setopt HIST_REDUCE_BLANKS   # strip superfluous blanks

# Completion

autoload -Uz compinit
compinit

# Plugins
if command -v brew >/dev/null 2>&1; then
  _zsh_brew_prefix="$(brew --prefix)"
  _zsh_plugins=(
    "$_zsh_brew_prefix/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"
    "$_zsh_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    "$_zsh_brew_prefix/share/zsh-autopair/autopair.zsh"
    "$_zsh_brew_prefix/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
    "$_zsh_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  )
else
  _zsh_plugins=(
    /usr/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
    /usr/share/zsh/plugins/zsh-autopair/zsh-autopair.plugin.zsh
    /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
  )
fi
for _plugin in "${_zsh_plugins[@]}"; do
  if [[ -r "$_plugin" ]]; then
    source "$_plugin"
  fi
done
unset _zsh_brew_prefix _zsh_plugins _plugin

# Ctrl+F: accept autosuggestion
if (( $+widgets[autosuggest-accept] )); then
  bindkey '^F' autosuggest-accept
fi

# fzf
if command -v fzf >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
  source <(fzf --zsh)
fi

# syswatch
if [[ -r "$HOME/.scripts/syswatch.zsh" ]]; then
  source "$HOME/.scripts/syswatch.zsh"
fi

# obsidian movie entry
if [[ -r "$HOME/.scripts/obsidian_movie_entry.zsh" ]]; then
  source "$HOME/.scripts/obsidian_movie_entry.zsh"
fi
