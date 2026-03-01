#!/usr/bin/env bash
# 6D plugin installer for Claude Code
# Usage: bash install.sh [--uninstall]

set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS=( 6D 6D-discover 6D-design 6D-demonstrate 6D-develop 6D-document 6D-debrief )

uninstall=false
if [[ "${1:-}" == "--uninstall" ]]; then
  uninstall=true
fi

mkdir -p "$SKILLS_DIR"

for skill in "${SKILLS[@]}"; do
  target="${SKILLS_DIR}/${skill}"
  source="${REPO_DIR}/skills/${skill}"

  if $uninstall; then
    if [[ -L "$target" ]]; then
      rm "$target"
      echo "Removed symlink: $target"
    elif [[ -d "$target" ]]; then
      echo "Warning: $target is a real directory (not a symlink) — skipping. Remove manually if desired."
    fi
  else
    if [[ -e "$target" && ! -L "$target" ]]; then
      echo "Warning: $target already exists and is not a symlink — skipping. Remove it manually to install."
      continue
    fi
    ln -sf "$source" "$target"
    echo "Installed: $target -> $source"
  fi
done

if $uninstall; then
  echo "6D skills uninstalled."
else
  echo "6D skills installed. Reload Claude Code to pick up the new skills."
fi
