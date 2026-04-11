# ── syswatch ───────────────────────────────────────────────────────────────────
# All-in-one performance & thermal monitor for ThinkPad P16 Gen 2 (zsh)
#
# Usage:  syswatch [interval]   (default: 0.5s, decimals ok)
#
# Environment variables:
#   TW_INTERVAL=0.5          default refresh interval (seconds)
#   TW_INTERVAL_MIN=0.5      minimum interval (+key floor)
#   TW_INTERVAL_MAX=10       maximum interval (-key ceiling)
#   TW_CORES=8               cores to show, 0=all
#   TW_TEMP_WARN=60          °C yellow threshold
#   TW_TEMP_HOT=75           °C orange threshold
#   TW_TEMP_CRIT=85          °C red threshold (also temp bar max)
#   TW_CPU_MAX_MHZ=0         CPU freq bar ceiling       (0 = auto from cpuinfo_max_freq)
#   TW_GPU_MAX_MHZ=0         GPU core clock bar ceiling (0 = auto from nvidia-smi) *
#   TW_MEM_MAX_MHZ=0         GPU mem clock bar ceiling  (0 = auto from nvidia-smi) *
#   TW_FAN_MAX_RPM=5500      fan RPM bar ceiling
#   TW_NO_NVIDIA=0           set to 1 to disable all nvidia-smi calls
#   TW_TOP_PROCS=5           top processes to show per section (0 = hide)
#
# * setting to 0 queries nvidia-smi at startup for the real GPU/MEM max clocks
#
# Keys:  q quit  +/- speed  c cores  n gpu  p procs  h help
# ──────────────────────────────────────────────────────────────────────────────

