# tmux

Home Manager installs tmux and links `tmux/.tmux.conf` to `~/.tmux.conf`.
Run `bash bootstrap/home.sh switch` from the repository root after editing it.
Copy mode sends text to the host through `~/.local/bin/clipboard-copy` and
through tmux OSC 52 when the outer terminal supports it. The helper selects
Windows `clip.exe` on WSL2, `pbcopy` on macOS, and Wayland or X11 tools on
Linux. If no native desktop clipboard is present, tmux still keeps its paste
buffer and attempts OSC 52. The terminal must allow clipboard escape sequences
for that fallback. Applications inside tmux cannot write its OSC 52 clipboard
because `set-clipboard` stays `external`; Neovim uses the native host clipboard
provider independently. Restart the tmux server after changing the server's
clipboard settings.
The prefix is `Ctrl-a`; press it twice to send `Ctrl-a` to a program. Use
prefix `h/j/k/l` to move between panes. From inside Neovim, use `Ctrl-h/j/k/l`
instead.

Use prefix `p` for the sesh picker. It lists running sessions and directories
recorded by zoxide; choosing a directory creates its session when needed. From
a shell, `sesh connect .` creates or opens a session for the current directory.
A session can hold many windows and panes. Git worktrees are optional and are
not created by this setup.

Use prefix `L` to return to the last session, `w` to browse tmux sessions and
windows, and `d` to detach. `tmux attach` resumes a detached session. Prefix
`t` and `T` move to the next and previous window. Prefix `?` shows tmux's key
list with descriptions of the custom bindings. Detached sessions keep running
until the tmux server stops; they do not survive a reboot. See the
[shortcut guide](../keybindings.md) for the full keymap.
