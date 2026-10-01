#!/usr/bin/env bash

set -Eeuo pipefail

log() { printf '[worktree] %s\n' "$*" >&2; }
warn() { log "WARN: $*"; }
fatal() { log "FATAL: $*"; exit 1; }
usage() {
  printf 'Usage:\n  worktree.sh create <name>\n  worktree.sh adopt [path]\n'
  printf '  worktree.sh remove <name> [--force]\n  worktree.sh list\n  worktree.sh gc\n'
}

COMMAND=${1:-help}
case "$COMMAND" in
  help | -h | --help) usage; exit 0 ;;
  create | adopt | remove | list | gc) shift ;;
  *) usage >&2; exit 2 ;;
esac
command -v git >/dev/null 2>&1 || fatal "git not on PATH"
command -v jq >/dev/null 2>&1 || fatal "jq not on PATH"
SCRIPT_DIR=$(CDPATH= cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
[ -f "$SCRIPT_DIR/port-offset.sh" ] || fatal "helper '$SCRIPT_DIR/port-offset.sh' is missing"
. "$SCRIPT_DIR/port-offset.sh"
CONTEXT_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || fatal "run this command from a repository checkout"
GIT_COMMON_DIR=$(git -C "$CONTEXT_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
  || fatal "could not resolve the shared Git directory"
MAIN_ROOT=$(resolve_physical_path "$(dirname "$GIT_COMMON_DIR")") || fatal "could not resolve the main checkout"
WORKTREE_PARENT="$MAIN_ROOT/.worktrees" ADOPT_PARENT="$MAIN_ROOT/.claude/worktrees" ADOPT_PREFIX=cw-
OWNERSHIP_DIR="$WORKTREE_PARENT/.managed" LOCK_DIR="$WORKTREE_PARENT/.managed/.lock" LOCK_HELD=0
INSPECTOR_BASE=9229 WORKTREE_ENV_FILE=.worktree.env

detect_base_branch() {
  local ref candidate
  if [ -n "${WORKTREE_BASE_BRANCH:-}" ]; then
    printf '%s\n' "$WORKTREE_BASE_BRANCH"
    return
  fi
  ref=$(git -C "$MAIN_ROOT" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [ -n "$ref" ] && git -C "$MAIN_ROOT" show-ref --verify --quiet "refs/heads/${ref#origin/}"; then
    printf '%s\n' "${ref#origin/}"
    return
  fi
  for candidate in main master develop; do
    if git -C "$MAIN_ROOT" show-ref --verify --quiet "refs/heads/$candidate"; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  git -C "$MAIN_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || fatal "could not detect a base branch; set WORKTREE_BASE_BRANCH"
}
BASE_BRANCH=$(detect_base_branch)

valid_name() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,63}$ ]]; }
validate_name() { valid_name "$1" || fatal "name '$1' must match [A-Za-z0-9][A-Za-z0-9-]{0,63}"; }
slug_is_adopted() { case "$1" in "$ADOPT_PREFIX"?*) return 0 ;; *) return 1 ;; esac; }
slug_base() { printf '%s\n' "${1#"$ADOPT_PREFIX"}"; }
slug_parent() { if slug_is_adopted "$1"; then printf '%s\n' "$ADOPT_PARENT"; else printf '%s\n' "$WORKTREE_PARENT"; fi; }
worktree_path() { printf '%s/%s\n' "$(slug_parent "$1")" "$(slug_base "$1")"; }
ownership_file() { printf '%s/%s.json\n' "$OWNERSHIP_DIR" "$1"; }
port_file() { printf '%s/%s.env\n' "$OWNERSHIP_DIR" "$1"; }
owned_field() { jq -r --arg f "$2" '.[$f] // empty' "$(ownership_file "$1")" 2>/dev/null; }
branch_name() { if slug_is_adopted "$1"; then owned_field "$1" branch; else printf 'worktree-%s\n' "$1"; fi; }
branch_exists() { git -C "$MAIN_ROOT" show-ref --verify --quiet "refs/heads/$1"; }
branch_oid() { git -C "$MAIN_ROOT" rev-parse "$1" 2>/dev/null; }
ahead_of_base() { git -C "$MAIN_ROOT" rev-list --count "$BASE_BRANCH..$1" 2>/dev/null; }
absent() { [ ! -e "$1" ] && [ ! -L "$1" ]; }
present_entry() { [ -e "$1" ] || [ -L "$1" ]; }

