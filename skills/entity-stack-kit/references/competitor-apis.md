# Competitor discovery for description alignment

Both providers answer the same question: which domains rank for the keywords this domain ranks for. The kit uses the answer to check description vocabulary, nothing more. 3 to 5 competitors is enough.

`scripts/competitors.mjs` wraps both. Keys come from the environment (`DATAFORSEO_LOGIN`/`DATAFORSEO_PASSWORD` or `AHREFS_API_KEY`), never from arguments and never into any output file.

## DataForSEO

Docs: https://docs.dataforseo.com/v3/dataforseo_labs-google-competitors_domain-live/

```bash
curl -s -X POST https://api.dataforseo.com/v3/dataforseo_labs/google/competitors_domain/live \
  -u "$DATAFORSEO_LOGIN:$DATAFORSEO_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '[{"target": "example.com", "language_name": "English", "location_code": 2840, "limit": 10, "exclude_top_domains": true}]'
```

- Auth is HTTP Basic with the account login and password.
- `exclude_top_domains: true` drops Wikipedia, YouTube and the like; without it the top of the list is useless for a niche SaaS.
- Competitor domains are at `tasks[0].result[0].items[].domain`; relevance at `items[].avg_position` and `items[].intersections`.
- The endpoint is paid per request. One call is enough for a kit.

## Ahrefs

Docs: https://docs.ahrefs.com/en/api/reference/site-explorer/get-organic-competitors

```bash
curl -s "https://api.ahrefs.com/v3/site-explorer/organic-competitors?target=example.com&limit=10&select=competitor_domain,common_keywords" \
  -H "Authorization: Bearer $AHREFS_API_KEY"
```

- Auth is a Bearer token; only Ahrefs workspace owners/admins can create keys, and calls consume API units.
- Competitors come back ordered by keyword overlap.

## From domains to alignment

1. For each competitor domain, fetch the homepage and read `<meta name="description">`, `og:description`, and `<title>`.
2. List the category nouns competitors repeat ("social media scheduling", "session replay", "brand monitoring").
3. Check the draft short and long descriptions against that list. The category noun searchers use must appear once. Feature claims stay the site's own.
4. Do not import phrasing beyond the category noun. The point is that the entity gets classified next to its alternatives, not that it sounds like them.

If no key is available, skip the step. A description written from the site's copy is complete; alignment is polish.
