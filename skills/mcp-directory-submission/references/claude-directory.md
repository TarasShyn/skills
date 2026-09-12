# Claude Connectors Directory and Claude plugins

Verified 2026-09-11: three connectors submitted, two approved by the automated scan within minutes, one held in human review until a charging tool was removed.

Docs: https://claude.com/docs/connectors/building/submission and the directory policy at https://support.claude.com/en/articles/13145358-anthropic-software-directory-policy. Escalation address: mcp-review@anthropic.com.

## Connectors Directory

### Access

The portal is `https://claude.ai/admin-settings/directory/submissions/new` and it only exists inside a Team or Enterprise organization where you are Owner. A Max plan on a personal login does not have it. One Team org (the cheapest is two seats, monthly) can submit every product; the Author fields are per submission.

### Flow

Eleven steps: Introduction, Connection, Tools, Listing, Use cases, Company, Authentication, Data handling, Test & launch, Compliance, Review. The browser keeps progress, so a closed tab resumes.

Connection: paste `https://mcp.example.com/mcp`, leave URL configuration as Universal URL, press Connect and authorize, sign in with the review account. The portal reads the tool list once, at this step; it labels the connection "temporary" because it removes it from your org after submission. If the redirect lands on a 404 at `.../submissions/new?&mcp_auth_source=...`, the query string is malformed; reopen the portal and pick the connector under "Or choose a connector you've already installed" after adding it as a custom connector in Settings, Connectors.

After changing the server's tools, go back to Connection, Change, reconnect, or the review runs against the old list.

Tools: shows every tool with its `title`, `readOnlyHint` and `destructiveHint`. Missing titles look bad here.

### Listing fields and caps

| Field | Rule | Value that passed |
| --- | --- | --- |
| Name | pre-filled from the host | `AdaptlyPost - social media scheduler` |
| Slug | permanent, pre-filled as `mcp-example-com` | `adaptlypost` |
| One-liner | 200 chars | platforms named, no counts |
| Description | 2000 chars | what it does, what Claude can do with it, tool count in words, auth in one line |
| Categories | up to 5, no "Data" category exists | Sales and marketing, Productivity |
| Author name / URL | brand, apex | `AdaptlyPost`, `https://adaptlypost.com` |
| Custom icon URL | needed; the MCP host's favicon is what the default reads and it 404s | `https://adaptlypost.com/logo_small.png` |
| Documentation | must be the MCP setup page, not the REST reference and not the marketing page | `/features/agents/docs`, or an anchor like `/features/agents#mcp-setup` |
| Enterprise managed auth docs | leave empty | |
| Support | one brand address | `contact@adaptlypost.com` |
| Privacy policy | apex URL, no `www.` | `https://adaptlypost.com/privacy` |

Use cases: five lines, each a use case with an example prompt in quotes. Connection requirements: what the account needs (a plan, a connected account) and that sign-in is OAuth with no API key. Read/write: pick Read and write if any tool writes; picking Read only lists the tools annotated as writing and refuses.

Authentication: OAuth 2.0 + Dynamic Client Registration, Partial auth unchecked. Data handling: We own the API, no health data, no sponsored content.

Test & launch: a Test setup instructions box (login URL, email, password, "verified email, no MFA", steps, what data the account holds, a suggested prompt per tool) and a Self-tested checkbox you may tick only after running every tool yourself as a custom connector or in MCP Inspector. The review account must stay working after approval.

Compliance: seven acknowledgements (public docs by publish date, no conversation data collection, no prompt injection, no financial transactions, no AI media generation, first-party API, guidelines read). Additional notes: one sentence if tool descriptions reference sibling tools, so the scanner does not read that as an external instruction source.

### What blocked the third one

Two tools could charge the user: activating pending keywords triggered a prorated plan upgrade on the saved payment mandate, with no confirmation, because the web UI's confirmation modal lived in the frontend. That contradicts "no financial transactions". Their descriptions also carried model instructions ("Always call preview first", "never call this in a loop"), which reads as prompt injection. The fix was in the product: the REST path no longer charges, the upgrade tool was removed, the descriptions were scrubbed, then Connection, Change, reconnect, resubmit.

Review time is undocumented. The automated pass approved two submissions within minutes; the community reports weeks to months for anything that needs a human.

### Corrections that came up

- No `www.` anywhere; the sites are apex.
- Documentation means the literal setup page.
- Write the password out in every sheet; "same as the other product" gets copied verbatim into a form.
- Keep the sheets outside any repo; they hold credentials.

## Claude plugins

Two portals reach the same queue: `https://platform.claude.com/plugins/submit` (Console) and `https://claude.ai/admin-settings/directory/submissions/plugins/new` (org portal). Docs: https://claude.com/docs/plugins/submit.

Fields: Link to plugin (repo URL), Path within repository (blank when the plugin is at the root), Plugin homepage, Plugin name (no brand names you do not own), Plugin description, Example use cases as "Example 1: ..." lines, Platforms (Claude Code; add Cowork only after testing there), License type, Privacy policy URL, Submitter email.

Where it lands: `anthropics/claude-plugins-community`, marketplace name `claude-community`, 2,000+ plugins. It is not built into Claude Code; users run `/plugin marketplace add anthropics/claude-plugins-community` then `/plugin install <name>@claude-community`. There is no web page per plugin. The official marketplace (`anthropics/claude-plugins-official`, the one shown on claude.com/plugins) is curated: "Anthropic decides which plugins to include at its discretion. There is no application process, and the submission form does not add plugins to the official marketplace." Bundling a connector that is already approved in the Connectors Directory "increases the likelihood of verification", per the docs.

Gotchas:

- Approved plugins are pinned to a commit. Anthropic bumps pins in its own batch PRs (roughly fortnightly); outside PRs against the marketplace repo are auto-closed. A pin months behind the repo is normal; email mcp-review@anthropic.com if it matters.
- Submissions cannot be withdrawn or edited from the Console; the cards are not clickable. A pending row from months ago costs nothing; resubmit a fresh one.
- Put a `.mcp.json` in the plugin with `type: http` and no headers so installing it connects the hosted connector over OAuth. Run `claude plugin validate .` before submitting.
- The skill's `last-updated` frontmatter drives a validator warning after 30 days; bump it with each version.
