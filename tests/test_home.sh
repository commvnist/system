#!/usr/bin/env bash
# Run with: bash tests/test_home.sh. All activation is mocked in a temporary home.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
test_home=$test_dir/home
mock_bin=$test_dir/bin
activation=$test_dir/activation
hm_path=$test_dir/hm
mkdir -p "$test_home" "$mock_bin" "$activation/home-files/.config" "$hm_path/bin"
printf 'configured zsh\n' > "$activation/home-files/.zshrc"
printf 'configured prompt\n' > "$activation/home-files/.config/starship.toml"
mkdir -p "$test_dir/pinned-plugin" "$activation/home-files/.local/share/zsh/plugins"
printf 'pinned plugin\n' > "$test_dir/pinned-plugin/plugin.zsh"
ln -s "$test_dir/pinned-plugin" "$activation/home-files/.local/share/zsh/plugins/fzf-tab"
printf '#!/bin/sh\nexit 0\n' > "$activation/activate"
chmod +x "$activation/activate"

cat > "$mock_bin/uname" <<'EOF'
#!/bin/sh
case "$1" in -s) printf 'Darwin\n' ;; -m) printf 'arm64\n' ;; *) exit 1 ;; esac
EOF
cat > "$mock_bin/nix" <<'EOF'
#!/bin/sh
case "$*" in
  *--version*) printf 'nix (mock) 2.35.2\n' ;;
  *'#homeConfigurations.'*'.activationPackage'*) printf '%s\n' "$MOCK_ACTIVATION" ;;
  *'#packages.'*'.home-manager'*) printf '%s\n' "$MOCK_HM_PATH" ;;
  *) printf 'unexpected Nix arguments: %s\n' "$*" >&2; exit 1 ;;
esac
EOF
cat > "$hm_path/bin/home-manager" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$MOCK_HM_LOG"
case "$*" in *generations*) printf 'mock generation 1 (current)\n' ;; esac
EOF
chmod +x "$mock_bin/uname" "$mock_bin/nix" "$hm_path/bin/home-manager"

assert_contains() {
  [[ "$1" == *"$2"* ]] || { printf 'Missing expected text: %s\n%s\n' "$2" "$1" >&2; exit 1; }
}
assert_status() {
  [[ "$1" == "$2" ]] || { printf 'Expected status %s, got %s\n%s\n' "$2" "$1" "$3" >&2; exit 1; }
}
run_home() {
  status=0
  output=$(env HOME="$test_home" PATH="$mock_bin:$PATH" \
    MOCK_ACTIVATION="$activation" MOCK_HM_PATH="$hm_path" \
    MOCK_HM_LOG="$test_dir/hm.log" \
    bash "$repo_root/bootstrap/home.sh" "$1" 2>&1) || status=$?
}

run_home doctor
assert_status "$status" 0 "$output"
assert_contains "$output" 'aarch64-darwin'
assert_contains "$output" 'Active profile: none'

cat > "$mock_bin/stat" <<'EOF'
#!/bin/sh
printf '123456\n'
EOF
chmod +x "$mock_bin/stat"
run_home doctor
assert_status "$status" 1 "$output"
assert_contains "$output" 'HOME is owned by UID 123456'
rm "$mock_bin/stat"

run_home check
assert_status "$status" 0 "$output"
assert_contains "$output" '3 managed files, no conflicts'

printf 'my local config\n' > "$test_home/.zshrc"
run_home check
assert_status "$status" 1 "$output"
assert_contains "$output" '.zshrc (existing file differs)'
rm "$test_home/.zshrc"

ln -s "$repo_root/zsh/.zshrc" "$test_home/.zshrc"
run_home check
assert_status "$status" 1 "$output"
assert_contains "$output" '.zshrc (managed by another source:'
rm "$test_home/.zshrc"

mkdir -p "$test_home/.local/share/zsh/plugins/fzf-tab"
run_home check
assert_status "$status" 1 "$output"
assert_contains "$output" 'fzf-tab (existing directory or file has a different type)'
rmdir "$test_home/.local/share/zsh/plugins/fzf-tab"

ln -s "$test_dir/missing" "$test_home/.zshrc"
run_home doctor
assert_status "$status" 1 "$output"
assert_contains "$output" 'Broken link:'
rm "$test_home/.zshrc"

mkdir -p "$test_home/.local/bin"
ln -s "$repo_root/zsh/.local/bin/zsh-plugin-sync" "$test_home/.local/bin/zsh-plugin-sync"
run_home doctor
assert_status "$status" 1 "$output"
assert_contains "$output" 'zsh-plugin-sync'
rm "$test_home/.local/bin/zsh-plugin-sync"

run_home switch
assert_status "$status" 0 "$output"
assert_contains "$output" 'Activating through pinned Home Manager'
assert_contains "$(cat "$test_dir/hm.log")" "--flake path:$repo_root#aarch64-darwin switch"
ln -s "$hm_path/bin/home-manager" "$mock_bin/home-manager"

run_home status
assert_status "$status" 0 "$output"
assert_contains "$output" 'mock generation 1 (current)'

run_home rollback
assert_status "$status" 1 "$output"
assert_contains "$output" 'nothing to roll back'
mkdir -p "$test_home/.local/state/nix/profiles"
ln -s "$activation" "$test_home/.local/state/nix/profiles/home-manager"
run_home rollback
assert_status "$status" 0 "$output"
assert_contains "$(cat "$test_dir/hm.log")" 'switch --rollback'

printf 'Home Manager wrapper tests passed (12 scenarios).\n'
