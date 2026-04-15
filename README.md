# dotfiles

Personal configuration files, versioned.

## Contents

### Claude Code commands (`claude/commands/`)

Slash commands available in all Claude Code projects:

| Command | Description |
|---------|-------------|
| `/plan_approved` | Proceed with the current plan — copies to `plans/`, sets up branch, starts `progress.md` tracking |
| `/plan_completed` | Wrap up a plan — docs review, lint, tests, commit, and PR |
| `/plan_create_issue` | Create a GitHub issue for the current plan |
| `/reset_context_with_progress` | Update `progress.md` and prepare for a context reset |
| `/review-branch` | Review the current branch's changes with parallel code and test review agents |

## Installation

```bash
git clone https://github.com/bowerhaus/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
bash install.sh
```

`install.sh` creates symlinks from `~/.claude/commands/` into this repo. Re-run after pulling to pick up new commands.
