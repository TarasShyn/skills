# What the hosted server must do before any submission

Verified on three production servers, 2026-08-29 to 2026-09-11. Each directory probes the endpoint differently; the list below is the union of what they need.

## OAuth with a real 401 challenge

Clients decide whether to start a login from the very first response. An unauthenticated `POST /mcp` must return:

```
HTTP/1.1 401
WWW-Authenticate: Bearer resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource/mcp", error="invalid_token", error_description="Authentication required"
```

Before this was on, the servers answered `initialize` and `tools/list` anonymously. Claude Code's `claude mcp add --transport http` then connected without a login and every `tools/call` failed with "API key is required". The Claude directory's connect step and the awesome-remote CI both read this challenge; the CI marks a 401 with an OAuth challenge as 🔐 and passes.

Protected resource metadata at `/.well-known/oauth-protected-resource` and at `/.well-known/oauth-protected-resource/mcp` (some clients append the path):

```json
{
  "resource": "https://mcp.example.com/mcp",
  "authorization_servers": ["https://<env>.authkit.app"],
  "bearer_methods_supported": ["header"],
  "resource_name": "Example"
}
```

The authorization server metadata lives on the AuthKit domain, not on the MCP host; do not serve `/.well-known/oauth-authorization-server` yourself.

Keep the switch as an env var that defaults to on (`MCP_OAUTH_REQUIRED !== 'false'`). The first deployment had it defaulting to off with nobody setting it in production, which is why anonymous calls kept working for two weeks.

## WorkOS AuthKit as the authorization server

Free up to 1M MAU. One AuthKit environment per product; a shared legacy environment sends users into the wrong user pool and they sign in as an account the product database has never seen. In the dashboard, Connect, Configuration:

- Enable Dynamic Client Registration. Claude, ChatGPT, and Cursor register themselves. Probe: `POST https://<env>.authkit.app/oauth2/register` with `{"client_name":"probe","redirect_uris":["http://localhost:3118/callback"],"grant_types":["authorization_code"],"response_types":["code"],"token_endpoint_auth_method":"none"}`. Disabled returns `dynamic_client_registration_disabled`; enabled returns 201 with a `client_id`.
- Enable Client ID Metadata Documents. Claude Code sends `client_id=https://claude.ai/oauth/claude-code-client-metadata`.
- List the resource indicator, exactly `https://mcp.example.com/mcp`. AuthKit refuses unlisted `resource=` values.
- Leave External Sign-in URI empty. Setting it breaks the flow unless your endpoint completes the AuthKit handshake, and it receives no per-product context anyway.
- `scope=default` yields `invalid_scope`; clients that send no scope work.

AuthKit's JWKS (`{domain}/oauth2/jwks`) differs from the SSO JWKS; verify tokens against the OAuth one. Clients cache the authorization server they discovered first; after moving environments, remove and re-add the connector.

## API tokens in the same header

Accept the product's API token in `Authorization` with or without `Bearer `:

```ts
const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
```

Branch on token shape: three dot-separated segments means a JWT to verify against the JWKS, anything else is an API token to validate against the product API. Smithery's gateway forwards the user's typed value verbatim and users forget the prefix.

## CORS on every response

Browser-based clients (Glama's playground and gateway) connect straight from the page. Send on every response, not only on OPTIONS:

```
Access-Control-Allow-Origin: *
Access-Control-Expose-Headers: mcp-session-id
```

OPTIONS answers 204 with `Access-Control-Allow-Methods: POST, GET, DELETE, OPTIONS` and `Access-Control-Allow-Headers: Content-Type, Authorization, mcp-session-id`. Without this, Glama's "Use proxy to bypass CORS" mode is the only way in, and that proxy strips `Authorization`, so every authenticated call 401s.

## Well-known files on the MCP host

| Path | Serves | Read by |
| --- | --- | --- |
| `/.well-known/glama.json` | `{"$schema":"https://glama.ai/mcp/schemas/connector.json","maintainers":[{"email":"<glama-account-email>"}]}` | Glama connector claim |
| `/.well-known/openai-apps-challenge` | the token from the ChatGPT portal, plain text, from an env var | ChatGPT domain verification |
| `/.well-known/oauth-protected-resource` and `/mcp` | resource metadata above | every OAuth client |
| `/health` | 200 JSON | your own monitoring, directory uptime probes |

The product site (apex) serves `/.well-known/mcp.json` declaring the registry name and the endpoint; say the header is optional and describe the 401 challenge. Also give the MCP host a `/favicon.ico`; Claude renders a paper-plane placeholder for connectors without one.

These files survive a hosting move as long as the hostname stays; no re-claim was needed when the servers moved between providers.

## Tool metadata

Directories score and diff tool definitions:

- `title` on every tool (Claude's portal shows it).
- `readOnlyHint`, `destructiveHint`, `openWorldHint` set explicitly on every tool; ChatGPT shows "Explicitly provided by your MCP server" and refuses to guess. A URL-fetching tool is open-world; a tool that only reads the product API is not.
- `outputSchema` plus `structuredContent` in results. Smithery scores typed output.
- Descriptions that say when to use this tool versus a sibling and what the parameters relate to. Glama's Tool Definition Quality scored a five-word description 2.9/5 and a tool that never said when to prefer it over its twin 3.4/5; rewriting descriptions was the only change needed to reach A.
- `.describe()` on every zod parameter. Smithery deducts for missing parameter descriptions.
- No wording that instructs the model ("always call X first", "never call this in a loop"). Claude's policy reads that as prompt injection.
- No tool that moves money. Claude's compliance step attests "no financial transactions"; a tool that could trigger a prorated plan upgrade on a saved mandate held one submission in human review until the tool was removed and the REST path stopped charging.

Ask curl with `-H 'Accept: application/json, text/event-stream'`; the SDK returns 406 without it.

## Probes you will see in the logs

- awesome-remote CI: `initialize` with `User-Agent: awesome-remote-mcp-servers-ci/1.0`, no credentials.
- ChatGPT after submission: `server/discover`, malformed `tools/list`, `this/method/does/not/exist` (all should 400), and a `__verifymcp_auth_probe_*__` tool call with no credentials, which must 401.
- Glama health: anonymous unless a Test profile exists.
- Smithery backlink scan: `SmitheryBot/1.0 (+https://smithery.ai)`; allow it through any WAF.

Ignore the 401s these produce; they are the point.

## Hosting notes

Long-lived streaming connections die behind a proxy with a 100-second idle limit (Cloudflare's orange cloud). Keep the MCP hostnames DNS-only if the origin gets its own certificates. When leaving a PaaS, delete its AAAA and `_acme-challenge` records; the end state per host is one A record.
