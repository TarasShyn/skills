const url = process.argv[2];

if (!url) {
  console.error('Usage: node extract-entity.mjs <site-url>');
  process.exit(1);
}

const decode = (text) =>
  text
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(parseInt(code, 16)));

const meta = (html, pattern) => {
  const match = html.match(pattern);

  return match ? decode(match[1].trim()) : '';
};

const collectJsonLd = (html) => {
  const blocks = [];
  const pattern = /<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi;

  for (const match of html.matchAll(pattern)) {
    try {
      const parsed = JSON.parse(match[1]);

      blocks.push(...(Array.isArray(parsed) ? parsed : [parsed]));
    } catch {
      continue;
    }
  }

  return blocks.flatMap((block) => (Array.isArray(block['@graph']) ? block['@graph'] : [block]));
};

const logoUrl = (logo) => {
  if (!logo) return '';
  if (typeof logo === 'string') return logo;

  return logo.contentUrl ?? logo.url ?? '';
};

const response = await fetch(url, { headers: { 'user-agent': 'entity-stack-kit/1.0', accept: 'text/html' } });

if (!response.ok) {
  console.error(`Fetch failed: HTTP ${response.status}`);
  process.exit(1);
}

const html = await response.text();
const nodes = collectJsonLd(html);
const entity =
  nodes.find((node) => Array.isArray(node.sameAs) && node.sameAs.length > 0) ??
  nodes.find((node) => ['Organization', 'SoftwareApplication'].includes(node['@type'])) ??
  {};

const absolute = (value) => {
  if (!value) return '';

  try {
    return new URL(value, url).href;
  } catch {
    return '';
  }
};

const kit = {
  name: entity.name ?? meta(html, /<meta[^>]+property="og:site_name"[^>]+content="([^"]*)"/i) ?? '',
  url: entity.url ?? url,
  logo: absolute(logoUrl(entity.logo)),
  banner: absolute(meta(html, /<meta[^>]+property="og:image"[^>]+content="([^"]*)"/i)),
  shortDescription: meta(html, /<meta[^>]+name="description"[^>]+content="([^"]*)"/i),
  longDescription: entity.description ?? '',
  foundingDate: entity.foundingDate ?? '',
  email: (entity.email ?? '').replace(/^mailto:/, ''),
  sameAs: entity.sameAs ?? [],
  broken: [],
};

console.log(JSON.stringify(kit, null, 2));
