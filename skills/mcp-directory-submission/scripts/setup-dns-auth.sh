#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:?Usage: setup-dns-auth.sh <domain>}"
KEYDIR="${HOME}/.mcp-registry"
KEY="${KEYDIR}/${DOMAIN}.pem"
OSSL=$(command -v /opt/homebrew/opt/openssl@3/bin/openssl || command -v /usr/local/opt/openssl@3/bin/openssl || command -v openssl)

if ! "$OSSL" genpkey -algorithm Ed25519 -out /dev/null 2>/dev/null; then
  echo "This openssl cannot generate Ed25519 keys (macOS LibreSSL). Install OpenSSL 3: brew install openssl@3" >&2
  exit 1
fi

mkdir -p "$KEYDIR" && chmod 700 "$KEYDIR"
if [ ! -f "$KEY" ]; then
  "$OSSL" genpkey -algorithm Ed25519 -out "$KEY"
  chmod 600 "$KEY"
fi

PUBLIC_KEY="$("$OSSL" pkey -in "$KEY" -pubout -outform DER | tail -c 32 | base64)"
echo "Key: $KEY (keep it; never commit it)"
echo
echo "Add this TXT record on the APEX of ${DOMAIN} (name @, not a selector):"
echo
echo "${DOMAIN}. IN TXT \"v=MCPv1; k=ed25519; p=${PUBLIC_KEY}\""
echo
echo "Then verify: dig +short TXT ${DOMAIN} @1.1.1.1 | grep MCPv1"
