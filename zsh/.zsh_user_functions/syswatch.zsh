# ── syswatch ───────────────────────────────────────────────────────────────────
# All-in-one performance & thermal monitor for ThinkPad P16 Gen 2 (zsh)
#
# Usage:  syswatch [interval]   (default: 0.5s, decimals ok)
#
# Environment variables:
#   TW_INTERVAL=0.5          default refresh interval (seconds)
#   TW_INTERVAL_MIN=0.5      minimum interval (+key floor)
#   TW_INTERVAL_MAX=10       maximum interval (-key ceiling)
#   TW_CORES=0               cores to show, 0=all
#   TW_TEMP_WARN=60          °C yellow threshold
#   TW_TEMP_HOT=75           °C orange threshold
#   TW_TEMP_CRIT=85          °C red threshold (also temp bar max)
#   TW_CPU_MAX_MHZ=5400      CPU freq bar ceiling        (0 = auto from cpuinfo_max_freq) *
#   TW_GPU_MAX_MHZ=2400      GPU core clock bar ceiling (0 = auto from nvidia-smi) *
#   TW_MEM_MAX_MHZ=9001      GPU mem clock bar ceiling  (0 = auto from nvidia-smi) *
#   TW_FAN_MAX_RPM=5500      fan RPM bar ceiling
#   TW_NO_NVIDIA=1           disable all nvidia-smi calls
#
# * setting to 0 queries nvidia-smi at startup for the real max clock
#
# Keys:  q quit  +/- speed  c cores  n gpu  h help
# ──────────────────────────────────────────────────────────────────────────────

