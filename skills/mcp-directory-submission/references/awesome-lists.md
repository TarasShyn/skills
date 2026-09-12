# The two punkpeye awesome lists

Both are maintained by the person who runs Glama, so the badge requirements are really "get scored on Glama". Both accept one PR per server on its own branch with a single clean commit, and both honour the agent fast track: CONTRIBUTING asks automated agents to append `🤖🤖🤖` to the PR title. Check the note still exists upstream before following it. Merges are manual, in batches, and the badges are live-rendered, so never recreate a PR to refresh one; leave a one-line comment once the score exists.

## awesome-remote-mcp-servers (hosted endpoints)

https://github.com/punkpeye/awesome-remote-mcp-servers, split out on 2026-09-08. Since then the older list closes hosted-server PRs with "We're splitting remote (hosted) MCP servers into their own list. Please open a PR at awesome-remote-mcp-servers instead."

Rules from CONTRIBUTING: public URL that answers `initialize`, usable by anyone with public sign-up, Streamable HTTP or SSE, and a Glama connector badge. Star the repo from the submitting account first; PRs from accounts that have not starred it are not merged.

Entry, three lines, alphabetical within the category, description under 120 characters ending with a period:

```markdown
- [Example](https://example.com) `https://mcp.example.com/mcp`
  [![Example MCP connector](https://glama.ai/mcp/connectors/com.example/mcp-server/badges/score.svg)](https://glama.ai/mcp/connectors/com.example/mcp-server)
  🔐 - One sentence naming the platforms or data the tools touch.
```

Line one links the product homepage, not the repo. Auth markers: 🔓 none, 🔑 API key, 🔐 OAuth; nothing else on that line.

CI (`check-submission.yml`) posts an anonymous `initialize` to the endpoint. A 200 with a result is 🔓; a 401 or 403 whose `WWW-Authenticate` mentions `resource_metadata` or `Bearer` is 🔐, otherwise 🔑; a timeout or 404 fails. It then fetches the connector page and checks the badge slug matches an existing connector. Labels: `endpoint-ok`, `has-connector`, `invalid-format`, `duplicate`. The marker must match what the probe saw.

The human gate is health: the maintainer commented on all three PRs that the connector "is currently showing an Unhealthy status. Per our guidelines, the connector must be Healthy before we can merge." Fix it on Glama (Admin, Test profile, sign in with OAuth), reply on the PR, and it merges within minutes. The post-merge bot offers a server-author flair on the MCP Discord.

## awesome-mcp-servers (local and stdio)

https://github.com/punkpeye/awesome-mcp-servers. Only for a repo that ships a runnable server. A hosted product qualifies when its public repo contains the stdio server source (see `public-repo.md`); the entry for one such repo merged on 2026-09-07 while the two repos without server code were closed and redirected to the remote list.

Entry, one line, loosely alphabetical by owner inside the category:

```markdown
- [owner/repo](https://github.com/owner/repo) [![owner/repo MCP server](https://glama.ai/mcp/servers/owner/repo/badges/score.svg)](https://glama.ai/mcp/servers/owner/repo) 🎖️ 📇 ☁️ - Description naming the platforms. Hosted at https://mcp.example.com/mcp (OAuth or API token).
```

Link text is the full `owner/repo`. Emojis come from a fixed legend (🎖️ official implementation, a language mark, ☁️ cloud or 🏠 local). `check-glama.yml` string-matches the added line for `glama.ai/mcp/servers/<x>/<y>/badges/score.svg` and labels `has-glama`; it never fetches the badge, so a 404ing badge still passes the bot. The duplicate and non-GitHub checks only look at the line's first link. The maintainer then requires an actual score: "the server must be evaluated by Glama with a quality score set (any grade is fine)". Get the Glama release done first.

## Housekeeping

Fork once, one branch per server, single commit with the entry, PR title `Add <Name> server 🤖🤖🤖`. If a first attempt gets bot comments you fixed, close it and open a clean one rather than force-pushing over a thread of stale checks; the maintainers skim the PR list. Delete your own stale comments with `gh api -X DELETE repos/<owner>/<repo>/issues/comments/<id>`.
