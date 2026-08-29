# Official MCP registry runbook

Source docs: https://github.com/modelcontextprotocol/registry/tree/main/docs/modelcontextprotocol-io (read 2026-08-29). The registry is in preview; "breaking changes or data resets may occur before general availability."

## server.json for a remote server

```json
{
  "$schema": "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
  "name": "com.example/mcp-server",
  "title": "Example",
  "description": "Under 100 characters or the API rejects it with 422.",
  "version": "1.0.0",
  "remotes": [
    { "type": "streamable-http", "url": "https://mcp.example.com/mcp" }
  ]
}
```

- `remotes[].type` is `streamable-http` (recommended) or `sse`; both can be listed at different URLs.
- The URL "MUST be publicly accessible".
- URL template variables (`https://{tenant}.example.com/mcp`) are supported with a `variables` map for multi-tenant servers.
- Observed in practice: `description` over 100 characters returns `422 Unprocessable Entity, expected length <= 100`. The schema page does not shout about this; the API enforces it.

## Namespaces and authentication

The auth method determines the allowed name:

| Auth | Name format |
| --- | --- |
| GitHub (`mcp-publisher login github`) | `io.github.<user-or-org>/*` |
| Domain (DNS or HTTP) | reverse-DNS of the domain, `com.example/*` and `com.example.*` |

Use domain auth for a brand: the name then matches what the site's `/.well-known/mcp.json` declares, and it doesn't depend on a GitHub account. Org GitHub namespaces require org Owner role.

## DNS auth, step by step

1. Generate an Ed25519 key. macOS ships LibreSSL which fails with `Algorithm Ed25519 not found`; use Homebrew OpenSSL 3 explicitly:

```bash
OSSL=/opt/homebrew/opt/openssl@3/bin/openssl
$OSSL genpkey -algorithm Ed25519 -out ~/.mcp-registry/example.com.pem
PUBLIC_KEY="$($OSSL pkey -in ~/.mcp-registry/example.com.pem -pubout -outform DER | tail -c 32 | base64)"
echo "example.com. IN TXT \"v=MCPv1; k=ed25519; p=${PUBLIC_KEY}\""
```

2. Add the TXT record on the **apex** of the domain (name `@`). The docs are explicit: SPF-style placement, not DKIM-style. A record under `_mcp-auth.example.com` is invisible to the registry and fails with a generic signature error. When rotating keys, delete the old apex record; a stale one gets tried first and breaks verification.

3. Confirm propagation: `dig +short TXT example.com @1.1.1.1 | grep MCPv1`.

4. Log in with the private key as a hex seed (the last 32 bytes of the DER encoding):

```bash
KEY=$($OSSL pkey -in ~/.mcp-registry/example.com.pem -outform DER | tail -c 32 | xxd -p -c 64)
mcp-publisher login dns --domain example.com --private-key "$KEY"
```

## Publishing

Run `mcp-publisher publish` in the directory containing `server.json`.

The trap with multiple domains: login state is a single token holding the permissions of the **last** login. Publishing server B after logging into domain A fails with `403 Forbidden: You have permission to publish: com.a/*`. Always pair login and publish per domain.

## Verify and maintain

```bash
curl -s "https://registry.modelcontextprotocol.io/v0/servers?search=com.example" | jq
```

The entry carries `status: active` and a publish timestamp in `_meta`. Version bumps: edit `version` in server.json, login, publish. There is no delete in the docs; treat names as permanent.

## Aggregators

The registry exposes an unauthenticated read API (`GET /v0.1/servers`, cursor pagination, `updated_since` filter) that downstream directories are expected to scrape "on a regular but infrequent basis (e.g., once per hour)". Practical consequence: publish here first, then check the aggregator directories a few days later before submitting to them manually.
