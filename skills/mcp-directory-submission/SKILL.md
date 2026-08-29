---
name: mcp-directory-submission
description: Publish a remote MCP server to the official MCP registry (registry.modelcontextprotocol.io) and the MCP directories - Smithery today, more as they get added - with working scripts, the exact server.json shape, DNS domain proof, and the review gotchas. Use this whenever the user wants to submit, publish, list, or register an MCP server anywhere, mentions mcp-publisher, server.json, registry.modelcontextprotocol.io, smithery.ai, MCP marketplaces or directories, or asks how people will discover their MCP server.
---

# MCP directory submission

A remote MCP server that nobody can discover is a private API. This skill publishes it where agents and people look: the official MCP registry first, because aggregator directories scrape it hourly and listings cascade from there, then the directories with their own submission flows.

Everything here was verified by publishing three production servers (com.adaptlypost, com.flowsery, com.redreplier) on 2026-08-29. The registry is in preview; if a step fails oddly, check the live docs at https://github.com/modelcontextprotocol/registry/tree/main/docs before fighting it.

## What you need before starting

- A remote MCP server, publicly reachable over streamable-http (or SSE) at a stable URL on a custom domain.
- Control of that domain's DNS (one TXT record on the apex proves ownership).
- `mcp-publisher` (`brew install mcp-publisher`) for the official registry.

Auth advice for the server itself: accept the API token both as `Bearer <token>` and as a bare `Authorization` value. Directory gateways (Smithery included) forward a user-entered parameter as the raw header value, and users forget the Bearer prefix. One fallback line server-side removes a whole class of support tickets:

```ts
const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
```

## 0. Prepare a submission sheet first

Every directory asks for the same values, and inventing them per form is how listings drift apart. Before the first submission, write one plain-text sheet covering every MCP in the portfolio, one block per product:

- MCP endpoint (custom-domain streamable-http URL) and auth methods
- Registry name (`com.<domain>/mcp-server`) and current version
- Display name, homepage (the product's agents page if it has one), public source repo, icon URL
- Short description, 100 characters or fewer - the registry and Smithery's parameter field both enforce this cap
- Long description in markdown - lead with what the server does for an agent, bullet the tool capabilities, end with one line on auth
- The Smithery connection parameter spec

Write the descriptions from the product's live homepage, not from memory; name the platforms and features the site names. Do not lead with counts ("9 platforms"); list the actual platform names. Keep the sheet next to other submission sheets in the main repo and update it as directories are added; every future form is then a copy-paste job.

## 1. Official MCP registry

The registry stores metadata only. For a remote server there is no package to publish, just a `server.json` and a domain proof.

1. Copy `assets/server.json.template` next to your server project and fill it in. Rules that reject submissions:
   - `name` must match your auth namespace. Domain auth means reverse-DNS: `com.example/mcp-server`. Use the same name your site's `/.well-known/mcp.json` declares.
   - `description` is capped at 100 characters. The API returns 422 above that; write the short version first.
   - The `remotes[].url` must be publicly reachable, custom domain, not a PaaS hostname.
2. Run `scripts/setup-dns-auth.sh <domain>`. It generates an Ed25519 key in `~/.mcp-registry/` and prints the TXT record to add. The record goes on the **apex** (`@`), never under a selector; a selector placement fails with a generic signature error. On macOS the script uses OpenSSL 3 from Homebrew because the system LibreSSL cannot generate Ed25519 keys.
3. Add the TXT record, confirm with `dig +short TXT <domain> | grep MCPv1`, then run `scripts/publish.sh <domain> <dir-with-server.json>`.
4. Publishing several servers: the CLI keeps only the last login's token, so login and publish per domain, in pairs. The publish script does this; do not batch logins first.
5. Verify with `scripts/verify.sh <name-prefix>`; the entry should show `status: active` within seconds.

Keep the key and the TXT record. Version bumps are: edit `server.json`, login, publish again. Full detail and quotes from the docs in `references/official-registry.md`.

## 2. Smithery

Web wizard at https://smithery.ai/new, no CLI. The walkthrough with screenshots-level detail is `references/smithery.md`; the short version:

1. Server ID: the product name, lowercase. The namespace is your account and is fixed.
2. MCP Server URL: the same custom-domain `/mcp` URL as the registry entry.
3. Connection settings: do not skip. Add one parameter, `apiKey`, type string, location **header**, required, with "Output as header" set to `Authorization`. Description caps at 100 characters; "<Product> API token. Create one in <Product> → Settings → API Tokens." fits.
4. After publishing, the Releases tab shows the deployment and a quality score. Expand the score; it lists the exact metadata (icon, homepage, tool annotations) that raises your ranking in their search.
5. "Publish via URL" on an existing server page creates a new release, not a new server.

## 3. Record the listings

Every live listing URL goes into the brand's `sameAs` array (see the `entity-stack-kit` skill in this collection). The Smithery server page is a real profile URL. The official registry has no per-server web page; its value is the aggregators that scrape it, so after a few days search your server name on those directories and collect the pages that appeared.

## Directories to add to this skill later

Not yet written up; claim URLs so the next session can start:

- PulseMCP (https://www.pulsemcp.com) - aggregates the official registry, manual submit exists.
- mcp.so (https://mcp.so/submit) - form submission.
- Glama MCP directory (https://glama.ai/mcp/servers) - claim or add.
- Cline marketplace (https://github.com/cline/mcp-marketplace) - GitHub-based submission.
- Docker MCP Catalog - needs a containerized server; skip for remote-only setups.

## Reference files

- `references/official-registry.md` - the registry runbook: server.json schema facts, DNS auth with key generation, publish errors seen in practice, aggregator model.
- `references/smithery.md` - the Smithery wizard, field by field, with the header-mapping and description-cap gotchas.
- `scripts/setup-dns-auth.sh` - key generation plus the TXT record to paste.
- `scripts/publish.sh` - login and publish for one domain.
- `scripts/verify.sh` - confirm the entry is live in the registry.
- `assets/server.json.template` - remote-server template with the field rules inline.
