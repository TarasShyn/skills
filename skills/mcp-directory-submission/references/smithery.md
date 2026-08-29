# Smithery submission, field by field

Wizard at https://smithery.ai/new. Verified 2026-08-29 by publishing a production remote server.

## Step 1: namespace and server ID

The namespace is your Smithery account slug and cannot be changed in the form. Server ID becomes the public slug (`smithery.ai/server/<namespace>/<server-id>`); use the lowercase product name.

## Step 2: server URL

The custom-domain streamable-http endpoint, the same one published to the official registry (`https://mcp.example.com/mcp`). Not the PaaS hostname; the domain URL survives infra moves.

## Step 3: connection settings (the step people skip and regret)

Smithery's gateway sits between the user and your server. If the server needs a token and you skip this step, every tool call through the gateway 401s.

Add one parameter:

- Name: `apiKey`
- Type: `string`
- Location: `header` (the default is `query`; change it, a query-string key never reaches your auth)
- Required: on
- "Output as header": `Authorization`
- Description, 100-character cap enforced: `<Product> API token. Create one in <Product> → Settings → API Tokens.`

The gateway then sends the user's value as the `Authorization` header, verbatim. Two server-side facts follow:

- If your server demands the `Bearer ` prefix, users must paste `Bearer <token>` into the field, and some won't. Make the server accept a bare token as a fallback and the description stays simple.
- If your server implements MCP OAuth (resource metadata + `WWW-Authenticate`), check whether Smithery offers an OAuth connection option before adding a parameter; a login flow beats a paste-a-token flow.

Use the Preview toggle to sanity-check what the gateway will prompt for.

## Step 4: after publishing

- The server page's Releases tab shows deployments; "Publish via URL" there creates a new release of the same server, not a new listing.
- The Quality Score (0-100) expands into a checklist of missing metadata: description, icon, homepage, tool annotations, typed output. Each item raises ranking inside Smithery's search; most take minutes since the assets already exist in the brand's entity kit.
- The public server page URL belongs in the brand's `sameAs` (see entity-stack-kit).
