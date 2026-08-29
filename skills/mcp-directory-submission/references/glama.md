# Glama listings

Verified 2026-08-29 with three production hosted servers. Glama has two separate listing types with different URLs, and confusing them wastes hours:

| | Connector | Server |
| --- | --- | --- |
| URL | `glama.ai/mcp/connectors/<registry-name>` | `glama.ai/mcp/servers/<owner>/<repo>` |
| Source | Auto-scraped from the official MCP registry within a day | Manual submission of a GitHub repo, human-reviewed |
| Score/badge | Tool Definition Quality score on the page; **no badge endpoint** (the badge URL 404s) | Quality score page plus `badges/score.svg` |
| For | Hosted remote servers | Open-source repos Glama can build and run |

## Connectors (automatic)

Publishing to the official registry is the submission; never submit a hosted server manually as a connector. New connectors show "Not tested" until Glama's checker runs; it passes on its own if the endpoint answers an anonymous `initialize`.

Claim the connector by serving `/.well-known/glama.json` from the MCP domain itself:

```json
{
  "$schema": "https://glama.ai/mcp/schemas/connector.json",
  "maintainers": [{ "email": "<glama-account-email>" }]
}
```

The email must match the owner's Glama account and is publicly downloadable, so ask before using a personal address. Glama detects the file within minutes of the owner signing in. Claiming gives listing control, analytics, and health alerts.

## Servers (the scored listing, and how a closed-source product gets one)

Glama only scores repos it can build and run, which normally excludes hosted closed-source servers. The fix: put a Dockerfile in the product's public repo that bridges stdio to the hosted endpoint.

```dockerfile
FROM node:22-alpine
RUN npm install -g mcp-remote
ENTRYPOINT ["mcp-remote", "https://mcp.example.com/mcp"]
```

This passes their stated bar ("the server starts and responds to introspection requests") as long as the hosted server answers `initialize` and `tools/list` anonymously. Test it exactly as their checker will before submitting:

```bash
docker build -t t https://github.com/<owner>/<repo>.git
(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"1.0"}}}'; sleep 15) | docker run -i --rm t
```

Submit at `glama.ai/mcp/servers`, Add Server button, Server tab: name (lowercase product), 1-2 sentence description naming the platforms and noting it connects to the hosted server, and the public repo URL. Submissions are human-reviewed before the page appears.

## Gateway and playground gotchas

- Glama's playground custom headers are literal. The header name must be `Authorization` with value `Bearer <token>`; a header named `apiKey` never reaches the server's auth.
- Their "Use proxy to bypass CORS restrictions" proxy strips the `Authorization` header, so authenticated calls 401 through it. The fix is server-side: send `Access-Control-Allow-Origin: *` (and expose `mcp-session-id`) on every response, not just OPTIONS, then connect without the proxy. Browser-based MCP clients in general need this.
