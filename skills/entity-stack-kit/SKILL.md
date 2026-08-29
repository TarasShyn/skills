---
name: entity-stack-kit
description: Generate a single HTML "entity kit" for a brand - logo, banner, homepage link, short and long descriptions, and every sameAs profile from its structured data - with copy buttons, per-directory submission guides, and a machine-readable JSON block so another agent can run submissions from the file alone. Use this whenever the user mentions entity stack, entity SEO, sameAs profiles, directory submissions, claiming brand profiles (Crunchbase, Wikidata, G2, Product Hunt, Trustpilot...), knowledge panel work, or wants one page with all their brand assets and descriptions ready to paste. Optionally takes a DataForSEO or Ahrefs API key to align the descriptions with competitors.
---

# Entity stack kit

A brand's entity stack is the set of profiles that all point back at the same organization: social accounts, Wikidata, Crunchbase, review sites, app stores. The site declares them in the `sameAs` array of its Organization (or SoftwareApplication) structured data, and Google's Organization doc says `sameAs` is "the URL of a page on another website with additional information about your organization." Structured data like this helps Google "disambiguate your organization in search results" and feeds the knowledge panel.

Declaring a profile in `sameAs` is the easy half. The slow half is actually creating and claiming each profile, one directory at a time, pasting the same name, logo, boilerplate and links into each form. This skill compresses that: read the site once, then emit one self-contained HTML file with everything a human or agent needs to work through the list.

Facts about the markup live in `references/google-entity-facts.md`. Per-directory submission guides live in `scripts/platforms.mjs` (machine data) and `references/platforms.md` (the tricky ones explained). Competitor-alignment APIs live in `references/competitor-apis.md`.

## Workflow

### 1. Extract the entity from the site

```bash
node scripts/extract-entity.mjs https://example.com > entity-kit.json
```

The script fetches the page, parses every `application/ld+json` block, finds the node with a `sameAs` array (Organization, SoftwareApplication, WebSite or Person), and merges in `og:image`, meta description and title. Output is a `kit.json` skeleton:

```json
{
  "name": "", "url": "", "logo": "", "banner": "",
  "shortDescription": "", "longDescription": "",
  "foundingDate": "", "email": "",
  "sameAs": ["https://..."]
}
```

Then verify, don't trust:

- Open the site (or its `/.well-known/brand-facts.json` if it has one) and fill anything the script left empty. Ask the user for what you cannot find, especially the banner and logo URLs.
- The logo must be at least 112x112 px and crawlable. That's Google's stated minimum for the Organization `logo`. Check the actual image, not the filename.
- Every `sameAs` URL must resolve. `curl -sI` each one; dead profiles go in the kit marked as broken, not silently dropped.

### 2. Write the two descriptions

Two fields, reused across every directory form:

- `shortDescription`, up to 160 characters. What it is and for whom. This is what goes in bio fields and meta-description-sized boxes.
- `longDescription`, 2 to 3 short paragraphs, roughly 100 to 180 words. Paragraph one says what it is and the core mechanism, in the site's own terms. Paragraph two walks the concrete capabilities as a workflow, features doing something, not a list. Paragraph three says who it's for plus the checkable facts the site states: founded year, platform count, pricing, languages, where it's built. Directory "about" boxes expect this length; a two-sentence blurb reads as an abandoned profile.

Write them from the site's own copy. Rules: no claims the site doesn't make, no "leading" or "innovative", no feature invented to sound complete. Every sentence must survive the question "where on the site does it say that?".

The bar, from a real kit:

> Short: AI that analyzes sessions and flags issues
>
> Long: Flowsery is AI session replay that finds bugs on autopilot. It watches every user session, spots rage clicks, dead clicks, and errors automatically, and tells your team what broke and why, without anyone scrubbing through recordings.
>
> When something breaks, Flowsery ranks the issue by impact, sends an alert with the replay and steps to reproduce, and drafts a fix your team can review, then opens a Linear or Jira ticket in one click. Underneath is a full web analytics layer: real-time traffic, revenue by source, funnels, goals, and user journeys in one dashboard.
>
> It is built in Europe, works without cookies or consent banners, and is made for product and engineering teams that want to know why users leave and fix it fast.

### 3. Optional: align descriptions with competitors

