# tmux (dotfiles)

This tmux setup uses TPM (Tmux Plugin Manager) and includes session restore.

## Install

1) Install TPM:

- `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`

2) Start tmux, then install plugins:

- Press `prefix` + `I`

Current prefix is `Ctrl-Space` (see `tmux.conf`).

## Restore workflow

- Auto-save every 15 minutes via `tmux-continuum`.
- Auto-restore on tmux server start via `@continuum-restore 'on'`.

Manual commands (inside tmux):
- Save: `prefix` + `Ctrl-s` (resurrect save)
- Restore: `prefix` + `Ctrl-r` (resurrect restore)

If those keybinds don’t work (older tmux-resurrect versions vary), use:
- `~/.tmux/plugins/tmux-resurrect/scripts/save.sh`
- `~/.tmux/plugins/tmux-resurrect/scripts/restore.sh`
