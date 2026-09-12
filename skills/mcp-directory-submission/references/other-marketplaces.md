# Cursor and xAI marketplaces

Both were submitted on 2026-09-07 from the same public repo; both queue behind a manual review and neither had responded by 2026-09-12.

## Cursor marketplace

Docs: https://cursor.com/docs/plugins and https://agent-plugins.org/plugin-authors/manifest. Submit at https://cursor.com/marketplace/publish (login required). "Every plugin is manually reviewed before it's listed"; the repo must be open source, and updates go through review again.

The repo needs the agent-plugins.org format: a root `plugin.json` with a `logo` field and a root `mcp.json` (shapes in `public-repo.md`). Cursor does not read `.claude-plugin/plugin.json`.

Form fields, one submission per product: Organization name, Organization handle (kebab-case; a dotted handle is rejected), Contact email, Logotype URL (1:1 with a background plate; a 127px favicon fails, a 512x512 PNG with the mark at about 60% width on white passed), GitHub repository, Website URL, Description (three or four sentences naming platforms, what the tools do, and that it connects to the hosted server with an API token).

If the account only allows one organization, submit under the maintainer's name with a kebab-case handle.

## xAI plugin marketplace

Repo: https://github.com/xai-org/plugin-marketplace, catalog `.grok-plugin/marketplace.json`. It accepts `.claude-plugin/plugin.json` repos. The queue is slow: around 90 third-party PRs open, a dozen merged in two months, mostly recognizable vendors.

Procedure that passed the automated checks:

1. Fork and clone, sync to upstream main, one branch per plugin.
2. Add one catalog entry: `name`, `description`, `category` (productivity, analytics, marketing), `source` with the repo URL and a pinned 40-character `sha`, `homepage`, brand-scoped `keywords`, `license`. Insert it as text matching the file's inline-array formatting; reformatting the whole file with a JSON dumper produced a 2,000-line diff and had to be redone.
3. Run their `scripts/validate-catalog.py` and the index generator before pushing.
4. Fill the PR template completely: every checkbox, the exact hosts the plugin talks to, the single env var, and a note that any `mcp-server/` directory is source for the hosted endpoint and is not executed by the plugin.
5. `gh pr create -R xai-org/plugin-marketplace --head "<you>:add-<name>"`.

Socket Security and Semgrep scan the repo, and they read `.mcp.json`; a placeholder like `Bearer TOKEN_HERE` looks like a leaked credential. Use `${EXAMPLE_API_KEY}`. The pinned SHA is a snapshot, so every later push to the plugin repo needs a follow-up PR bumping it.

## Not a submission path

`claude.com/platform/marketplace` is the enterprise resale channel (partners like GitLab and Snowflake), waitlist only. It is unrelated to plugins or connectors.
