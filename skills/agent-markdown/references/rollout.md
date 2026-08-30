# Agent Markdown — Implementation Recipes

Stack-agnostic module layout, with code sketches. The sketches use TypeScript and Next.js/Cloudflare idioms because that's the reference deployment, but each maps 1:1 onto any middleware-capable stack — the comments call out what each piece is for.

## Module layout

Keep the pattern in five small modules, shared across sites if you have more than one:

| Module | Role |
| --- | --- |
| `detection` | Pure functions + constants: `wantsMarkdown(headers)`, `stripMarkdownExtension(path)`, `markdownHeaders(canonicalUrl, cacheable)`, the bypass/suffix header names, the override path prefix. Keep it dependency-free — it gets bundled into the edge/middleware layer. |
| `middleware branch` | Inside the site's existing middleware: override pass-through (G1), suffix/normalization interplay (G3/G4), internal rewrite to the handler (G5), context headers (G6). |
| `handler` | The catch-all markdown route: override → self-fetch → noindex check → convert → serve. |
| `converter` | HTML→Markdown projection + frontmatter serializer. Ship it in a format both the runtime handler and a build script can import. |
| `indexes` | `/sitemap.md`, `/llms-full.txt` routes; `llms.txt` is a hand-written static file. |

## Detection (the heart — gotchas G9–G12)

```ts
export const BYPASS_HEADER = 'x-agent-markdown-render';   // loop breaker (G2)
export const SUFFIX_HEADER = 'x-agent-markdown-suffix';   // ".md URL" marker (G12/G13)
export const OVERRIDE_PREFIX = '/agent-md/';              // authored overrides in static hosting

const CLI_UA = /(curl|wget|httpie|python-requests|aiohttp|httpx|go-http-client|node-fetch|undici|axios|got|okhttp|libwww-perl|guzzle|java\/|ruby|powershell|deno|bun)/i;

// Excluded from CLI sniffing: crawlers keep getting HTML (canonical/hreflang/JSON-LD live there).
const CRAWLER_UA = /(googlebot|bingbot|duckduckbot|baiduspider|yandex|applebot|gptbot|oai-searchbot|chatgpt-user|claudebot|claude-user|perplexitybot|ccbot|bytespider|amazonbot|ahrefsbot|semrushbot)/i;

// Literal token match only — a browser's */* must not flip the site to Markdown (G9),
// nor count as an HTML opt-out (G39).
const acceptTokens = (accept: string | null) =>
  (accept ?? '').split(',').map((e) => e.split(';')[0]?.trim().toLowerCase());

const acceptsMarkdown = (accept: string | null) =>
  acceptTokens(accept).some((t) => t === 'text/markdown' || t === 'text/x-markdown');

const acceptsHtml = (accept: string | null) =>
  acceptTokens(accept).some((t) => t === 'text/html' || t === 'application/xhtml+xml');

export const wantsMarkdown = (headers: Headers): boolean => {
  if (headers.has(BYPASS_HEADER)) return false;          // 1. self-fetch → HTML
  const accept = headers.get('accept');
  if (acceptsMarkdown(accept)) return true;              // 2. explicit opt-in
  if (acceptsHtml(accept)) return false;                 // 3. explicit opt-out (G39)
  const ua = headers.get('user-agent') ?? '';
  if (CRAWLER_UA.test(ua)) return false;                 // 4. crawlers → HTML (G11)
  return CLI_UA.test(ua);                                // 5. CLI clients → Markdown (G10)
};

/** `/pricing.md` -> `/pricing`; null when there's no suffix (or the path is just `.md`). */
export const stripMarkdownExtension = (path: string): string | null => {
  if (!path.endsWith('.md')) return null;
  const s = path.slice(0, -3);
  return s === '' || s.endsWith('/') ? null : s;
};

/** cacheable=true ONLY for .md suffix URLs — see G13. */
export const markdownHeaders = (canonicalUrl: string, cacheable = false) => ({
  'Content-Type': 'text/markdown; charset=utf-8',
  Vary: 'Accept, User-Agent',                            // intent only; CDNs ignore it
  'X-Content-Type-Options': 'nosniff',
  Link: `<${canonicalUrl}>; rel="canonical"`,            // cite the HTML page, not the .md
  'Cache-Control': cacheable
    ? 'public, max-age=0, s-maxage=3600, stale-while-revalidate=86400'
    : 'private, no-store',
});
```

These headers are advice, not enforcement: URL-pattern header rules elsewhere in the stack can
overwrite the `no-store` after this code runs (G35). If a custom cache layer sits in front of the
site, it must independently refuse `text/markdown` bodies at non-`.md` URLs and bypass reads and
writes for requests where `wantsMarkdown()` is true (G36) — and verify the deployed response
headers, not the code.

## Middleware branch (G1–G6)

Order within the site's middleware matters:

