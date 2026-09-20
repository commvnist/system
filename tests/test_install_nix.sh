#!/usr/bin/env bash
# Run with: bash tests/test_install_nix.sh
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# Sourcing exposes the preflight and handoff functions without running main.
source "$repo_root/bootstrap/install-nix.sh"
# Keep getenforce tests independent of the host's SELinux state.
selinux_enforce_file=/nonexistent/system-test-selinux-enforce

assert_status() {
  [[ "$1" == "$2" ]] || { printf 'Expected status %s, got %s\n%s\n' "$2" "$1" "$3" >&2; exit 1; }
}

assert_contains() {
  [[ "$1" == *"$2"* ]] || { printf 'Missing expected text: %s\n%s\n' "$2" "$1" >&2; exit 1; }
}

status=0
output=$(
  (
    platform=Linux first_uid=30001 group_gid=30000 user_count=32
    lookup_account() {
      if [[ "$1:$2" == group:30000 ]]; then
        printf 'othergroup\n'
        return 0
      fi
      if [[ "$1:$2" == passwd:30002 ]]; then
        printf 'otheruser\n'
        return 0
      fi
      return 1
    }
    check_ids
    printf '%s\n' "${conflicts[@]}"
    suggest_ids
    printf 'suggested=%s,%s\n' "$suggested_first_uid" "$suggested_group_gid"
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'GID 30000 belongs to group othergroup'
assert_contains "$output" 'UID 30002 belongs to user otheruser'
assert_contains "$output" 'suggested=30003,30001'

status=0
output=$(
  (
    platform=Linux mode=multi systemd=1 user_prefix=nixbld
    first_uid=30001 group_gid=30000 user_count=32
    lookup_account() { return 1; }
    choose_ids
    print_plan
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'UID range: 30001-30032'
assert_contains "$output" 'Build group: nixbld (GID 30000)'

status=0
output=$(
  (
    platform=Darwin first_uid=351 group_gid=350 user_count=32
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    dscl() {
      if [[ "$*" == '/Search -list /Users UniqueID' ]]; then
        printf 'existing 351\n'
      elif [[ "$*" == '/Search -list /Groups PrimaryGroupID' ]]; then
        printf 'staff 350\n'
      else
        return 1
      fi
    }
    load_accounts
    check_ids
    printf '%s\n' "${conflicts[@]}"
    suggest_ids
    printf 'suggested=%s,%s\n' "$suggested_first_uid" "$suggested_group_gid"
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'UID 351 belongs to user existing'
assert_contains "$output" 'GID 350 belongs to group staff'
assert_contains "$output" 'suggested=352,351'

status=0
output=$(
  (
    platform=Linux user_prefix=nixbld user_count=32
    lookup_account() {
      [[ "$1:$2" == group:nixbld ]] && { printf 'nixbld\n'; return 0; }
      return 1
    }
    check_reserved_names
  ) 2>&1
) || status=$?
assert_status "$status" 1 "$output"
assert_contains "$output" 'group nixbld already exists'

status=0
output=$(
  (
    platform=Darwin user_prefix=_nixbld user_count=32
    lookup_account() {
      [[ "$1:$2" == passwd:_nixbld1 ]] && { printf '_nixbld1\n'; return 0; }
      return 1
    }
    check_reserved_names
  ) 2>&1
) || status=$?
assert_status "$status" 1 "$output"
assert_contains "$output" 'user _nixbld1 already exists'

status=0
output=$(
  (
    platform=Linux first_uid=30001 group_gid=30000 user_count=32
    lookup_account() { return 2; }
    check_ids
  ) 2>&1
) || status=$?
assert_status "$status" 1 "$output"
assert_contains "$output" 'could not query GID 30000'

status=0
output=$(
  (
    platform=Linux mode=auto systemd=1
    getenforce() { printf 'Enforcing\n'; }
    select_install_mode
    printf 'mode=%s\n' "$mode"
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'mode=single'
assert_contains "$output" 'Enforcing SELinux detected'

status=0
output=$(
  (
    platform=Linux mode=multi systemd=1
    getenforce() { printf 'Enforcing\n'; }
    select_install_mode
  ) 2>&1
) || status=$?
assert_status "$status" 1 "$output"
assert_contains "$output" 'rejects enforcing SELinux in multi-user mode'

status=0
output=$(
  (
    platform=Linux mode=auto systemd=1
    getenforce() { printf 'Permissive\n'; }
    select_install_mode
    printf 'mode=%s\n' "$mode"
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'mode=multi'

status=0
output=$(
  (
    platform=Linux mode=auto systemd=1
    getenforce() { return 1; }
    select_install_mode
  ) 2>&1
) || status=$?
assert_status "$status" 1 "$output"
assert_contains "$output" 'could not determine SELinux state'

status=0
output=$(
  (
    platform=Linux mode=auto systemd=1
    getenforce() { printf 'unknown\n'; }
    select_install_mode
  ) 2>&1
) || status=$?
assert_status "$status" 1 "$output"
assert_contains "$output" 'unexpected SELinux state'

status=0
output=$(
  (
    platform=Linux mode=auto systemd=0
    getenforce() { return 1; }
    select_install_mode
    printf 'mode=%s\n' "$mode"
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'mode=single'

status=0
output=$(
  (
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    printf '1\n' > "$temp_dir/enforce"
    selinux_enforce_file=$temp_dir/enforce
    platform=Linux mode=auto systemd=1
    select_install_mode
    printf 'mode=%s\n' "$mode"
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'mode=single'

status=0
output=$(
  (
    check_number 'first UID' 030001 200 60000
  ) 2>&1
) || status=$?
assert_status "$status" 1 "$output"
assert_contains "$output" 'must not have leading zeroes'

status=0
output=$(
  (
    platform=Linux mode=multi first_uid=31001 group_gid=31000 user_count=16
    sh() { printf 'args=%s,%s ids=%s,%s,%s\n' "$1" "${2:-}" "$NIX_FIRST_BUILD_UID" "$NIX_BUILD_GROUP_ID" "$NIX_USER_COUNT"; }
    run_upstream_installer /tmp/mock-installer
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'args=/tmp/mock-installer,--daemon ids=31001,31000,16'

status=0
output=$(
  (
    platform=Darwin mode=multi first_uid=360 group_gid=355 user_count=16
    sh() { printf 'args=%s,%s ids=%s,%s,%s\n' "$1" "${2:-}" "$NIX_FIRST_BUILD_UID" "$NIX_BUILD_GROUP_ID" "$NIX_USER_COUNT"; }
    run_upstream_installer /tmp/mock-installer
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'args=/tmp/mock-installer, ids=360,355,16'

status=0
output=$(
  (
    platform=Linux mode=single
    sh() { printf 'args=%s,%s\n' "$1" "${2:-}"; }
    run_upstream_installer /tmp/mock-installer
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'args=/tmp/mock-installer,--no-daemon'

status=0
output=$(
  (
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    printf '#!/bin/sh\nexit 0\n' > "$temp_dir/install"
    if command -v sha256sum >/dev/null 2>&1; then
      INSTALLER_SHA256=$(sha256sum "$temp_dir/install")
    else
      INSTALLER_SHA256=$(shasum -a 256 "$temp_dir/install")
    fi
    INSTALLER_SHA256=${INSTALLER_SHA256%% *}
    verify_installer "$temp_dir/install"
  ) 2>&1
) || status=$?
assert_status "$status" 0 "$output"
assert_contains "$output" 'Verified installer SHA-256:'

status=0
output=$(
  (
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    printf '#!/bin/sh\nexit 0\n' > "$temp_dir/install"
    INSTALLER_SHA256=0000000000000000000000000000000000000000000000000000000000000000
    verify_installer "$temp_dir/install"
  ) 2>&1
) || status=$?
assert_status "$status" 1 "$output"
assert_contains "$output" 'installer SHA-256 mismatch'

printf 'Guided Nix installer tests passed (19 scenarios).\n'
