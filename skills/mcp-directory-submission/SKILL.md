---
name: mcp-directory-submission
description: Publish a remote MCP server everywhere agents look for one - the official MCP registry (registry.modelcontextprotocol.io), Smithery, Glama connectors and servers, the Claude Connectors Directory and Claude plugin marketplace, ChatGPT apps, awesome-remote-mcp-servers and awesome-mcp-servers, Cursor and xAI marketplaces, and the paid mcp.so - with the public repo layout every directory expects, working scripts, the exact server.json, DNS domain proof, OAuth requirements, and the review gotchas from three production servers. Use this whenever the user wants to submit, publish, list, register, or get approved for an MCP server anywhere, mentions mcp-publisher, server.json, glama.json, Smithery, Glama, mcp.so, the Claude directory, ChatGPT apps, awesome-mcp-servers, MCP marketplaces or directories, or asks how people will discover their MCP server.
---

# MCP directory submission

A remote MCP server nobody can find is a private API. This skill lists it where agents and people look. Everything here comes from publishing three production servers (AdaptlyPost, Flowsery, RedReplier) between 2026-08-29 and 2026-09-11, including the rejections. Directories change their rules without notice; when a step fails oddly, read the live docs linked in the reference file before fighting it.

## Order of operations

The order matters because listings feed each other. Do them in this sequence:

1. Make the server meet the requirements in the next section (OAuth challenge, CORS, well-known files, tool annotations).
2. Build the public repo (`references/public-repo.md`). Every directory except the registry reads it.
3. Official registry. Aggregators scrape it hourly; the Glama connector appears from this on its own.
4. Glama: claim the connector, set the Test profile so health stays green, then list the repo as a server and cut a release so it gets a score.
5. Smithery.
6. Claude Connectors Directory, then the Claude plugin marketplace (the plugin bundles the approved connector).
7. awesome-remote-mcp-servers (needs the Glama connector healthy) and, only if the repo ships a runnable stdio server, awesome-mcp-servers (needs the Glama server score).
8. ChatGPT apps, Cursor, xAI. Paid mcp.so last, if the user wants the backlink.
9. Record every live URL in the brand's `sameAs`.

## What the server must do first

Every directory probes the endpoint, and three of them (Claude, ChatGPT, Glama) sign in and call the tools. Ship these before the first form:

- Streamable HTTP at a custom-domain URL like `https://mcp.example.com/mcp`. Never a PaaS hostname; listings outlive infra moves.
- OAuth per the MCP spec. An unauthenticated `initialize` returns `401` with `WWW-Authenticate: Bearer resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource/mcp"`. That challenge is what makes `claude mcp add --transport http` and the Claude directory's connect step start a login. If the server answers anonymously, clients conclude no auth is needed and every tool call fails later. Details in `references/server-requirements.md`.
- API tokens still work in the same `Authorization` header, with or without the `Bearer ` prefix. Smithery's gateway and users forget the prefix; one fallback line removes a class of support tickets.
- CORS on every response, not only OPTIONS. Glama's playground and gateway run in the browser; their CORS proxy strips `Authorization`.
- Well-known files on the MCP host. `/.well-known/glama.json` (connector claim), `/.well-known/openai-apps-challenge` (ChatGPT domain proof), `/.well-known/oauth-protected-resource` and its `/mcp` variant.
- Every tool carries `title`, a description that says when to use it versus its siblings, `.describe()` on every parameter, `readOnlyHint`, `destructiveHint`, `openWorldHint`, and an `outputSchema`. Claude's portal and ChatGPT's form diff these against the live server; Glama and Smithery score them.
- No tool that can charge the user's card. Claude's compliance step asks you to attest "no financial transactions"; a keyword-activation tool that triggered a plan upgrade put one submission into a human queue while the other two auto-approved in minutes.

## Submission sheet

Every directory asks for the same values, and inventing them per form is how listings drift apart. Write one sheet per product before the first form, keep it outside the repo (it will hold review credentials), and copy from it:

- MCP endpoint, auth modes, registry name (`com.<domain>/mcp-server`) and version
- Display name, apex homepage, the agents page, the MCP setup docs page, privacy URL, support email (one contact address per brand, use it everywhere)
- Public repo (exactly one per product, decided before anything is submitted; switching mid-campaign means redoing badges, PR entries, and pending reviews)
- Icon URL, a 512x512 PNG on a white plate hosted on the brand CDN. Favicons get scraped at 127px otherwise, and Cursor wants a 1:1 plate.
- Short description, 100 characters or fewer, naming the platforms or data the server touches. Never counts ("9 networks"); the names are what people search.
- Long description in markdown: what the server does for an agent, a bullet list of tool capabilities, one line on auth. Write it from the product's live homepage.
- A review account with a verified email, no MFA, a live plan, and data to read. Claude and ChatGPT both need it; keep it working after approval because they re-test.

