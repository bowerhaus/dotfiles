#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

mkdir -p ~/.claude/commands

for f in "$DOTFILES/claude/commands/"*.md; do
  ln -sf "$f" ~/.claude/commands/"$(basename "$f")"
  echo "  linked: ~/.claude/commands/$(basename "$f")"
done

echo "Done. Symlinks created in ~/.claude/commands/"
