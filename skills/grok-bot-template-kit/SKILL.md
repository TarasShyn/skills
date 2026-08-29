---
name: grok-bot-template-kit
description: Point it at any product's API docs and get a shareable Grok Bot template - a bot profile, a paste-ready skill that drives the product's REST API, an optional routine, and a single self-contained HTML kit with copy buttons walking the owner through creating, verifying, and publishing the template at x.ai/bot. Use this whenever the user mentions Grok Bot, xAI bot templates, publishing a bot template, or wants a product usable from Grok Bot the way Post Bridge's "repost X posts everywhere" template works.
---

# Grok Bot template kit

A Grok Bot template is a published bot configuration anyone can install from an `x.ai/bot/<id>` link. The template carries the bot's profile, skills, and routines; it strips API keys, secrets, signed-in sessions, custom MCP servers, and chat history. That split decides the design: the skill text must drive the product's public REST API with a bearer token the installer supplies, because the skill ships and the credential does not.

There is no API or file format for creating templates. Bots are built in the Grok Bot app (needs an eligible paid plan, see `references/grok-bot-facts.md`) and published with Share as Template. So the deliverable of this skill is not the template itself, it is a kit the owner clicks through: every paste block one copy button away, in the order the app asks for them.

The input can be as little as a product name or homepage. Everything else is discovered from the docs.

## Workflow

### 1. Discover the API from the docs

Whatever the user gives - a product name, homepage, docs URL, or spec URL - resolve it to a machine-readable spec:

1. Try the spec directly: `<api-base>/openapi.json`, `/openapi.json`, `/swagger.json`, `/api/openapi.json` on the docs host and the API host. Many docs sites link it; search the docs pages for "OpenAPI", "API reference", "spec".
2. No spec? Read the API reference pages themselves and reconstruct: base URL, endpoints, parameters. Slower but the output is the same.
3. Nothing public at all? Ask the user for their API docs. Do not invent endpoints.

From the spec and docs, extract:

- **Base URL** - from the spec's `servers` block, verified with one unauthenticated probe (the spec URL itself, or a documented public endpoint).
- **Auth** - from `securitySchemes`. This skill needs a static bearer token or API key; if the API is OAuth-only with no personal-token option, stop and tell the user a template skill cannot carry an OAuth flow.
- **Token facts** - where a user creates a token and any documented prefix. Docs usually show both in a "Get your API key" section; quote the real URL, never guess one.
- **The 5 to 10 endpoints a bot needs** - not the whole spec. Pick: the "start here" read that lists the user's resources (accounts, workspaces, projects), the reads that answer the questions people would actually ask in chat, the one flagship write that is the product's point, and its status/result endpoints. Skip admin, billing, and webhook-management endpoints.

### 2. Write the four blocks

**Bot name.** The product name, nothing appended.

**Profile.** A title of a few words stating the job, and a description of 2 to 4 sentences: what the bot does, through which product, ending with the concrete verbs an installer will use. Write it from the product's own site copy; no claims the site doesn't make, no adjectives doing the arguing.

**Skill.** One paste block, structured as: Purpose (one line). Auth (exact header, token prefix, creation URL, and the sentence "Store it in the connector credential field, never in the conversation."). Base URL, plus the spec URL if it is public. Workflow (numbered, each step naming real endpoints with their key parameters, in the order a task actually flows: discover resources, then read, then write, then check results). Validation (which writes need owner confirmation first). Failure (what a 401/404 means and what not to retry). Every endpoint named must exist in the spec you read, checked, not remembered.

**Routine (optional).** One recurring job that shows the product's value on autopilot, derived from what the product does: monitoring and analytics products get a scheduled digest of what changed; publishing and automation products get a mirror-or-act loop over new items. State: name, schedule with timezone, what to do, approval boundary (writes need per-item approval at least for the first runs), and what happens when there is nothing to report.

### 3. Build the HTML kit

Write the blocks into a `kit.json` (schema at the top of `scripts/build-kit.mjs`), then:

```bash
node scripts/build-kit.mjs kit.json > grok-bot-kit.html
```

The output is one self-contained HTML file, inline CSS and JS, no network requests. It renders the publish walkthrough in app order:

1. Requirements: the eligible plans, and the app download link.
2. Create the bot: Cmd/Ctrl+N, Create new agent, paste the name.
3. Save the skill: the full skill block with a copy button, and the follow-up line "save this as a skill".
4. Add the credential: token prefix, creation URL, and the warning to use the credential field.
5. Verify: one copy-button prompt answerable by a read-only endpoint ("list my workspaces").
6. Profile: title and description blocks, avatar suggestion.
7. Routine, if the kit has one.
8. Publish: Bot actions, Share as Template, copy the x.ai/bot link. Plus the pre-share check: open the saved skill and search it for the token prefix, because skill text ships with the template and a pasted key baked into it would too.

A machine-readable `<script type="application/json" id="grok-bot-template-kit-data">` block holds the full kit so another agent can rebuild or update it from the file alone.

### 4. Hand over

The deliverable is `grok-bot-kit.html` on disk. When the environment can publish Claude Artifacts, also publish it and give the user the link. Copy buttons flip an icon to a check for two seconds and never change text or layout.

## Checklist before handing over

- [ ] The base URL and every endpoint in the skill block exist in the spec or docs you actually read.
- [ ] The auth section names the real token prefix and a creation URL that resolves.
- [ ] The skill block contains no actual token, no example key, nothing matching the prefix.
- [ ] The verify prompt is answerable by a read-only endpoint.
- [ ] The routine (if any) states schedule, approval boundary, and empty-case behavior.
- [ ] The file opens from disk with no network needed.
- [ ] `#grok-bot-template-kit-data` JSON parses and matches the visible blocks.

## Reference files

- `references/grok-bot-facts.md` - what xAI documents about Grok Bot, plans, and what a template carries, with quotes.
- `scripts/build-kit.mjs` - kit.json to grok-bot-kit.html.
- `assets/kit-template.html` - the HTML shell the build script fills.
