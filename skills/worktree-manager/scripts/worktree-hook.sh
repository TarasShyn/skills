#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
WORKTREE_SH="$SCRIPT_DIR/worktree.sh"
PAYLOAD=$(cat)

field() { printf '%s' "$PAYLOAD" | jq -r "$1 // empty"; }

enter_project() {
  local dir
  dir=$(field '.cwd')
  [ -n "$dir" ] && [ -d "$dir" ] || dir=${CLAUDE_PROJECT_DIR:-$PWD}
  cd "$dir"
}

sanitize_name() {
  local name
  name=$(printf '%s' "$1" | tr -c 'A-Za-z0-9-' '-' | sed -e 's/^[^A-Za-z0-9]*//' -e 's/^\(cw-\)*//')
  name=$(printf '%s' "$name" | cut -c1-64 | sed 's/-*$//')
  [ -n "$name" ] || name="wt-$(date +%s)"
  printf '%s\n' "$name"
}

slug_for_path() {
  local target=$1 file
  for file in "$(git rev-parse --path-format=absolute --git-common-dir)/../.worktrees/.managed"/*.json; do
    [ -f "$file" ] || continue
    if [ "$(jq -r '.path' "$file")" = "$target" ]; then
      jq -r '.slug' "$file"
      return 0
    fi
  done
  return 1
}

case "${1:-}" in
  create)
    enter_project
    exec "$WORKTREE_SH" create "$(sanitize_name "$(field '.name')")"
    ;;
  remove)
    enter_project
    target=$(field '.worktree_path // .path')
    [ -n "$target" ] || { echo "[worktree] hook payload has no worktree_path" >&2; exit 1; }
    target=$(CDPATH= cd -P -- "$target" 2>/dev/null && pwd -P || printf '%s' "$target")
    slug=$(slug_for_path "$target") || {
      echo "[worktree] '$target' is not managed; left in place (adopt it or remove it by hand)" >&2
      exit 1
    }
    exec "$WORKTREE_SH" remove "$slug"
    ;;
  guard)
    command=$(field '.tool_input.command')
    if printf '%s' "$command" | grep -Eq '(^|[^[:alnum:]_/.-])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+worktree[[:space:]]+(add|remove|rm|move|prune)([[:space:]]|$)'; then
      echo "Raw 'git worktree add/remove/move/prune' is blocked. Use $WORKTREE_SH (create <name> | adopt [path] | remove <name> [--force] | list | gc)." >&2
      exit 2
    fi
    ;;
  *)
    echo "usage: worktree-hook.sh create|remove|guard  (reads the hook payload on stdin)" >&2
    exit 2
    ;;
esac
