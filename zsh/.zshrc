# Editor
export EDITOR=vim

# Keep Home Manager packages available when a launcher inherits Nix's
# already-sourced marker but provides a fresh PATH.
if [[ -d "$HOME/.nix-profile/bin" && ":$PATH:" != *":$HOME/.nix-profile/bin:"* ]]; then
  export PATH="$HOME/.nix-profile/bin:$PATH"
fi

# Local user tools
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# Zsh state
_zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
_zsh_plugin_dir="$HOME/.local/share/zsh/plugins"
mkdir -p "$_zsh_cache_dir" 2>/dev/null || _zsh_cache_dir="$HOME"

# Prompt
if command -v starship >/dev/null 2>&1 && [[ "${TERM:-}" != dumb ]]; then
  eval "$(starship init zsh)"
fi

# ls: use supported color options on GNU and BSD implementations.
if command ls --color=auto --group-directories-first /dev/null >/dev/null 2>&1; then
  alias ls='ls --color=auto --group-directories-first'
elif command ls -G /dev/null >/dev/null 2>&1; then
  alias ls='ls -G'
fi
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
setopt EXTENDED_HISTORY     # keep timestamps and durations
setopt INC_APPEND_HISTORY   # write to HISTFILE immediately, not on shell exit
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_DUPS     # don't record consecutive duplicates
setopt HIST_IGNORE_SPACE    # don't record commands prefixed with a space
setopt HIST_REDUCE_BLANKS   # strip superfluous blanks
setopt HIST_SAVE_NO_DUPS

# Completion

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select
zmodload zsh/complist 2>/dev/null || true
autoload -Uz compinit
compinit -d "$_zsh_cache_dir/zcompdump-${ZSH_VERSION}"

# Home Manager links these plugins from the pinned Nix inputs.

_zsh_source_first() {
  local name="$1"
  local plugin
  shift

  for plugin in "$@"; do
    [[ -n "$plugin" && -r "$plugin" ]] || continue
    source "$plugin"
    return 0
  done

  if [[ -n "${ZSH_PLUGIN_DEBUG:-}" ]]; then
    print -u2 "zsh: plugin not found: $name"
  fi
  return 1
}

_zsh_source_first fzf-tab \
  "$_zsh_plugin_dir/fzf-tab/fzf-tab.plugin.zsh" \
  "$_zsh_plugin_dir/fzf-tab/fzf-tab.zsh"

_zsh_source_first zsh-autosuggestions \
  "$_zsh_plugin_dir/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "$_zsh_plugin_dir/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"

_zsh_source_first zsh-autopair \
  "$_zsh_plugin_dir/zsh-autopair/autopair.zsh" \
  "$_zsh_plugin_dir/zsh-autopair/zsh-autopair.plugin.zsh"

_zsh_source_first zsh-history-substring-search \
  "$_zsh_plugin_dir/zsh-history-substring-search/zsh-history-substring-search.zsh" \
  "$_zsh_plugin_dir/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh"

# fzf
if command -v fzf >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
  source <(fzf --zsh 2>/dev/null)
fi

# Vim mode. KEYTIMEOUT is in hundredths of a second; 20 keeps Esc responsive
# without making Alt key sequences fragile over SSH or WSL2.
export KEYTIMEOUT=20
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

# Shell editing: Esc enters normal mode, v opens the command in Vim, and
# Ctrl-r/Ctrl-t/Alt-c use fzf when available. Arrow history search is optional.
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

# Syntax highlighting is loaded last so it can wrap custom ZLE widgets.
_zsh_source_first zsh-syntax-highlighting \
  "$_zsh_plugin_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "$_zsh_plugin_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"

unset -f _zsh_source_first
unset _zsh_cache_dir _zsh_plugin_dir
