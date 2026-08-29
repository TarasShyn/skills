const target = process.argv[2];

if (!target) {
  console.error('Usage: node competitors.mjs <domain>');
  console.error('Auth via env: DATAFORSEO_LOGIN + DATAFORSEO_PASSWORD, or AHREFS_API_KEY');
  process.exit(1);
}

const fromDataForSeo = async () => {
  const auth = Buffer.from(`${process.env.DATAFORSEO_LOGIN}:${process.env.DATAFORSEO_PASSWORD}`).toString('base64');
  const response = await fetch('https://api.dataforseo.com/v3/dataforseo_labs/google/competitors_domain/live', {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify([{ target, language_name: 'English', location_code: 2840, limit: 10, exclude_top_domains: true }]),
  });
  const data = await response.json();
  const items = data.tasks?.[0]?.result?.[0]?.items ?? [];

  return items.map((item) => item.domain).filter((domain) => domain && domain !== target);
};

const fromAhrefs = async () => {
  const query = new URLSearchParams({ target, limit: '10', select: 'competitor_domain,common_keywords' });
  const response = await fetch(`https://api.ahrefs.com/v3/site-explorer/organic-competitors?${query}`, {
    headers: { Authorization: `Bearer ${process.env.AHREFS_API_KEY}` },
  });
  const data = await response.json();

  return (data.competitors ?? data.items ?? []).map((item) => item.competitor_domain).filter(Boolean);
};

const homepageDescriptions = async (domain) => {
  try {
    const response = await fetch(`https://${domain}/`, {
      headers: { 'user-agent': 'entity-stack-kit/1.0', accept: 'text/html' },
      signal: AbortSignal.timeout(10000),
    });
    const html = await response.text();
    const pick = (pattern) => html.match(pattern)?.[1]?.trim() ?? '';

    return {
      domain,
      title: pick(/<title[^>]*>([^<]*)<\/title>/i),
      description: pick(/<meta[^>]+name="description"[^>]+content="([^"]*)"/i),
      ogDescription: pick(/<meta[^>]+property="og:description"[^>]+content="([^"]*)"/i),
    };
  } catch {
    return { domain, title: '', description: '', ogDescription: '' };
  }
};

const hasDataForSeo = process.env.DATAFORSEO_LOGIN && process.env.DATAFORSEO_PASSWORD;
const hasAhrefs = process.env.AHREFS_API_KEY;

if (!hasDataForSeo && !hasAhrefs) {
  console.error('No API credentials in the environment.');
  process.exit(1);
}

const domains = (hasDataForSeo ? await fromDataForSeo() : await fromAhrefs()).slice(0, 5);
const results = await Promise.all(domains.map(homepageDescriptions));

console.log(JSON.stringify({ target, competitors: results }, null, 2));
