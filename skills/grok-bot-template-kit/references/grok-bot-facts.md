# Grok Bot facts

Sourced from docs.x.ai/grok-bot (checked 2026-08-29). Re-verify before relying on limits; the product moves fast.

## Access

Grok Bot is a desktop app (macOS/Windows) behind a paid plan. The docs list the eligible plans as "SuperGrok Plus, SuperGrok Heavy, Cursor Pro+, Cursor Ultra, or Cursor Teams Standard or Premium". There is no free tier and no web-only creation flow.

## What a bot is made of

- Profile: name, title, description, avatar.
- Skills: reusable instruction sets, saved from chat ("save this as a skill").
- Routines: scheduled or event-triggered recurring tasks. Docs state "up to 50 routines per Bot" with the "20 most recent runs" retained.
- Working memory and learned preferences (per-bot, not shareable).

## Creation flow (UI only)

"Choose New in the sidebar or press Cmd/Ctrl+N, then in New chat, select Create new agent. Open Bot actions -> Edit Profile to set its name, title, description, and avatar."

There is no documented API, CLI, or config-file route for creating bots or templates.

## Templates

Published via Bot actions -> Share as Template; the result is a public page at `x.ai/bot/<id>` with an Add to Grok Bot button and a `grokbot://` deep link.

What transfers: profile, skills, routines, first-party integrations.

What does not transfer: "conversation history, computer, signed-in sessions, API keys, or other secrets", plus custom MCP servers, scripts, and code.

Consequences:

- A template skill must drive a public REST API with a bearer token the installer supplies; the installer pastes their own key into the connector credential field on first use.
- Skill text DOES ship. A token accidentally written into the skill body ships with it. Always search the saved skill for the token prefix before sharing.
- Whether a template link survives deleting its source bot is undocumented. Keep the source bot alive while the link matters.

## Credentials

Connector API keys are entered through "the connector's secure credential field, not through the conversation". Instruct the bot accordingly inside the skill, and tell the owner the same in the kit.
