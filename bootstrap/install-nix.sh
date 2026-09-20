#!/usr/bin/env bash
# Guide a fresh upstream Nix install without taking over existing accounts.
# Bash 3.2 compatible for the Bash shipped with macOS.
set -euo pipefail

# Pin the official release script. Update both values from releases.nixos.org.
NIX_VERSION=2.35.2
INSTALLER_URL="https://releases.nixos.org/nix/nix-${NIX_VERSION}/install"
INSTALLER_SHA256=9adda97297d9e8ab360df95c729eabff4f4f93d6db091953c3a68f29e3fb130c
mode=auto
dry_run=0
first_uid=
group_gid=
user_count=32
ids_supplied=0
temp_dir=
users_file=
groups_file=
conflicts=()

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: bootstrap/install-nix.sh [options]

Options:
  --mode auto|multi|single   Default: multi with systemd or on macOS;
                             single on Linux/WSL2 without systemd.
  --first-uid NUMBER         First Nix build user UID (multi-user only).
  --group-gid NUMBER         nixbld group GID (multi-user only).
  --user-count NUMBER        Build users, 1-64 (default: 32).
  --dry-run                  Check the host and print the plan; install nothing.
  -h, --help                 Show this help.

Run as your normal user. The wrapper inspects accounts, offers replacement IDs
when defaults collide, and asks for confirmation before downloading and running
the upstream Nix installer. It never deletes or renumbers existing accounts.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --mode|--first-uid|--group-gid|--user-count)
        (($# >= 2)) || fail "$1 needs a value"
        [[ -n "$2" ]] || fail "$1 needs a value"
        case "$1" in
          --mode) mode=$2 ;;
          --first-uid) first_uid=$2; ids_supplied=1 ;;
          --group-gid) group_gid=$2; ids_supplied=1 ;;
          --user-count) user_count=$2; ids_supplied=1 ;;
        esac
        shift 2
        ;;
      --dry-run) dry_run=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
  case "$mode" in auto|multi|single) ;; *) fail "invalid mode: $mode" ;; esac
}

check_number() {
  local label=$1 value=$2 minimum=$3 maximum=$4
  case "$value" in
    ''|*[!0-9]*) fail "$label must be a decimal integer from $minimum to $maximum" ;;
  esac
  # Reject leading zeroes to avoid octal arithmetic and ambiguous plans.
  case "$value" in 0|[1-9]|[1-9][0-9]*) ;; *) fail "$label must not have leading zeroes" ;; esac
  ((${#value} <= ${#maximum})) || fail "$label must be at most $maximum"
  ((value >= minimum && value <= maximum)) || fail "$label must be from $minimum to $maximum"
}

cleanup() {
  if [[ -n "$temp_dir" ]]; then
    rm -rf "$temp_dir"
  fi
}

detect_platform() {
  platform=$(uname -s)
  case "$platform" in
    Darwin)
      default_first_uid=351
      default_group_gid=350
      user_prefix=_nixbld
      systemd=0
      ;;
    Linux)
      default_first_uid=30001
      default_group_gid=30000
      user_prefix=nixbld
      systemd=0
      [[ -d /run/systemd/system ]] && systemd=1
      ;;
    *) fail "unsupported platform: $platform (expected macOS or Linux)" ;;
  esac

  if [[ "$mode" == auto ]]; then
    if [[ "$platform" == Darwin || "$systemd" == 1 ]]; then
      mode=multi
    else
      mode=single
    fi
  fi
  [[ "$mode" != multi || "$platform" != Linux || "$systemd" == 1 ]] ||
    fail 'multi-user Nix on Linux needs running systemd. Enable systemd in WSL2, restart the distro, or use --mode single.'
  [[ "$mode" != single || "$platform" != Darwin ]] ||
    fail 'the upstream macOS installer supports multi-user installation only'
  [[ "$mode" != single || "$ids_supplied" == 0 ]] ||
    fail 'UID/GID options apply only to --mode multi'

  [[ -n "$first_uid" ]] || first_uid=$default_first_uid
  [[ -n "$group_gid" ]] || group_gid=$default_group_gid
}

check_fresh_host() {
  if [[ -e /nix || -L /nix || -e /etc/nix || -L /etc/nix ]] || command -v nix >/dev/null 2>&1; then
    fail 'Nix files or a Nix command already exist. Inspect the current/partial installation and use its repair or uninstall instructions before a fresh install; this guide will not overwrite it.'
  fi
}

check_prerequisites() {
  command -v curl >/dev/null 2>&1 || fail 'curl is required to download Nix'
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required for the fresh Nix installation'
  command -v tar >/dev/null 2>&1 || fail 'tar is required to unpack Nix'
  if [[ "$platform" == Linux ]]; then
    command -v xz >/dev/null 2>&1 || fail 'xz is required to unpack Nix on Linux (install xz or xz-utils)'
  fi
  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    fail 'sha256sum or shasum is required to verify the installer'
  fi
}

