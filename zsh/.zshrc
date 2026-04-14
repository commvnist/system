# editor
export EDITOR=vim

# starship
eval "$(starship init zsh)"

# word jumping
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# For some others (tmux alters sequences)
bindkey "^[Od" backward-word
bindkey "^[Oc" forward-word

# bat
alias cat="bat"

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

# copminit

autoload -U compinit; compinit

# plugins
_zsh_plugins=(
  fzf-tab/fzf-tab.plugin.zsh
  zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
  zsh-autopair/zsh-autopair.plugin.zsh
  zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
  zsh-history-substring-search/zsh-history-substring-search.zsh
)
for _plugin in "${_zsh_plugins[@]}"; do
  source "/usr/share/zsh/plugins/${_plugin}"
done
unset _zsh_plugins _plugin

# Ctrl+F: accept autosuggestion
bindkey '^F' autosuggest-accept

# fzf
source <(fzf --zsh)

# syswatch
source ~/.scripts/syswatch.zsh

# obsidian movie entry
source ~/.scripts/obsidian_movie_entry.zsh
