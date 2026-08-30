# Agent Markdown — Gotcha Registry

Every gotcha hit while shipping this pattern in production. Each entry states the **agnostic principle** first, then **how it manifested** on the stack where it was first hit (Next.js middleware / Cloudflare Workers). When implementing on another stack, the principle is the part that transfers; the manifestation tells you what the symptom looks like.

Severity: 🔴 broke production or served wrong content · 🟡 SEO/correctness damage · 🔵 quality/cost.

## Routing & middleware

### G1 🔴 The override directory must bypass ALL middleware transforms
**Principle:** Static files whose paths end in `.md` must never re-enter the markdown pipeline. Any middleware that redirects (locale, trailing slash, https) or rewrites `.md` paths will loop on them.
**Manifestation:** Overrides lived at `/agent-md/**` and were fetched by the markdown route itself. Without an early pass-through, the fetch got locale-redirected, then rewritten back into the markdown route, which re-requested an ever-longer override path — unbounded recursion; Cloudflare killed the Worker with error 1102. Fix: `if (path.startsWith('/agent-md/')) return next()` before every other middleware branch — and a regression test asserting the override path produces no redirect and no rewrite.

### G2 🔴 The self-fetch needs a loop-breaker header, checked first
**Principle:** The markdown handler fetches its own site's HTML. That request travels back through the same middleware; without an explicit bypass signal it re-negotiates into the handler — infinite loop, even on non-`.md` paths, because the self-fetch UA can itself look like a bot.
**Manifestation:** A custom header (e.g. `x-agent-markdown-render: 1`) set on every internal fetch; both the middleware and the "wants markdown" detector check it before anything else. Belt-and-suspenders: also send `accept: text/html` on the self-fetch.

### G3 🔴 Path-normalize on the suffix-stripped path, redirect on the raw path
**Principle:** Suffix URLs confuse any path-shape-based routing (locale prefixes, trailing slashes). Normalize using the logical path, but preserve the suffix through redirects.
**Manifestation:** `/en.md` is the homepage's Markdown twin, but the raw path is neither `/en` nor `/en/…`, so locale detection read it as locale-less and 301'd it into the nonexistent `/en/en.md`. Fix: run the locale check against `stripMarkdownExtension(path) ?? path`; the redirect itself still uses the raw path so a genuinely locale-less `/pricing.md` becomes `/en/pricing.md`, keeping its suffix through the hop.

### G4 🟡 Run the markdown rewrite AFTER path normalization
**Principle:** Rewrite to the markdown handler only once the path is in canonical shape, so the handler sees exactly one path format instead of every pre-normalization variant.
**Manifestation:** The markdown branch sits after the locale/https/trailing-slash block, so by the time it runs, `/pricing.md` has already collapsed to `/en/pricing.md`.

### G5 🔴 Rewrite internally; never redirect to the markdown handler
**Principle:** The handler route is an internal implementation detail. Redirecting exposes it, breaks the canonical-URL story, and crawlers are unreliable across 3xx hops.
**Manifestation:** An internal rewrite to `/agent-markdown/<path>`; that route is never linked from anywhere.

### G6 🟡 Forward request context describing the PAGE, not the rewrite
**Principle:** After an internal rewrite the handler can no longer trust the URL it received; pass the original pathname/locale/query along (custom headers work well) so it can rebuild the canonical URL.
**Manifestation:** `x-pathname`, `x-language`, `x-search` stamped on the rewritten request. Next.js-specific trap: set them on the **request** headers (`NextResponse.next({ request: { headers } })`), not just the response — server components reading `headers()` only see request headers. Setting response-only made `<html lang>` fall back to `accept-language` and render `en` on `/es/...` pages (flagged by Ahrefs as a hreflang mismatch).

### G7 🟡 Site-wide index files must bypass locale routing
**Principle:** `sitemap.md` and `llms-full.txt` are site-wide (no locale dimension); locale-prefixing them 404s the well-known URLs agents actually try.
**Manifestation:** Added to the same root-asset bypass list as `robots.txt`/`sitemap.xml`. Locale selection for `sitemap.md` goes through a query param (`?lng=`) instead.

### G8 🟡 Suffix URLs collide with other suffix conventions
**Principle:** Once you serve `<route>.md`, audit every other magic suffix on the platform for the same path-shape collisions.
**Manifestation:** Next.js static-export apps probe RSC payloads at `<route>.txt`, so a link to `/en` arrived as `/en.txt` → locale-redirected to `/en/en.txt` → 404. Worse, the buggy 301 carried no cache-control and browsers cached it forever; a doubled-locale collapse redirect had to be shipped just to rescue those clients. Any new suffix needs the same stripping treatment `.md` got.

## Content negotiation

