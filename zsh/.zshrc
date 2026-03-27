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

# ── tempwatch ──────────────────────────────────────────────────
# Usage: tempwatch [interval_seconds]   (default: 2)
# Keys:  q = quit  |  + = faster  |  - = slower
tempwatch() {
  local interval=${1:-2}

  _tw_color() {
    local t=$1
    if   (( t < 60 )); then printf '\e[92m'
    elif (( t < 75 )); then printf '\e[93m'
    elif (( t < 85 )); then printf '\e[38;5;208m'
    else                    printf '\e[91m'
    fi
  }

  _tw_bar() {
    local t=$1 max=${2:-100} width=28
    local filled=$(( t * width / max ))
    (( filled > width )) && filled=$width
    (( filled < 0     )) && filled=0
    local empty=$(( width - filled ))
    printf '%s' "$(_tw_color $t)"
    (( filled > 0 )) && printf '%0.s█' $(seq 1 $filled)
    printf '\e[90m'
    (( empty  > 0 )) && printf '%0.s░' $(seq 1 $empty)
    printf '\e[0m'
  }

  _tw_row() {
    local label=$1 temp=$2 max=${3:-100}
    printf '  \e[38;5;250m%-20s\e[0m ' "$label"
    _tw_bar "$temp" "$max"
    printf ' %s%3d°C\e[0m\n' "$(_tw_color $temp)" "$temp"
  }

  _tw_fan_row() {
    local label=$1 rpm=${2:-0} max=${3:-5000}
    local width=28
    local filled=$(( rpm * width / max ))
    (( filled > width )) && filled=$width
    (( filled < 0     )) && filled=0
    local empty=$(( width - filled ))
    printf '  \e[38;5;250m%-20s\e[0m \e[38;5;75m' "$label"
    (( filled > 0 )) && printf '%0.s█' $(seq 1 $filled)
    printf '\e[90m'
    (( empty  > 0 )) && printf '%0.s░' $(seq 1 $empty)
    printf '\e[0m \e[38;5;75m%4d RPM\e[0m\n' "$rpm"
  }

  _tw_section() {
    printf '  \e[38;5;244m%s\e[0m\n' "$1"
    printf '  \e[38;5;238m'
    printf '─%.0s' {1..46}
    printf '\e[0m\n'
  }

  _tw_key() {
    local key
    IFS= read -r -s -k 1 -t 0.05 key 2>/dev/null
    printf '%s' "$key"
  }

  _tw_from_block() {
    local adapter=$1 label=$2
    sensors 2>/dev/null | awk -v adapter="$adapter" -v label="$label" '
      /^$/ { in_block = 0; next }
      !in_block {
        if (index($0, adapter)) in_block = 1
        next
      }
      in_block && index($0, label) {
        match($0, /[+-]?[0-9]+\.[0-9]+/, arr)
        printf "%d", arr[0]+0
        exit
      }
    '
  }

  _tw_cpu_core_max() {
    sensors 2>/dev/null | awk '
      /^$/ { in_block = 0; next }
      !in_block { if (index($0, "coretemp-isa")) in_block = 1; next }
      in_block && /Core [0-9]+:/ {
        match($0, /[+-]?([0-9]+)\.[0-9]+/, arr)
        v = arr[0]+0; if (v > m) m = v
      }
      END { printf "%d", (m ? m : 0) }
    '
  }

  _tw_ram_avg() {
    sensors 2>/dev/null | awk '
      /^$/ { in_block = 0; next }
      !in_block { if (index($0, "spd5118")) in_block = 1; next }
      in_block && /temp1:/ {
        match($0, /[+-]?([0-9]+)\.[0-9]+/, arr)
        sum += arr[0]+0; count++
      }
      END { printf "%d", (count ? sum/count : 0) }
    '
  }

  # Fixed: match "NNN RPM" to skip the digit in "fan1:"
  _tw_fan() {
    local fanline=$1
    sensors 2>/dev/null | awk -v fanline="$fanline" '
      /^$/ { in_block = 0; next }
      !in_block { if (index($0, "thinkpad-isa")) in_block = 1; next }
      in_block && index($0, fanline) {
        match($0, /([0-9]+) RPM/, arr)
        printf "%d", arr[0]+0
        exit
      }
    '
  }

  printf '\e[?25l'
  tput smcup 2>/dev/null

  local last_draw=0

  while true; do
    local now=$EPOCHSECONDS
    local key=$(_tw_key)
    case $key in
      q|Q) break ;;
      +)   (( interval-- )); (( interval < 1  )) && interval=1  ;;
      -)   (( interval++ )); (( interval > 10 )) && interval=10 ;;
    esac

    if (( now - last_draw >= interval )); then
      last_draw=$now

      local gpu_temp=$(_tw_from_block  'thinkpad-isa'  'GPU:')
      local cpu_pkg=$(_tw_from_block   'coretemp-isa'  'Package id 0:')
      local cpu_core_max=$(_tw_cpu_core_max)
      local cpu_ec=$(_tw_from_block    'thinkpad-isa'  'CPU:')
      local nvme_temp=$(_tw_from_block 'nvme-pci'      'Composite:')
      local ram_avg=$(_tw_ram_avg)
      local wifi_temp=$(_tw_from_block 'iwlwifi'       'temp1:')
      local fan1=$(_tw_fan 'fan1:')
      local fan2=$(_tw_fan 'fan2:')

      tput cup 0 0
      printf '\e[2J'

      printf '\n'
      printf '  \e[1;38;5;75mtempwatch\e[0m'
      printf '  \e[38;5;240mrefresh %ds  │  +/- adjust  │  q quit\e[0m\n\n' "$interval"

      _tw_section "GPU  (thinkpad EC)"
      printf '\n'
      _tw_row "gpu" "${gpu_temp:-0}"
      printf '\n'

      _tw_section "CPU  (coretemp)"
      printf '\n'
      _tw_row "package id 0"  "${cpu_pkg:-0}"
      _tw_row "core max"      "${cpu_core_max:-0}"
      [[ ${cpu_ec:-0} -gt 0 ]] && _tw_row "ec crosscheck" "${cpu_ec:-0}"
      printf '\n'

      _tw_section "Storage & memory"
      printf '\n'
      [[ ${nvme_temp:-0} -gt 0 ]] && _tw_row "nvme composite" "${nvme_temp:-0}" "86"
      [[ ${ram_avg:-0}   -gt 0 ]] && _tw_row "ram avg (×4)"   "${ram_avg:-0}"   "55"
      [[ ${wifi_temp:-0} -gt 0 ]] && _tw_row "wifi"           "${wifi_temp:-0}"
      printf '\n'

      _tw_section "Fans"
      printf '\n'
      _tw_fan_row "fan 1 (left)"  "${fan1:-0}"
      _tw_fan_row "fan 2 (right)" "${fan2:-0}"
      printf '\n'
    fi

    sleep 0.05
  done

  tput rmcup 2>/dev/null
  printf '\e[?25h'
}
