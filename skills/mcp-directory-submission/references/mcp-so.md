# mcp.so submission (paid)

Verified 2026-08-29 by purchasing a Remote Server listing for a production server. mcp.so is paid-only: $39 one-time per server buys instant publishing without review, a verified badge, featured placement, and dofollow links. Their pitch claims DR 72 (Ahrefs) with 57K backlinks; unverified but plausible for the domain. The purchase decision is the user's; the skill's default stance is that the free channels (official registry, Smithery, aggregators) cover discovery and mcp.so is bought for the backlink.

## Why the backlink is real

Live listing pages render up to three structured link buttons at the top: Homepage, Documentation (Docs), and Repository. All three carry `rel="noopener noreferrer"` with no `nofollow`, so they pass equity. Every link inside the markdown body gets `rel="nofollow ugc"` instead. Consequences:

- Never spend the Homepage field on the MCP endpoint or subdomain. `https://mcp.example.com/mcp` returns JSON-RPC errors to a crawler, never gets indexed, and the equity dies there. Point Homepage at the apex (`https://example.com`).
- Docs and Repository are two more dofollow slots: use a real docs page and the brand's public repo (a private repo 404s for visitors).
- Don't bother putting URLs in the description body; they are nofollowed.
- mcp.so may append `utm_source=mcp_so` to outbound links; the target page's canonical absorbs it.

After the listing is live, view source and confirm your anchors have no `nofollow`/`ugc`/`sponsored` in `rel`, then check the listing page itself gets indexed by Google within a week or two. If either fails on the first purchase, don't buy more.

## Submission flow

1. https://mcp.so/submit, tab **Remote Server** (tabs: MCP Server, Remote Server, MCP Client, AI Agent; pick what the project actually is, miscategorizing wastes the listing).
2. The pre-pay form is minimal: Remote endpoint URL (the real `/mcp` streamable-http URL) and Name. "Pay and submit automatically", $39 via their checkout.
3. Payment unlocks the full edit form. Fields observed:
   - Name, Author (use the brand name, not a personal name, if editable)
   - Description (short text; the auto-generated "X is a remote MCP server available at..." is filler, replace it with the submission sheet's platform-naming description)
   - Category (single slug) and Tags (comma list; replace their auto-guessed tags)
   - Homepage URL and Docs URL (the dofollow slots)
   - GitHub repo URL (dofollow, public repo only)
   - Type (`remote-server`), Endpoint, Server config JSON (`{"mcpServers": {"<id>": {"type": "http", "url": "..."}}}`)
   - Authentication (write "OAuth or API key (Authorization header)"; if single-choice, pick OAuth)
   - Screenshot uploads (max 10MB each) and a markdown Content section (template starts "## What is ...")
4. Content section: What is / Key features / How to use / Use cases, from the submission sheet's long description. No links (nofollowed anyway).

## Categories

Server categories as of 2026-08: developer-tools, ai-agents, cloud-infra, memory-knowledge, media-design, databases, version-control, data-analytics, finance-commerce, productivity, communication, search, browser-automation, files-storage, reasoning, other. Pick the most specific fit, and prefer a smaller category over ai-agents (1,100+ servers) for ranking inside the directory; there is no marketing/social category, communication is the closest for social tools.

## After publishing

The listing URL (`https://mcp.so/servers/<slug>`) goes into the brand's `sameAs` (see entity-stack-kit; the platform table shows mcp.so with a `paid` badge). Record the purchase and the listing URL in the submission sheet.
