---
name: agent-markdown
description: >
  Implements the "agent markdown" pattern: serving a Markdown twin of every indexable page to AI agents and CLI clients — via `.md` suffix URLs, `Accept: text/markdown` negotiation, a `/sitemap.md` index, `llms.txt` / `llms-full.txt`, and `rel="alternate"` discovery links. Platform-agnostic (works on any stack with a middleware/edge layer and static hosting), and carries every hard-won gotcha from production deployments on Next.js + Cloudflare Workers: CDNs ignoring Vary, config-level header rules clobbering the handler's no-store and poisoning canonical URLs with Markdown, rewrite recursion through the override directory, locale-redirect collisions with suffix URLs, auth pages leaking into public caches, icon-only table cells going blank in conversion.
  TRIGGER when: user asks to add/serve markdown versions of pages, make a site readable by AI agents/LLMs/crawlers, add llms.txt or llms-full.txt, add a markdown sitemap, add `.md` URLs, negotiate content by Accept header or user agent, or convert rendered HTML pages to Markdown.
  TRIGGER when: modifying an existing implementation of this pattern (markdown middleware branch, markdown route handler, HTML→Markdown converter, authored-override directory) — the gotchas here are regression traps.
  DO NOT TRIGGER when: writing ordinary markdown docs/README/blog content files, or SEO work that doesn't touch the markdown-serving surface.
---

# Agent Markdown Pattern

Serve every indexable page in two representations: canonical HTML for humans and search engines, and a Markdown projection for AI agents and CLI clients. Agents get clean, token-cheap text; the HTML page stays the single canonical document.

The pattern needs only three capabilities from a stack, so it ports anywhere:

1. An **edge/middleware layer** that can inspect requests and rewrite them internally (Next.js middleware, Cloudflare Worker, nginx, Express middleware, …).
2. A **route or build step** that can produce Markdown for a page.
3. **Static file hosting** for authored overrides.

Implementation recipes (dynamic-server and static-export variants, with code) are in `references/rollout.md`. The full gotcha registry is in `references/gotchas.md` — read it before touching routing, caching, or conversion code.

## The five surfaces

Every rollout ships all five. Shipping only some breaks discovery or creates drift.