### G9 🔴 Match Accept as literal tokens, never substring/wildcard
**Principle:** Browsers send `Accept: text/html,...,*/*;q=0.8`. If a wildcard counts as "accepts markdown", every browser gets Markdown.
**Manifestation:** Split on `,`, strip `;q=` params, compare each token exactly to `text/markdown` / `text/x-markdown`.

### G10 🟡 CLI clients send no Accept header — sniff the UA
**Principle:** `curl` sends no `Accept` at all; if negotiation is header-only, the pattern's main audience never sees Markdown.
**Manifestation:** A UA allowlist of CLI/HTTP libraries (curl, wget, httpie, python-requests, aiohttp, httpx, go-http-client, node-fetch, undici, axios, got, okhttp, powershell, deno, bun, …) gets Markdown by default.

### G11 🔴 Search and social crawlers must keep getting HTML
**Principle:** Canonical link, hreflang alternates, OG tags, and structured data live only in the HTML. UA-sniffing a crawler into Markdown destroys SEO and looks like cloaking.
**Manifestation:** An explicit crawler UA pattern (Googlebot, Bingbot, GPTBot, OAI-SearchBot, ClaudeBot, PerplexityBot, CCBot, Bytespider, ahrefs/semrush, …) is **excluded** from CLI sniffing and always gets HTML. Crawlers can still opt in via explicit `Accept: text/markdown` or a `.md` URL. Full precedence: bypass header → `.md` suffix → `Accept: text/markdown` → `Accept: text/html` (G39) → crawler exclusion → CLI UA → HTML.