check_linux_selinux() {
  local state
  if [[ "$platform" == Linux && "$mode" == multi ]] && command -v getenforce >/dev/null 2>&1; then
    state=$(getenforce) || fail 'could not determine SELinux state with getenforce'
    [[ "$state" != Enforcing ]] ||
      fail 'the upstream shell installer rejects enforcing SELinux. Use the NixOS community nix-installer for this host instead.'
  fi
}

load_accounts() {
  if [[ "$platform" == Linux ]]; then
    command -v getent >/dev/null 2>&1 || fail 'getent is needed to check Linux accounts'
  else
    command -v dscl >/dev/null 2>&1 || fail 'dscl is needed to check macOS accounts'
    users_file=$temp_dir/users
    groups_file=$temp_dir/groups
    dscl /Search -list /Users UniqueID > "$users_file" || fail 'could not list macOS users with dscl /Search'
    dscl /Search -list /Groups PrimaryGroupID > "$groups_file" || fail 'could not list macOS groups with dscl /Search'
  fi
}

# Each lookup prints the owner and returns 0 when occupied, 1 when free, 2 on
# account-service failure. Linux uses keyed NSS lookups so non-enumerable LDAP
# accounts still block conflicting IDs.
lookup_account() {
  local kind=$1 key=$2 entry status owner file
  if [[ "$platform" == Linux ]]; then
    if entry=$(getent "$kind" "$key"); then
      [[ -n "$entry" ]] || return 2
      printf '%s\n' "${entry%%:*}"
      return 0
    else
      status=$?
      [[ "$status" == 2 ]] && return 1
      return 2
    fi
  fi

  if [[ "$kind" == passwd ]]; then file=$users_file; else file=$groups_file; fi
  if [[ "$key" == *[!0-9]* ]]; then
    owner=$(awk -v key="$key" '$1 == key { print $1; exit }' "$file") || return 2
  else
    owner=$(awk -v key="$key" '$NF == key { print $1; exit }' "$file") || return 2
  fi
  [[ -n "$owner" ]] || return 1
  printf '%s\n' "$owner"
}

check_reserved_names() {
  local owner status i
  if owner=$(lookup_account group nixbld); then
    fail "group nixbld already exists ($owner); this may be a partial Nix install"
  else
    status=$?
    [[ "$status" == 1 ]] || fail 'could not query the nixbld group name'
  fi
  for ((i=1; i<=user_count; i++)); do
    if owner=$(lookup_account passwd "${user_prefix}${i}"); then
      fail "user ${user_prefix}${i} already exists; this may be a partial Nix install"
    else
      status=$?
      [[ "$status" == 1 ]] || fail "could not query user ${user_prefix}${i}"
    fi
  done
}

check_ids() {
  local uid owner status i
  conflicts=()
  if owner=$(lookup_account group "$group_gid"); then
    conflicts+=("GID $group_gid belongs to group $owner")
  else
    status=$?
    [[ "$status" == 1 ]] || fail "could not query GID $group_gid"
  fi
  for ((i=0; i<user_count; i++)); do
    uid=$((first_uid + i))
    if owner=$(lookup_account passwd "$uid"); then
      conflicts+=("UID $uid belongs to user $owner")
    else
      status=$?
      [[ "$status" == 1 ]] || fail "could not query UID $uid"
    fi
  done
}

suggest_ids() {
  local candidate i owner status free limit search_limit
  suggested_first_uid=
  suggested_group_gid=
  if [[ "$platform" == Darwin ]]; then limit=399; else limit=60000; fi
  search_limit=$((first_uid + 1024))
  ((search_limit < limit)) && limit=$search_limit

  candidate=$first_uid
  while ((candidate + user_count - 1 <= limit)); do
    free=1
    for ((i=0; i<user_count; i++)); do
      if owner=$(lookup_account passwd "$((candidate+i))"); then
        free=0
        candidate=$((candidate + i + 1))
        break
      else
        status=$?
        [[ "$status" == 1 ]] || fail "could not query UID $((candidate+i))"
      fi
    done
    if [[ "$free" == 1 ]]; then
      suggested_first_uid=$candidate
      break
    fi
  done

  if [[ "$platform" == Darwin ]]; then
    limit=399
  else
    limit=$((group_gid + 1024))
    ((limit > 60000)) && limit=60000
  fi
  for ((candidate=group_gid; candidate<=limit; candidate++)); do
    if owner=$(lookup_account group "$candidate"); then
      continue
    else
      status=$?
      [[ "$status" == 1 ]] || fail "could not query GID $candidate"
      suggested_group_gid=$candidate
      break
    fi
  done
}

