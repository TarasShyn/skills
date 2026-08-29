# What Google documents about organization entities

Source: https://developers.google.com/search/docs/appearance/structured-data/organization (read 2026-08-28). Quotes are verbatim. If this file disagrees with the live page, the live page wins.

## Why the markup exists

Organization structured data "can help Google better understand your organization's administrative details and disambiguate your organization in search results", and it influences "which logo is shown in Search results and your knowledge panel".

## sameAs

Google's definition: "The URL of a page on another website with additional information about your organization, if applicable. For example, a URL to your organization's profile page on a social media or review site."

That is the whole contract. `sameAs` is an identity signal, not a ranking lever. The kit exists to make the set of profiles real, live, and consistent; do not promise more than that.

## logo

- Minimum 112x112 px.
- Must be crawlable and indexable (not blocked by robots.txt, not data-inlined only).
- "Should display clearly on a white background" per Google's logo guidance.
- Either a plain URL or an `ImageObject` with `contentUrl`/`url`.

## Placement

"We recommend placing this information on your home page, or a single page that describes your organization, for example the about us page."

One page carries the markup; every other page can reference it by `@id`.

## Properties Google lists for Organization

`name`, `alternateName`, `legalName`, `url`, `logo`, `description`, `sameAs`, `foundingDate`, `address`, `contactPoint`, `telephone`, `email`, `numberOfEmployees`, `vatID`, `taxID`, `iso6523Code`, `naics`, `duns`, `leiCode`, `globalLocationNumber`, `hasMerchantReturnPolicy`, `hasMemberProgram`.

A SaaS entity kit usually carries: `name`, `url`, `logo`, `description`, `sameAs`, `foundingDate`, `email`, `address`. Add the tax/registry identifiers only when the user supplies them; never invent them.

## Consistency

Directories, Google, and LLMs cross-check fields. The same name, the same logo file, the same founding year and the same one-liner should appear on every profile. When a directory forces a character limit, truncate the short description; do not write a new variant per site.
