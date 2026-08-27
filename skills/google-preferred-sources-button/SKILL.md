---
name: google-preferred-sources-button
description: Add a "Make us preferred on Google" button to any website so readers can mark the site as a Google preferred source (shown with a "preferred" badge in Top Stories, AI Mode and AI Overviews). Language and framework agnostic - plain HTML, React, Vue, Svelte, Astro, PHP templates, anything that renders HTML. Use this whenever the user mentions preferred sources, "preferred on Google", the Google source preferences tool, the `publisher.js` / `swg` script, a "prefer us on Google" button, or wants readers to see their articles more often in Google Search. Also use it when adding a footer CTA or an end-of-article CTA for a blog and the site is a news, blog, or content publisher.
---

# Google preferred sources button

Google lets readers pick sites they want to see more of. When a reader marks your site as a preferred source, Google is more likely to show your articles in Top Stories with a "preferred" badge, and it can badge your content in AI Mode and AI Overviews for that reader. The mechanism is per reader, so the job of this skill is to get the ask in front of readers at the moments they are most likely to say yes, using code Google actually documents.

Everything below comes from Google's official guide at
https://developers.google.com/search/docs/appearance/preferred-sources
(verbatim code and links are in `references/google-docs.md`). Do not claim ranking boosts, traffic numbers, or "SEO" effects that the doc does not state. What Google says: the site becomes "more likely to appear in Top Stories" for that reader, and gets a "preferred" badge in Top Stories, AI Mode and AI Overviews.

## Check eligibility first

Only domains and subdomains are eligible. `https://www.example.com/` and `https://blog.example.com/` can be preferred sources. `https://www.example.com/blog` cannot, because the preference applies to the whole host.

Before writing code:

1. Open `https://www.google.com/preferences/source?q=<domain>` and confirm the site shows up in the search box results. If it does not appear, the button will open a dialog with nothing to add. Tell the user and stop.
2. Note which host the reader will actually prefer. A blog on `blog.example.com` makes `blog.example.com` the preferred source, not the marketing site. A blog under `example.com/blog` makes all of `example.com` the preferred source. Say this out loud to the user so the wording matches reality.

## Pick an implementation

Google ships three. Pick by what the site can run.

| Site can run | Use | Why |
| --- | --- | --- |
| Client-side JavaScript, default look is fine | Standard button (two lines) | Google renders a localized, Google-styled button. Least code. |
| Client-side JavaScript, you want your own button | Manual mode (`preferred-sources-control="manual"` + `PREFERRED_SOURCE` queue, or the ESM import) | Your design system, your label, same dialog flow. |
| No JavaScript (email, CMS with no script access, social posts) | Deeplink `https://www.google.com/preferences/source?q=<domain>` | Plain link to the source preferences tool. |

Most product sites want manual mode: the button should look like the rest of the footer, and the label should be in the site's translation files.

### Standard button

```html
<script async src="https://news.google.com/swg/js/v1/publisher.js"></script>
<div google-add-preferred-source-btn data-theme="light" data-lang="en"></div>
```

`data-theme` is `light` (default) or `dark`. `data-lang` overrides the browser language; the supported codes are in Google's CSV (link in the references file). The script scans the DOM for `google-add-preferred-source-btn` on load, so in a client-rendered app make sure the element exists before the script runs, or use manual mode.

### Manual mode (your own button)

Load the script once with the manual attribute, then push a callback onto the global queue. The callback runs when the library is ready, whether that is before or after your code executed.

```html
<script async preferred-sources-control="manual"
  src="https://news.google.com/swg/js/v1/publisher.js"></script>

<button id="prefer-on-google">Make us preferred on Google</button>

<script>
  (self.PREFERRED_SOURCE = self.PREFERRED_SOURCE || []).push(function (preferredSource) {
    preferredSource.init({ theme: 'light', lang: 'en' });
    document.getElementById('prefer-on-google')
      .addEventListener('click', function () { preferredSource.addPreferredSource(); });
  });
</script>
```