## 1. Official MCP registry

Metadata only; for a remote server there is no package, just `server.json` and a domain proof.

1. Copy `assets/server.json.template`. `name` is reverse-DNS of the domain (`com.example/mcp-server`) and must match what the site's `/.well-known/mcp.json` declares. `description` over 100 characters fails with `422 expected length <= 100`. `remotes[].url` is the custom domain.
2. `scripts/setup-dns-auth.sh <domain>` generates an Ed25519 key in `~/.mcp-registry/` and prints the TXT record. It goes on the apex (`@`), never under a selector. macOS needs Homebrew OpenSSL 3; LibreSSL cannot make Ed25519 keys.
3. Add the TXT in the DNS dashboard (the Cloudflare wrangler token cannot write DNS), confirm with `dig +short TXT <domain> @1.1.1.1 | grep MCPv1`, run `scripts/publish.sh <domain> <dir-with-server.json>`.
4. Several domains: the CLI keeps only the last login's token, so login and publish per domain, in pairs. Batching logins first gives `403 You have permission to publish: com.a/*`.
5. `scripts/verify.sh com.example` shows `status: active` within seconds.

Server code changes need no republish; the entry only points at the URL. Description changes do, because aggregators reprint it verbatim. Old versions stay listed. Keep `server.json` in a small private repo per product. Full runbook: `references/official-registry.md`.

## 2. Glama, connector and server

Two listing types, different URLs, both wanted:

- Connector (`glama.ai/mcp/connectors/<registry-name>`) appears about an hour after the registry publish. Claim it by serving `/.well-known/glama.json` with the owner's Glama account email. Its health check is anonymous, so once the server requires auth it goes Unhealthy; open Admin, Test profile, and sign in with OAuth or paste an API key. Do not loosen auth to please the probe. The connector badge (`.../badges/score.svg`) is what awesome-remote-mcp-servers requires, and the maintainer refuses to merge while it says Unhealthy.
- Server (`glama.ai/mcp/servers/<owner>/<repo>`) is a human-reviewed submission of a public GitHub repo. It gets a quality score only after Glama builds and runs the server from that repo. A Dockerfile that shells out to `mcp-remote` is rejected: "CMD cannot use mcp-remote. The Dockerfile must build and run the server locally." Ship the stdio server source in the public repo (see `references/public-repo.md`), claim with a root `glama.json` listing GitHub usernames, then Build & Release from the admin page. The listing's repo cannot be changed after creation.

The reviewer rejected one repo twice as "an agent that connects to a hosted MCP server, not an MCP server"; the approved repos differed only by having `.mcp.json` at the root and the server README. Runbook, form values, and the score checklist: `references/glama.md`.

## 3. Smithery

Web wizard at https://smithery.ai/new. Server ID is the product name; the namespace is your account. Connection settings: one parameter `apiKey`, type string, location `header` (the default is `query`, which never reaches your auth), output as header `Authorization`, description under 100 characters. Then the Settings tab (display name, markdown description, homepage, public repo, icon) and two verifications: a `smithery-verification=` TXT next to the registry's record on the apex, and a badge in the repo README. Server pages are `smithery.ai/servers/<namespace>/<id>`, plural. Score breakdown and what each point costs: `references/smithery.md`.

## 4. Claude Connectors Directory and Claude plugins

Submitting a connector needs a Team or Enterprise org where you are Owner; the portal is `https://claude.ai/admin-settings/directory/submissions/new`. The wizard connects to the server over OAuth with your review account, reads the tool list once, and walks eleven steps (listing, use cases, company, authentication, data handling, test instructions, compliance). Two of three submissions passed the automated scan within minutes; the third sat in review because a tool could charge money. Slug is permanent, categories max five and there is no "Data" category, the Documentation link must be the MCP setup page, and the icon needs a custom URL if the MCP host has no favicon. Changing the server after the connect step means Change, reconnect, so the portal re-reads the tools.

Plugins go through `platform.claude.com/plugins/submit` into `anthropics/claude-plugins-community`, which users add by hand; the official marketplace on claude.com is curated with no application path. Bundle a `.mcp.json` with `type: http` and no headers so the plugin connects the approved connector over OAuth. Pins point at a commit and only Anthropic bumps them; submissions cannot be withdrawn. Field-by-field values and the rejection cause: `references/claude-directory.md`.

## 5. The two awesome lists

