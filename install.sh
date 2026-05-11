#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

link() {
  local src="$1"
  local dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo -e "  ${YELLOW}skipped${NC}  $dst (file exists and is not a symlink)"
    return
  fi
  ln -sf "$src" "$dst"
  echo -e "  ${GREEN}linked${NC}   $dst"
}

echo ""
echo "Installing pycemrg-context commands into $COMMANDS_DIR"
echo ""

mkdir -p "$COMMANDS_DIR"

for cmd in "$REPO_DIR/commands/"*.md; do
  name="$(basename "$cmd")"
  link "$cmd" "$COMMANDS_DIR/$name"
done

echo ""
echo "Done. Start a new Claude Code session to pick up the changes."
echo ""