Only when the user provides an API key. Both routes end the same way: get 3 to 5 competitor domains, fetch each competitor's homepage `<meta name="description">` and `og:description`, and compare vocabulary. The goal is category language, not copy. If every competitor says "social media scheduling" and the draft says "content calendar automation", the draft is describing the product in words nobody searches. Fix the noun, keep the facts.

- DataForSEO: `POST https://api.dataforseo.com/v3/dataforseo_labs/google/competitors_domain/live`, Basic auth with `login:password`.
- Ahrefs: `GET https://api.ahrefs.com/v3/site-explorer/organic-competitors`, `Authorization: Bearer <key>`.

Exact request shapes and a ready script are in `references/competitor-apis.md` and `scripts/competitors.mjs`. Never paste the key into the generated HTML or the kit JSON.

### 4. Build the HTML kit

```bash
node scripts/build-kit.mjs entity-kit.json > entity-kit.html
```

The script renders `assets/kit-template.html`:

- Identity block at the top: logo, banner, name linked to the homepage, short description, long description. Every value has a copy button.
- One `<details>` row per profile, grouped by category (social, knowledge graph, app stores, reviews, dev). Each row: status (`live`, `broken`, or `to submit`), an effort tag, the profile URL with a copy button, and the submission guide steps for that directory. Effort is `easy` for every form-based directory, `medium` for the extension stores (published extension, developer account, review pass), and `hard` for the AI agent and automation directories (Claude plugin directory, ChatGPT app directory, Zapier, n8n), which need a working plugin, MCP server, or integration plus a platform review.
- Gap rows: every platform in `scripts/platforms.mjs` that is missing from `sameAs` renders as `to submit`, with the claim URL and guide. That turns the kit into a to-do list, not just an inventory. The whole table is required, extension stores and npm included; the only quiet entries are GetApp and Software Advice, because the Capterra vendor listing covers them. Directories with paid-only submission (There's An AI For That, BetaList, Uneed) are not in the table: the kit never urges paying for a listing, but if they are already in `sameAs` they render as live rows.
- Machine block: the full kit as `<script type="application/json" id="entity-kit-data">` plus an Organization JSON-LD with the `sameAs` array. An agent pointed at the file needs nothing else; the top of the file says so in one line.

The generated HTML is self-contained: inline CSS and JS, no external requests except the logo and banner images by URL. Copy buttons flip an icon to a check for two seconds and never change the text or layout.

### 5. Hand over

The deliverable is `entity-kit.html` on disk; the user opens it, hosts it, or points an agent at it. When the environment can publish Claude Artifacts, also publish the file as an artifact and give the user the link, with one adjustment: inline the logo and banner as `data:` URIs in the published copy, because the artifact viewer blocks images from other origins. Leave the on-disk file with plain URLs; it is the portable original.

### 6. Text rules for the generated file

The kit is a working document, not a landing page. Keep it dry:

- Every string states what something is or what to do. No marketing adjectives, no "comprehensive", no exclamation marks.
- Guides are numbered steps, 2 to 4 per directory, each starting with a verb.
- If a sentence would fit any brand's kit unchanged, delete it.

## Checklist before handing over the file

- [ ] Logo loads, is 112x112 or larger, and is the same file the site's structured data points at.
- [ ] Banner loads (usually the OG image).
- [ ] Short description is 160 characters or fewer; long description has only site-backed claims.
- [ ] Every `sameAs` URL was probed; broken ones are marked `broken`.
- [ ] Missing platforms render as `to submit` rows with claim URLs.
- [ ] `#entity-kit-data` JSON parses and matches the visible content.
- [ ] The file opens from disk with no network needed except the two images.
- [ ] No API keys anywhere in the output.

## Reference files

- `references/google-entity-facts.md` - what Google documents about Organization markup, sameAs, and logos, with quotes.
- `references/platforms.md` - the directories that need explanation: Wikidata notability, the Gartner trio (Capterra/GetApp/Software Advice), G2 vendor claiming, Bluesky domain handles.
- `references/competitor-apis.md` - DataForSEO and Ahrefs request shapes for competitor discovery, and how to turn that into description alignment.
- `scripts/extract-entity.mjs` - site to kit.json.
- `scripts/build-kit.mjs` - kit.json to entity-kit.html.
- `scripts/competitors.mjs` - competitor domains via DataForSEO or Ahrefs, then their homepage descriptions.
- `scripts/platforms.mjs` - the platform table: hostname patterns, categories, claim URLs, guide steps.
- `assets/kit-template.html` - the HTML shell the build script fills.
