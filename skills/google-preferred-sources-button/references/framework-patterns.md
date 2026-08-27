# Framework patterns

The mechanics never change: load `publisher.js` once in manual mode, push a callback onto `PREFERRED_SOURCE`, call `init` with theme and language, call `addPreferredSource` on click, replay a click that happened before the library loaded. What changes is where each framework lets you do those things. Port the shape, not the file.

## React (Next.js app router, or any client component)

This is a working component extracted from a production monorepo. Replace the design-system imports with your own button, icon and translation hook.

```tsx
'use client';

import { useCallback, useEffect, useRef } from 'react';

interface PreferredSourceApi {
  init: (options: { theme: 'light' | 'dark'; lang: string }) => void;
  addPreferredSource: () => void;
}

declare global {
  interface Window {
    PREFERRED_SOURCE?: Array<(api: PreferredSourceApi) => void>;
  }
}

const SCRIPT_ID = 'google-preferred-source';
const SCRIPT_SRC = 'https://news.google.com/swg/js/v1/publisher.js';

const loadScript = () => {
  if (document.getElementById(SCRIPT_ID)) return;

  const script = document.createElement('script');
  script.id = SCRIPT_ID;
  script.src = SCRIPT_SRC;
  script.async = true;
  script.setAttribute('preferred-sources-control', 'manual');
  document.head.appendChild(script);
};

const enqueue = (callback: (api: PreferredSourceApi) => void) => {
  window.PREFERRED_SOURCE = window.PREFERRED_SOURCE || [];
  window.PREFERRED_SOURCE.push(callback);
};

interface PreferredSourceButtonProps {
  theme: 'light' | 'dark';
  lang: string;
  label: string;
  className?: string;
}

export const PreferredSourceButton = ({ theme, lang, label, className }: PreferredSourceButtonProps) => {
  const apiRef = useRef<PreferredSourceApi | null>(null);

  useEffect(() => {
    enqueue((api) => {
      apiRef.current = api;
      api.init({ theme, lang });
    });

    loadScript();
  }, [theme, lang]);

  const handleClick = useCallback(() => {
    if (apiRef.current) {
      apiRef.current.addPreferredSource();
      return;
    }

    enqueue((api) => api.addPreferredSource());
  }, []);

  return (
    <button type="button" onClick={handleClick} className={className}>
      <GoogleIcon aria-hidden="true" />
      {label}
    </button>
  );
};
```

Why each piece exists:

- `useEffect` depends on `[theme, lang]`, so a dark-mode toggle or language switch re-runs `init`. The queue accepts callbacks after load too, so pushing again is safe.
- `loadScript` runs after `enqueue` so the callback is already waiting when the library boots.
- `apiRef` remembers the API from the first callback. A click after load calls it directly; a click before load pushes a second callback that fires as soon as the library is ready.
- `'use client'` keeps `window` access out of server rendering.

End-of-article card that wraps the button:

```tsx
export const BlogPreferredSource = ({ title, description, button }: Props) => (
  <div className="mt-10 flex flex-col gap-5 rounded-2xl border-2 px-6 py-5 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <h3>{title}</h3>
      <p className="mt-1">{description}</p>
    </div>
    {button}
  </div>
);
```

### Tests (Jest + Testing Library)

Assert the contract, not the markup:

