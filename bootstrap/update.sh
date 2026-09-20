#!/usr/bin/env bash
# Update selected flake inputs and validate the Home Manager configuration.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if command -v nix >/dev/null 2>&1; then
  nix_bin=$(command -v nix)
elif [[ -x /nix/var/nix/profiles/default/bin/nix ]]; then
  nix_bin=/nix/var/nix/profiles/default/bin/nix
elif [[ -x "$HOME/.nix-profile/bin/nix" ]]; then
  nix_bin=$HOME/.nix-profile/bin/nix
else
  printf 'Error: Nix is required to update flake inputs.\n' >&2
  exit 1
fi

cd "$repo_root"
"$nix_bin" --extra-experimental-features 'nix-command flakes' flake update "$@"
"$nix_bin" --extra-experimental-features 'nix-command flakes' flake check \
  --no-update-lock-file path:"$repo_root"
"$nix_bin" --extra-experimental-features 'nix-command flakes' flake check \
  --no-update-lock-file --all-systems --no-build path:"$repo_root"
printf 'Update validated. Review flake.lock before switching.\n'