assert_layout_physical() {
  local dir resolved
  for dir in "$WORKTREE_PARENT" "$ADOPT_PARENT" "$OWNERSHIP_DIR"; do
    case "$dir" in "$MAIN_ROOT"/*) ;; *) fatal "'$dir' must be strictly beneath the physical repository root" ;; esac
    [ ! -L "$dir" ] || fatal "'$dir' is a symlink; refusing worktree operations"
    [ -e "$dir" ] || continue
    [ -d "$dir" ] || fatal "'$dir' exists but is not a directory"
    resolved=$(resolve_physical_path "$dir") || fatal "could not resolve '$dir'"
    [ "$resolved" = "$dir" ] || fatal "'$dir' resolves outside its expected physical path"
  done
}

target_is_safe() {
  local target resolved
  target=$(worktree_path "$1")
  case "$target" in "$(slug_parent "$1")"/*) ;; *) return 1 ;; esac
  [ ! -L "$target" ] || return 1
  [ -e "$target" ] || return 0
  [ -d "$target" ] && resolved=$(resolve_physical_path "$target") && [ "$resolved" = "$target" ]
}
assert_target_safe() { target_is_safe "$1" || fatal "managed target for '$1' is not a physical directory strictly beneath '$(slug_parent "$1")'"; }

acquire_lock() {
  local owner stale waited=0 empty_waits=0
  assert_layout_physical
  mkdir -p "$OWNERSHIP_DIR"
  assert_layout_physical
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    owner=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)
    stale=0
    if [ -z "$owner" ]; then
      empty_waits=$((empty_waits + 1))
      [ "$empty_waits" -lt 50 ] || stale=1
    elif ! kill -0 "$owner" 2>/dev/null; then
      stale=1
    fi
    if [ "$stale" = 1 ]; then
      warn "removing stale lock left by pid ${owner:-unknown}"
      rm -rf "$LOCK_DIR"
      continue
    fi
    waited=$((waited + 1))
    [ "$waited" -lt 600 ] || fatal "timed out waiting for the lock held by pid ${owner:-unknown}"
    sleep 0.1
  done
  printf '%s\n' "$$" >"$LOCK_DIR/pid"
  LOCK_HELD=1
}
release_lock() {
  [ "$LOCK_HELD" = 1 ] || return 0
  rm -rf "$LOCK_DIR"
  LOCK_HELD=0
}
trap release_lock EXIT

registered_worktree() {
  git -C "$MAIN_ROOT" worktree list --porcelain | grep -Fxq "worktree $1"
}

worktree_dirty() { [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]; }

used_slots() {
  local file
  for file in "$OWNERSHIP_DIR"/*.json; do
    [ -f "$file" ] || continue
    jq -r '.slot // empty' "$file"
  done
}

allocate_slot() {
  local slot used gateway_base
  used=" $(used_slots | tr '\n' ' ') "
  gateway_base=$(app_base_port "$MAIN_ROOT/apps/gateway/.env.example" 2>/dev/null || true)
  for slot in $(seq 1 "$PORT_SLOT_MAX"); do
    case "$used" in *" $slot "*) continue ;; esac
    if [ -n "$gateway_base" ] && port_listening "$(slot_port "$gateway_base" "$slot")"; then
      continue
    fi
    printf '%s\n' "$slot"
    return 0
  done
  fatal "all $PORT_SLOT_MAX port slots are taken; remove a worktree or run gc"
}

link_shared_dirs() {
  local target=$1
  if absent "$target/node_modules" && [ -d "$MAIN_ROOT/node_modules" ]; then
    ln -s "$MAIN_ROOT/node_modules" "$target/node_modules"
  fi
}

copy_env_files() {
  local target=$1 file rel
  for file in "$MAIN_ROOT"/.env "$MAIN_ROOT"/.env.local "$MAIN_ROOT"/*/.env "$MAIN_ROOT"/*/*/.env; do
    [ -f "$file" ] || continue
    rel=${file#"$MAIN_ROOT"/}
    case "$rel" in node_modules/* | */node_modules/*) continue ;; esac
    [ -d "$(dirname "$target/$rel")" ] || continue
    absent "$target/$rel" || continue
    cp -p "$file" "$target/$rel"
  done
}

write_ownership() {
  local slug=$1 kind=$2 path=$3 branch=$4 slot=$5 base_oid=$6 tmp
  tmp=$(mktemp "$OWNERSHIP_DIR/.tmp.XXXXXX")
  jq -n \
    --arg slug "$slug" --arg kind "$kind" --arg path "$path" --arg branch "$branch" \
    --arg base "$BASE_BRANCH" --arg baseOid "$base_oid" --argjson slot "$slot" \
    --arg createdAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{slug: $slug, kind: $kind, path: $path, branch: $branch, base: $base, baseOid: $baseOid, slot: $slot, createdAt: $createdAt}' \
    >"$tmp"
  mv "$tmp" "$(ownership_file "$slug")"
}

ensure_excluded() {
  local exclude="$GIT_COMMON_DIR/info/exclude" entry
  mkdir -p "$(dirname "$exclude")"
  for entry in "/$WORKTREE_ENV_FILE" /.worktrees/; do
    grep -Fxq "$entry" "$exclude" 2>/dev/null || printf '%s\n' "$entry" >>"$exclude"
  done
}

provision() {
  local slug=$1 target=$2 slot=$3
  link_shared_dirs "$target"
  copy_env_files "$target"
  write_port_env "$MAIN_ROOT" "$slug" "$slot" "$INSPECTOR_BASE" "$(port_file "$slug")"
  cp "$(port_file "$slug")" "$target/$WORKTREE_ENV_FILE"
}

CREATE_TARGET="" CREATE_BRANCH="" CREATE_NEW_BRANCH=0
rollback_create() {
  [ "$BASH_SUBSHELL" = 0 ] && [ -n "$CREATE_TARGET" ] || return 0
  warn "rolling back partial worktree '$CREATE_TARGET'"
  git -C "$MAIN_ROOT" worktree remove --force "$CREATE_TARGET" >/dev/null 2>&1 || true
  if [ "$CREATE_NEW_BRANCH" = 1 ]; then
    git -C "$MAIN_ROOT" branch -D "$CREATE_BRANCH" >/dev/null 2>&1 || true
  fi
  release_lock
}

cmd_create() {
  local name=${1:-} target branch slot base_oid
  [ -n "$name" ] || { usage >&2; exit 2; }
  validate_name "$name"
  ! slug_is_adopted "$name" || fatal "names starting with '$ADOPT_PREFIX' are reserved for adopted worktrees"
  acquire_lock
  assert_target_safe "$name"
  target=$(worktree_path "$name")
  branch=$(branch_name "$name")

  if [ -f "$(ownership_file "$name")" ] && registered_worktree "$target"; then
    log "'$name' already exists on $(owned_field "$name" branch)"
    printf '%s\n' "$target"
    return 0
  fi
  absent "$target" || fatal "'$target' exists but is not a managed worktree"
  base_oid=$(branch_oid "$BASE_BRANCH") || fatal "base branch '$BASE_BRANCH' not found"
  slot=$(allocate_slot)

  CREATE_TARGET=$target CREATE_BRANCH=$branch
  trap 'rollback_create' ERR
  if branch_exists "$branch"; then
    log "reusing existing branch $branch ($(ahead_of_base "$branch") commits ahead of $BASE_BRANCH)"
    git -C "$MAIN_ROOT" worktree add --quiet "$target" "$branch" >&2
  else
    CREATE_NEW_BRANCH=1
    git -C "$MAIN_ROOT" worktree add --quiet -b "$branch" "$target" "$BASE_BRANCH" >&2
  fi
  provision "$name" "$target" "$slot"
  write_ownership "$name" created "$target" "$branch" "$slot" "$base_oid"
  trap - ERR
  CREATE_TARGET=""

  log "created '$name' on $branch at $target (port slot $slot)"
  printf '%s\n' "$target"
}

cmd_adopt() {
  local input=${1:-$PWD} target base slug branch slot
  target=$(git -C "$input" rev-parse --show-toplevel 2>/dev/null) || fatal "'$input' is not inside a git checkout"
  target=$(resolve_physical_path "$target") || fatal "could not resolve '$input'"
  case "$target" in
    "$ADOPT_PARENT"/*) ;;
    "$WORKTREE_PARENT"/*) fatal "'$target' was created by this script; nothing to adopt" ;;
    *) fatal "only worktrees directly under '$ADOPT_PARENT' can be adopted" ;;
  esac
  base=${target#"$ADOPT_PARENT"/}
  case "$base" in */*) fatal "'$target' is nested below '$ADOPT_PARENT'" ;; esac
  validate_name "$base"
  slug="$ADOPT_PREFIX$base"

  acquire_lock
  assert_target_safe "$slug"
  registered_worktree "$target" || fatal "'$target' is not a registered worktree of $MAIN_ROOT"
  if [ -f "$(ownership_file "$slug")" ]; then
    log "'$slug' is already managed"
    printf '%s\n' "$target"
    return 0
  fi
  branch=$(git -C "$target" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  [ -n "$branch" ] || warn "'$target' has a detached HEAD; remove will leave its commits unreferenced"
  slot=$(allocate_slot)
  provision "$slug" "$target" "$slot"
  write_ownership "$slug" adopted "$target" "$branch" "$slot" "$(branch_oid "$BASE_BRANCH" || true)"
  log "adopted '$slug' on ${branch:-detached HEAD} (port slot $slot)"
  printf '%s\n' "$target"
}

cmd_remove() {
  local name=${1:-} force=0 target branch ahead
  [ -n "$name" ] || { usage >&2; exit 2; }
  case "${2:-}" in "") ;; --force) force=1 ;; *) usage >&2; exit 2 ;; esac
  [ $# -le 2 ] || { usage >&2; exit 2; }
  validate_name "$name"
  acquire_lock
  [ -f "$(ownership_file "$name")" ] || fatal "'$name' is not a managed worktree (see: worktree.sh list)"
  assert_target_safe "$name"
  target=$(worktree_path "$name")
  branch=$(branch_name "$name")

  if registered_worktree "$target"; then
    if worktree_dirty "$target" && [ "$force" = 0 ]; then
      fatal "'$name' has uncommitted changes; commit them or pass --force"
    fi
    ahead=0
    [ -z "$branch" ] || ahead=$(ahead_of_base "$branch" || printf '0')
    if [ "$ahead" -gt 0 ] && [ "$force" = 0 ]; then
      fatal "$branch has $ahead commits not on $BASE_BRANCH; merge them or pass --force (the branch is kept)"
    fi
    rm -f "$target/$WORKTREE_ENV_FILE"
    [ ! -L "$target/node_modules" ] || rm -f "$target/node_modules"
    if [ "$force" = 1 ]; then
      git -C "$MAIN_ROOT" worktree remove --force "$target" >&2
    else
      git -C "$MAIN_ROOT" worktree remove "$target" >&2
    fi
  elif present_entry "$target"; then
    fatal "'$target' exists but git no longer tracks it; inspect it, delete it by hand, then run gc"
  else
    warn "'$target' was already gone"
  fi

  if [ -n "$branch" ] && [ "$branch" != "$BASE_BRANCH" ] && branch_exists "$branch"; then
    ahead=$(ahead_of_base "$branch" || printf '1')
    if [ "$ahead" = 0 ]; then
      git -C "$MAIN_ROOT" branch -D "$branch" >/dev/null
      log "deleted branch $branch"
    else
      log "kept branch $branch ($ahead commits ahead of $BASE_BRANCH)"
    fi
  fi
  rm -f "$(ownership_file "$name")" "$(port_file "$name")"
  log "removed '$name'"
}

