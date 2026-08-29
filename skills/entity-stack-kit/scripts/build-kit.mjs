import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { CATEGORIES, PLATFORMS, isPaidHost, matchPlatform } from './platforms.mjs';

const kitPath = process.argv[2];

if (!kitPath) {
  console.error('Usage: node build-kit.mjs <kit.json> > entity-kit.html');
  process.exit(1);
}

const kit = JSON.parse(await readFile(kitPath, 'utf8'));
const templatePath = path.join(path.dirname(fileURLToPath(import.meta.url)), '../assets/kit-template.html');
const template = await readFile(templatePath, 'utf8');

const esc = (value) =>
  String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

const COPY_ICON = `<svg class="idle" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="9" width="13" height="13" rx="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg><svg class="done" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"></path></svg>`;

const copyButton = (value) => `<button type="button" class="copy" data-copy="${esc(value)}" aria-label="Copy">${COPY_ICON}</button>`;

const field = (label, value, variant = '') =>
  value
    ? `<div class="field"><span class="field-label">${esc(label)}</span><span class="field-value${variant ? ` ${variant}` : ''}">${esc(value)}</span>${copyButton(value)}</div>`
    : '';

const STATUS_LABELS = { live: 'live', broken: 'broken', 'to-submit': 'to submit' };

const hostOf = (url) => {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
};

const profileRow = ({ platform, url, status }) => {
  const name = platform?.name ?? hostOf(url ?? '');
  const guide = platform?.guide ?? ['Create the profile with the kit name, logo, short description, and homepage URL.'];
  const targetUrl = url ?? platform.claimUrl;
  const urlLine = url
    ? `<div class="platform-url"><a href="${esc(url)}" rel="noopener">${esc(url)}</a>${copyButton(url)}</div>`
    : `<div class="platform-url"><a href="${esc(platform.claimUrl)}" rel="noopener">${esc(platform.claimUrl)}</a>${copyButton(platform.claimUrl)}</div>`;

  const effort = platform?.effort ?? 'easy';
  const paid = Boolean(url && isPaidHost(url));
  const badges = `<span class="badge effort-${esc(effort)}">${esc(effort)}</span>${paid ? '<span class="badge paid">paid</span>' : ''}`;

  return `<details data-platform="${esc(platform?.id ?? 'unknown')}" data-status="${esc(status)}" data-effort="${esc(effort)}" data-paid="${paid}" data-url="${esc(targetUrl)}">
<summary><span class="status status-${esc(status)}">${STATUS_LABELS[status]}</span>${badges}<span class="platform-name">${esc(name)}</span><span class="platform-host">${esc(url ? hostOf(url) : platform.claimUrl)}</span></summary>
<div class="platform-body">${urlLine}<ol>${guide.map((step) => `<li>${esc(step)}</li>`).join('')}</ol></div>
</details>`;
};

const broken = new Set(kit.broken ?? []);
const rows = kit.sameAs.map((url) => ({
  platform: matchPlatform(url),
  url,
  status: broken.has(url) ? 'broken' : 'live',
}));

const covered = new Set(rows.map((row) => row.platform?.id).filter(Boolean));
const gaps = PLATFORMS.filter((platform) => !platform.optional && !covered.has(platform.id)).map((platform) => ({
  platform,
  url: null,
  status: 'to-submit',
}));

const all = [...rows, ...gaps];
const sections = Object.entries(CATEGORIES)
  .map(([key, label]) => {
    const entries = all.filter((row) => (row.platform?.category ?? 'other') === key);

    if (entries.length === 0) return '';

    return `<h2>${esc(label)}</h2>\n${entries.map(profileRow).join('\n')}`;
  })
  .filter(Boolean)
  .join('\n');

const fields = [
  field('Name', kit.name),
  field('Homepage', kit.url, 'mono'),
  field('Short description', kit.shortDescription),
  field('Long description', kit.longDescription, 'prewrap'),
  field('Logo URL', kit.logo, 'mono'),
  field('Banner URL', kit.banner, 'mono'),
  field('Founded', kit.foundingDate),
  field('Email', kit.email, 'mono'),
].join('\n');

const jsonLd = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: kit.name,
  url: kit.url,
  ...(kit.logo && { logo: kit.logo }),
  ...(kit.longDescription && { description: kit.longDescription }),
  ...(kit.foundingDate && { foundingDate: kit.foundingDate }),
  ...(kit.email && { email: kit.email }),
  sameAs: kit.sameAs,
};

const html = template
  .replaceAll('{{NAME}}', esc(kit.name))
  .replaceAll('{{URL}}', esc(kit.url))
  .replaceAll('{{URL_HOST}}', esc(hostOf(kit.url)))
  .replaceAll('{{DATE}}', new Date().toISOString().slice(0, 10))
  .replace('{{BANNER_IMG}}', kit.banner ? `<img class="banner" src="${esc(kit.banner)}" alt="${esc(kit.name)} banner" />` : '')
  .replace('{{LOGO_IMG}}', kit.logo ? `<img src="${esc(kit.logo)}" alt="${esc(kit.name)} logo" />` : '')
  .replace('<!--FIELDS-->', fields)
  .replace('<!--SECTIONS-->', sections)
  .replace('{{KIT_JSON}}', JSON.stringify(kit, null, 2).replaceAll('</', '<\\/'))
  .replace('{{JSONLD}}', JSON.stringify(jsonLd, null, 2).replaceAll('</', '<\\/'));

console.log(html);
