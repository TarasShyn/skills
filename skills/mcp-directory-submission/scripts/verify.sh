#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:?Usage: verify.sh <name-prefix, e.g. com.example>}"
curl -s "https://registry.modelcontextprotocol.io/v0/servers?search=${PREFIX}" | python3 -c '
import json, sys
servers = json.load(sys.stdin).get("servers", [])
if not servers:
    print("not found")
    raise SystemExit(1)
for s in servers:
    v = s["server"]
    m = s.get("_meta", {}).get("io.modelcontextprotocol.registry/official", {})
    print(v["name"], "v" + v["version"], "|", m.get("status", "?"), "|", v["remotes"][0]["url"])
'
