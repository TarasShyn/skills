# Skills

Agent skills I use across my own products ([AdaptlyPost](https://adaptlypost.com), [Flowsery](https://flowsery.com), [RedReplier](https://redreplier.com), [ClawOneClick](https://clawoneclick.com)). Each one is a `SKILL.md` folder, so it works with Claude Code, Codex, Cursor and any agent that reads skills.

Every skill here came out of shipping the thing first and writing down what actually worked. No theory, no guesses about what Google or a framework "probably" does.

Pages for each skill, with a copy button, live at [tarasshynkarenko.com/skills](https://tarasshynkarenko.com/skills).

## Install

```bash
npx skills@latest add TarasShyn/skills
```

Or clone one folder by hand into `.claude/skills/<name>` (or your agent's skills directory).

## Reference

- **[google-preferred-sources-button](./skills/google-preferred-sources-button/SKILL.md)** — Add a "Make us preferred on Google" button to any site so readers can mark it as a Google preferred source. Placement, wording, framework-agnostic code, tests. Everything factual comes from Google's own guide.
- **[mcp-directory-submission](./skills/mcp-directory-submission/SKILL.md)** — Publish a remote MCP server to the official MCP registry and Smithery: server.json template, DNS domain proof, publish scripts, and the review gotchas from three production submissions. More directories as they get added.
- **[entity-stack-kit](./skills/entity-stack-kit/SKILL.md)** — Read a site's `sameAs` schema and generate one HTML submission kit: logo, banner, descriptions, and every entity profile with copy buttons and per-directory guides. Machine-readable for agents; optional DataForSEO or Ahrefs description alignment.

## License

MIT
