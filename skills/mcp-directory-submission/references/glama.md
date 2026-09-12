# Glama listings

Verified 2026-08-29 to 2026-09-11 with three production hosted servers. Glama has two listing types with different URLs, and confusing them wastes hours:

| | Connector | Server |
| --- | --- | --- |
| URL | `glama.ai/mcp/connectors/<registry-name>` | `glama.ai/mcp/servers/<owner>/<repo>` |
| Source | Scraped from the official MCP registry, about an hour after publish | You submit a public GitHub repo; a human approves it |
| Score | Tool Definition Quality (TDQS) plus endpoint health, from a live probe | Coherence, TDQS, Maintenance, from a build Glama runs itself |
| Badge | `.../badges/score.svg`, required by awesome-remote-mcp-servers | `.../badges/score.svg`, required by awesome-mcp-servers |
| Claim | `/.well-known/glama.json` on the MCP host | `glama.json` in the repo root, then "Login with GitHub to claim" |

## Connector

Publishing to the registry is the submission. Never submit a hosted server through the Add Connector button; that is the user-side gateway. The page reprints the registry description verbatim, so fix a bad description at the registry and republish.

### Claim

Serve this from the MCP host itself:

```json
{
  "$schema": "https://glama.ai/mcp/schemas/connector.json",
  "maintainers": [{ "email": "<glama-account-email>" }]
}
```

The email must match the account that signs in to Glama and is publicly downloadable, so ask before using a personal address. The connector page also offers an HTTP challenge or a DNS record. Once claimed, the admin area has Listing, Test profile, Publisher, Analytics, and Advertising tabs.

### Health, and why it turns Unhealthy

The health probe is anonymous. The day the servers started requiring auth on `initialize`, all three connectors flipped to Unhealthy, and the awesome-remote-mcp-servers maintainer refused to merge: "the connector must be Healthy before we can merge. For OAuth-protected servers, ensure OAuth works correctly in Glama, or send test credentials to support@glama.ai."

The fix is self-serve. Admin, Test profile: "Glama uses this profile to check server health and index its available tools." Pick Authentication Type OAuth 2.0 and sign in with the review account, or API Key, or add a Custom Header `Authorization: Bearer <token>`. Press Test Connection. All three went Healthy within the hour and TDQS was rescored (A, 4.7/5) from the authenticated tool list. Do not re-enable anonymous `initialize` to satisfy the probe; that puts the server in "partial auth" mode and contradicts what the Claude directory submission declared.

"OAuth: Works in Glama" on the public page only means Glama found the OAuth metadata; it says nothing about health.

### Playground

Custom headers are literal. Name the header `Authorization` with value `Bearer <token>`; a header named `apiKey` never reaches the server. Untick "Use proxy to bypass CORS restrictions" once the server sends CORS headers on every response; the proxy strips `Authorization`.

## Server

### What the reviewer wants

Submit at `glama.ai/mcp/servers`, Add Server, Server tab: name (lowercase product), a one or two sentence description naming the platforms and saying it connects to the hosted server, the public repo URL. A human reviews it and emails approve or reject with a reason.

Two of three repos passed on the first try. The third was rejected twice: "The repository is not an MCP server; it's an agent that connects to a hosted MCP server. The README does not describe or contain an MCP server implementation, only a client configuration to connect to an external server. This fails criterion 3." The approved repos had the same README structure; the differences were a root `.mcp.json` and a README section that describes the server and its tools. Add both before submitting (see `public-repo.md`). Resubmitting the same repo after the fix went through.

The listing is tied to the repo at creation and cannot be repointed. Submitting two repos for one product creates two listings; ask support@glama.ai to drop one.

### Getting a score

The approval email says: "Once claimed, you can provide a Dockerfile via your server's admin page on Glama. This Dockerfile is used by Glama to run automated safety and quality checks. Only servers that pass these checks are listed in search results." Until a Glama release exists the score page shows "No Glama release" and the badge renders without a grade, and the awesome-mcp-servers maintainer will not merge ("the server must be evaluated by Glama with a quality score set, any grade is fine").

Claim first: put `glama.json` with GitHub usernames in the repo root, then "Login with GitHub to claim" on the server page. The checklist then shows "Author verified" and "Has valid glama.json".

Then Admin, Dockerfile. The form has Node.js version, Build steps (JSON array), CMD arguments (JSON array), an env JSON Schema, Placeholder parameters, an optional pinned commit, and a Build & Release button. An `mcp-remote` shim is rejected on submit: "CMD cannot use mcp-remote. The Dockerfile must build and run the server locally, not proxy to an external endpoint." Values that built in 24 seconds:

```
Build steps:   ["npm install -g bun", "cd mcp-server && bun install --frozen-lockfile --production"]
CMD arguments: ["bun", "run", "mcp-server/src/index.ts"]
Env schema:    {"type":"object","properties":{"EXAMPLE_API_TOKEN":{"type":"string","description":"Your Example API token from https://example.com/api-tokens"}},"required":["EXAMPLE_API_TOKEN"]}
Placeholder:   {"EXAMPLE_API_TOKEN":"placeholder"}
```

The env var name must be the one the server reads; a wrong name builds fine and fails the tool listing. Build & Release opens a test page, shows "success" and "Release Created" with an auto-incremented version (0.1.0, then 0.1.1). The saved config persists, so later rebuilds are Sync Server plus Build & Release.

Gotchas:

- "Sync Server" runs as a background job; the page keeps showing the old commit for a minute or more after GitHub has the new one. Click, wait, click again. Pinning a SHA does not skip the lag.
- Grades appeared within minutes of the first release for one server and took up to a day for the others. A rebuild does not re-grade immediately.
- Score page lists every tool with its TDQS. Descriptions that fail to say when to use a tool versus its sibling score in the 3s; five-word descriptions score under 3. Rewriting descriptions alone took all three from B to A.
- Profile completion counts "related servers" that only users can add. On `/related-servers`, Suggest Server, type a name, pick it (no login needed). Suggesting the product's own siblings and its competitors moved profile completion from 83% to 92%.
- A server under a personal account shows "claimed by its maintainer"; one under the product's org shows "official vendor server". Use the org.
- `/related` 404s; the page is `/related-servers`. The API is `https://glama.ai/api/mcp/v1/servers/<owner>/<repo>`.

### Badges

```
[![<owner>/<repo> MCP server](https://glama.ai/mcp/servers/<owner>/<repo>/badges/score.svg)](https://glama.ai/mcp/servers/<owner>/<repo>)
```

Live-rendered, so a PR that embeds it updates on its own once the score exists.
