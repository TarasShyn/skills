# Gotchas

Each entry is something that broke or nearly broke while building and running `worktree.sh` across several repos and parallel agent sessions.

## Git

**G1. A new worktree checks out the committed `.gitignore`, not your working copy.** Adding `.worktree.env` to `.gitignore` in the main checkout does nothing for a worktree branched from a commit that predates the edit, so the file shows up as untracked and `remove` refuses the worktree as dirty. The script writes its ignore entries to `.git/info/exclude` in the shared git directory instead, which every worktree of the repo reads.

**G2. Ignored files do not block `git worktree remove`.** Copied `.env` files and the `node_modules` symlink are gitignored, so a clean worktree removes without `--force`. Untracked files that are not ignored do block it, which is why `remove` checks `git status --porcelain` first and gives a clear message instead of git's.

**G3. Branches outlive worktrees.** `remove` deletes the branch only when it has zero commits beyond the base branch. Anything ahead is kept and named in the log, even with `--force`, because a worktree is cheap to recreate and a lost commit is not.

**G4. Detached HEAD worktrees can be adopted but not protected.** There is no branch to compare against the base, so `remove` cannot tell whether the commits are merged. `adopt` warns about it.

**G5. The default branch is not always `main`.** Hard-coding it breaks `create` in any repo on `master` or `develop`. The script reads `origin/HEAD` first and accepts `WORKTREE_BASE_BRANCH` as an override.

## Claude Code hooks

**G6. `WorktreeCreate` reads the worktree path from stdout.** Any other output on stdout, including git's own progress lines, corrupts the path. Every log line goes to stderr, and `git worktree add` runs with `--quiet` and `>&2`.

**G7. Hook worktree names are free text.** `claude --worktree feature/auth` passes `feature/auth`. The hook sanitizes to `[A-Za-z0-9-]`, trims to 64 characters, and strips the reserved `cw-` prefix used for adopted worktrees.

**G8. Two `WorktreeCreate` hooks fight.** A project-level hook and a global one would both try to create the worktree. The installer warns when it finds another `WorktreeCreate` hook.

**G9. A failed `WorktreeRemove` is not an error the user sees.** When the script refuses (dirty, unmerged), the worktree stays and the reason is in the hook log. That is the intended outcome, but check `worktree.sh list` after sessions end.

**G10. The `PreToolUse` guard sees the whole command string.** It cannot tell `git worktree add` from `echo "git worktree add"` or a JSON test payload that contains the words. Building the string from variables (`w=worktree; ... "git $w add"`) gets a test past it.

**G11. Open sessions keep the instructions they started with.** `CLAUDE.md` is read at session start. The hooks reload when `settings.json` changes in a directory the session already watches, or after `/hooks` is opened once.

## Shell

**G12. macOS `/usr/bin/env bash` is bash 3.2.** No associative arrays, no `mapfile`, no `${var,,}`, and `"${empty[@]}"` under `set -u` is an unbound variable error. The scripts use plain strings and globs throughout.

**G13. `set -E` makes the `ERR` trap fire inside `$(...)`.** The rollback trap checks `$BASH_SUBSHELL` so a failing command substitution cannot delete the worktree or release the lock from a subshell.

**G14. A `mkdir` lock can be left empty.** If a process dies between `mkdir` and writing its pid, the lock has no owner to check. The script treats an empty lock that stays empty for about five seconds as stale.

## Ports

**G15. Slots are counted per repo.** The ownership records live in each repo's `.worktrees/.managed/`, so a back-end and a front-end worktree can both get slot 1. Only matters if both run dev servers whose ports overlap.

**G16. Only HTTP `PORT` values are offset.** gRPC ports and the URLs services use to call each other come from the copied `.env` files unchanged. One full stack per machine at a time, or offset those by hand.

**G17. A slot is skipped when its gateway port is already listening.** If `lsof` finds something on the slot's gateway port, `create` moves to the next slot, so a dev server started outside the script does not get a twin.
