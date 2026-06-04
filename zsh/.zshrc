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

# RAPL power limit
_rapl_restore_script=/usr/local/sbin/restore-cpu-rapl-limits
_rapl_restore_stow_target="$HOME/system/rapl-power-limit/usr/local/sbin/restore-cpu-rapl-limits"
if [[ -L "$_rapl_restore_script" && -f "$_rapl_restore_script" &&
      "$(readlink -f "$_rapl_restore_script" 2>/dev/null)" == "$_rapl_restore_stow_target" ]]; then
  alias rapl-restore='sudo bash /usr/local/sbin/restore-cpu-rapl-limits'
fi
unset _rapl_restore_script _rapl_restore_stow_target

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

# Plugins. Syntax highlighting is loaded last so it can wrap custom ZLE widgets.
if command -v brew >/dev/null 2>&1; then
  _zsh_brew_prefix="$(brew --prefix)"
  _zsh_plugins=(
    "$_zsh_brew_prefix/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"
    "$_zsh_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    "$_zsh_brew_prefix/share/zsh-autopair/autopair.zsh"
    "$_zsh_brew_prefix/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
  )
  _zsh_syntax_highlighting="$_zsh_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
  _zsh_plugins=(
    /usr/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
    /usr/share/zsh/plugins/zsh-autopair/zsh-autopair.plugin.zsh
    /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
  )
  _zsh_syntax_highlighting=/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
fi
for _plugin in "${_zsh_plugins[@]}"; do
  if [[ -r "$_plugin" ]]; then
    source "$_plugin"
  fi
done

# fzf
if command -v fzf >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
  source <(fzf --zsh)
fi

# Vim mode
export KEYTIMEOUT=10
bindkey -v

autoload -Uz edit-command-line
zle -N edit-command-line

_zsh_bind_widget() {
  local keymap="$1"
  local key="$2"
  local widget="$3"

  (( $+widgets[$widget] )) || return 0
  bindkey -M "$keymap" "$key" "$widget"
}

_zsh_bind_widget_all_keymaps() {
  local key="$1"
  local widget="$2"
  local keymap

  for keymap in viins vicmd; do
    _zsh_bind_widget "$keymap" "$key" "$widget"
  done
}

_zsh_set_cursor_for_keymap() {
  [[ "${TERM:-}" == dumb ]] && return

  case "${KEYMAP:-}" in
    vicmd) printf '\e[2 q' ;;      # block cursor
    viins|main|'') printf '\e[6 q' ;; # bar cursor
    *) printf '\e[6 q' ;;
  esac
}

zle-keymap-select() {
  _zsh_set_cursor_for_keymap
}
zle -N zle-keymap-select

zle-line-init() {
  zle -K viins
  _zsh_set_cursor_for_keymap
}
zle -N zle-line-init

zle-line-finish() {
  [[ "${TERM:-}" == dumb ]] || printf '\e[0 q'
}
zle -N zle-line-finish

for _keymap in viins vicmd; do
  bindkey -M "$_keymap" "^[[1;5C" forward-word
  bindkey -M "$_keymap" "^[[1;5D" backward-word
  bindkey -M "$_keymap" "^[Oc" forward-word
  bindkey -M "$_keymap" "^[Od" backward-word
  bindkey -M "$_keymap" "^P" up-line-or-history
  bindkey -M "$_keymap" "^N" down-line-or-history
done

bindkey -M viins "^A" beginning-of-line
bindkey -M viins "^E" end-of-line
bindkey -M viins "^K" kill-line
bindkey -M viins "^U" backward-kill-line
bindkey -M viins "^W" backward-kill-word
bindkey -M viins "^?" backward-delete-char
bindkey -M vicmd "v" edit-command-line

_zsh_bind_widget_all_keymaps "^[[A" history-substring-search-up
_zsh_bind_widget_all_keymaps "^[[B" history-substring-search-down
_zsh_bind_widget_all_keymaps "^P" history-substring-search-up
_zsh_bind_widget_all_keymaps "^N" history-substring-search-down
_zsh_bind_widget_all_keymaps "^R" fzf-history-widget
_zsh_bind_widget_all_keymaps "^T" fzf-file-widget
_zsh_bind_widget_all_keymaps "^[c" fzf-cd-widget
_zsh_bind_widget viins "^F" autosuggest-accept

unset -f _zsh_bind_widget _zsh_bind_widget_all_keymaps
unset _keymap

# syswatch
if [[ -r "$HOME/.scripts/syswatch.zsh" ]]; then
  source "$HOME/.scripts/syswatch.zsh"
fi

# obsidian movie entry
if [[ -r "$HOME/.scripts/obsidian_movie_entry.zsh" ]]; then
  source "$HOME/.scripts/obsidian_movie_entry.zsh"
fi

if [[ -r "$_zsh_syntax_highlighting" ]]; then
  source "$_zsh_syntax_highlighting"
fi
unset _zsh_brew_prefix _zsh_plugins _plugin _zsh_syntax_highlighting
