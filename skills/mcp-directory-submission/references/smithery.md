# Smithery submission, field by field

Wizard at https://smithery.ai/new. Verified 2026-08-29 by publishing three production remote servers under one personal namespace.

## Step 1: namespace and server ID

The namespace is your Smithery account slug and cannot be changed in the form. Server ID becomes the public slug (`smithery.ai/servers/<namespace>/<server-id>`, plural); use the lowercase product name.

## Step 2: server URL

The custom-domain streamable-http endpoint, the same one published to the official registry (`https://mcp.example.com/mcp`). Not the PaaS hostname; the domain URL survives infra moves.

## Step 3: connection settings (the step people skip and regret)

Smithery's gateway sits between the user and your server. If the server needs a token and you skip this step, every tool call through the gateway 401s.

Add one parameter:

- Name: `apiKey`
- Type: `string`
- Location: `header` (the default is `query`; change it, a query-string key never reaches your auth)
- Required: on for the first publish. Once the server does OAuth, turn it off: the score gives 15 points for optional config, and a user who leaves it blank gets the OAuth login instead.
- "Output as header": `Authorization`
- Description, 100-character cap enforced: `<Product> API token. Create one in <Product> → Settings → API Tokens.`

The gateway then sends the user's value as the `Authorization` header, verbatim. Two server-side facts follow:

- If your server demands the `Bearer ` prefix, users must paste `Bearer <token>` into the field, and some won't. Make the server accept a bare token as a fallback and the description stays simple.
- If your server implements MCP OAuth (resource metadata + `WWW-Authenticate`), check whether Smithery offers an OAuth connection option before adding a parameter; a login flow beats a paste-a-token flow.

Use the Preview toggle to sanity-check what the gateway will prompt for.

## Step 4: server settings (Settings tab, required for a listing that ranks)

The wizard publishes a bare listing; the Settings tab is where the marketplace-facing fields live, and they feed the Quality Score. Fill all of them:

- Display Name: the product name with proper casing (`AdaptlyPost`, not the slug).
- Description: markdown, no tight length cap. Lead with what the server does for an agent, then a short bullet list of the tools' capabilities, then one line on auth. Reuse the brand's agent-directory description; do not write a new variant per site.
- Homepage: the page about the product's agent integration if one exists (e.g. `/features/agents`), else the product root.
- GitHub Repository: optional public source link on the server page. Use a public repo only; a private one 404s for visitors. The brand's public agent/plugin repo works; leave blank if everything relevant is private.
- Server Icon: upload the brand logo (same file the entity kit uses). Without it Smithery scrapes the homepage favicon, which is usually low-resolution.
- Unlisted: leave unchecked.

## Step 5: verifications (Domain and Badges panels)

Two checks on the server page prove ownership and earn the verified state; both re-check on demand.

- Domain TXT: Smithery gives a token like `smithery-verification=<hex>`. Add it as an **additional** TXT value on the apex of the homepage host, next to the MCP registry's `v=MCPv1` record; multiple TXT values on the same name coexist.
- Link to Smithery: their scanner must find a link to the server page in one of three places - the README of the GitHub repo linked in settings, the homepage, or a custom backlink URL on the same domain. The cheapest is the README badge, pasted near the top:

  `[![smithery badge](https://smithery.ai/badge/<namespace>/<id>)](https://smithery.ai/servers/<namespace>/<id>)`

  Server pages live at `smithery.ai/servers/<namespace>/<id>` (plural `servers`). If the backlink lives on the site instead and the site sits behind a WAF or bot protection, allow the user agent `SmitheryBot/1.0 (+https://smithery.ai)` or the scan never sees it.

## Step 6: after publishing

- The server page's Releases tab shows deployments; "Publish via URL" there creates a new release of the same server, not a new listing.
- The Quality Score (0-100) has three parts. Capability, 40 points: tool descriptions 12, parameter descriptions 12, output schemas 12, annotations, naming. Metadata, 35: description 12, homepage 12, icon 8, display name 3. Configuration UX, 25: optional config 15, config schema 10. A bare wizard publish scored 49; filling Settings took it to 81; `.describe()` on every parameter plus Publish via URL (which rescans) and Required off on the parameter is the path to 100.
- Do not pay for anything. Listing and the gateway credits need no plan, and the developer checkout returned a 500 (`Stripe is not configured`) after the Arcade.dev acquisition.
- The public server page URL belongs in the brand's `sameAs` (see entity-stack-kit).