`punkpeye/awesome-remote-mcp-servers` is where hosted endpoints go since 2026-09-08; the older `awesome-mcp-servers` now closes hosted-server PRs with a redirect. The remote list wants a three-line entry (name linked to the homepage, the endpoint in backticks, the Glama connector badge, an auth marker and a one-sentence description under 120 characters), alphabetical within category, from an account that has starred the repo, with `🤖🤖🤖` at the end of the PR title for the agent fast track. CI runs an anonymous `initialize` (a 401 with an OAuth challenge passes as 🔐) and checks the connector exists; the maintainer then checks it is Healthy. All three merged within minutes of the health fix.

The local list still accepts a repo that ships a runnable stdio server, with the Glama server score badge; the maintainer holds the PR until the score exists. Formats and CI details: `references/awesome-lists.md`.

## 6. ChatGPT apps

Portal `https://platform.openai.com/plugins`, Standard type, OAuth only (the connector dialog offers OAuth or None). Domain proof is a token served at `/.well-known/openai-apps-challenge`. Upload `chatgpt-app-submission.json` after Scan Tools, or the justifications land on stale tools. Exactly five test cases and three negative cases, read-only or draft-only, each standalone, with "last month" windows so the reviewer's date does not empty the result. Subtitle 30 characters. Test credentials block and a demo video recorded on web and mobile in Chat mode with Developer Mode on. All three first submissions were rejected because the live server had drifted from the JSON (more tools, changed annotations, a negative case that now triggers). Regenerate the JSON from the live server before every submission. Details: `references/chatgpt-apps.md`.

## 7. mcp.so (paid, $39 one-time per server)

Paid-only since mid-2026. The fee buys instant publishing, a verified badge, and up to three dofollow links (Homepage, Docs, Repository) from a DR ~70 domain; body links are `nofollow ugc`. That backlink is the reason to pay; buying is the user's call. Submit on the Remote Server tab with the real `/mcp` endpoint, never the repo tab. Point Homepage at the apex, not the MCP subdomain. The listing text is built from the repo README, and repointing the repo later needs a support ticket. Walkthrough and categories: `references/mcp-so.md`.

## 8. Cursor and xAI marketplaces

Cursor (`cursor.com/marketplace/publish`) reviews by hand, wants an open-source repo with a root `plugin.json` and `mcp.json` in the agent-plugins.org format, a kebab-case org handle, and a 1:1 logo. xAI (`xai-org/plugin-marketplace`) takes a PR adding one catalog entry with a pinned commit SHA; its security scan reads MCP configs, so `.mcp.json` must reference env vars, not placeholder tokens. Both in `references/other-marketplaces.md`.

## 9. Record the listings

Every live URL goes into the brand's `sameAs` (see the `entity-stack-kit` skill): Smithery server page, Glama connector and server pages, mcp.so listing, the merged awesome-list anchors, the Claude directory page once live. The official registry has no per-server page; search the aggregators for the server name after a few days and collect what appeared. PulseMCP has no submission path; search pulsemcp.com periodically. Cline's marketplace (`github.com/cline/mcp-marketplace`) and the Docker MCP Catalog were skipped for remote-only servers.

## Reference files

- `references/server-requirements.md` - OAuth challenge, WorkOS AuthKit settings (DCR, client ID metadata, resource indicators), CORS, well-known files, tool annotations, the probes each directory sends.
- `references/public-repo.md` - the one public repo per product: layout, every file with its exact shape, and which directory reads which file.
- `references/official-registry.md` - server.json rules, DNS auth, publish errors, aggregator model.
- `references/glama.md` - connector claim and Test profile, server submission, Build & Release form values, score checklist, related servers, playground gotchas.
- `references/smithery.md` - wizard field by field, Settings tab, verifications, score breakdown.
- `references/claude-directory.md` - Connectors Directory steps and field caps, plugin submission, what blocks approval.
- `references/awesome-lists.md` - entry formats, CI checks, and maintainer rules for both punkpeye lists.
- `references/chatgpt-apps.md` - portal, submission JSON, test-case rules, rejection causes.
- `references/mcp-so.md` - paid listing, dofollow fields, post-payment form, categories.
- `references/other-marketplaces.md` - Cursor and xAI.
- `scripts/setup-dns-auth.sh`, `scripts/publish.sh`, `scripts/verify.sh` - registry key, publish, and check.
- `assets/server.json.template` - registry entry for a remote server.
- `assets/public-repo/` - `glama.json`, `.mcp.json`, `mcp.json`, `Dockerfile`, and `well-known-glama.json` templates for the public repo and the MCP host.