syswatch() {
  emulate -L zsh
  setopt local_options local_traps pipe_fail
  zmodload zsh/datetime 2>/dev/null || {
    print -u2 'syswatch: zsh/datetime is required for EPOCHREALTIME'
    return 1
  }

  # ── declare all locals up front to prevent zsh assignment leaks ──────────────
  # Config
  local interval interval_default interval_min interval_max
  local -i INTERVAL_MIN_CS INTERVAL_MAX_CS
  local -i TOP_CORES TOP_PROCS T_WARN T_HOT T_CRIT T_MAX
  local -i CPU_MAX GPU_MAX_DEF MEM_MAX FAN_MAX
  local -i NO_NVIDIA
  local -i SHOW_CORES SHOW_NVIDIA SHOW_HELP SHOW_PROCS

  # Colors
  local R DIM DIMMER LBL ACC TTL SEC GRN YLW ORG RED BLU

  # Init-time
  local cpu_model nvidia_max mem_max
  local -i interval_cs last_cs
  local -i rapl_e_prev rapl_t_prev rapl_pkg_w

  # Per-frame data
  local -i now_cs
  local key
  local cpu_pkg cpu_cmax gpu_ec nvme wifi fan1 fan2
  local -a fs ps bi nv cl ram_dimms gpu_procs cpu_procs mem_procs
  local fmin fmax favg ncpu nact
  local gov epp turbo hwpb pmin pmax
  local prof pwrsrc
  local bpct bwatt bst
  local nvc nvm nvu nvp nvps nvvu nvvt nvt
  local ram_used ram_total
  local -i rapl_e_now rapl_t_now rapl_de rapl_dt rapl_emax sys_pwr_w

  # Render temporaries
  local _buf disp_int ts bcol clabel di
  local line _mhz _rest _cpu _phys _temp cf ct2 ctype
  local _pct _pct_i _name _mem _col_proc
  local sdata
  local v vp vc
  local rp rc

  # ── script defaults — edit these, or override via env vars before calling ────
  : ${TW_INTERVAL:=0.5}        # refresh interval (seconds)
  : ${TW_INTERVAL_MIN:=0.5}    # minimum interval (+key floor)
  : ${TW_INTERVAL_MAX:=10}     # maximum interval (-key ceiling)
  : ${TW_CORES:=8}             # cores to show (0=all)
  : ${TW_TEMP_WARN:=60}        # °C yellow threshold
  : ${TW_TEMP_HOT:=75}         # °C orange threshold
  : ${TW_TEMP_CRIT:=85}        # °C red threshold (also temp bar max)
  : ${TW_CPU_MAX_MHZ:=0}       # CPU freq bar ceiling       (0 = auto from cpuinfo_max_freq)
  : ${TW_GPU_MAX_MHZ:=0}       # GPU core clock bar ceiling (0 = auto from nvidia-smi) *
  : ${TW_MEM_MAX_MHZ:=0}       # GPU mem clock bar ceiling  (0 = auto from nvidia-smi) *
  : ${TW_FAN_MAX_RPM:=5500}    # fan RPM bar ceiling
  : ${TW_NO_NVIDIA:=0}         # set to 1 to disable all nvidia-smi calls
  : ${TW_TOP_PROCS:=5}         # top processes per section (0 = hide)

  _sw_num_or() {  # _sw_num_or <raw> <fallback>
    local raw=${1:-} fallback=${2}
    if [[ ${raw} =~ '^([0-9]+([.][0-9]*)?|[.][0-9]+)$' ]]; then
      printf '%s' "${raw}"
    else
      printf '%s' "${fallback}"
    fi
  }

  _sw_int_or() {  # _sw_int_or <raw> <fallback>
    local raw=${1:-} fallback=${2}
    if [[ ${raw} =~ '^[0-9]+$' ]]; then
      printf '%s' "${raw}"
    else
      printf '%s' "${fallback}"
    fi
  }

  _sw_centiseconds() {  # _sw_centiseconds <seconds> <fallback>
    local raw
    local -i cs
    raw=$(_sw_num_or "${1:-}" "${2:-0}")
    cs=$(( raw * 100 ))
    printf '%d' "${cs}"
  }

  # ── config assignments ───────────────────────────────────────────────────────
  interval_default=$(_sw_num_or "${TW_INTERVAL}"     0.5)
  interval_min=$(_sw_num_or     "${TW_INTERVAL_MIN}" 0.5)
  interval_max=$(_sw_num_or     "${TW_INTERVAL_MAX}" 10)
  interval=$(_sw_num_or         "${1:-${interval_default}}" "${interval_default}")

  INTERVAL_MIN_CS=$(_sw_centiseconds "${interval_min}" 0.5)
  INTERVAL_MAX_CS=$(_sw_centiseconds "${interval_max}" 10)
  (( INTERVAL_MIN_CS < 5 )) && INTERVAL_MIN_CS=5
  (( INTERVAL_MAX_CS < INTERVAL_MIN_CS )) && INTERVAL_MAX_CS=${INTERVAL_MIN_CS}

  TOP_CORES=$(_sw_int_or   "${TW_CORES}"        8)
  T_WARN=$(_sw_int_or      "${TW_TEMP_WARN}"    60)
  T_HOT=$(_sw_int_or       "${TW_TEMP_HOT}"     75)
  T_CRIT=$(_sw_int_or      "${TW_TEMP_CRIT}"    85)
  CPU_MAX=$(_sw_int_or     "${TW_CPU_MAX_MHZ}"  0)
  GPU_MAX_DEF=$(_sw_int_or "${TW_GPU_MAX_MHZ}"  0)
  MEM_MAX=$(_sw_int_or     "${TW_MEM_MAX_MHZ}"  0)
  FAN_MAX=$(_sw_int_or     "${TW_FAN_MAX_RPM}"  5500)
  NO_NVIDIA=$(_sw_int_or   "${TW_NO_NVIDIA}"    0)
  TOP_PROCS=$(_sw_int_or   "${TW_TOP_PROCS}"    5)

  (( T_HOT < T_WARN )) && T_HOT=${T_WARN}
  (( T_CRIT < T_HOT )) && T_CRIT=${T_HOT}
  (( FAN_MAX < 1 )) && FAN_MAX=5500
  (( NO_NVIDIA != 0 )) && NO_NVIDIA=1

  T_MAX=$(( T_CRIT + 15 ))   # temp bar scale: crit+15 = 100%
  SHOW_CORES=1
  SHOW_NVIDIA=1
  SHOW_HELP=0
  SHOW_PROCS=1
  last_cs=0

  # ── colors ($'...' = real ESC bytes, never backslash-e in double quotes) ─────
  R=$'\e[0m'
  DIM=$'\e[38;5;240m'
  DIMMER=$'\e[38;5;238m'
  LBL=$'\e[38;5;250m'
  ACC=$'\e[38;5;75m'
  TTL=$'\e[1;38;5;75m'
  SEC=$'\e[38;5;244m'
  GRN=$'\e[92m'
  YLW=$'\e[93m'
  ORG=$'\e[38;5;208m'
  RED=$'\e[91m'
  BLU=$'\e[38;5;75m'

  # ── output buffer ────────────────────────────────────────────────────────────
  # All rendering appends to _buf; _sw_flush prints atomically to avoid flicker.
  _buf=''
  _sw_p()     { _buf+="${*}"; }
  _sw_pn()    { _buf+="${*}"$'\e[K\n'; }
  _sw_flush() { printf '%s' "${_buf}"; _buf=''; }

  # ── color selectors — return ANSI escape to stdout for use in $(...) ─────────
  _sw_temp_color() {   # temp color: _sw_temp_color <degrees>
    if   (( $1 < T_WARN )); then printf '%s' "${GRN}"
    elif (( $1 < T_HOT  )); then printf '%s' "${YLW}"
    elif (( $1 < T_CRIT )); then printf '%s' "${ORG}"
    else                         printf '%s' "${RED}"
    fi
  }
  _sw_freq_color() {   # freq color: _sw_freq_color <mhz> [max]
    local pct
    pct=$(( ${1} * 100 / ( ${2:-${CPU_MAX}} > 0 ? ${2:-${CPU_MAX}} : 1 ) ))
    if   (( pct < 25 )); then printf '%s' "${GRN}"
    elif (( pct < 55 )); then printf '%s' "${YLW}"
    elif (( pct < 80 )); then printf '%s' "${ORG}"
    else                      printf '%s' "${RED}"
    fi
  }
  _sw_percent_color() {   # percent color: _sw_percent_color <pct>
    if   (( $1 < 30 )); then printf '%s' "${GRN}"
    elif (( $1 < 60 )); then printf '%s' "${YLW}"
    elif (( $1 < 85 )); then printf '%s' "${ORG}"
    else                     printf '%s' "${RED}"
    fi
  }
  _sw_watt_color() {   # watt color: _sw_watt_color <watts>
    if   (( $1 < 20 )); then printf '%s' "${GRN}"
    elif (( $1 < 45 )); then printf '%s' "${YLW}"
    elif (( $1 < 80 )); then printf '%s' "${ORG}"
    else                     printf '%s' "${RED}"
    fi
  }

  # ── render primitives ────────────────────────────────────────────────────────
  _sw_bar() {  # _sw_bar <val> <max> <color>
    local bw val max f e
    bw=$(( ${COLUMNS:-80} - 32 ))
    (( bw <  8 )) && bw=8
    (( bw > 36 )) && bw=36
    val=${1}; max=${2}
    f=$(( val * bw / ( max > 0 ? max : 1 ) ))
    (( f > bw )) && f=${bw}
    (( f < 0  )) && f=0
    e=$(( bw - f ))
    _sw_p "${3}"
    (( f > 0 )) && _sw_p "${(r:${f}::█:)}"
    _sw_p "${DIMMER}"
    (( e > 0 )) && _sw_p "${(r:${e}::░:)}"
    _sw_p "${R}"
  }

  _sw_sec() {  # section divider: _sw_sec <title>
    local w
    w=$(( ${COLUMNS:-80} - 4 ))
    (( w < 8 )) && w=8
    _sw_pn ""
    _sw_pn "  ${SEC}${1}${R}"
    _sw_p  "  ${DIMMER}${(r:${w}::─:)}${R}"
    _sw_pn ""
  }

  _sw_temp_row() {  # temp bar row: _sw_temp_row <label> <degrees>
    local col temp label
    label=${1}; temp=${2:-0}
    col=$(_sw_temp_color "${temp}")
    _sw_p  "  ${LBL}${(r:18:)label}${R} "
    _sw_bar "${temp}" "${T_MAX}" "${col}"
    _sw_pn " ${col}${(l:5:)temp} °C${R}"
  }

  _sw_freq_row() {  # freq bar row: _sw_freq_row <label> <mhz> [max]
    local col mhz max label
    label=${1}; mhz=${2:-0}; max=${3:-${CPU_MAX}}
    col=$(_sw_freq_color "${mhz}" "${max}")
    _sw_p  "  ${LBL}${(r:18:)label}${R} "
    _sw_bar "${mhz}" "${max}" "${col}"
    _sw_pn " ${col}${(l:5:)mhz} MHz${R}"
  }

  _sw_percent_row() {  # percent bar row: _sw_percent_row <label> <pct>
    local col pct label
    label=${1}; pct=${2:-0}
    col=$(_sw_percent_color "${pct}")
    _sw_p  "  ${LBL}${(r:18:)label}${R} "
    _sw_bar "${pct}" 100 "${col}"
    _sw_pn " ${col}${(l:5:)pct} %${R}"
  }

  _sw_rpm_row() {  # fan bar row: _sw_rpm_row <label> <rpm>
    local rpm label
    label=${1}; rpm=${2:-0}
    _sw_p  "  ${LBL}${(r:18:)label}${R} "
    _sw_bar "${rpm}" "${FAN_MAX}" "${BLU}"
    _sw_pn " ${BLU}${(l:5:)rpm} RPM${R}"
  }

  _sw_restore_terminal() {
    tput rmcup 2>/dev/null
    printf '%s' $'\e[?25h'
  }

  # ── data collectors ──────────────────────────────────────────────────────────
  # Sensors is called once per frame; helpers accept that cached output to avoid
  # redundant forks, and only call sensors themselves when used standalone.

  _sw_from_block() {  # _sw_from_block <adapter> <label> [sensors_output]
    local input
    if (( $# >= 3 )); then
      input="${3}"
    else
      input=$(sensors 2>/dev/null)
    fi
    printf '%s' "${input}" | awk -v a="${1}" -v l="${2}" '
      /^$/ { b=0; next }
      !b   { if (index($0, a)) b=1; next }
      b && index($0, l) {
        match($0, /[+-]?[0-9]+\.[0-9]+/, r)
        printf "%d", r[0]+0; exit
      }'
  }

  _sw_core_max_temp() {  # _sw_core_max_temp [sensors_output]
    local input
    if (( $# >= 1 )); then
      input="${1}"
    else
      input=$(sensors 2>/dev/null)
    fi
    printf '%s' "${input}" | awk '
      /^$/ { b=0; next }
      !b   { if (index($0, "coretemp-isa")) b=1; next }
      b && /Core [0-9]+:/ {
        match($0, /\+([0-9]+\.[0-9]+)/, r); v=r[1]+0; if (v>m) m=v
      }
      END { printf "%d", (m ? m : 0) }'
  }

  _sw_ram_temps() {  # returns one temp per line for all spd5118 DIMMs
    local input
    if (( $# >= 1 )); then
      input="${1}"
    else
      input=$(sensors 2>/dev/null)
    fi
    printf '%s' "${input}" | awk '
      /^spd5118/               { b=1; next }
      /^[a-zA-Z].*-[0-9]/     { b=0 }
      b && /temp1:/ {
        match($0, /\+([0-9]+\.[0-9]+)/, r)
        printf "%d\n", r[1]+0
      }'
  }

  _sw_fan() {  # _sw_fan <fanline> [sensors_output]
    local input
    if (( $# >= 2 )); then
      input="${2}"
    else
      input=$(sensors 2>/dev/null)
    fi
    printf '%s' "${input}" | awk -v f="${1}" '
      /^$/ { b=0; next }
      !b   { if (index($0, "thinkpad-isa")) b=1; next }
      b && index($0, f) {
        match($0, /([0-9]+) RPM/, r); printf "%d", r[1]+0; exit
      }'
  }

  _sw_freq_summary() {
    awk '
      /^cpu MHz/ { v=int($4); if(v<mn||mn=="")mn=v; if(v>mx)mx=v; s+=v; c++; if(v>800)ac++ }
      END { printf "%d %d %d %d %d", mn+0, mx+0, (c?int(s/c):0), c+0, ac+0 }
    ' /proc/cpuinfo
  }

  _sw_pstate_info() {
    local nt hb mn mx epp gov ts
    nt=$(< /sys/devices/system/cpu/intel_pstate/no_turbo              2>/dev/null) || nt=1
    hb=$(< /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost     2>/dev/null) || hb=0
    mn=$(< /sys/devices/system/cpu/intel_pstate/min_perf_pct          2>/dev/null) || mn=0
    mx=$(< /sys/devices/system/cpu/intel_pstate/max_perf_pct          2>/dev/null) || mx=100
    epp=$(< /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null) || epp='?'
    gov=$(< /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor     2>/dev/null) || gov='?'
    (( nt == 0 )) && ts='on' || ts='off'
    printf '%s %s %s %s %s %s' "${gov}" "${epp}" "${ts}" "${hb}" "${mn}" "${mx}"
  }

  _sw_battery() {
    local en ef pn st
    en=$(< /sys/class/power_supply/BAT0/energy_now  2>/dev/null) || en=0
    ef=$(< /sys/class/power_supply/BAT0/energy_full 2>/dev/null) || ef=1
    pn=$(< /sys/class/power_supply/BAT0/power_now   2>/dev/null) || pn=0
    st=$(< /sys/class/power_supply/BAT0/status      2>/dev/null) || st='?'
    # Newline-separated so multi-word status (e.g. "Not charging") is preserved
    printf '%d\n%d\n%s\n' "$(( ef > 0 ? en * 100 / ef : 0 ))" "$(( pn / 1000 ))" "${st}"
  }

  _sw_nvidia() {
    if (( NO_NVIDIA )); then
      printf '0 0 0 0 disabled 0 0 0'
      return
    fi
    if ! command -v nvidia-smi &>/dev/null; then
      printf '0 0 0 0 unavailable 0 0 0'
      return
    fi
    local query raw
    query='clocks.current.graphics,clocks.current.memory,utilization.gpu'
    query+=',power.draw,pstate,memory.used,memory.total,temperature.gpu'
    raw=$(nvidia-smi \
      --query-gpu="${query}" \
      --format=csv,noheader,nounits 2>/dev/null)
    if [[ -z "${raw}" ]]; then
      printf '0 0 0 0 suspended 0 0 0'
      return
    fi
    printf '%s' "${raw}" | awk -F', ' 'NR == 1 {
      gsub(/ /, "", $5)
      gsub(/[^0-9]/, "", $3)
      printf "%d %d %d %.0f %s %d %d %d", $1,$2,$3,$4,$5,$6,$7,$8
      exit
    }'
  }

  _sw_cpu_max() {
    # Non-zero TW_CPU_MAX_MHZ = use it as the bar ceiling; 0 = auto from sysfs
    (( CPU_MAX > 0 )) && { printf '%d' "${CPU_MAX}"; return; }
    local v
    v=$(< /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
    printf '%d' "$(( ${v:-5400000} / 1000 ))"
  }

  _sw_nvidia_max() {
    # Non-zero TW_GPU_MAX_MHZ = use it as the bar ceiling; 0 = auto from nvidia-smi
    (( GPU_MAX_DEF > 0 )) && { printf '%d' "${GPU_MAX_DEF}"; return; }
    if (( NO_NVIDIA )) || ! command -v nvidia-smi &>/dev/null; then
      printf '%d' "${GPU_MAX_DEF}"
      return
    fi
    local v
    v=$(nvidia-smi --query-gpu=clocks.max.graphics --format=csv,noheader,nounits 2>/dev/null)
    v=${v%%$'\n'*}
    v=${v//[[:space:]]/}
    v=$(_sw_int_or "${v}" 1000)
    printf '%d' "${v:-1000}"
  }

  _sw_mem_max() {
    # Non-zero TW_MEM_MAX_MHZ = use it as the bar ceiling; 0 = auto from nvidia-smi
    (( MEM_MAX > 0 )) && { printf '%d' "${MEM_MAX}"; return; }
    if (( NO_NVIDIA )) || ! command -v nvidia-smi &>/dev/null; then
      printf '%d' "${MEM_MAX}"
      return
    fi
    local v
    v=$(nvidia-smi --query-gpu=clocks.max.memory --format=csv,noheader,nounits 2>/dev/null)
    v=${v%%$'\n'*}
    v=${v//[[:space:]]/}
    v=$(_sw_int_or "${v}" 9001)
    printf '%d' "${v:-9001}"
  }

  _sw_nvidia_procs() {  # returns lines: "mem_mib name" sorted desc by mem
    local limit=${1:-5}
    if (( NO_NVIDIA )) || ! command -v nvidia-smi &>/dev/null; then
      return
    fi
    nvidia-smi 2>/dev/null | awk -v lim="${limit}" '
      BEGIN { FS="|"; count=0 }
      /^\| *[0-9]+ +[A-Z0-9\/N]+.*MiB/ {
        line = $2; gsub(/^ +| +$/, "", line)
        n = split(line, f, / +/)
        mem_str = f[n]; gsub(/MiB/, "", mem_str); mem = mem_str + 0
        if (mem <= 0) next
        name = f[6]
        for (i = 7; i < n; i++) name = name " " f[i]
        sub(/.*\//, "", name)
        if (length(name) > 18) name = substr(name, 1, 18)
        lines[count] = mem " " name; count++
      }
      END {
        for (i = 0; i < count-1; i++)
          for (j = i+1; j < count; j++) {
            split(lines[i], a); split(lines[j], b)
            if (b[1]+0 > a[1]+0) { tmp=lines[i]; lines[i]=lines[j]; lines[j]=tmp }
          }
        for (i = 0; i < count && i < lim; i++) print lines[i]
      }'
  }

  _sw_cpu_top_procs() {  # returns lines: "pct name" sorted desc by cpu%
    local limit=${1:-5}
    ps -eo pcpu,etimes,comm --no-headers --sort=-pcpu 2>/dev/null | \
      awk -v lim="${limit}" '
        $2+0 < 5  { next }
        $1+0 <= 0 { next }
        ++count <= lim { name = substr($3, 1, 18); printf "%.1f %s\n", $1+0, name }
      '
  }

  _sw_mem_top_procs() {  # returns lines: "pct rss_mib name" sorted desc by mem%
    local limit=${1:-5}
    ps -eo pmem,rss,etimes,comm --no-headers --sort=-pmem 2>/dev/null | \
      awk -v lim="${limit}" '
        $3+0 < 5  { next }
        $1+0 <= 0 { next }
        ++count <= lim { name = substr($4, 1, 18); printf "%.1f %d %s\n", $1+0, int($2/1024), name }
      '
  }

  # per-core lines: "mhz cpu coreid temp" sorted desc by mhz
  # coretemp "Core N" == /proc/cpuinfo "core id" N (direct match, no topology math)
  _sw_core_lines() {
    local limit=${1:-0}
    local sout
    if (( $# >= 2 )); then
      sout="${2}"
    else
      sout=$(sensors 2>/dev/null)
    fi

    local -A ct cm_mhz cm_coreid
    local ci tmp mz coreid

    # Build core-id → temp map from coretemp
    while IFS=' ' read -r ci tmp; do
      ct[${ci}]=${tmp}
    done < <(printf '%s' "${sout}" | awk '
      /^$/ { b=0; next }
      !b   { if (index($0, "coretemp-isa")) b=1; next }
      b && /Core [0-9]+:/ {
        match($0, /Core ([0-9]+):/, ci)
        match($0, /\+([0-9]+\.[0-9]+)/, tr)
        printf "%d %d\n", ci[1], tr[1]+0
      }')

    # Build logical-cpu → mhz + coreid map from /proc/cpuinfo
    # Block format: processor → core id → cpu MHz → blank line
    while IFS=' ' read -r ci coreid mz; do
      cm_mhz[${ci}]=${mz}
      cm_coreid[${ci}]=${coreid}
    done < <(awk '
      /^processor/ { cpu=$3;  coreid=""; mhz="" }
      /^core id/   { coreid=$4 }
      /^cpu MHz/   { mhz=$4 }
      /^$/ {
        if (cpu!="" && coreid!="" && mhz!="")
          printf "%d %d %.0f\n", cpu, coreid, mhz
        cpu=""; coreid=""; mhz=""
      }
      END {
        if (cpu!="" && coreid!="" && mhz!="")
          printf "%d %d %.0f\n", cpu, coreid, mhz
      }' /proc/cpuinfo)

    # Combine into sortable lines
    local lines=() ph n=0 line
    for ci in "${(@k)cm_mhz}"; do
      ph=${cm_coreid[${ci}]:-0}
      lines+=("${cm_mhz[${ci}]} ${ci} ${ph} ${ct[${ph}]:-0}")
    done

    # Sort descending by mhz, emit up to limit
    for line in "${(On)lines[@]}"; do
      (( limit > 0 && n >= limit )) && break
      printf '%s\n' "${line}"
      (( n++ ))
    done
  }

  # ── init ─────────────────────────────────────────────────────────────────────
  cpu_model=$(awk -F': ' '/^model name/{gsub(/\(R\)|\(TM\)/,"",$2); gsub(/  +/," ",$2); print $2; exit}' /proc/cpuinfo)
  CPU_MAX=$(_sw_cpu_max)
  nvidia_max=$(_sw_nvidia_max)
  mem_max=$(_sw_mem_max)
  interval_cs=$(_sw_centiseconds "${interval}" "${interval_default}")
  (( interval_cs < INTERVAL_MIN_CS )) && interval_cs=${INTERVAL_MIN_CS}
  (( interval_cs > INTERVAL_MAX_CS )) && interval_cs=${INTERVAL_MAX_CS}
  rapl_e_prev=0
  rapl_t_prev=0
  rapl_pkg_w=0

  printf '%s' $'\e[?25l'
  tput smcup 2>/dev/null
  trap _sw_restore_terminal EXIT
  trap 'return 130' INT TERM

  # ── main loop ────────────────────────────────────────────────────────────────
  while true; do
    now_cs=$(( EPOCHREALTIME * 100 ))
    key=''
    IFS= read -r -s -k 1 -t 0.05 key 2>/dev/null || true
    case ${key} in
      q|Q|$'\x04') break ;;
      +)   (( interval_cs -= 50 )); (( interval_cs < INTERVAL_MIN_CS )) && interval_cs=${INTERVAL_MIN_CS} ;;
      -)   (( interval_cs += 50 )); (( interval_cs > INTERVAL_MAX_CS )) && interval_cs=${INTERVAL_MAX_CS} ;;
      c)   (( SHOW_CORES  ^= 1 )) ;;
      n)   (( SHOW_NVIDIA ^= 1 )) ;;
      p)   (( SHOW_PROCS  ^= 1 )) ;;
      h)   (( SHOW_HELP   ^= 1 )) ;;
    esac

    if (( now_cs - last_cs >= interval_cs )); then
      last_cs=${now_cs}

      # ── collect — run sensors once, pass cached output to all collectors ────
      sdata=$(sensors 2>/dev/null)

      cpu_pkg=$(_sw_from_block   'coretemp-isa' 'Package id 0:' "${sdata}")
      cpu_cmax=$(_sw_core_max_temp                               "${sdata}")
      gpu_ec=$(_sw_from_block    'thinkpad-isa' 'GPU:'          "${sdata}")
      nvme=$(_sw_from_block      'nvme-pci'     'Composite:'    "${sdata}")
      ram_dimms=("${(@f)$(_sw_ram_temps "${sdata}")}")
      ram_dimms=("${(@)ram_dimms:#}")
      wifi=$(_sw_from_block      'iwlwifi'      'temp1:'        "${sdata}")
      fan1=$(_sw_fan             'fan1:'                        "${sdata}")
      fan2=$(_sw_fan             'fan2:'                        "${sdata}")

      fs=($(_sw_freq_summary))
      fmin=${fs[1]}; fmax=${fs[2]}; favg=${fs[3]}; ncpu=${fs[4]}; nact=${fs[5]}

      ps=($(_sw_pstate_info))
      gov=${ps[1]}; epp=${ps[2]}; turbo=${ps[3]}; hwpb=${ps[4]}; pmin=${ps[5]}; pmax=${ps[6]}

      prof=$(< /sys/firmware/acpi/platform_profile 2>/dev/null) || prof='?'
      pwrsrc=$(< /sys/class/power_supply/AC/online 2>/dev/null) || pwrsrc='0'
      [[ "${pwrsrc}" == '1' ]] && pwrsrc='AC' || pwrsrc='BAT'

      bi=("${(@f)$(_sw_battery)}")
      bpct=${bi[1]}; bwatt=${bi[2]}; bst=${bi[3]}

      # RAPL CPU package power (uJ counter delta / us elapsed = W)
      rapl_e_now=$(< /sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj 2>/dev/null) || rapl_e_now=0
      rapl_t_now=$(( EPOCHREALTIME * 1000000 ))
      if (( rapl_e_prev > 0 && rapl_t_now > rapl_t_prev )); then
        rapl_de=$(( rapl_e_now - rapl_e_prev ))
        if (( rapl_de < 0 )); then
          rapl_emax=$(< /sys/class/powercap/intel-rapl/intel-rapl:0/max_energy_range_uj 2>/dev/null) || rapl_emax=0
          (( rapl_emax > 0 )) && rapl_de=$(( rapl_de + rapl_emax ))
        fi
        rapl_dt=$(( rapl_t_now - rapl_t_prev ))
        (( rapl_dt > 0 )) && rapl_pkg_w=$(( rapl_de / rapl_dt )) || rapl_pkg_w=0
      fi
      rapl_e_prev=${rapl_e_now}
      rapl_t_prev=${rapl_t_now}

      nv=($(_sw_nvidia))
      nvc=${nv[1]}; nvm=${nv[2]}; nvu=${nv[3]}; nvp=${nv[4]}
      nvps=${nv[5]}; nvvu=${nv[6]}; nvvt=${nv[7]}; nvt=${nv[8]}
      sys_pwr_w=$(( rapl_pkg_w + nvp ))

      read ram_used ram_total < <(awk '
        /^MemTotal/     { t=$2 }
        /^MemAvailable/ { a=$2 }
        END { printf "%d %d", int((t-a)/1024), int(t/1024) }
      ' /proc/meminfo)

      cl=()
      (( SHOW_CORES )) && cl=("${(@f)$(_sw_core_lines ${TOP_CORES} "${sdata}")}")
      cl=("${(@)cl:#}")

      gpu_procs=(); cpu_procs=(); mem_procs=()
      if (( SHOW_PROCS && TOP_PROCS > 0 )); then
        (( ! NO_NVIDIA )) && command -v nvidia-smi &>/dev/null && \
          gpu_procs=("${(@f)$(_sw_nvidia_procs ${TOP_PROCS})}")
        cpu_procs=("${(@f)$(_sw_cpu_top_procs ${TOP_PROCS})}")
        mem_procs=("${(@f)$(_sw_mem_top_procs ${TOP_PROCS})}")
        gpu_procs=("${(@)gpu_procs:#}")
        cpu_procs=("${(@)cpu_procs:#}")
        mem_procs=("${(@)mem_procs:#}")
      fi

      # ── build frame buffer ───────────────────────────────────────────────────
      _buf=''
      printf -v disp_int '%.1f' "$(( interval_cs / 100.0 ))"
      ts=$(date '+%H:%M:%S')

      _sw_pn ""
      _sw_p  "  ${TTL}syswatch${R}  ${DIM}${ts}  ${disp_int}s  +/- speed  c cores  n gpu  p procs  q quit${R}"
      if (( SHOW_HELP )); then
        _sw_pn ""
        _sw_pn "  ${DIM}TW_CORES=N  TW_INTERVAL=N  TW_INTERVAL_MIN=N  TW_INTERVAL_MAX=N${R}"
        _sw_pn "  ${DIM}TW_TEMP_WARN=N  TW_TEMP_HOT=N  TW_TEMP_CRIT=N  TW_NO_NVIDIA=1  TW_TOP_PROCS=N${R}"
        _sw_pn "  ${DIM}TW_CPU_MAX_MHZ=N  TW_GPU_MAX_MHZ=N  TW_MEM_MAX_MHZ=N  TW_FAN_MAX_RPM=N${R}"
      fi
      _sw_pn ""

      # system bar
      bcol="${GRN}"
      [[ "${bst}" == 'Charging'    ]] && bcol="${BLU}"
      [[ "${bst}" == 'Discharging' ]] && (( bpct < 40 )) && bcol="${ORG}"
      [[ "${bst}" == 'Discharging' ]] && (( bpct < 20 )) && bcol="${RED}"
      _sw_p  "  ${LBL}src${R} ${ACC}${pwrsrc}${R}"
      _sw_p  "   ${LBL}bat${R} ${bcol}${(l:3:)bpct}% ${bst:l} ${(l:3:)bwatt}W${R}"
      _sw_p  "   ${LBL}sys pwr${R} $(_sw_watt_color ${sys_pwr_w})${(l:3:)sys_pwr_w}W${R}"
      _sw_p  "   ${LBL}profile${R} ${ACC}${prof}${R}"
      _sw_pn "   ${LBL}cores${R} ${ACC}${nact}/${ncpu}${R}"

      # ── CPU ─────────────────────────────────────────────────────────────────
      _sw_sec "CPU  (${cpu_model})"
      _sw_temp_row "package id 0"  "${cpu_pkg:-0}"
      _sw_temp_row "core max"      "${cpu_cmax:-0}"
      _sw_pn ""
      _sw_freq_row "freq min"      "${fmin:-0}"
      _sw_freq_row "freq avg"      "${favg:-0}"
      _sw_freq_row "freq max"      "${fmax:-0}"
      _sw_pn ""
      _sw_p  "  ${LBL}gov${R} ${ACC}${gov}${R}"
      _sw_p  "   ${LBL}epp${R} ${ACC}${epp}${R}"
      _sw_p  "   ${LBL}turbo${R} ${ACC}${turbo}${R}"
      _sw_p  "   ${LBL}hwp boost${R} ${ACC}${hwpb}${R}"
      _sw_p  "   ${LBL}perf${R} ${ACC}${pmin}-${pmax}%${R}"
      _sw_pn "   ${LBL}cpu pwr${R} $(_sw_watt_color ${rapl_pkg_w})${(l:3:)rapl_pkg_w}W${R}"

      # ── per-core ────────────────────────────────────────────────────────────
      if (( SHOW_CORES )) && (( ${#cl[@]} > 0 )); then
        clabel="all ${ncpu} cores"
        (( TOP_CORES > 0 )) && clabel="top ${TOP_CORES} of ${ncpu} cores"
        _sw_pn ""
        _sw_pn "  ${SEC}${clabel}${R}"
        for line in "${cl[@]}"; do
          [[ -z "${line}" ]] && continue
          _mhz=${line%% *};    _rest=${line#* }
          _cpu=${_rest%% *};   _rest=${_rest#* }
          _phys=${_rest%% *};  _temp=${_rest#* }
          (( _mhz < 100 )) && _mhz=0
          cf=$(_sw_freq_color "${_mhz}" "${CPU_MAX}")
          ct2=$(_sw_temp_color "${_temp:-0}")
          # P-cores: core id < 32   E-cores: core id >= 32
          ctype='E'; (( _phys < 32 )) && ctype='P'
          _name="c${(l:2::0:)_cpu}[${ctype}]"
          _sw_p "  ${DIM}${(r:18:)_name}${R} "
          _sw_bar "${_mhz}" "${CPU_MAX}" "${cf}"
          _sw_p " ${cf}${(l:5:)_mhz} MHz${R}"
          (( _temp > 0 )) && _sw_p "  ${ct2}${(l:5:)_temp} °C${R}"
          _sw_pn ""
        done
      fi

      if (( SHOW_PROCS )) && (( ${#cpu_procs[@]} > 0 )); then
        _sw_pn ""
        _sw_pn "  ${SEC}top cpu processes${R}${DIM}  (cpu%)${R}"
        for line in "${cpu_procs[@]}"; do
          [[ -z "${line}" ]] && continue
          _pct=${line%% *}; _name=${line#* }
          _pct_i=${_pct%%.*}
          _col_proc=$(_sw_percent_color "${_pct_i}")
          _sw_p  "  ${LBL}${(r:18:)_name}${R} "
          _sw_bar "${_pct_i}" 100 "${_col_proc}"
          _sw_pn " ${_col_proc}${(l:5:)_pct} %${R}"
        done
      fi

      # ── GPU ─────────────────────────────────────────────────────────────────
      if (( SHOW_NVIDIA )); then
        _sw_sec "GPU  (RTX 4000 Ada)"
        if [[ "${nvps}" == 'disabled' ]]; then
          _sw_pn "  ${DIM}nvidia-smi disabled by TW_NO_NVIDIA=1${R}"
        elif [[ "${nvps}" == 'unavailable' ]]; then
          _sw_pn "  ${DIM}nvidia-smi unavailable${R}"
        elif [[ "${nvps}" == 'suspended' ]] || (( nvc == 0 && nvu == 0 )); then
          _sw_temp_row "gpu temp (EC)"  "${gpu_ec:-0}"
          _sw_pn "  ${DIM}suspended — RTD3/D3cold${R}"
        else
          _sw_temp_row "gpu temp"       "${nvt:-0}"
          _sw_temp_row "gpu temp (EC)"  "${gpu_ec:-0}"
          _sw_pn ""
          _sw_freq_row "core clock"     "${nvc:-0}"   "${nvidia_max}"
          _sw_freq_row "mem clock"      "${nvm:-0}"   "${mem_max}"
          _sw_percent_row "utilization" "${nvu:-0}"
          if (( nvvt > 0 )); then
            vp=$(( nvvu * 100 / nvvt ))
            vc=$(_sw_percent_color "${vp}")
            _name=" ${nvvt} MiB"
            _sw_p  "  ${LBL}vram${R}${DIM}${(r:14:)_name}${R} "
            _sw_bar "${nvvu}" "${nvvt}" "${vc}"
            _sw_pn " ${vc}${(l:5:)nvvu} MiB${R}"
          fi
          _sw_pn ""
          _sw_pn "  ${LBL}pstate${R} ${ACC}${nvps}${R}   ${LBL}gpu pwr${R} $(_sw_watt_color ${nvp})${(l:3:)nvp}W${R}"

          if (( SHOW_PROCS )) && (( ${#gpu_procs[@]} > 0 )); then
            _sw_pn ""
            _sw_pn "  ${SEC}top gpu processes${R}${DIM}  (vram%)${R}"
            for line in "${gpu_procs[@]}"; do
              [[ -z "${line}" ]] && continue
              _mem=${line%% *}; _name=${line#* }
              vp=$(( nvvt > 0 ? _mem * 100 / nvvt : 0 ))
              vc=$(_sw_percent_color "${vp}")
              _sw_p  "  ${LBL}${(r:18:)_name}${R} "
              _sw_bar "${vp}" 100 "${vc}"
              _sw_pn " ${vc}${(l:5:)vp} %${R}${DIM}  ${(l:5:)_mem} MiB${R}"
            done
          fi
        fi
      fi

      # ── Memory ──────────────────────────────────────────────────────────────
      _sw_sec "Memory"
      if (( ram_total > 0 )); then
        rp=$(( ram_used * 100 / ram_total ))
        rc=$(_sw_percent_color "${rp}")
        _name=" ${ram_total} MiB"
        _sw_p  "  ${LBL}ram${R}${DIM}${(r:15:)_name}${R} "
        _sw_bar "${ram_used}" "${ram_total}" "${rc}"
        _sw_pn " ${rc}${(l:5:)ram_used} MiB${R}"
      fi
      if (( ${#ram_dimms[@]} > 0 )); then
        di=1; _pct_i=1
        for v in "${ram_dimms[@]}"; do
          if (( v > 0 )); then
            (( _pct_i )) && _sw_p "  " || _sw_p "   "
            _pct_i=0
            _sw_p "${LBL}dimm${di}${R} $(_sw_temp_color ${v})${(l:3:)v}°C${R}"
          fi
          (( di++ ))
        done
        _sw_pn ""
      fi

      if (( SHOW_PROCS )) && (( ${#mem_procs[@]} > 0 )); then
        _sw_pn ""
        _sw_pn "  ${SEC}top mem processes${R}${DIM}  (mem%)${R}"
        for line in "${mem_procs[@]}"; do
          [[ -z "${line}" ]] && continue
          _pct=${line%% *};  _rest=${line#* }
          _mem=${_rest%% *}; _name=${_rest#* }
          _pct_i=${_pct%%.*}
          _col_proc=$(_sw_percent_color "${_pct_i}")
          _sw_p  "  ${LBL}${(r:18:)_name}${R} "
          _sw_bar "${_pct_i}" 100 "${_col_proc}"
          _sw_pn " ${_col_proc}${(l:5:)_pct} %${R}${DIM}  ${(l:5:)_mem} MiB${R}"
        done
      fi

      # ── Storage / Network / Fans ─────────────────────────────────────────────
      _sw_sec "Storage / Network / Fans"
      [[ ${nvme:-0} -gt 0 ]] && _sw_pn "  ${LBL}nvme${R} $(_sw_temp_color ${nvme})${nvme}°C${R}"
      [[ ${wifi:-0} -gt 0 ]] && _sw_pn "  ${LBL}wifi${R} $(_sw_temp_color ${wifi})${wifi}°C${R}"
      if (( fan1 > 0 || fan2 > 0 )); then
        _sw_pn ""
        _sw_rpm_row "fan1" "${fan1:-0}"
        _sw_rpm_row "fan2" "${fan2:-0}"
      else
        _sw_pn "  ${DIM}fan sensors unavailable${R}"
      fi

      # ── atomic flush — overwrite in place, then erase any leftover lines ───────
      printf '%s' $'\e[H'
      _sw_flush
      printf '%s' $'\e[J'
    fi

    sleep 0.05
  done
}
