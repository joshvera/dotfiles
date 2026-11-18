# Per-repo Claude Code auto mode context.
#
# Claude Code only reads `autoMode` from user or managed settings, and the user
# settings file (.claude/settings.json) is tracked in this public repo. Repo
# specific classifier context (internal paths, deploy targets, where secrets
# live) stays untracked in ~/.config/claude/automode/<repo>.json and is layered
# on per session with --settings.
#
# <repo> is the main checkout's name, so linked worktrees and bare layouts all
# resolve to the same file:
#
#   ~/src/foo/.git           -> foo
#   ~/wt/feature (worktree)  -> common dir ~/src/foo/.git -> foo
#   ~/src/foo.git (bare)     -> foo
#
# Launchers that skip the interactive shell (desktop app, agent spawners) do
# not get this.
#
# The github plugin's MCP server authenticates with GITHUB_PERSONAL_ACCESS_TOKEN.
# Borrow gh's keyring token per launch instead of exporting a secret from a
# public repo.
claude() {
  local common_dir repo_root repo_settings
  if [[ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]] && (( $+commands[gh] )); then
    local -x GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token 2>/dev/null)"
  fi
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  if [[ -n "$common_dir" ]]; then
    if [[ "${common_dir:t}" == .git ]]; then
      repo_root="${common_dir:h}"
    else
      repo_root="${common_dir:r}"
    fi
    repo_settings="${XDG_CONFIG_HOME:-$HOME/.config}/claude/automode/${repo_root:t}.json"
    if [[ -r "$repo_settings" ]]; then
      command claude --settings "$repo_settings" "$@"
      return
    fi
  fi
  command claude "$@"
}
