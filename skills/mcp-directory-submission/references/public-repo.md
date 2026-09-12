# The one public repo per product

Pick it before the first submission and never switch. Smithery links it, mcp.so and Glama build listing text from its README, Glama builds and runs it, Cursor and xAI install from it, the Claude plugin marketplace pins a commit in it. One product started with two candidate repos and paid for it with a duplicate Glama listing, a rejected review, and re-done badges.

Naming that worked: `<org>/agent` (public, under the product's GitHub org, not a personal account). The hosted server source can stay in a private repo; copy `src/` into the public repo under `mcp-server/` and keep the two in sync on every server change. A private repo cannot be used by any directory, and Glama's approval email reads the repo, so "we'll flip it public later" costs a review round.

## Layout

```
agent/
├── README.md                 Smithery badge on line 3, install commands, hosted config, tool list
├── LICENSE                   MIT; Glama grades a missing license F and refuses installs
├── Dockerfile                builds and runs mcp-server/ over stdio (no mcp-remote)
├── glama.json                Glama server claim, GitHub usernames
├── .mcp.json                 Claude Code config for the hosted endpoint
├── mcp.json                  agent-plugins.org config (Cursor)
├── plugin.json               agent-plugins.org manifest (Cursor), with logo
├── .claude-plugin/
│   ├── plugin.json           Claude plugin manifest
│   └── marketplace.json      lets the repo act as its own marketplace
├── skills/<product>/
│   ├── SKILL.md              the agent skill (keep last-updated fresh; the validator warns after 30 days)
│   └── scripts/<product>.js
└── mcp-server/
    ├── package.json          repository and bugs URLs point at this repo
    ├── bun.lock
    ├── tsconfig.json
    ├── README.md             "# @<product>/mcp-server", hosted one-link config, tool table
    └── src/                  the same code the hosted endpoint runs; stdio when not started with --http
```

`node_modules/` and `.env` in `.gitignore`. The registry's `server.json` lives in a separate small private repo, not here.

## File shapes

`glama.json` (schema has exactly one property):

```json
{
  "$schema": "https://glama.ai/mcp/schemas/server.json",
  "maintainers": ["<github-username>"]
}
```

`.mcp.json`. Reference an env var; xAI's security scan reads this file and a placeholder like `TOKEN_HERE` looks like a leaked credential. In the Claude plugin repo, omit `headers` entirely so the plugin connects over OAuth:

```json
{
  "mcpServers": {
    "<product>": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "headers": { "Authorization": "Bearer ${EXAMPLE_API_KEY}" }
    }
  }
}
```

`mcp.json` (Cursor reads this one):

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  "mcpServers": {
    "<product>": {
      "type": "streamable-http",
      "url": "https://mcp.example.com/mcp",
      "headers": { "Authorization": "Bearer ${EXAMPLE_API_KEY}" }
    }
  }
}
```

`plugin.json` (Cursor and agent-plugins.org):

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "<product>",
  "version": "1.1.0",
  "description": "What the agent can do, naming the platforms or data.",
  "author": { "name": "<Brand>", "email": "contact@example.com", "url": "https://example.com" },
  "homepage": "https://example.com/features/agents",
  "repository": "https://github.com/<org>/agent",
  "license": "MIT",
  "keywords": ["<product>", "mcp"],
  "logo": "https://cdn.example.com/public/brand/logo-512.png"
}
```

`.claude-plugin/plugin.json` carries name, description, version, author, repository, license, homepage. `.claude-plugin/marketplace.json` lists the plugin with `"source": "./"` and `"strict": true`.

`Dockerfile`. Glama runs it; the only bar is that the server starts and answers `initialize` and `tools/list` with a placeholder token:

```dockerfile
FROM oven/bun:1-alpine
WORKDIR /app/mcp-server
COPY mcp-server/package.json mcp-server/bun.lock ./
RUN bun install --frozen-lockfile --production
COPY mcp-server/src ./src
CMD ["bun", "run", "src/index.ts"]
```

Test it the way Glama does:

```bash
docker build -t probe https://github.com/<org>/agent.git
(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"1.0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'; sleep 5) \
  | docker run -i --rm -e EXAMPLE_API_TOKEN=placeholder probe
```

An `mcp-remote` shim (`ENTRYPOINT ["mcp-remote", "https://mcp.example.com/mcp"]`) passes this local test but Glama's Dockerfile form rejects it outright.

## README

The first screen decides two reviews. Glama's human reviewer rejected a repo whose README "does not describe an MCP server implementation, tools, resources, or SDK usage, only how to configure a client". mcp.so builds the listing text from it, so a README that opens with `npx skills add` reads like a skill page on a server directory. Order that passed:

1. H1, then the Smithery badge, then one sentence naming what the agent can do and on which platforms.
2. Install (skill command, manual copy).
3. Setup (account, API token, config).
4. What it does (the tool capabilities as bullets).
5. "Run it locally" with a stdio config pointing at `mcp-server/src/index.ts`, and the hosted one-link config.
6. Links: product, agents page, docs, API tokens.

Use one contact address (`contact@example.com`) in every manifest and README; a stray `support@` address in one file gets copied into forms.

## Releases and versions

A GitHub release tag is not required by any directory. Glama cuts its own release from Build & Release; Claude pins a commit; xAI pins a SHA you type into the PR. Bump `.claude-plugin/plugin.json` and `plugin.json` versions when the skill or config changes so Anthropic's nightly sync has something to pick up.

## What each directory reads

| Directory | Reads |
| --- | --- |
| Glama server | README, LICENSE, `glama.json`, Dockerfile or the admin build config, `mcp-server/` |
| Smithery | README badge (backlink scan), the repo link in Settings |
| mcp.so | README (listing body), the repo link (dofollow) |
| Claude plugins | `.claude-plugin/plugin.json`, `.mcp.json`, `skills/` at a pinned commit |
| Cursor | `plugin.json`, `mcp.json`, `skills/` |
| xAI | `.claude-plugin/plugin.json`, `.mcp.json` (security scan), pinned SHA |
| awesome-mcp-servers | the repo URL as the entry link, Glama server score badge |
