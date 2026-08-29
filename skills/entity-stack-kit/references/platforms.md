# Directory notes

`scripts/platforms.mjs` holds the full table (hostnames, categories, claim URLs, guide steps) and is what the build script renders. This file explains only the directories where a bare guide step is not enough.

## Wikidata

The strongest entity signal and the easiest to get deleted. Wikidata has a notability policy: an item needs at least one serious external reference (press coverage, registry entry, an identifier on another structured database), not just the company's own site.

- Create at https://www.wikidata.org/wiki/Special:NewItem after registering.
- Minimum statements for a software company: `instance of` (software or business), `official website`, `inception`, `logo image` (must be uploaded to Wikimedia Commons under a free license), `founded by`.
- Add external identifiers as they exist: Crunchbase organization ID, X username, GitHub username. Cross-links are what make the item stick.
- Do not write promotional descriptions. Wikidata descriptions are lowercase phrases like "social media scheduling software".

## The Gartner trio: Capterra, GetApp, Software Advice

One vendor account covers all three; they share the Gartner Digital Markets backend. Apply once at https://www.capterra.com/vendors/ and the listing propagates. Expect a human review pass and a wait measured in weeks. The category you pick there is the category the entity gets associated with, so pick the one competitors actually rank in.

## G2

Profiles often exist before you claim them because G2 seeds from public data. Search for the product first; claim via the "Claim this profile" flow or https://sell.g2.com. Reviews are the currency; an unclaimed empty profile is still worth having in `sameAs` because the URL is stable.

## Mastodon

Field links on Mastodon render with `rel="nofollow noopener me"`, so this is not a link-equity play. What it offers is the strongest identity loop after Bluesky: put `<link rel="me" href="https://mastodon.social/@handle">` in the site head, re-save the profile field, and Mastodon marks the website field verified with a green check. The profile page's own head then serves `<link rel="me">` back to the site. Cross-verified both ways, on a domain crawlers trust.

## Bluesky

Different from every other social profile: the handle itself can be the domain. Set the handle to the brand domain (Settings, then Change handle, then "I have my own domain") and add the `_atproto` TXT record they show. The result, like `bsky.app/profile/example.com`, is a profile URL that proves domain ownership by construction.

## Product Hunt

The product page (`producthunt.com/products/<slug>`) exists independently of a launch. Add the product first; launching is a separate, optional event. `sameAs` should point at the product page, not at a launch post.

## Trustpilot

The review page `trustpilot.com/review/<domain>` is generated from the domain. Claim it from https://business.trustpilot.com so the logo and description are yours; the URL works either way.

## AlternativeTo

Submissions are user-generated and moderated. Register, then add the app via the "Manage" flow. The description gets edited by moderators toward neutral wording, so submit neutral wording to begin with; it survives review unchanged.

## SourceForge

For non-open-source SaaS the listing goes through SourceForge's business software directory (Slashdot Media). Expect a sales follow-up email; the free listing is real, the upsell is optional.

## Paid-only directories

There's An AI For That, BetaList, and Uneed charge for submission. They are not in the platform table, so the kit never renders them as to-submit rows. When a brand already has them in `sameAs`, they show up as live rows under Other profiles with a `paid` badge (the `PAID_HOSTS` list in `scripts/platforms.mjs`); existing listings are inventory, paying for new ones is the user's call, not the kit's.

## App and extension stores

If the product ships a browser extension or app, the store listings (Chrome Web Store, Edge Add-ons, Firefox Add-ons, Opera add-ons, App Store, Google Play) belong in `sameAs` too. These are the medium-effort rows: each store wants a developer account, the extension bundle, and a review wait, but one Chromium build covers Chrome, Edge, and Opera, and Firefox usually needs only manifest tweaks. They are among the few profiles Google can verify against a binary artifact. Use the exact store URL of the published item.

## AI agent and automation directories

The hard tier. Claude, OpenAI, Zapier, and n8n all list product integrations, and every listing doubles as an entity profile, but each needs a working artifact first, not a form. For the MCP side (official registry, Smithery, and the MCP directories), the `mcp-directory-submission` skill in this collection is the full runbook: scripts, server.json template, DNS proof, and the review gotchas. Zapier wants a reviewed integration built on its developer platform before the zapier.com/apps listing exists; n8n wants a published npm community node that passes verification before it appears at n8n.io/integrations.

For Claude, the plugin is a public repo with `.claude-plugin/plugin.json` plus a skill or MCP server. Validate with `claude plugin validate .`, submit at https://platform.claude.com/plugins/submit, and approval adds the plugin to the `anthropics/claude-plugins-community` catalog, installable as `<name>@claude-community`. The official curated marketplace has no application process; Anthropic promotes plugins at its discretion.

For ChatGPT, the app is an MCP server built with the Apps SDK and hosted at a public URL. The submission (https://platform.openai.com/plugins) wants directory metadata, privacy and terms URLs, starter prompts, and a read-only/open-world/destructive justification for every tool. Approved apps show in the in-ChatGPT directory and load via @mention.