```tsx
const SCRIPT_SELECTOR = 'script#google-preferred-source';
const createApi = () => ({ init: jest.fn(), addPreferredSource: jest.fn() });
const flushQueue = (api) => {
  const queued = window.PREFERRED_SOURCE ?? [];
  window.PREFERRED_SOURCE = [];
  queued.forEach((cb) => cb(api));
};

beforeEach(() => {
  document.querySelectorAll(SCRIPT_SELECTOR).forEach((n) => n.remove());
  delete window.PREFERRED_SOURCE;
});

it('loads the publisher script once with manual control', () => {
  render(<PreferredSourceButton theme="light" lang="en" label="x" />);
  render(<PreferredSourceButton theme="light" lang="en" label="x" />);
  const scripts = document.querySelectorAll(SCRIPT_SELECTOR);
  expect(scripts).toHaveLength(1);
  expect(scripts[0]?.getAttribute('preferred-sources-control')).toBe('manual');
});

it('initialises with theme and language', () => {
  const api = createApi();
  render(<PreferredSourceButton theme="dark" lang="de" label="x" />);
  flushQueue(api);
  expect(api.init).toHaveBeenCalledWith({ theme: 'dark', lang: 'de' });
});

it('starts the flow on click', () => {
  const api = createApi();
  render(<PreferredSourceButton theme="light" lang="en" label="x" />);
  flushQueue(api);
  fireEvent.click(screen.getByRole('button'));
  expect(api.addPreferredSource).toHaveBeenCalledTimes(1);
});

it('queues the flow when the script has not loaded yet', () => {
  const api = createApi();
  render(<PreferredSourceButton theme="light" lang="en" label="x" />);
  fireEvent.click(screen.getByRole('button'));
  flushQueue(api);
  expect(api.addPreferredSource).toHaveBeenCalledTimes(1);
});
```

## Vue 3

Same shape in `onMounted` and a `watch` on theme/locale:

```vue
<script setup>
import { onMounted, ref, watch } from 'vue';
const props = defineProps({ theme: String, lang: String, label: String });
const api = ref(null);

const enqueue = (cb) => (window.PREFERRED_SOURCE = window.PREFERRED_SOURCE || []).push(cb);
const loadScript = () => {
  if (document.getElementById('google-preferred-source')) return;
  const s = document.createElement('script');
  s.id = 'google-preferred-source';
  s.src = 'https://news.google.com/swg/js/v1/publisher.js';
  s.async = true;
  s.setAttribute('preferred-sources-control', 'manual');
  document.head.appendChild(s);
};
const initApi = () => enqueue((a) => { api.value = a; a.init({ theme: props.theme, lang: props.lang }); });

onMounted(() => { initApi(); loadScript(); });
watch(() => [props.theme, props.lang], initApi);

const onClick = () => (api.value ? api.value.addPreferredSource() : enqueue((a) => a.addPreferredSource()));
</script>

<template>
  <button type="button" @click="onClick">{{ label }}</button>
</template>
```

## Svelte

`onMount` for the script and first `init`, a reactive statement for theme/lang changes, same click handler. Nothing framework-specific beyond that.

## Astro, Eleventy, Hugo, WordPress, any server-rendered template

There is no component lifecycle to fight, so use Google's snippet almost as-is inside the layout:

```html
<script async preferred-sources-control="manual"
  src="https://news.google.com/swg/js/v1/publisher.js"></script>

<button type="button" id="prefer-on-google">Make us preferred on Google</button>

<script>
  (self.PREFERRED_SOURCE = self.PREFERRED_SOURCE || []).push(function (ps) {
    ps.init({
      theme: document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light',
      lang: document.documentElement.lang || 'en',
    });
    document.querySelectorAll('[data-prefer-on-google]')
      .forEach((el) => el.addEventListener('click', () => ps.addPreferredSource()));
  });
</script>
```

Use a data attribute selector rather than an id when the footer button and the end-of-article button are both on the page. If the site toggles dark mode client-side, call `ps.init` again from the toggle handler with the new theme.

## Localisation

Google localises its dialog from the `lang` you pass (or the browser language if you pass nothing). Your button label, card heading and card description live in your own translation files. Ship all of them for every locale the site supports. Suggested English keys:

```json
{
  "preferredSource": {
    "button": "Make us preferred on Google",
    "title": "See us more often in Google",
    "description": "One click marks {{brand}} as a preferred source, so our articles sit higher in your Top Stories, AI Mode, and AI Overviews."
  }
}
```
