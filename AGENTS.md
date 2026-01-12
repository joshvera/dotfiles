# Repository Guidelines

## Project Structure
- Shell configurations: `.zshrc`, `.zshenv`, `.zprofile`, `zsh/`
- Editor configs: `nvim/`, `vscode/`, `zed/`
- Terminal configs: `tmux/`, `zellij/`
- Claude Code: `.claude/` (hooks, settings, skills)
- Shared hooks: `hooks/` (for wiggum-enabled projects)
- Skills: `skills/` (slash command definitions)

## Development Commands
- Symlink dotfiles: `./install.sh` (if present) or manual `ln -s`
- Test shell config: `source ~/.zshrc`

## Coding Style
- Shell scripts: Use `set -euo pipefail`, prefer functions over inline logic
- Keep configs modular and well-commented
- Use existing patterns from the codebase

## Hooks

# Review plan with Codex before starting build (blocks on rejection)
on_plan_complete: hooks/review-plan.sh mode=block timeout=300

# Review task implementation with Codex (blocks on rejection)
on_task_complete: hooks/review-task.sh mode=block timeout=120

# Send notification after each task
on_task_complete: hooks/notify.sh mode=warn timeout=60

# Create GitHub PR when build finishes
on_build_complete: hooks/create-pr.sh mode=block timeout=300