syswatch() {
  emulate -L zsh
  setopt local_options pipe_fail

  # ── declare all locals up front to prevent zsh assignment leaks ──────────────
  # Config
  local interval
  local INTERVAL_MIN_CS INTERVAL_MAX_CS
  local TOP_CORES T_WARN T_HOT T_CRIT T_MAX
  local CPU_MAX GPU_MAX_DEF MEM_MAX FAN_MAX
  local NO_NVIDIA
  local SHOW_CORES SHOW_NVIDIA SHOW_HELP

  # Colors
  local R DIM DIMMER LBL ACC TTL SEC GRN YLW ORG RED BLU

  # Init-time
  local cpu_model nvidia_max mem_max interval_cs last_cs
  local rapl_e_prev rapl_t_prev rapl_pkg_w

  # Per-frame data
  local now_cs key
  local cpu_pkg cpu_cmax gpu_ec nvme wifi fan1 fan2
  local -a fs ps bi nv cl ram_dimms
  local fmin fmax favg ncpu nact
  local gov epp turbo hwpb pmin pmax
  local prof pwrsrc
  local bpct bwatt bst
  local nvc nvm nvu nvp nvps nvvu nvvt nvt
  local ram_used ram_total
  local rapl_e_now rapl_t_now rapl_de rapl_dt rapl_emax sys_pwr_w

  # Render temporaries
  local _buf disp_int ts bcol clabel di
  local line _mhz _rest _cpu _phys _temp cf ct2 ctype
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
  : ${TW_CPU_MAX_MHZ:=0}       # CPU freq bar ceiling        (0 = auto from cpuinfo_max_freq) *
  : ${TW_GPU_MAX_MHZ:=0}       # GPU core clock bar ceiling (0 = auto from nvidia-smi) *
  : ${TW_MEM_MAX_MHZ:=0}       # GPU mem clock bar ceiling  (0 = auto from nvidia-smi) *
  : ${TW_FAN_MAX_RPM:=5500}    # fan RPM bar ceiling
  : ${TW_NO_NVIDIA:=0}         # set to 1 to disable all nvidia-smi calls

  # ── config assignments ───────────────────────────────────────────────────────
  interval=${1:-${TW_INTERVAL}}
  INTERVAL_MIN_CS=$(( int(TW_INTERVAL_MIN * 100) ))
  INTERVAL_MAX_CS=$(( int(TW_INTERVAL_MAX * 100) ))
  TOP_CORES=${TW_CORES}
  T_WARN=${TW_TEMP_WARN}
  T_HOT=${TW_TEMP_HOT}
  T_CRIT=${TW_TEMP_CRIT}
  T_MAX=$(( T_CRIT + 15 ))   # temp bar scale: crit+15 = 100%
  CPU_MAX=${TW_CPU_MAX_MHZ}
  GPU_MAX_DEF=${TW_GPU_MAX_MHZ}
  MEM_MAX=${TW_MEM_MAX_MHZ}
  FAN_MAX=${TW_FAN_MAX_RPM}
  NO_NVIDIA=${TW_NO_NVIDIA}
  SHOW_CORES=1
  SHOW_NVIDIA=1
  SHOW_HELP=0
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
  # All rendering appends to _buf; _flush prints atomically to avoid flicker.
  _buf=''
  _p()     { _buf+="${*}"; }
  _pn()    { _buf+="${*}"$'\n'; }
  _flush() { printf '%s' "${_buf}"; _buf=''; }

  # ── color selectors — return ANSI escape to stdout for use in $(...) ─────────
  _tc() {   # temp color: _tc <degrees>
    if   (( $1 < T_WARN )); then printf '%s' $'\e[92m'
    elif (( $1 < T_HOT  )); then printf '%s' $'\e[93m'
    elif (( $1 < T_CRIT )); then printf '%s' $'\e[38;5;208m'
    else                         printf '%s' $'\e[91m'
    fi
  }
  _fc() {   # freq color: _fc <mhz> [max]
    local pct
    pct=$(( ${1} * 100 / ( ${2:-${CPU_MAX}} > 0 ? ${2:-${CPU_MAX}} : 1 ) ))
    if   (( pct < 25 )); then printf '%s' $'\e[92m'
    elif (( pct < 55 )); then printf '%s' $'\e[93m'
    elif (( pct < 80 )); then printf '%s' $'\e[38;5;208m'
    else                      printf '%s' $'\e[91m'
    fi
  }
  _pc() {   # percent color: _pc <pct>
    if   (( $1 < 30 )); then printf '%s' $'\e[92m'
    elif (( $1 < 60 )); then printf '%s' $'\e[93m'
    elif (( $1 < 85 )); then printf '%s' $'\e[38;5;208m'
    else                     printf '%s' $'\e[91m'
    fi
  }
  _wc() {   # watt color: _wc <watts>
    if   (( $1 < 20 )); then printf '%s' $'\e[92m'
    elif (( $1 < 45 )); then printf '%s' $'\e[93m'
    elif (( $1 < 80 )); then printf '%s' $'\e[38;5;208m'
    else                     printf '%s' $'\e[91m'
    fi
  }

  # ── render primitives ────────────────────────────────────────────────────────
  _bw() {   # bar width based on terminal width
    local bw
    bw=$(( ${COLUMNS:-80} - 32 ))
    (( bw <  8 )) && bw=8
    (( bw > 36 )) && bw=36
    printf '%d' "${bw}"
  }

  _bar() {  # _bar <val> <max> <color>
    local bw val max f e
    bw=$(_bw)
    val=${1}; max=${2}
    f=$(( val * bw / ( max > 0 ? max : 1 ) ))
    (( f > bw )) && f=${bw}
    (( f < 0  )) && f=0
    e=$(( bw - f ))
    _p "${3}"
    (( f > 0 )) && _p "${(r:${f}::█:)}"
    _p "${DIMMER}"
    (( e > 0 )) && _p "${(r:${e}::░:)}"
    _p "${R}"
  }

  _sec() {  # section divider: _sec <title>
    local w
    w=$(( ${COLUMNS:-80} - 4 ))
    (( w < 8 )) && w=8
    _pn ""
    _pn "  ${SEC}${1}${R}"
    _p  "  ${DIMMER}${(r:${w}::─:)}${R}"
    _pn ""
  }

  _trow() {  # temp bar row: _trow <label> <degrees>
    local col temp label
    label=${1}; temp=${2:-0}
    col=$(_tc "${temp}")
    _p  "  ${LBL}${(r:18:)label}${R} "
    _bar "${temp}" "${T_MAX}" "${col}"
    _pn " ${col}${temp}°C${R}"
  }

  _frow() {  # freq bar row: _frow <label> <mhz> [max]
    local col mhz max label
    label=${1}; mhz=${2:-0}; max=${3:-${CPU_MAX}}
    col=$(_fc "${mhz}" "${max}")
    _p  "  ${LBL}${(r:18:)label}${R} "
    _bar "${mhz}" "${max}" "${col}"
    _pn " ${col}${(l:5:)mhz} MHz${R}"
  }

  _prow() {  # percent bar row: _prow <label> <pct>
    local col pct label
    label=${1}; pct=${2:-0}
    col=$(_pc "${pct}")
    _p  "  ${LBL}${(r:18:)label}${R} "
    _bar "${pct}" 100 "${col}"
    _pn " ${col}${(l:3:)pct}%${R}"
  }

  # ── data collectors ──────────────────────────────────────────────────────────
  # All collectors run sensors/sysfs once per call; sensors is called per-frame
  # in the main loop and results passed where possible to avoid redundant forks.

  _sensors_once() {
    # Cache sensors output for one frame — called once, result stored in $1 (nameref)
    sensors 2>/dev/null
  }

  _from_block() {  # _from_block <adapter> <label> [sensors_output]
    local input
    if [[ -n "${3:-}" ]]; then
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

  _core_max_temp() {  # _core_max_temp [sensors_output]
    local input=${1:-$(sensors 2>/dev/null)}
    printf '%s' "${input}" | awk '
      /^$/ { b=0; next }
      !b   { if (index($0, "coretemp-isa")) b=1; next }
      b && /Core [0-9]+:/ {
        match($0, /\+([0-9]+\.[0-9]+)/, r); v=r[1]+0; if (v>m) m=v
      }
      END { printf "%d", (m ? m : 0) }'
  }

  _ram_temps() {  # returns one temp per line for all spd5118 DIMMs
    local input=${1:-$(sensors 2>/dev/null)}
    printf '%s' "${input}" | awk '
      /^spd5118/               { b=1; next }
      /^[a-zA-Z].*-[0-9]/     { b=0 }
      b && /temp1:/ {
        sub(/.*\+/, ""); sub(/\..*/, "")
        printf "%d\n", $0+0
      }'
  }

  _fan() {  # _fan <fanline> [sensors_output]
    local input=${2:-$(sensors 2>/dev/null)}
    printf '%s' "${input}" | awk -v f="${1}" '
      /^$/ { b=0; next }
      !b   { if (index($0, "thinkpad-isa")) b=1; next }
      b && index($0, f) {
        match($0, /([0-9]+) RPM/, r); printf "%d", r[1]+0; exit
      }'
  }

  _freq_summary() {
    awk '
      /^cpu MHz/ { v=int($4); if(v<mn||mn=="")mn=v; if(v>mx)mx=v; s+=v; c++; if(v>800)ac++ }
      END { printf "%d %d %d %d %d", mn+0, mx+0, (c?int(s/c):0), c+0, ac+0 }
    ' /proc/cpuinfo
  }

  _pstate_info() {
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

  _battery() {
    local en ef pn st
    en=$(< /sys/class/power_supply/BAT0/energy_now  2>/dev/null) || en=0
    ef=$(< /sys/class/power_supply/BAT0/energy_full 2>/dev/null) || ef=1
    pn=$(< /sys/class/power_supply/BAT0/power_now   2>/dev/null) || pn=0
    st=$(< /sys/class/power_supply/BAT0/status      2>/dev/null) || st='?'
    printf '%d %d %s' "$(( ef > 0 ? en * 100 / ef : 0 ))" "$(( pn / 1000 ))" "${st}"
  }

  _nvidia() {
    if (( NO_NVIDIA )) || ! command -v nvidia-smi &>/dev/null; then
      printf '0 0 0 0 unavailable 0 0 0'
      return
    fi
    local raw
    raw=$(nvidia-smi \
      --query-gpu=clocks.gr,clocks.mem,utilization.gpu,power.draw,pstate,memory.used,memory.total,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null)
    if [[ -z "${raw}" ]]; then
      printf '0 0 0 0 suspended 0 0 0'
      return
    fi
    printf '%s' "${raw}" | awk -F', ' '{
      gsub(/ /, "", $5)
      gsub(/[^0-9]/, "", $3)
      printf "%d %d %d %.0f %s %d %d %d", $1,$2,$3,$4,$5,$6,$7,$8
    }'
  }

  _cpu_max() {
    # Non-zero TW_CPU_MAX_MHZ = use it as the bar ceiling; 0 = auto from sysfs
    (( CPU_MAX > 0 )) && { printf '%d' "${CPU_MAX}"; return; }
    local v
    v=$(< /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
    printf '%d' "$(( ${v:-5400000} / 1000 ))"
  }

  _nvidia_max() {
    # Non-zero TW_GPU_MAX_MHZ = use it as the bar ceiling; 0 = auto from nvidia-smi
    (( GPU_MAX_DEF > 0 )) && { printf '%d' "${GPU_MAX_DEF}"; return; }
    if (( NO_NVIDIA )) || ! command -v nvidia-smi &>/dev/null; then
      printf '%d' "${GPU_MAX_DEF}"
      return
    fi
    local v
    v=$(nvidia-smi --query-gpu=clocks.max.gr --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
    printf '%d' "${v:-1000}"
  }

  _mem_max() {
    # Non-zero TW_MEM_MAX_MHZ = use it as the bar ceiling; 0 = auto from nvidia-smi
    (( MEM_MAX > 0 )) && { printf '%d' "${MEM_MAX}"; return; }
    if (( NO_NVIDIA )) || ! command -v nvidia-smi &>/dev/null; then
      printf '%d' "${MEM_MAX}"
      return
    fi
    local v
    v=$(nvidia-smi --query-gpu=clocks.max.mem --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
    printf '%d' "${v:-9001}"
  }

  # per-core lines: "mhz cpu coreid temp" sorted desc by mhz
  # coretemp "Core N" == /proc/cpuinfo "core id" N (direct match, no topology math)
  _core_lines() {
    local limit=${1:-0}
    local sout
    sout=$(sensors 2>/dev/null)

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
  CPU_MAX=$(_cpu_max)
  nvidia_max=$(_nvidia_max)
  mem_max=$(_mem_max)
  interval_cs=$(( int(interval * 100) ))
  (( interval_cs < INTERVAL_MIN_CS )) && interval_cs=${INTERVAL_MIN_CS}
  (( interval_cs > INTERVAL_MAX_CS )) && interval_cs=${INTERVAL_MAX_CS}
  rapl_e_prev=0
  rapl_t_prev=0
  rapl_pkg_w=0

  printf $'\e[?25l'
  tput smcup 2>/dev/null

  # ── main loop ────────────────────────────────────────────────────────────────
  while true; do
    now_cs=$(( int(EPOCHREALTIME * 100) ))
    key=''
    IFS= read -r -s -k 1 -t 0.05 key 2>/dev/null || true
    case ${key} in
      q|Q) break ;;
      +)   (( interval_cs -= 50 )); (( interval_cs < INTERVAL_MIN_CS )) && interval_cs=${INTERVAL_MIN_CS} ;;
      -)   (( interval_cs += 50 )); (( interval_cs > INTERVAL_MAX_CS )) && interval_cs=${INTERVAL_MAX_CS} ;;
      c)   (( SHOW_CORES  ^= 1 )) ;;
      n)   (( SHOW_NVIDIA ^= 1 )) ;;
      h)   (( SHOW_HELP   ^= 1 )) ;;
    esac

    if (( now_cs - last_cs >= interval_cs )); then
      last_cs=${now_cs}

      # ── collect — run sensors once, pass cached output to all collectors ────
      sdata=$(sensors 2>/dev/null)

      cpu_pkg=$(_from_block   'coretemp-isa' 'Package id 0:' "${sdata}")
      cpu_cmax=$(_core_max_temp                               "${sdata}")
      gpu_ec=$(_from_block    'thinkpad-isa' 'GPU:'          "${sdata}")
      nvme=$(_from_block      'nvme-pci'     'Composite:'    "${sdata}")
      ram_dimms=("${(@f)$(_ram_temps "${sdata}")}")
      wifi=$(_from_block      'iwlwifi'      'temp1:'        "${sdata}")
      fan1=$(_fan             'fan1:'                        "${sdata}")
      fan2=$(_fan             'fan2:'                        "${sdata}")

      fs=($(_freq_summary))
      fmin=${fs[1]}; fmax=${fs[2]}; favg=${fs[3]}; ncpu=${fs[4]}; nact=${fs[5]}

      ps=($(_pstate_info))
      gov=${ps[1]}; epp=${ps[2]}; turbo=${ps[3]}; hwpb=${ps[4]}; pmin=${ps[5]}; pmax=${ps[6]}

      prof=$(< /sys/firmware/acpi/platform_profile 2>/dev/null) || prof='?'
      pwrsrc=$(< /sys/class/power_supply/AC/online 2>/dev/null) || pwrsrc='0'
      [[ "${pwrsrc}" == '1' ]] && pwrsrc='AC' || pwrsrc='BAT'

      bi=($(_battery))
      bpct=${bi[1]}; bwatt=${bi[2]}; bst=${bi[3]}

      # RAPL CPU package power (uJ counter delta / us elapsed = W)
      rapl_e_now=$(< /sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj 2>/dev/null) || rapl_e_now=0
      rapl_t_now=$(( int(EPOCHREALTIME * 1000000) ))
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

      nv=($(_nvidia))
      nvc=${nv[1]}; nvm=${nv[2]}; nvu=${nv[3]}; nvp=${nv[4]}
      nvps=${nv[5]}; nvvu=${nv[6]}; nvvt=${nv[7]}; nvt=${nv[8]}
      sys_pwr_w=$(( rapl_pkg_w + nvp ))

      read ram_used ram_total <<< $(awk '
        /^MemTotal/     { t=$2 }
        /^MemAvailable/ { a=$2 }
        END { printf "%d %d", int((t-a)/1024), int(t/1024) }
      ' /proc/meminfo)

      cl=()
      (( SHOW_CORES )) && cl=("${(@f)$(_core_lines ${TOP_CORES})}")

      # ── build frame buffer ───────────────────────────────────────────────────
      _buf=''
      printf -v disp_int '%.1f' "$(( interval_cs / 100.0 ))"
      ts=$(date '+%H:%M:%S')

      _pn ""
      _p  "  ${TTL}syswatch${R}  ${DIM}${ts}  ${disp_int}s  +/- speed  c cores  n gpu  q quit${R}"
      if (( SHOW_HELP )); then
        _pn ""
        _pn "  ${DIM}TW_CORES=N  TW_INTERVAL=N  TW_INTERVAL_MIN=N  TW_INTERVAL_MAX=N${R}"
        _pn "  ${DIM}TW_TEMP_WARN=N  TW_TEMP_HOT=N  TW_TEMP_CRIT=N  TW_NO_NVIDIA=1${R}"
      fi
      _pn ""

      # system bar
      bcol="${GRN}"
      [[ "${bst}" == 'Charging'    ]] && bcol="${BLU}"
      [[ "${bst}" == 'Discharging' ]] && (( bpct < 40 )) && bcol="${ORG}"
      [[ "${bst}" == 'Discharging' ]] && (( bpct < 20 )) && bcol="${RED}"
      _pn "  ${LBL}src${R} ${ACC}${pwrsrc}${R}   ${LBL}bat${R} ${bcol}${bpct}% ${bst} ${bwatt}W${R}   ${LBL}sys pwr${R} $(_wc ${sys_pwr_w})${sys_pwr_w}W${R}   ${LBL}profile${R} ${ACC}${prof}${R}   ${LBL}cores${R} ${ACC}${nact}/${ncpu}${R}"

      # ── CPU ─────────────────────────────────────────────────────────────────
      _sec "CPU  (${cpu_model})"
      _trow "package id 0"  "${cpu_pkg:-0}"
      _trow "core max"      "${cpu_cmax:-0}"
      _pn ""
      _frow "freq max"      "${fmax:-0}"
      _frow "freq avg"      "${favg:-0}"
      _pn ""
      _pn "  ${LBL}gov${R} ${ACC}${gov}${R}   ${LBL}epp${R} ${ACC}${epp}${R}   ${LBL}turbo${R} ${ACC}${turbo}${R}   ${LBL}hwp boost${R} ${ACC}${hwpb}${R}   ${LBL}cpu pwr${R} $(_wc ${rapl_pkg_w})${rapl_pkg_w}W${R}"

      # ── per-core ────────────────────────────────────────────────────────────
      if (( SHOW_CORES )) && (( ${#cl[@]} > 0 )); then
        clabel="all ${ncpu} cores"
        (( TOP_CORES > 0 )) && clabel="top ${TOP_CORES} of ${ncpu} cores"
        _sec "${clabel}"
        for line in "${cl[@]}"; do
          [[ -z "${line}" ]] && continue
          _mhz=${line%% *};    _rest=${line#* }
          _cpu=${_rest%% *};   _rest=${_rest#* }
          _phys=${_rest%% *};  _temp=${_rest#* }
          (( _mhz < 100 )) && _mhz=0
          cf=$(_fc "${_mhz}" "${CPU_MAX}")
          ct2=$(_tc "${_temp:-0}")
          # P-cores: core id < 32   E-cores: core id >= 32
          ctype='E'; (( _phys < 32 )) && ctype='P'
          _p "  ${DIM}c${(l:2::0:)_cpu}[${ctype}]${R} "
          _bar "${_mhz}" "${CPU_MAX}" "${cf}"
          _p " ${cf}${(l:4:)_mhz}MHz${R}"
          (( _temp > 0 )) && _p "  ${ct2}${_temp}°${R}"
          _pn ""
        done
      fi

      # ── GPU ─────────────────────────────────────────────────────────────────
      if (( SHOW_NVIDIA )); then
        _sec "GPU  (RTX 4000 Ada)"
        if [[ "${nvps}" == 'unavailable' ]]; then
          _pn "  ${DIM}nvidia-smi unavailable${R}"
        elif [[ "${nvps}" == 'suspended' ]] || (( nvc == 0 && nvu == 0 )); then
          _trow "gpu temp (EC)"  "${gpu_ec:-0}"
          _pn "  ${DIM}suspended — RTD3/D3cold${R}"
        else
          _trow "gpu temp"       "${nvt:-0}"
          _trow "gpu temp (EC)"  "${gpu_ec:-0}"
          _pn ""
          _frow "core clock"     "${nvc:-0}"   "${nvidia_max}"
          _frow "mem clock"      "${nvm:-0}"   "${mem_max}"
          _prow "utilization"    "${nvu:-0}"
          if (( nvvt > 0 )); then
            vp=$(( nvvu * 100 / nvvt ))
            vc=$(_pc "${vp}")
            _p  "  ${LBL}${(r:18:):-vram}${R} "
            _bar "${nvvu}" "${nvvt}" "${vc}"
            _pn " ${vc}${nvvu}/${nvvt} MiB${R}"
          fi
          _pn ""
          _pn "  ${LBL}pstate${R} ${ACC}${nvps}${R}   ${LBL}gpu pwr${R} $(_wc ${nvp})${nvp}W${R}"
        fi
      fi

      # ── Storage / Memory / Fans — plain text, no bars ───────────────────────
      _sec "Storage / Memory / Network / Fans"
      [[ ${nvme:-0} -gt 0 ]] && _p "  ${LBL}nvme${R} $(_tc ${nvme})${nvme}°C${R}"
      if (( ${#ram_dimms[@]} > 0 )); then
        local di=1
        for v in "${ram_dimms[@]}"; do
          (( v > 0 )) && _p "   ${LBL}dimm${di}${R} $(_tc ${v})${v}°C${R}"
          (( di++ ))
        done
      fi
      [[ ${wifi:-0} -gt 0 ]] && _p "   ${LBL}wifi${R} $(_tc ${wifi})${wifi}°C${R}"
      _pn ""
      if (( ram_total > 0 )); then
        rp=$(( ram_used * 100 / ram_total ))
        rc=$(_pc "${rp}")
        _p  "  ${LBL}${(r:18:):-ram}${R} "
        _bar "${ram_used}" "${ram_total}" "${rc}"
        _pn " ${rc}${ram_used}/${ram_total} MiB${R}"
      fi
      _pn "  ${LBL}fan1${R} ${BLU}${fan1} RPM${R}   ${LBL}fan2${R} ${BLU}${fan2} RPM${R}"

      # ── atomic flush — overwrite in place, then erase any leftover lines ───────
      printf $'\e[H'
      _flush
      printf $'\e[J'
    fi

    sleep 0.05
  done

  tput rmcup 2>/dev/null
  printf $'\e[?25h'
}
