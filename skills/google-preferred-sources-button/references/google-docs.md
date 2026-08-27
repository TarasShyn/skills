# Facts from Google's preferred sources guide

Source: https://developers.google.com/search/docs/appearance/preferred-sources (read 2026-08-27). Code blocks below are copied from that page unchanged. If anything here disagrees with the live page, the live page wins.

## What the feature does

- When a reader selects a site as a preferred source, that site's content "is more likely to appear in Top Stories, highlighted with a 'preferred' badge."
- "In AI Mode and AI Overviews, your content can be highlighted with a 'preferred' badge for users who have selected your site as a preferred source."
- The feature is per reader. It changes what that signed-in reader sees, not the site's general ranking.

## Availability

- Top Stories: "available globally ... in all languages where Google Search is available."
- AI Mode and AI Overviews: "in all languages and locales where those features are available."
- Timeline reported by press coverage of Google's announcements: US and India launch August 2025, English worldwide December 2025, all supported languages April 30, 2026, AI Overviews and AI Mode May 27, 2026, embeddable button and the developer doc August 20, 2026.

## Eligibility

"Only domain-level and subdomain-level sites are eligible to appear in the source preferences tool. For example, https://www.example.com/ and https://code.example.com/ are eligible for preferred sources, but the subdirectory https://www.example.com/blog isn't eligible."

To check a site, type it into the search box of the source preferences tool: https://www.google.com/preferences/source

Google also states the button and link "are examples of how you can build your audience ... It's not required to do them in order to appear as a preferred source."

## Implementation 1: standard JavaScript button (Google recommends this)

Script, preferably in `<head>`:

```html
<script async src="https://news.google.com/swg/js/v1/publisher.js"></script>
```

Container, anywhere in `<body>`:

```html
<div google-add-preferred-source-btn></div>
```

Theme (default light):

```html
<div google-add-preferred-source-btn data-theme="dark"></div>
```

Language override (default is the reader's browser language):

```html
<div google-add-preferred-source-btn data-lang="en"></div>
```

Supported language codes CSV: https://developers.google.com/static/search/docs/appearance/preferred-sources-languages.csv

Behaviour: without the manual attribute, the library "automatically scans the DOM for elements with the google-add-preferred-source-btn attribute and renders the standard badge."

## Implementation 2: advanced JavaScript, your own UI

### ES module

```js
import { preferredSource } from
  "https://news.google.com/swg/js/v1/publisher.mjs";

// 1. Initialize directly using the imported module instance
preferredSource.init({
  theme: 'light', // Theme choice: "light" or "dark" (default "light")
  lang: 'en'      // Optional: override language (defaults to page language)
});

// 2. Programmatically bind flow invocation using a click handler
const button = document.querySelector('#myButton');
button.onclick = () => {
  preferredSource.addPreferredSource();
};
```

### Script tag with callback queue

Load with the manual attribute so the library does not render its own button:

```html
<script async preferred-sources-control="manual" src="https://news.google.com/swg/js/v1/publisher.js"></script>
```

Then:

```html
<script>
  (self.PREFERRED_SOURCE = self.PREFERRED_SOURCE || []).push(
    function(preferredSource) {
      // 1. Initialize with options
      preferredSource.init({
        theme: 'light',
        lang: 'en'
      });

      // 2. Programmatically bind trigger button
      const button = document.querySelector('#myButton');
      button.addEventListener('click', () => {
        preferredSource.addPreferredSource();
      });
  });
</script>
```

Google's note: "If the preferred-sources-control="manual" attribute is omitted, it'll search for and immediately initialize any elements with the google-add-preferred-source-btn attribute."

API exposed to the callback / module: `init({ theme, lang })` and `addPreferredSource()`. Both distributions "expose identical capabilities and methods."

Live demo from Google: https://reader-revenue-demo.ue.r.appspot.com/preferred-sources/esm

## Implementation 3: deeplink (no JavaScript)

URL format:

```
https://www.google.com/preferences/source?q=Your_Website's_URL
```

Text link:

```html
<a
  href="https://www.google.com/preferences/source?q=example.com">
  Add as Preferred Source
</a>
```

Image link:

```html
<a
  href="https://www.google.com/preferences/source?q=example.com">
  <img src="path/to/your/button.png" alt="Add as Preferred Source">
</a>
```

Google suggests the deeplink for "social posts, email newsletters, or promotions" too.

Official translated badge images (zip): https://services.google.com/fh/files/helpcenter/google_preferred_source_badge_all_languages.zip

## Related Google pages

- Reader-facing help for Top Stories and preferred sources: https://support.google.com/websearch/answer/16379181
- Source preferences tool: https://www.google.com/preferences/source
