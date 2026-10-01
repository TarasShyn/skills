# shellcheck shell=bash

PORT_STRIDE=100
PORT_SLOT_MAX=19

resolve_physical_path() {
  local target=$1 dir
  if [ -d "$target" ]; then
    (CDPATH= cd -P -- "$target" 2>/dev/null && pwd -P)
    return
  fi
  dir=$(CDPATH= cd -P -- "$(dirname -- "$target")" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s\n' "$dir" "$(basename -- "$target")"
}

slot_port() { printf '%s\n' $(($1 + $2 * PORT_STRIDE)); }
slot_inspector_port() { printf '%s\n' $(($1 + $2)); }

port_listening() {
  command -v lsof >/dev/null 2>&1 || return 1
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

app_port_var() { printf '%s_PORT\n' "$(printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_')"; }

app_base_port() {
  sed -n 's/^PORT=\([0-9][0-9]*\).*/\1/p' "$1" | head -n 1
}

write_port_env() {
  local root=$1 slug=$2 slot=$3 inspector_base=$4 out=$5 example app base
  {
    printf 'WORKTREE_NAME=%s\n' "$slug"
    printf 'WORKTREE_SLOT=%s\n' "$slot"
    printf 'WORKTREE_PORT_OFFSET=%s\n' "$((slot * PORT_STRIDE))"
    printf 'NODE_INSPECT_PORT=%s\n' "$(slot_inspector_port "$inspector_base" "$slot")"
    for example in "$root"/apps/*/.env.example; do
      [ -f "$example" ] || continue
      base=$(app_base_port "$example")
      [ -n "$base" ] || continue
      app=$(basename -- "$(dirname -- "$example")")
      printf '%s=%s\n' "$(app_port_var "$app")" "$(slot_port "$base" "$slot")"
    done
  } >"$out"
}
