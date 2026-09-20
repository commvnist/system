#!/usr/bin/env bash
# Manage this user's pinned Home Manager configuration without changing hosts.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap/home.sh doctor|check|switch|status|rollback

  doctor    Inspect this host without downloading or changing anything.
  check     Build the pinned configuration and preview file conflicts.
  switch    Check, then activate through the pinned Home Manager command.
  status    Show the active Home Manager generations, if any.
  rollback  Activate the previous Home Manager generation.
EOF
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [[ $# != 1 ]]; then usage >&2; exit 2; fi
case "$1" in
  doctor|check|switch|status|rollback) action=$1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) fail 'unsupported operating system (expected Linux or macOS)' ;;
esac
case "$(uname -m)" in
  x86_64) arch=x86_64 ;;
  aarch64|arm64) arch=aarch64 ;;
  *) fail 'unsupported architecture (expected x86_64 or aarch64)' ;;
esac
system=$arch-$os

export USER
USER=$(id -un) || fail 'could not determine the current user'
export HOME
[[ -n "${HOME:-}" && "$HOME" == /* && -d "$HOME" ]] ||
  fail 'HOME must be an existing absolute directory'
[[ "$HOME" != / ]] || fail 'HOME cannot be the filesystem root'
if home_uid=$(stat -L -c '%u' "$HOME" 2>/dev/null); then
  :
elif home_uid=$(stat -L -f '%u' "$HOME" 2>/dev/null); then
  :
else
  fail "could not determine the owner of HOME: $HOME"
fi
[[ "$home_uid" == "$(id -u)" ]] ||
  fail "HOME is owned by UID $home_uid but the current UID is $(id -u); use the intended user's shell"

find_nix() {
  local nix_dir
  if command -v nix >/dev/null 2>&1; then
    nix_bin=$(command -v nix)
  elif [[ -x /nix/var/nix/profiles/default/bin/nix ]]; then
    nix_bin=/nix/var/nix/profiles/default/bin/nix
  elif [[ -x "$HOME/.nix-profile/bin/nix" ]]; then
    nix_bin=$HOME/.nix-profile/bin/nix
  else
    fail 'Nix was not found; see docs/nix/README.md for installation or repair'
  fi
  # Home Manager invokes nix, nix-env, and nix-instantiate itself.
  nix_dir=$(dirname "$nix_bin")
  export PATH="$nix_dir:$PATH"
  export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG
}extra-experimental-features = nix-command flakes"
}

require_lock() {
  [[ -f "$repo_root/flake.lock" ]] ||
    fail 'flake.lock is missing; restore it from Git before building'
}

show_target() {
  printf 'Target: %s at %s (%s)\n' "$USER" "$HOME" "$system"
}

profile_path() {
  local state_profile=${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager
  local global_profile=/nix/var/nix/profiles/per-user/$USER/home-manager
  if [[ -L "$state_profile" ]]; then
    printf '%s\n' "$state_profile"
  elif [[ -L "$global_profile" ]]; then
    printf '%s\n' "$global_profile"
  fi
}

doctor() {
  local profile path plugin plugin_dir present=0 missing=0
  show_target
  find_nix
  "$nix_bin" --version
  require_lock
  profile=$(profile_path)
  if [[ -n "$profile" ]]; then
    printf 'Active profile: %s -> %s\n' "$profile" "$(readlink "$profile")"
  else
    printf 'Active profile: none (first activation)\n'
  fi
  for path in .zshrc .tmux.conf .vimrc .config/starship.toml .local/bin/zsh-plugin-sync; do
    if [[ -L "$HOME/$path" && ! -e "$HOME/$path" ]]; then
      printf 'Broken link: %s\n' "$HOME/$path" >&2
      missing=$((missing + 1))
    fi
  done
  ((missing == 0)) || fail "$missing broken home link(s); repair or move them before switching"
  plugin_dir=$HOME/.local/share/zsh/plugins
  for plugin in fzf-tab zsh-autosuggestions zsh-autopair zsh-history-substring-search zsh-syntax-highlighting; do
    [[ -d "$plugin_dir/$plugin" ]] && present=$((present + 1))
  done
  printf 'Pinned Zsh plugins: %s/5 present in %s\n' "$present" "$plugin_dir"
  if ((present < 5)); then printf 'Switch will provide the pinned plugins.\n'; fi
  printf 'Next: bash bootstrap/home.sh check\n'
}

build_activation() {
  local flake_ref="path:$repo_root"
  require_lock
  find_nix
  printf 'Building %s configuration for %s (%s)\n' "$system" "$USER" "$HOME"
  activation=$(
    "$nix_bin" --extra-experimental-features 'nix-command flakes' build \
      --impure --no-update-lock-file --no-link --print-out-paths \
      "$flake_ref#homeConfigurations.$system.activationPackage"
  ) || fail "Home Manager build failed for $system; inspect the Nix error above"
  [[ -x "$activation/activate" && -d "$activation/home-files" ]] ||
    fail "build did not produce a valid activation package: $activation"
}

conflicts=()
add_conflict() {
  local entry
  if ((${#conflicts[@]} > 0)); then
    for entry in "${conflicts[@]}"; do
      [[ "$entry" == "$1" ]] && return
    done
  fi
  conflicts+=("$1")
}

check_parent_paths() {
  local relative=$1 parent=$HOME component i
  local -a parts
  IFS=/ read -r -a parts <<< "$relative"
  for ((i=0; i<${#parts[@]}-1; i++)); do
    component=${parts[i]}
    parent=$parent/$component
    if [[ -L "$parent" ]]; then
      add_conflict "$parent (parent directory is a symlink)"
      return 1
    elif [[ -e "$parent" && ! -d "$parent" ]]; then
      add_conflict "$parent (parent path is not a directory)"
      return 1
    fi
  done
  return 0
}

preview_targets() {
  local files=$activation/home-files source relative target link count=0 entry shown=0
  conflicts=()
  find -H "$files" \( -type f -o -type l \) -print0 >/dev/null ||
    fail "could not read generated home files: $files"
  # Home Manager writes one link for each generated leaf. Follow only the
  # home-files root symlink; do not traverse symlinks inside that directory.
  while IFS= read -r -d '' source; do
    relative=${source#"$files"/}
    target=$HOME/$relative
    count=$((count + 1))
    check_parent_paths "$relative" || continue
    if [[ -L "$target" ]]; then
      link=$(readlink "$target")
      case "$link" in
        /nix/store/*-home-manager-files/*)
          [[ -e "$target" ]] || add_conflict "$target (broken Home Manager link)"
          ;;
        *) add_conflict "$target (managed by another source: $link)" ;;
      esac
    elif [[ -e "$target" ]]; then
      if [[ -d "$source" || -d "$target" ]]; then
        add_conflict "$target (existing directory or file has a different type)"
      elif ! cmp -s "$source" "$target"; then
        add_conflict "$target (existing file differs)"
      fi
    fi
  done < <(find -H "$files" \( -type f -o -type l \) -print0)

  if ((${#conflicts[@]} > 0)); then
    printf '%s managed files checked; %s conflict(s):\n' "$count" "${#conflicts[@]}" >&2
    for entry in "${conflicts[@]}"; do
      if ((shown < 20)); then printf '  %s\n' "$entry" >&2; fi
      shown=$((shown + 1))
    done
    if ((shown > 20)); then printf '  ... and %s more\n' "$((shown - 20))" >&2; fi
    fail 'move or unlink conflicting files, then run check again'
  fi
  printf 'Build and file preview succeeded: %s managed files, no conflicts\n' "$count"
}

find_home_manager() {
  if [[ -x "$HOME/.nix-profile/bin/home-manager" ]]; then
    hm_bin=$HOME/.nix-profile/bin/home-manager
  elif command -v home-manager >/dev/null 2>&1; then
    hm_bin=$(command -v home-manager)
  else
    hm_bin=
  fi
}

build_pinned_home_manager() {
  require_lock
  find_nix
  local hm_path
  hm_path=$(
    "$nix_bin" --extra-experimental-features 'nix-command flakes' build \
      --no-update-lock-file --no-link --print-out-paths \
      "path:$repo_root#packages.$system.home-manager"
  ) || fail 'could not build the pinned Home Manager command'
  hm_bin=$hm_path/bin/home-manager
  [[ -x "$hm_bin" ]] || fail "Home Manager command is missing: $hm_bin"
}

case "$action" in
  doctor) doctor ;;
  check)
    build_activation
    preview_targets
    ;;
  switch)
    build_activation
    preview_targets
    build_pinned_home_manager
    printf 'Activating through pinned Home Manager\n'
    "$hm_bin" --extra-experimental-features 'nix-command flakes' \
      --no-update-lock-file --impure --flake "path:$repo_root#$system" switch
    ;;
  status)
    show_target
    find_nix
    find_home_manager
    [[ -n "$hm_bin" ]] || fail 'Home Manager is not installed for this user; run switch first'
    "$hm_bin" generations
    ;;
  rollback)
    show_target
    find_nix
    find_home_manager
    if [[ -z "$hm_bin" ]]; then build_pinned_home_manager; fi
    [[ -n "$(profile_path)" ]] || fail 'no Home Manager generation is active; nothing to roll back'
    "$hm_bin" --extra-experimental-features 'nix-command flakes' switch --rollback
    ;;
esac