### G39 🟡 An explicit `Accept: text/html` opts a CLI client back out
**Principle:** Negotiation must work in both directions. UA sniffing is a default for clients that expressed no preference — not an override of an expressed one. A literal `text/html` (or `application/xhtml+xml`) token returns HTML even from a CLI UA; the wildcard `*/*` (curl's default) counts for **neither** direction. If both markdown and html tokens are listed, markdown wins — an agent naming markdown with an html fallback should get markdown.
**Manifestation:** `curl -H "Accept: text/html"` returned Markdown because the only Accept handling was the markdown opt-in, so people testing "what browsers see" from a terminal concluded the site served Markdown to browsers. Full precedence became: bypass header → `.md` suffix → `Accept: text/markdown` → `Accept: text/html` → crawler UA → CLI UA → HTML.

### G12 🔴 The `.md` suffix outranks negotiation
**Principle:** An explicit URL is unambiguous regardless of headers, and it is the only cacheable variant — check it first.
**Manifestation:** The suffix branch runs before header/UA detection and stamps a marker header (e.g. `x-agent-markdown-suffix: 1`) so the handler knows this response may carry shared-cache headers.

## Caching

### G13 🔴 CDNs ignore Vary — never shared-cache a negotiated response
**Principle:** A negotiated Markdown body shares its URL with the HTML page. Any shared cache that doesn't honor `Vary: Accept, User-Agent` will replay Markdown to browsers at the canonical URL.
**Manifestation:** Cloudflare ignores `Vary` for everything except `Accept-Encoding`. Negotiated responses: `private, no-store`. `.md` suffix URLs only: `public, max-age=0, s-maxage=3600, stale-while-revalidate=86400`. `Vary` is still sent — as documentation of intent, not protection.

### G35 🔴 Framework header rules silently clobber the handler's Cache-Control
**Principle:** Config-level header rules matched by URL pattern (framework config `headers()`, CDN page rules) apply to every response at that URL — including the negotiated Markdown twin, which shares the canonical URL. The handler's `private, no-store` can be overwritten to the page's `public, s-maxage` without any change to the markdown code, re-breaking G13 from outside it. Verify the **live** response header on the deployed site, not the code.
**Manifestation:** URL-pattern cache rules in the framework config (set so the CDN would edge-cache HTML pages) overrode the markdown route's `private, no-store` in production. The negotiated response shipped publicly cacheable, an edge cache stored it under the canonical URL, and browsers — and crawlers on cache hits — got Markdown until the TTL expired. Every unit test on the handler passed; only curling the deployed site exposed it.

### G36 🔴 Enforce "never cache negotiated Markdown" in the cache layer itself
**Principle:** Response headers are advice that other layers can clobber (G35). Whatever component actually writes to the shared cache must enforce the rule independently, with two guards: (1) never store a `text/markdown` body under a URL that lacks the `.md` suffix, regardless of its Cache-Control; (2) requests that negotiate Markdown on canonical URLs bypass the cache in **both directions** — reading the shared entry would hand the agent the cached HTML variant, and writing would seed Markdown for browsers.
**Manifestation:** A cache wrapper keyed by URL only. The bypass + content-type guard fixed what headers alone could not. A compounding asymmetry: HTML responses often carry `Set-Cookie` (locale/consent stamping) and shared caches refuse them, while the Markdown response is cookie-free — so Markdown can be the *only* variant the cache ever stores at a canonical URL, and a poisoned entry is never displaced by an HTML one. If middleware stamps re-derivable cookies, strip them from the stored copy and layer them back per request, or the HTML surface never caches at all.

### G37 🟡 Middleware redirects need explicit Cache-Control
**Principle:** Permanent redirects (301/308) without freshness headers are heuristically cacheable per RFC 9110 — browsers may replay them indefinitely, and when the target depends on request state (locale from `accept-language` or a cookie), a pinned redirect cannot be fixed server-side. Bound every middleware redirect with a short TTL, and make it `private`: a header-dependent target must never enter a URL-keyed shared cache, or one visitor's locale redirect is served to everyone.
**Manifestation:** G8 already showed browsers pinning an uncontrolled 301 forever, forcing a server-side rescue redirect for clients that could never be reached otherwise. The systematic fix: every redirect the middleware emits (https upgrade, locale prefix, trailing-slash strip, the G8 rescue) carries `Cache-Control: private, max-age=300`.

### G38 🔵 Verify the edge cache honors the directives you send
**Principle:** Edge cache APIs implement subsets of HTTP caching; a directive that is silently ignored means the behavior you designed around doesn't exist. Check the platform's documented support before promising it in comments or headers.
**Manifestation:** Cloudflare's Workers Cache API ignores `stale-while-revalidate` and `stale-if-error` entirely — the SWR window on `.md` responses (G13) documented a behavior the edge never delivered; effective TTL was `s-maxage` alone. Responses with `Set-Cookie` are also never stored (see G36).

### G14 🔴 Strip cookies/auth from the self-fetch
**Principle:** Publicly cacheable output must be built from an anonymous render; forwarding the requester's cookies would bake a signed-in page into a shared cache.
**Manifestation:** The self-fetch sends only the bypass header, a self-identifying UA (useful in origin logs), and `accept: text/html` — never inbound cookies or authorization headers.

### G15 🔵 Cap the self-fetch with a timeout
**Principle:** The markdown handler is an extra hop in front of your own origin; without a timeout a slow page ties up the edge runtime.
**Manifestation:** `AbortController` + ~8s timeout; failure → markdown 404.

## The markdown handler

### G16 🟡 Auth-gated pages: read the page's own noindex, don't keep a route list
**Principle:** An anonymous fetch of a protected page renders the sign-in screen, so its `.md` would be a sign-in stub. A hand-maintained blocklist rots; the page already declares itself non-indexable.
**Manifestation:** The handler checks the fetched HTML for `<meta name="robots" content="...noindex...">` and returns a markdown 404. The markdown sitemap (derived from the real sitemap) already excludes these routes; the noindex check covers direct hits.

### G17 🟡 Empty conversion → 404, not empty 200
**Principle:** Client-only shells and auth redirects convert to nothing; a 200 with an empty body teaches agents the page has no content.
**Manifestation:** Empty conversion result → markdown 404, whose body is itself a small Markdown document with frontmatter (never an HTML error page).

### G18 🔴 Fetch static overrides over the origin, not the filesystem
**Principle:** Edge runtimes (Cloudflare Workers and similar) have no filesystem; `fs.readFile` works in local dev and dies in production. Fetching through the origin behaves identically in both.
**Manifestation:** The override reader fetches `${origin}/agent-md${path}.md` — with the bypass header, or G1/G2 recursion follows.

### G19 🔴 A missing static asset may come back as the HTML shell
**Principle:** Some hosts answer a 404'd asset path with the SPA/HTML fallback and a 200. `response.ok` is not proof you got a markdown file.
**Manifestation:** The override reader rejects any response whose `content-type` includes `text/html`, and rejects empty bodies.

### G20 🟡 Rebuild the origin from forwarded headers
**Principle:** Behind proxies, the handler's own URL object lies about protocol/host; canonical URLs built from it point at internal hosts or `http://`.
**Manifestation:** Origin = `x-forwarded-proto` (falling back to `https`, or `http` only for localhost) + the `host` header.

## HTML → Markdown conversion

### G21 🔵 Pick a converter that runs without a DOM
**Principle:** Edge runtimes have no DOM; converters that ship a fake one are dead bundle weight and may not run at all.
**Manifestation:** `node-html-markdown` over `turndown` — turndown bundles domino to fake a DOM, dead weight on Workers.

### G22 🟡 Recover icon semantics BEFORE stripping SVGs — but only in table cells
**Principle:** Boolean cells in feature/comparison tables are often aria-hidden icons with no accessible name. Stripping SVGs blanks the whole table; the meaning survives only in the icon's class name.
**Manifestation:** With lucide icons: `lucide-check*` → "Yes", `lucide-x*` → "No", `lucide-minus` → "—", substituted **only inside `<td>`/`<th>`**. Elsewhere the icon sits beside its own label ("✓ Unlimited posts") and substitution would emit a stray "Yes" next to text that already says it. Order matters: run before the generic SVG strip.

### G23 🔵 Strip chrome and interactive affordances
**Principle:** Navigation, forms, and script payloads are noise in a text projection; convert only the content region.
**Manifestation:** Strip `script`, `style`, `noscript`, `svg`, `iframe`, `template`, `nav`, `header`, `footer`, `form`, `button`, `select`, plus any element with `aria-hidden="true"`. Extract `<main>` (fallback `<article>`, then `<body>`).

### G24 🟡 Absolutize relative links
**Principle:** Agents read the Markdown detached from the page URL; `(/pricing)` is a dead link in a chat transcript.
**Manifestation:** Rewrite `](/...` to `](https://site.com/...` in both the runtime converter and any build script.

### G25 🔵 Strip per-deploy cache busters from output
**Principle:** Build fingerprints in asset URLs churn the diff of every page on every deploy — noise for anything caching or diffing the Markdown.
**Manifestation:** Deployment-id query params (e.g. `?dpl=<id>`) stripped from converter output.

### G26 🔵 Frontmatter must survive punctuation; `url` cites the HTML page
**Principle:** Titles containing `:` or `"` produce invalid YAML unless quoted; and the frontmatter `url` should point where a human can follow — the canonical HTML page, never the `.md` projection. Same for the `Link: rel="canonical"` response header.
**Manifestation:** `JSON.stringify` every frontmatter value. Drop the " | Brand" title suffix — `url` already identifies the site.

## Discovery surfaces

### G27 🟡 `.md` URLs stay OUT of sitemap.xml
**Principle:** They are alternate representations, not documents; listing them reports every page to search engines twice (duplicate-content risk).
**Manifestation:** `sitemap.md` is their only index, listed in `robots.txt` next to `sitemap.xml` and advertised via `rel="alternate"`.

### G28 🟡 Derive sitemap.md from the same source as sitemap.xml
**Principle:** Two hand-maintained lists drift; the markdown sitemap must be a projection of the real one.
**Manifestation:** The `/sitemap.md` route takes the same sitemap-generating function the XML route uses. Section labels are derived from path segments rather than enumerated — a fixed label map dumps every newly added section into "Other".

### G29 🟡 llms-full.txt reads the same files the page route serves
**Principle:** Inlined full-text must come from the authored overrides at request time, or the two surfaces drift.
**Manifestation:** The `/llms-full.txt` route fetches the override files over the origin (same reader semantics as G18/G19) and strips their frontmatter before inlining each under a `# <url>` heading.

### G30 🔵 Every page advertises its own `.md`
**Principle:** One site-wide alternate link doesn't let a crawler find a specific page's twin.
**Manifestation:** A head component reads the current pathname (from the middleware-stamped header) and emits `<link rel="alternate" type="text/markdown" href="<page>.md">` per page, plus the site-wide sitemap/llms links. Guard: skip when the pathname already ends in `.md`.

## Static-export variant

### G31 🟡 Copy Markdown source; don't round-trip compiled HTML
**Principle:** When content is authored as Markdown, the compiled HTML is lossy (code fences, tables, footnotes). Convert HTML only for pages with no Markdown source.
**Manifestation:** The build script copies content sources first, then converts leftover exported HTML (about/privacy/etc. — otherwise they'd be the only sitemap routes whose `.md` 404s). It never overwrites a source-derived twin with a conversion of its own output, and skips build artifacts and error pages (`_next/`, `404`, `500`, `_not-found`).

### G32 🟡 Synthesize listing pages
**Principle:** List pages assemble their content at render time — neither the exported HTML shell nor an `index.md` source contains the entries.
**Manifestation:** The build script accumulates entries per collection and appends an "All N pages" linked list to whatever intro exists.

### G33 🟡 Content in frontmatter vs body: pick the richer source per file
**Principle:** When some files carry their whole page in structured frontmatter (empty body) and others in the body (frontmatter mirrored for components), preferring either source unconditionally blanks out the other set.
**Manifestation:** Render both candidates and keep the longer one, per file — self-tuning, no per-collection config or length threshold to maintain.

### G34 🔵 The static worker negotiates only canonical URLs
**Principle:** Explicit `.md` URLs are already static assets; the worker's only job is `Accept`/UA negotiation — rewrite internally to the sibling `.md` asset and re-wrap with the correct headers.
**Manifestation:** Worker: `wantsMarkdown(request)` → fetch `path + '.md'` from the asset binding → re-serve with the markdown headers built for the canonical URL; anything not-ok falls through to HTML.
