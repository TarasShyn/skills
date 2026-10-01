#!/usr/bin/env bash

set -euo pipefail

SRC=$(CDPATH= cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CLAUDE_HOME=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
DEST="$CLAUDE_HOME/scripts"
SETTINGS="$CLAUDE_HOME/settings.json"
MEMORY="$CLAUDE_HOME/CLAUDE.md"

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required (brew install jq / apt install jq)" >&2; exit 1; }

mkdir -p "$DEST"
for file in worktree.sh port-offset.sh worktree-hook.sh; do
  cp "$SRC/$file" "$DEST/$file"
  chmod 0755 "$DEST/$file"
done

[ -f "$SETTINGS" ] || printf '{}\n' >"$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-worktree"

jq --arg hook "$DEST/worktree-hook.sh" '
  def ours: (.hooks // []) | any(.command // "" | contains("worktree-hook.sh"));
  def cmd($mode): {type: "command", command: ("bash \"" + $hook + "\" " + $mode)};
  .hooks //= {}
  | .hooks.WorktreeCreate = ([(.hooks.WorktreeCreate // [])[] | select(ours | not)]
      + [{hooks: [cmd("create") + {timeout: 120, statusMessage: "Creating worktree via worktree.sh"}]}])
  | .hooks.WorktreeRemove = ([(.hooks.WorktreeRemove // [])[] | select(ours | not)]
      + [{hooks: [cmd("remove") + {timeout: 60}]}])
  | .hooks.PreToolUse = ([(.hooks.PreToolUse // [])[] | select(ours | not)]
      + [{matcher: "Bash", hooks: [cmd("guard")]}])
' "$SETTINGS.bak-worktree" >"$SETTINGS.tmp"
mv "$SETTINGS.tmp" "$SETTINGS"

if [ "$(jq '.hooks.WorktreeCreate | length' "$SETTINGS")" -gt 1 ]; then
  echo "WARN: $SETTINGS has another WorktreeCreate hook; remove it so only one hook creates worktrees" >&2
fi

RULE="- Manage every git worktree with \`$DEST/worktree.sh\` (\`create <name>\`, \`adopt [path]\`, \`remove <name> [--force]\`, \`list\`, \`gc\`). Never run \`git worktree add/remove/move/prune\` directly; a global hook blocks it. New worktrees go in \`<repo>/.worktrees/<name>\` on branch \`worktree-<name>\`, and each gets a \`.worktree.env\` with its port slot."
touch "$MEMORY"
grep -Fq 'worktree.sh' "$MEMORY" || printf '\n%s\n' "$RULE" >>"$MEMORY"

echo "Installed scripts to $DEST"
echo "Hooks merged into $SETTINGS (backup: $SETTINGS.bak-worktree)"
echo "Rule added to $MEMORY"
echo "Restart open Claude Code sessions, or open /hooks once, to load the hooks."
