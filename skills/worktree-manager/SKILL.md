---
name: worktree-manager
description: >
  Routes every git worktree a coding agent creates through one script, `worktree.sh`: worktrees land in `<repo>/.worktrees/<name>` on branch `worktree-<name>` from the repo's default branch, with `node_modules` symlinked, the gitignored `.env` files copied, a per-worktree port slot in `.worktree.env`, and an ownership record so `remove` refuses to throw away uncommitted work or unmerged commits. Ships an installer that wires Claude Code's `WorktreeCreate` and `WorktreeRemove` hooks to the script, adds a `PreToolUse` guard that blocks raw `git worktree add/remove/move/prune`, and writes the rule into `~/.claude/CLAUDE.md`.
  TRIGGER when: user asks to set up, standardize, or enforce how worktrees are created; to run parallel agent sessions or subagents in isolated checkouts; to stop worktrees from colliding on ports or missing `.env` files and dependencies; or to make `claude --worktree`, `EnterWorktree` or `isolation: "worktree"` use a custom script.
  TRIGGER when: creating, listing, adopting or removing a worktree on a machine where this skill is installed. Use the script, never raw `git worktree`.
  DO NOT TRIGGER when: the user asks about plain branching, stashing, or git concepts that do not involve worktrees.
---

# Worktree manager

One script owns every worktree. Agents, subagents, `claude --worktree` and you at the terminal all go through `worktree.sh`, so every worktree is set up the same way and torn down safely.

## Install

```bash
bash scripts/install.sh
```

It needs `git` and `jq`, and it is safe to re-run. It does four things:

1. Copies `worktree.sh`, `port-offset.sh` and `worktree-hook.sh` to `~/.claude/scripts/` (or `$CLAUDE_CONFIG_DIR/scripts/`).
2. Merges three hooks into `~/.claude/settings.json` and saves the old file as `settings.json.bak-worktree`. Hooks from other tools stay untouched, and a second run replaces this skill's hooks instead of duplicating them.
3. Appends one rule to `~/.claude/CLAUDE.md` naming the script and its commands.
4. Prints a reminder to restart open sessions (or open `/hooks` once) so they load the hooks.

## Commands

| Command | What it does |
| --- | --- |
| `worktree.sh create <name>` | New worktree at `<repo>/.worktrees/<name>` on `worktree-<name>`, branched from the default branch. Re-running with the same name prints the existing path |
| `worktree.sh adopt [path]` | Takes over a worktree Claude Code already made in `<repo>/.claude/worktrees/<name>`, managed as `cw-<name>` |
| `worktree.sh remove <name> [--force]` | Refuses a dirty worktree or a branch with commits not on the base branch. `--force` removes the worktree but keeps an unmerged branch |
| `worktree.sh list` | Managed worktrees with slot, branch, commits ahead and clean/dirty state, plus unmanaged ones under `.claude/worktrees/` |
| `worktree.sh gc` | Prunes git's worktree list and drops records whose worktree is gone. Never deletes a directory |

`create` prints only the worktree path on stdout and logs everything else to stderr, which is what Claude Code's `WorktreeCreate` hook requires.

## What `create` sets up

1. Finds the main checkout through `git rev-parse --git-common-dir`, so it works from inside any worktree.
2. Takes a `mkdir` lock in `.worktrees/.managed/.lock`, and clears it when the owning process is dead.
3. Picks the base branch: `$WORKTREE_BASE_BRANCH`, then `origin/HEAD`, then `main`, `master` or `develop`.
4. Runs `git worktree add`. A branch that already exists is checked out again rather than recreated, so `remove` followed by `create` resumes the work.
5. Symlinks `node_modules` from the main checkout when there is one.
6. Copies the gitignored `.env` and `.env.local` at the root and `.env` files up to two folders deep, skipping `node_modules`.
7. Picks the lowest free port slot (1 to 19) and writes `.worktree.env` with `WORKTREE_SLOT`, `WORKTREE_PORT_OFFSET` and `NODE_INSPECT_PORT`. In a repo with `apps/*/.env.example` files that set `PORT=`, it also writes one `<APP>_PORT` per app at that base port plus 100 per slot.
8. Adds `/.worktrees/` and `/.worktree.env` to `.git/info/exclude`, so no repo needs a `.gitignore` change.
9. Writes `.worktrees/.managed/<name>.json` with the path, branch, base commit and slot.

If a step after `git worktree add` fails, an `ERR` trap removes the half-made worktree and any branch it created.

Run a dev server on its slot:

```bash
set -a; . ./.worktree.env; set +a
PORT=$AUTH_PORT npm run dev
```

## How the agent ends up using it

- **Rule.** `CLAUDE.md` loads into every session, so the agent calls `worktree.sh` itself when it wants a worktree.
- **`WorktreeCreate` / `WorktreeRemove` hooks.** `claude --worktree <name>`, the `EnterWorktree` tool and subagents with `isolation: "worktree"` run the script in place of Claude Code's built-in git logic. Hook names are sanitized to `[A-Za-z0-9-]`, so `feature/Auth` becomes `feature-Auth`.
- **`PreToolUse` guard.** A Bash command that runs `git worktree add`, `remove`, `rm`, `move` or `prune` is blocked with exit code 2, and the message names the script. The agent reads it and retries with the script. `git worktree list` is allowed.

A removal through the hook is never forced. If the work has uncommitted changes or unmerged commits, the worktree stays and the hook logs why.

## Gotchas

The full list is in `references/gotchas.md`. The ones that will bite first:

- **The guard matches text, not intent.** `echo git worktree prune` is blocked too. To test the guard, build the string from variables.
- **Port slots are per repo.** Two repos can both hand out slot 1. Only HTTP ports are offset, so gRPC ports and URLs services use to reach each other still collide if two full stacks run at once.
- **Manual worktrees skip the remove hook.** A worktree the agent made by calling the script is not cleaned up when the session ends. Run `worktree.sh remove <name>` after merging.
- **Already-open sessions** keep the `CLAUDE.md` they loaded at start. The hooks still apply to them once reloaded.
- **macOS ships bash 3.2.** The scripts avoid arrays, `mapfile` and `${var,,}` for that reason. Keep it that way when editing them.
