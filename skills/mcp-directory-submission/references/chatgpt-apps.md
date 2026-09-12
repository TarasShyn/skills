# ChatGPT apps

Verified 2026-08-28 to 2026-09-11: three apps submitted, all three first versions rejected for test-case drift, resubmitted as 1.1.0.

Portal: https://platform.openai.com/plugins (OpenAI calls them plugins again in the UI). Docs: https://developers.openai.com/plugins/deploy/submission.md, guidelines at https://developers.openai.com/apps-sdk/app-submission-guidelines, JSON schema at https://developers.openai.com/apps-sdk/schemas/chatgpt-app-submission.v1.json. The `openai/plugins` repo ships a `chatgpt-app-submission` skill that generates the JSON from a running server.

## Prerequisites

- Verified developer identity in the organization settings (government ID) and an Apps Management role with Write.
- OAuth on the server. The connector dialog offers OAuth or None, and reviewers test the production endpoint. There is no credentials field for a demo token, and the user rule here was never to hand over accounts beyond the review account the form now asks for.
- A token served at `https://mcp.example.com/.well-known/openai-apps-challenge` as plain text, from an env var, one per app. The form's "Challenge Base URL" ignores paths; use the MCP host.
- Every tool with explicit `readOnlyHint`, `openWorldHint`, `destructiveHint`; the form shows "Explicitly provided by your MCP server" and will not guess.

## Create the app

Create plugin, type Standard (one production URL for all users; Templated is for per-tenant URLs). Tabs: Info, MCP, Skills, Prompts, Testing, Global, Submit.

MCP tab: server URL, Authentication OAuth, Scan Tools (signs in with the review account), then upload `chatgpt-app-submission.json`. Order matters: scan first, then upload, or the justifications attach to a stale tool snapshot and the new tools show empty "Describe why Read Only is set" boxes. A successful import reads like "Imported 17 tool justifications. Skipped 0. Missing 0. Mismatched 1. Stale annotations: upload_media." Mismatched means the JSON's annotation differs from the live server; fix the server or the JSON, rescan, re-import.

The JSON carries `app_info` (name, subtitle, description, category enum such as PRODUCTIVITY or BUSINESS), `tools` with annotations and a one-sentence justification for each of the three hints, exactly five `test_cases` and exactly three `negative_test_cases`. Support, privacy, terms URLs, logo, countries, prompts, release notes, and the video are form-only.

Constraints hit:

- Subtitle 30 characters or fewer (`Subtitle must be 30 characters or fewer`). No counts in it.
- Exactly 5 test cases and 3 negative cases.
- Each test standalone; no "that draft" carried from the previous test.
- Read-only or draft-only prompts. Nothing that publishes, charges, or deletes real data.
- Date windows as "last month", not "this week"; a reviewer on a quiet day gets an empty result and fails the case.
- Name the exact site or account when the review account has several.
- Avoid realtime prompts that can legitimately return zero.
- Negative cases pass when no app tool is called; a negative prompt that a newly added tool now answers becomes a failure.

Info tab: name, subtitle, category, website, support, privacy, terms (all must resolve), description written in the product's voice, three starter prompts (fill all three), release notes as one public line ("Initial release. ..."), icons 256px and 48px in light and dark. Commerce: no sales, no digital goods, no links out to purchase. Mature content: no.

Testing tab now has a required Test credentials block: login URL, tenant or workspace, username, password, sign-in steps; no MFA, no emailed codes, dedicated account, keep it working. Saving does not submit.

Demo video: ChatGPT in Chat mode (not agent mode) with Developer Mode on (Settings, Apps & Connectors, Advanced), show the OAuth connect once, then each of the five prompts in a fresh chat with the tool card expanded, then repeat one or two on ChatGPT mobile. Unlisted YouTube or a Google Drive link with viewer access. Web-only videos get bounced.

## Why the first versions were rejected

The text was the same for all three: "One or more of your test cases did not produce correct results. Please re-run all submitted test cases and align tool behavior/output with the documented expected outcomes. Ensure the same test cases pass consistently on both ChatGPT web and mobile."

Cause in every case: the live server had moved on since the JSON was written. One app justified 12 tools while the server served 18, and a negative case about follower counts started triggering once analytics tools existed. Another referenced tools that were not yet deployed when the reviewer ran it. The third still exposed a tool that had since been removed. Rejected versions are read-only; create a new draft with a higher semver, regenerate the JSON from the live server, rescan, re-import, re-record the video.

## Client-side gotchas seen during recording

- ChatGPT died composing one edit tool's call ("Stopped talking to ...") while reads and creates worked; server logs proved the request never left ChatGPT. Known SDK bug at the time. Swap the test case for a read tool rather than fight it.
- Dev-mode connectors cache `tools/list` until you press Refresh on the connector.
- Deploying to a single-instance server mid-recording kills in-flight calls.
- After submission the validator sends `server/discover`, a malformed `tools/list`, a nonexistent method, and an unauthenticated `__verifymcp_auth_probe_*__` tool call. The first three should 400; the last must 401.