1. **Per-page Markdown** — `GET /pricing.md` returns the page as Markdown; `GET /pricing` with `Accept: text/markdown` (or a CLI user agent) returns the same document at the canonical URL.
2. **`/sitemap.md`** — Markdown mirror of the sitemap, grouped by section, linking to every page's `.md` URL. Derived from the same source as `sitemap.xml` so the two cannot drift.
3. **`/llms.txt`** — hand-curated link index (a static file), the front door for agents: site blurb plus links to the canonical HTML pages that matter.
4. **`/llms-full.txt`** — curated pages inlined in full under `# <url>` headings. Built at request time from the same files the per-page route serves, so it cannot drift either.
5. **Discovery links** — `<link rel="alternate" type="text/markdown">` on every page (pointing to that page's own `.md`, plus site-wide links to `sitemap.md`, `llms.txt`, `llms-full.txt`), and `sitemap.md` listed in `robots.txt` alongside `sitemap.xml`.

## Two content sources, strict precedence

For any page, the Markdown body comes from one of:

1. **Authored override** — a hand-written `.md` file in static hosting (e.g. `public/agent-md/<route>.md`). Always wins. Write these for the pages that matter most (home, pricing); they also feed `llms-full.txt`.
2. **Automatic conversion** — fetch the page's rendered HTML and convert it to Markdown (conversion rules: `references/gotchas.md` G21–G26). This fallback keeps the Markdown surface complete without authoring every page.

Both are wrapped in YAML frontmatter (`title`, `description`, `url`) where `url` is the **canonical HTML page**, never the `.md` projection — a quoting agent should link somewhere a human can follow.

## Request flow (dynamic sites)

```
request
  → middleware: is this a .md URL, or a client that wants markdown?
      → internal rewrite to the markdown handler (never a redirect)
  → markdown handler:
      1. authored override exists?  → serve it
      2. self-fetch the HTML page (with loop-breaker header, no cookies)
      3. page is noindex / empty?   → markdown 404
      4. convert HTML → Markdown, wrap in frontmatter, serve
```

Detection precedence, in order — each step exists for a reason:

1. **Loop-breaker header present → always HTML.** The handler's own self-fetch must never re-negotiate back into the handler.
2. **`.md` suffix → Markdown.** Unambiguous regardless of headers, and the only variant safe to shared-cache (it's a distinct URL).
3. **`Accept` contains a literal `text/markdown` token → Markdown.** Token match only — a browser's `*/*` wildcard must NOT flip the whole site to Markdown.
4. **`Accept` contains a literal `text/html` token → HTML.** An expressed preference wins in both directions: UA sniffing is a default for clients that said nothing, never an override of what a client asked for. The wildcard counts for neither direction, and markdown wins when both tokens are listed.
5. **Search/social crawler UA → HTML**, even if the UA also looks CLI-ish. Canonical link, hreflang, and structured data live in the HTML; serving crawlers different content also looks like cloaking. They can still opt in explicitly.
6. **CLI/HTTP-library UA → Markdown.** `curl` sends no `Accept` header at all, so UA sniffing is the only signal for the pattern's main audience.
7. Everything else → HTML.

## Static-export sites

No runtime handler exists, so the split moves to build time plus a thin edge worker:

- A build script emits a `.md` twin next to every exported HTML file. When content is **authored as Markdown, copy the source** — round-tripping the compiled HTML loses code fences, tables, and footnotes. Convert HTML only for pages with no Markdown source, and never overwrite a source-derived twin with a conversion of its own output.
- Listing pages assemble their lists at render time, so neither the exported HTML shell nor an `index.md` source contains the list — synthesize the collection index (intro + linked entries) in the build script.
- The worker in front of the assets handles only **negotiation on canonical URLs** (rewrite internally to the sibling `.md` asset); explicit `.md` URLs are already static assets and need nothing.

## Caching — the one rule that is not optional

**Only `.md` suffix URLs may be shared-cached. Negotiated responses must be `private, no-store`.**

A negotiated Markdown response shares its URL with the HTML page and differs only by request headers. CDNs — Cloudflare specifically — **ignore `Vary` for everything except `Accept-Encoding`**, so a shared-cached Markdown body at the canonical URL gets replayed to real browsers. Send `Vary: Accept, User-Agent` anyway (it documents intent and helps compliant caches), but never rely on it. The `.md` URL is a distinct URL whose body is always Markdown, so it can take `public, s-maxage` + `stale-while-revalidate` safely.

Because the output is publicly cacheable, the handler's self-fetch must **strip cookies and auth headers** — a signed-in render must never reach a cacheable Markdown body.

Two hardening rules on top (G35, G36, G38):

- **Headers are not enforcement.** URL-pattern header rules elsewhere in the stack (framework config, CDN page rules) apply to the negotiated response too — it shares the page's URL — and can silently overwrite `no-store` with the page's `public, s-maxage`. Whatever layer actually writes to the shared cache must independently refuse to store a `text/markdown` body under a non-`.md` URL, and must bypass the cache in both directions for markdown-negotiating requests (reading serves them the HTML variant; writing poisons browsers). Verify the live response headers on the deployed site — the handler's code can be correct while the deployed header is wrong.
- **Confirm the cache honors your directives.** Some edge cache APIs ignore `stale-while-revalidate` (Cloudflare's Workers Cache API does), making `s-maxage` the entire effective TTL.

## Not everything gets a Markdown twin

- **Auth-gated pages**: an anonymous self-fetch of `/dashboard` renders the sign-in page, so `/dashboard.md` would serve a sign-in stub. Don't maintain a route blocklist — read the rendered page's own `<meta name="robots" content="noindex">` and 404 the Markdown. The sitemap already excludes these; the noindex check covers direct hits.
- **Empty conversions** (client-only shells, auth redirects): 404, never an empty 200.
- The Markdown 404 is itself a small Markdown document with frontmatter, not an HTML error page.
- `.md` URLs stay **out of `sitemap.xml`** — they are alternate representations, not documents; listing them reports every page to search engines twice. `sitemap.md` is their index.

## Gotchas

The full registry — 39 entries, each an agnostic principle plus the concrete way it bit in production — is in **`references/gotchas.md`**. The highest-severity ones, because they broke production or served wrong content:

- **G1 Override-directory recursion**: authored-override paths end in `.md`; if middleware doesn't pass them through untouched, they get redirected/rewritten back into the markdown route, which re-fetches an ever-longer override path — unbounded recursion that kills the edge runtime. Add a regression test for this path and keep it green.
- **G2 CDN ignores Vary** → the caching rule above.
- **G3 Suffix URLs vs path-normalizing redirects**: `/en.md` reads as locale-less unless routing checks the *suffix-stripped* path — otherwise it redirects into the nonexistent `/en/en.md`. Redirect using the *raw* path so `/pricing.md` keeps its suffix through the hop.
- **G4 Auth/cookie leak into cacheable output** → strip credentials from the self-fetch.
- **G5 Wildcard Accept**: `Accept: */*` must not count as "wants markdown".
- **G35 Header rules clobber `no-store`**: URL-pattern header config elsewhere in the stack can re-mark the negotiated response as publicly cacheable — the handler's code stays correct while the deployed header is wrong.
- **G36 Enforce at the cache layer**: the component doing the cache writes must refuse markdown bodies at non-`.md` URLs and bypass reads/writes for negotiating clients, independent of headers.

## Verifying a rollout

```
curl https://site/pricing            # markdown (CLI UA sniff)
curl https://site/pricing.md         # markdown (suffix, cacheable headers)
curl -H 'Accept: text/markdown' …    # markdown (negotiation, no-store)
curl -H 'Accept: text/html' …        # HTML (explicit opt-out beats UA sniff)
curl -A Googlebot https://site/…     # HTML
browser                              # HTML
curl https://site/dashboard.md       # markdown 404, not a sign-in stub
```

Run these against the **deployed site**, not just locally, and read the response headers: the negotiated response must actually carry `private, no-store` in production (G35), and after a curl of a canonical URL, a browser-UA request to the same URL must still get HTML — the sequence that exposes cache poisoning. A debug header on the cache layer (`HIT` / `MISS` / bypass tags) makes this verifiable at a glance.

Plus: `sitemap.md` lists every indexable page and nothing else; `.md` URLs absent from `sitemap.xml`; `robots.txt` lists both sitemaps; every page's HTML head carries its own `rel="alternate"` markdown link; the home page's `.md` doesn't redirect-loop.
