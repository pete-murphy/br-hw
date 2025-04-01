## Get nearby locations

Given a lat/long & radius

```sh
curl 'https://production.retailers.boobook-services.com/retailers/nearby?latitude=-37.8418681&longitude=144.7936336&radi
us=40135' | jq . | pbcopy
```

Not documented, but JSON looks like

```json
{
  "problems": [],
  "retailers": [
    {
      "address": "30 Hall St<br/>Newport, VIC Australia 3015",
      "distance_in_kms": "7.955011139423457 km",
      "id": "10499549067565072563",
      "latitude": -37.8425583,
      "longitude": 144.8840064,
      "name": "Say It Sister",
      "phone_number": null,
      "retailer_type": "brick-and-mortar",
      "updated_at": "2024-09-03 03:18 UTC +00:00",
      "website": "https://sayitsister.com.au/search?type=product,article,page&q=bellroy"
    }
    // ...
  ]
}
```

## Search locations

Mapbox Search Box API https://docs.mapbox.com/api/search/search-box/#interactive-search

## Directions to location

https://docs.mapbox.com/api/navigation/directions/
(Implement a rate limit on client side in Elm)

## Colors

Main accent color is #E15A1D

```css
@theme {
  --color-brand-50: oklch(96.84% 0.014 46.23);
  --color-brand-100: oklch(93.61% 0.027 47.21);
  --color-brand-200: oklch(86.44% 0.06 45.85);
  --color-brand-300: oklch(80.34% 0.09 45.8);
  --color-brand-400: oklch(74.63% 0.121 45.15);
  --color-brand-500: oklch(68.69% 0.155 44.19);
  --color-brand-600: oklch(63.52% 0.182 41.07); /* #E15A1D */
  --color-brand-700: oklch(51.33% 0.142 41.94);
  --color-brand-800: oklch(39.08% 0.104 42.48);
  --color-brand-900: oklch(24.5% 0.057 44.33);
  --color-brand-950: oklch(17.14% 0.034 51.83);
}
```

Actual CSS from sources

```css
:root {
  --color-white: #ffffff;
  --color-grey-100: #f7f7f7;
  --color-grey-200: #efefef;
  --color-grey-300: #dbdbdb;
  --color-grey-400: #9b9b9b;
  --color-grey-500: #666666;
  --color-grey-600: #333333;
  --color-pop-orange: #e15a1d;
  --color-text-primary: var(--color-grey-600);
  --color-text-secondary: var(--color-grey-500);
  --color-text-tertiary: var(--color-grey-400);
  --color-text-inverted: var(--color-white);
  --color-text-brand: var(--color-pop-orange);
  --color-surface-primary: var(--color-grey-100);
  --color-surface-secondary: var(--color-grey-300);
  --color-surface-tertiary: var(--color-grey-400);
  --color-surface-brand: var(--color-pop-orange);
  --link-color-text: var(--color-text-brand);
  --modal-color-surface: #efeae5;
  --modal-header-color: var(--color-text-brand);
}
```

Some grays used in "About us" #82999E #A6B8BA #ECEAE4 (main bg)