cmd_list() {
  local file slug target branch slot state ahead dir base
  assert_layout_physical
  printf '%-36s %-5s %-44s %-7s %-8s %s\n' NAME SLOT BRANCH AHEAD STATE PATH
  for file in "$OWNERSHIP_DIR"/*.json; do
    [ -f "$file" ] || continue
    slug=$(jq -r '.slug' "$file")
    target=$(jq -r '.path' "$file")
    branch=$(jq -r '.branch // ""' "$file")
    slot=$(jq -r '.slot' "$file")
    ahead=-
    [ -z "$branch" ] || ahead=$(ahead_of_base "$branch" || printf '?')
    if ! registered_worktree "$target"; then
      state=missing
    elif worktree_dirty "$target"; then
      state=dirty
    else
      state=clean
    fi
    printf '%-36s %-5s %-44s %-7s %-8s %s\n' "$slug" "$slot" "${branch:-detached}" "$ahead" "$state" "$target"
  done
  for dir in "$ADOPT_PARENT"/*/; do
    [ -d "$dir" ] || continue
    base=$(basename "$dir")
    [ ! -f "$(ownership_file "$ADOPT_PREFIX$base")" ] || continue
    printf '%-36s %-5s %-44s %-7s %-8s %s\n' "($base)" - - - unmanaged "${dir%/}"
  done
}

cmd_gc() {
  local file slug target
  acquire_lock
  git -C "$MAIN_ROOT" worktree prune
  for file in "$OWNERSHIP_DIR"/*.json; do
    [ -f "$file" ] || continue
    slug=$(jq -r '.slug' "$file")
    target=$(jq -r '.path' "$file")
    registered_worktree "$target" && continue
    if present_entry "$target"; then
      warn "'$target' is on disk but git no longer tracks it; left in place"
      continue
    fi
    rm -f "$file" "$(port_file "$slug")"
    log "dropped stale record '$slug'"
  done
  find "$OWNERSHIP_DIR" -maxdepth 1 -name '.tmp.*' -type f -delete 2>/dev/null || true
}

case "$COMMAND" in create | adopt | remove) ensure_excluded ;; esac
case "$COMMAND" in
  create) cmd_create "$@" ;;
  adopt) cmd_adopt "$@" ;;
  remove) cmd_remove "$@" ;;
  list) cmd_list ;;
  gc) cmd_gc ;;
esac
