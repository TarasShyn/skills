#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:?Usage: publish.sh <domain> <dir-with-server.json>}"
DIR="${2:?Usage: publish.sh <domain> <dir-with-server.json>}"
KEY_FILE="${HOME}/.mcp-registry/${DOMAIN}.pem"
OSSL=$(command -v /opt/homebrew/opt/openssl@3/bin/openssl || command -v /usr/local/opt/openssl@3/bin/openssl || command -v openssl)

[ -f "$KEY_FILE" ] || { echo "No key at $KEY_FILE. Run setup-dns-auth.sh $DOMAIN first." >&2; exit 1; }
[ -f "$DIR/server.json" ] || { echo "No server.json in $DIR" >&2; exit 1; }

dig +short TXT "$DOMAIN" @1.1.1.1 | grep -q MCPv1 || { echo "TXT record for $DOMAIN not visible yet." >&2; exit 1; }

KEY_HEX=$("$OSSL" pkey -in "$KEY_FILE" -outform DER | tail -c 32 | xxd -p -c 64)
cd "$DIR"
mcp-publisher login dns --domain "$DOMAIN" --private-key "$KEY_HEX"
mcp-publisher publish
