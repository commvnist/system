#!/usr/bin/env bash
# Exercise the native tmux copy bridge without touching the real clipboard.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
tmux_socket=system-clipboard-$$
cleanup() {
  tmux -L "$tmux_socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$test_dir"
}
trap cleanup EXIT
mkdir -p "$test_dir/bin"
export MOCK_CLIPBOARD_FILE=$test_dir/copied

write_mock() {
  cat > "$test_dir/bin/$1" <<'EOF'
#!/bin/sh
cat > "$MOCK_CLIPBOARD_FILE"
EOF
  chmod +x "$test_dir/bin/$1"
}

case $(uname -s) in
  Darwin)
    write_mock pbcopy
    ;;
  Linux)
    if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]] ||
      [[ -r /proc/sys/kernel/osrelease && $(cat /proc/sys/kernel/osrelease) == *[Mm]icrosoft* ]]; then
      write_mock clip.exe
      write_mock wl-copy
      export WAYLAND_DISPLAY=mock-wayland
    else
      write_mock wl-copy
      export WAYLAND_DISPLAY=mock-wayland
    fi
    ;;
  *) printf 'Unsupported test platform\n' >&2; exit 1 ;;
esac

printf 'tmux clipboard bridge\n' |
  PATH="$test_dir/bin:$PATH" "$repo_root/clipboard/clipboard-copy"
[[ $(cat "$MOCK_CLIPBOARD_FILE") == 'tmux clipboard bridge' ]] || {
  printf 'Native clipboard copy did not receive tmux text\n' >&2
  exit 1
}

if [[ $(uname -s) == Linux && -z "${WSL_DISTRO_NAME:-}${WSL_INTEROP:-}" ]] &&
  [[ $(cat /proc/sys/kernel/osrelease) != *[Mm]icrosoft* ]]; then
  write_mock xclip
  unset WAYLAND_DISPLAY
  export DISPLAY=:99
  printf 'x11 clipboard bridge\n' |
    PATH="$test_dir/bin:$PATH" "$repo_root/clipboard/clipboard-copy"
  [[ $(cat "$MOCK_CLIPBOARD_FILE") == 'x11 clipboard bridge' ]] || {
    printf 'X11 clipboard copy did not receive tmux text\n' >&2
    exit 1
  }
fi

mkdir -p "$test_dir/home/.local/bin"
ln -s "$repo_root/clipboard/clipboard-copy" "$test_dir/home/.local/bin/clipboard-copy"
export HOME=$test_dir/home
export PATH="$test_dir/bin:$PATH"
: > "$MOCK_CLIPBOARD_FILE"
tmux -L "$tmux_socket" -f "$repo_root/tmux/.tmux.conf" new-session -d -s smoke \
  'printf "TMUX_COPY_MARKER\n"; sleep 15'
for ((i=0; i<30; i++)); do
  [[ $(tmux -L "$tmux_socket" capture-pane -p -t smoke) == *TMUX_COPY_MARKER* ]] && break
  sleep 0.1
done
[[ $(tmux -L "$tmux_socket" capture-pane -p -t smoke) == *TMUX_COPY_MARKER* ]] || {
  printf 'tmux pane did not display its test marker\n' >&2
  exit 1
}
tmux -L "$tmux_socket" copy-mode -t smoke
for command in cursor-up start-of-line begin-selection end-of-line copy-pipe-and-cancel; do
  tmux -L "$tmux_socket" send-keys -X -t smoke "$command"
done
for ((i=0; i<30; i++)); do
  [[ $(cat "$MOCK_CLIPBOARD_FILE") == TMUX_COPY_MARKER ]] && break
  sleep 0.1
done
[[ $(cat "$MOCK_CLIPBOARD_FILE") == TMUX_COPY_MARKER ]] || {
  printf 'tmux copy mode did not reach the host clipboard bridge\n' >&2
  exit 1
}
[[ $(tmux -L "$tmux_socket" show-buffer) == TMUX_COPY_MARKER ]] || {
  printf 'tmux copy mode did not retain its paste buffer\n' >&2
  exit 1
}

printf 'Clipboard bridge tests passed.\n'
