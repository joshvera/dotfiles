# Dotfiles repository guidance

Apply these instructions when working in this repository. Shared personal preferences are loaded through the global AGENTS.md symlink to `.codex/AGENTS.md`, which `~/.claude/CLAUDE.md` also imports. Codex-only role routing lives in `.codex/developer-instructions.md` and is injected into `~/.codex/config.toml` by `scripts/sync-codex-developer-instructions.sh`.

<project_structure>
- Shell configurations: `.zshrc`, `.zshenv`, `.zprofile`, `zsh/`
- Editor configs: `nvim/`, `vscode/`, `zed/`
- Terminal configs: `tmux/`, `zellij/`
- Shared agent skills: `.agents/skills/`
- Claude Code: `.claude/` (hooks, settings, agents; `~/.claude/skills` mirrors `~/.agents/skills`)
- Codex: `.codex/` (Codex-specific and system skills)
- Shared hooks: `hooks/` (for wiggum-enabled projects)
- Skills: `skills/` (slash command definitions)
</project_structure>

<development_commands>
- Symlink dotfiles: `./install.sh` if present, otherwise use manual `ln -s`.
- Test shell config: `source ~/.zshrc`.
</development_commands>

<coding_style>
- Shell scripts: use `set -euo pipefail`, prefer functions over inline logic.
- Keep configs modular and well-commented.
- Use existing patterns from the codebase.
</coding_style>

<hooks>
- `on_plan_complete: hooks/review-plan.sh mode=block timeout=300`
- `on_task_complete: hooks/review-task.sh mode=block timeout=120`
- `on_task_complete: hooks/notify.sh mode=warn timeout=60`
- `on_build_complete: hooks/create-pr.sh mode=block timeout=300`
</hooks>
