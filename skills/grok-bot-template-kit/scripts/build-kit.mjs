#!/usr/bin/env node
// Usage: node build-kit.mjs kit.json > grok-bot-kit.html
//
// kit.json schema:
// {
//   "product": { "name": "", "title": "", "description": "", "avatarHint": "" },
//   "api": { "tokenPrefix": "", "tokenCreateUrl": "" },
//   "skill": { "text": "" },
//   "routine": { "name": "", "text": "" },   // optional
//   "verifyPrompt": ""
// }

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const kitPath = process.argv[2];
if (!kitPath) {
  console.error('Usage: node build-kit.mjs kit.json > grok-bot-kit.html');
  process.exit(1);
}

const kit = JSON.parse(readFileSync(kitPath, 'utf8'));
for (const [path, value] of [
  ['product.name', kit.product?.name],
  ['product.title', kit.product?.title],
  ['product.description', kit.product?.description],
  ['api.tokenPrefix', kit.api?.tokenPrefix],
  ['api.tokenCreateUrl', kit.api?.tokenCreateUrl],
  ['skill.text', kit.skill?.text],
  ['verifyPrompt', kit.verifyPrompt],
]) {
  if (!value) {
    console.error(`kit.json is missing ${path}`);
    process.exit(1);
  }
}

const esc = (s) =>
  String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

let blockId = 0;
const copyBlock = (label, text) => {
  const id = `paste-${++blockId}`;
  return `<div class="block">
        <div class="block-label"><span>${esc(label)}</span>
          <button class="copy" data-target="${id}" type="button" aria-label="Copy ${esc(label)}">
            <svg class="clip" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="5" y="5" width="8" height="9" rx="1.5"/><path d="M11 5V3.5A1.5 1.5 0 0 0 9.5 2h-5A1.5 1.5 0 0 0 3 3.5v7A1.5 1.5 0 0 0 4.5 12H5"/></svg>
            <svg class="check" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 8.5 6.5 12 13 4.5"/></svg>
            copy
          </button>
        </div>
        <pre id="${id}">${esc(text)}</pre>
      </div>`;
};

const hasRoutine = Boolean(kit.routine?.text);
const routineSection = hasRoutine
  ? `<h2>6. Add the routine (optional)</h2>
      <p class="step">Paste this and ask the bot to set it up as a routine named "${esc(kit.routine.name || 'routine')}".</p>
      ${copyBlock('routine', kit.routine.text)}`
  : '';

const template = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), '..', 'assets', 'kit-template.html'),
  'utf8',
);

const html = template
  .replaceAll('{{NAME}}', esc(kit.product.name))
  .replace('{{NAME_BLOCK}}', copyBlock('bot name', kit.product.name))
  .replace('{{SKILL_BLOCK}}', copyBlock('skill', kit.skill.text))
  .replaceAll('{{TOKEN_URL}}', esc(kit.api.tokenCreateUrl))
  .replaceAll('{{TOKEN_PREFIX}}', esc(kit.api.tokenPrefix))
  .replace('{{VERIFY_BLOCK}}', copyBlock('verify prompt', kit.verifyPrompt))
  .replace('{{AVATAR_HINT}}', esc(kit.product.avatarHint || 'the product logo'))
  .replace('{{TITLE_BLOCK}}', copyBlock('title', kit.product.title))
  .replace('{{DESCRIPTION_BLOCK}}', copyBlock('description', kit.product.description))
  .replace('{{ROUTINE_SECTION}}', routineSection)
  .replace('{{PUBLISH_STEP}}', hasRoutine ? '7' : '6')
  .replace('{{KIT_JSON}}', JSON.stringify(kit).replaceAll('</', '<\\/'));

process.stdout.write(html);
