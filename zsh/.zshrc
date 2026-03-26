# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

plugins=(git)

source $ZSH/oh-my-zsh.sh

# Starship
eval "$(starship init zsh)"

# bat
alias cat="bat"

# History
export HISTSIZE=10000
export HISTFILESIZE=10000

# zsh-autocomplete
source /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh

# zsh-autosuggestions
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh

# zsh-autopair
source /usr/share/zsh/plugins/zsh-autopair/zsh-autopair.plugin.zsh

# zsh-syntax-highlighting
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh

# zsh-history-substring-search
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# fzf
source <(fzf --zsh)