ESM variant, for bundlers and module scripts:

```js
import { preferredSource } from 'https://news.google.com/swg/js/v1/publisher.mjs';

preferredSource.init({ theme: 'light', lang: 'en' });
button.onclick = () => preferredSource.addPreferredSource();
```

Rules that make manual mode behave in a real app:

- Load the script exactly once. Give the `<script>` an id and check for it before appending; component frameworks mount the same footer on every route.
- Never call `init` or `addPreferredSource` directly on a global you assume exists. Always go through the queue (or the ESM import). The library may not be loaded when the user clicks.
- If the user clicks before the library is ready, push `addPreferredSource` onto the queue instead of dropping the click.
- Pass the site's real theme and language to `init`. If the site has a dark mode toggle, re-run `init` when the theme changes so Google's dialog matches. Same for a language switcher.
- Guard for `window` when the framework renders on the server. The script tag and the queue only exist in the browser.

`references/framework-patterns.md` has a React component that does all of the above, plus notes for Vue, Svelte and Astro. Port the pattern, not the file.

### Deeplink

```html
<a href="https://www.google.com/preferences/source?q=example.com">Add as Preferred Source</a>
```

Use the bare domain in `q`. This is also what goes in newsletters and social bios. Google offers translated badge images (zip link in the references file) if you want a graphic instead of text.

## Where to put it

Two placements cover most sites. Do both when the site has a blog.

**Footer, every page.** A secondary-style button in the footer's brand column, next to the theme switcher or contact links. It is always available without shouting. Use the site's normal secondary button component with a Google "G" icon on the left.

**End of every article, above the newsletter or product CTA.** A small card: heading, one sentence, the button on the right. Readers who just finished an article are the ones most likely to want more, so this is the placement that converts. Put it after the article body and reactions, before the "before you go" product pitch, so it does not compete with the sale.

Do not put it in the header or in a modal. Do not auto-open the flow. The dialog is a Google account action and readers should choose to start it.

## Wording

Google's own button reads "Add to Preferred Sources" / "Add as Preferred Source". That is accurate but generic. Wording that has worked on product blogs is direct about what the reader gets and mentions Google by name, because "preferred source" alone means nothing to most readers.

Button label (footer and card, keep it identical so it is recognisable):

> Make us preferred on Google

Card heading:

> See us more often in Google

Card description (swap the brand):

> One click marks AdaptlyPost as a preferred source, so our articles sit higher in your Top Stories, AI Mode, and AI Overviews.

Rules for the copy:

- Say "Google" in the label. The reader needs to know which account they are about to touch.
- Describe the reader's outcome (see us more often), not yours (help our traffic).
- Keep the button label under about 30 characters so it fits next to a theme switcher on mobile.
- Localise the label, heading and description into every language the site ships. Google localises its own dialog from `lang`; your button text is your job.
- Do not promise ranking changes, "SEO boost", or that the reader will see every article. Google's doc says "more likely to appear" and "can be highlighted". Stay inside that.

## Checklist before you say it is done

- [ ] Site is a domain or subdomain and appears in `https://www.google.com/preferences/source?q=<domain>`.
- [ ] Script loads once (id guard), `async`, with `preferred-sources-control="manual"` if you render your own button.
- [ ] `init` receives the site's real theme and language, and re-runs when either changes.
- [ ] Click before load is queued, not lost.
- [ ] Footer button present on every page; end-of-article card present on every blog post.
- [ ] Button label, heading, description exist in every locale file.
- [ ] Server-rendered pages do not touch `window` during render.
- [ ] A test asserts: script tag added once with the manual attribute; `init` called with theme and lang; click calls `addPreferredSource`; a click before load is replayed after load.
- [ ] Copy makes no claims beyond Google's doc.

## Reference files

- `references/google-docs.md` - the facts from Google's guide: every code sample verbatim, availability, eligibility, asset and CSV download links, the demo URL.
- `references/framework-patterns.md` - a full React component with tests, and how the same pattern maps to Vue, Svelte, Astro and server-rendered templates.