```ts
// 1. FIRST: overrides pass through untouched, or they recurse (G1).
if (pathname.startsWith(OVERRIDE_PREFIX)) return next();

// 2. Path normalization (locale prefix, trailing slash, https) — but locale-check
//    against the suffix-stripped path (G3), redirect using the raw path.
const logicalPath = stripMarkdownExtension(pathname) ?? pathname;
// ... existing normalization, using logicalPath for shape checks ...

// 3. AFTER normalization (G4): the markdown branch.
if (!request.headers.has(BYPASS_HEADER)) {
  const stripped = stripMarkdownExtension(pathname);
  if (stripped !== null || wantsMarkdown(request.headers)) {
    const contentPath = stripped ?? pathname;
    const h = new Headers(request.headers);
    if (stripped !== null) h.set(SUFFIX_HEADER, '1');   // only .md URLs may shared-cache
    h.set('x-pathname', contentPath);                    // describe the PAGE, not the rewrite (G6)
    return rewrite(`/agent-markdown${contentPath}`, { requestHeaders: h }); // internal, never a redirect (G5)
  }
}
```

Also add `sitemap.md` and `llms-full.txt` to whatever root-asset bypass list exempts `robots.txt`/`sitemap.xml` from locale routing (G7).

## Handler (G14–G20)

Catch-all route at `/agent-markdown/[[...path]]` (or your router's equivalent), never linked publicly:

```ts
async function handle(request) {
  const contentPath = /* rebuild from x-pathname / route params */;
  const origin = /* x-forwarded-proto + host header — not the internal URL (G20) */;
  const canonicalUrl = `${origin}${contentPath}`;
  const cacheable = request.headers.get(SUFFIX_HEADER) === '1';

  // 1. Authored override wins. Fetch over the origin, not fs (G18);
  //    reject HTML-shell fallbacks and empty bodies (G19).
  const authored = await fetchOverride(`${origin}/agent-md${contentPath}.md`);
  if (authored) return respond(authored, markdownHeaders(canonicalUrl, cacheable));

  // 2. Self-fetch the page: bypass header, accept: text/html, self-identifying UA,
  //    NO cookies or auth (G14), with a timeout (G15).
  const html = await fetchPage(canonicalUrl);
  if (!html) return markdown404(canonicalUrl);

  // 3. Auth-gated pages render sign-in for anonymous fetches; their own
  //    noindex meta is the signal — no route blocklist (G16).
  if (/<meta\s+name="robots"[^>]*noindex/i.test(html)) return markdown404(canonicalUrl);

  // 4. Convert; empty result (client-only shell) → 404, not empty 200 (G17).
  const { title, description, markdown } = convert({ html, canonicalUrl });
  if (!markdown) return markdown404(canonicalUrl);

  return respond(serialize({ title, description, canonicalUrl, markdown }),
                 markdownHeaders(canonicalUrl, cacheable));
}
```

## Converter (G21–G26)

Use a DOM-free converter (e.g. `node-html-markdown`). Pipeline order:

1. Extract the content region: `<main>` → `<article>` → `<body>`.
2. Substitute icon semantics in table cells only (check→Yes, x→No, minus→—) — before any SVG strip (G22).
3. Strip chrome/interactive tags and `aria-hidden` elements (G23).
4. Convert to Markdown.
5. Post-process: strip deploy-fingerprint query params (G25), absolutize relative links (G24), collapse 3+ blank lines.
6. Wrap in frontmatter — `JSON.stringify` each value; `url` = canonical HTML page; drop the " | Brand" title suffix (G26).

## Indexes & discovery (G27–G30)

- `/sitemap.md`: a route that calls the **same** sitemap-generating function as `sitemap.xml`, groups by first path segment (derived labels, not an enumerated map), and links each page's `.md` URL. Locale via `?lng=`, cross-linking the other locales.
- `/llms.txt`: hand-written static file — one-paragraph site description + curated links to canonical HTML pages.
- `/llms-full.txt`: a route that fetches the authored overrides (same reader as the handler), strips frontmatter, and inlines each under `# <url>`.
- `robots.txt`: list both `sitemap.xml` and `sitemap.md`. Never put `.md` URLs in `sitemap.xml` (G27).
- Every page's head: `<link rel="alternate" type="text/markdown" href="<this page>.md">` (from the middleware-stamped pathname; skip if it already ends in `.md`) plus site-wide links to `sitemap.md`, `llms.txt`, `llms-full.txt`.

## Static-export variant (G31–G34)

Build step, appended after the site export:

1. For every content file authored as Markdown: copy the source to `out/<route>.md` (with frontmatter + absolutized links). Don't round-trip compiled HTML (G31).
2. Synthesize listing-page `.md`s: intro (if an `index.md` exists) + an "All N pages" linked list accumulated during step 1 (G32).
3. Convert remaining exported HTML (about/privacy/…) so no route's `.md` 404s — skipping build artifacts and error pages, never overwriting a step-1 file (G31).
4. If pages exist in both frontmatter-structured and body-authored forms, render both and keep the richer one per file (G33).

Runtime: a thin worker in front of the static assets that handles only negotiation on canonical URLs — `wantsMarkdown()` → fetch the sibling `.md` asset → re-serve with `markdownHeaders(canonicalUrl)` (G34). Explicit `.md` URLs are plain static assets and need nothing.

## Regression tests worth keeping forever

- Override paths (`/agent-md/**.md`) produce **no redirect and no rewrite** (G1).
- A request carrying the bypass header is never rewritten, even on a `.md` path (G2).
- A normal `.md` URL rewrites to the handler path (the happy path still works).
- The homepage's `.md` twin (`/<locale>.md` on localized sites) does not redirect-loop (G3).