choose_ids() {
  local line response
  check_number 'first UID' "$first_uid" 200 60000
  check_number 'group GID' "$group_gid" 200 60000
  check_number 'user count' "$user_count" 1 64
  while :; do
    ((first_uid + user_count - 1 <= 60000)) || fail 'the final build UID must be at most 60000'
    check_ids
    if ((${#conflicts[@]} == 0)); then
      if [[ "$platform" == Darwin ]] &&
        ((first_uid < 351 || first_uid + user_count - 1 > 399 || group_gid > 399)); then
        printf 'Caution: upstream Nix targets macOS role-user IDs around 200-399; review this custom range.\n' >&2
      fi
      return 0
    fi
    printf 'Account conflicts for this plan:\n' >&2
    for line in "${conflicts[@]}"; do printf '  - %s\n' "$line" >&2; done
    suggest_ids
    if [[ "$dry_run" == 1 ]]; then
      if [[ -n "$suggested_first_uid" && -n "$suggested_group_gid" ]]; then
        printf 'Try --first-uid %s --group-gid %s (then run --dry-run again).\n' \
          "$suggested_first_uid" "$suggested_group_gid" >&2
      else
        printf 'No free IDs found in the search range; choose IDs manually or reduce --user-count.\n' >&2
      fi
      exit 2
    fi
    [[ -t 0 ]] || fail 'conflicts require an interactive terminal or explicit free IDs'
    if [[ -z "$suggested_first_uid" || -z "$suggested_group_gid" ]]; then
      fail 'no free IDs found in the search range; choose IDs manually with CLI options or reduce --user-count'
    fi
    printf 'Suggested first UID: %s; suggested group GID: %s\n' "$suggested_first_uid" "$suggested_group_gid"
    read -r -p "First build UID [$suggested_first_uid]: " response || fail 'input ended'
    first_uid=${response:-$suggested_first_uid}
    read -r -p "Build group GID [$suggested_group_gid]: " response || fail 'input ended'
    group_gid=${response:-$suggested_group_gid}
    check_number 'first UID' "$first_uid" 200 60000
    check_number 'group GID' "$group_gid" 200 60000
  done
}

print_plan() {
  printf 'Platform: %s\nMode: %s-user\n' "$platform" "$mode"
  if [[ "$platform" == Linux && "$systemd" == 0 ]]; then
    printf 'No running systemd detected. Enable it before choosing multi-user mode.\n'
  fi
  if [[ "$mode" == multi ]]; then
    printf 'Build users: %s1 through %s%s\n' "$user_prefix" "$user_prefix" "$user_count"
    printf 'UID range: %s-%s\nBuild group: nixbld (GID %s)\n' \
      "$first_uid" "$((first_uid + user_count - 1))" "$group_gid"
  else
    printf 'No nixbld users or group will be created.\n'
  fi
  printf 'Nix version: %s\nInstaller: %s\nSHA-256: %s\n' \
    "$NIX_VERSION" "$INSTALLER_URL" "$INSTALLER_SHA256"
  printf 'The upstream installer will request administrator access and change system files.\n'
}

verify_installer() {
  local installer=$1 checksum
  [[ -s "$installer" ]] || fail 'downloaded installer was empty'
  if command -v sha256sum >/dev/null 2>&1; then
    checksum=$(sha256sum "$installer") || fail 'could not hash the downloaded installer'
  else
    checksum=$(shasum -a 256 "$installer") || fail 'could not hash the downloaded installer'
  fi
  checksum=${checksum%% *}
  [[ "$checksum" == "$INSTALLER_SHA256" ]] ||
    fail "installer SHA-256 mismatch: expected $INSTALLER_SHA256, got $checksum"
  sh -n "$installer" || fail 'downloaded installer failed shell syntax check'
  printf 'Verified installer SHA-256: %s\n' "$checksum"
}

install_nix() {
  local installer reply
  [[ "$(id -u)" != 0 ]] || fail 'run this guide as your normal user; the upstream installer will request sudo'
  [[ -t 0 ]] || fail 'installation requires an interactive terminal; use --dry-run for a noninteractive check'
  read -r -p 'Type install to download and run the upstream installer: ' reply || fail 'input ended'
  [[ "$reply" == install ]] || fail 'installation cancelled'

  installer=$temp_dir/nix-install.sh
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --connect-timeout 15 --max-time 180 -fsSL \
    "$INSTALLER_URL" -o "$installer" || fail "download failed: $INSTALLER_URL"
  verify_installer "$installer"

  check_fresh_host
  if [[ "$mode" == multi ]]; then
    load_accounts
    check_reserved_names
    check_ids
    ((${#conflicts[@]} == 0)) || fail 'account IDs changed during download; run the guide again'
  fi
  run_upstream_installer "$installer"
  printf 'Installer finished. Open a new shell, then run: nix --version\n'
}

run_upstream_installer() {
  local installer=$1
  if [[ "$mode" == multi ]]; then
    export NIX_FIRST_BUILD_UID=$first_uid NIX_BUILD_GROUP_ID=$group_gid NIX_USER_COUNT=$user_count
    # The upstream macOS installer selects daemon mode by default.
    if [[ "$platform" == Darwin ]]; then sh "$installer"; else sh "$installer" --daemon; fi
  else
    sh "$installer" --no-daemon
  fi
}

main() {
  parse_args "$@"
  detect_platform
  check_fresh_host
  check_prerequisites
  check_linux_selinux
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/nix-guide.XXXXXX") || fail 'could not create temporary directory'
  trap cleanup EXIT
  if [[ "$mode" == multi ]]; then
    load_accounts
    check_reserved_names
    choose_ids
  fi
  print_plan
  [[ "$dry_run" == 1 ]] && return 0
  install_nix
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
