# Instagram launch kit — assets

Finished, ready-to-post assets for **@the_ironbit**. Captions, hashtags, calendar, and the posting
workflow live in [`../../campaigns/2026-07-10-instagram-launch-kit.md`](../../campaigns/2026-07-10-instagram-launch-kit.md).
Account facts + guardrails: [`../../marketing_memory.md`](../../marketing_memory.md).

## Layout

```
identity/
  pfp-bit.png                 ← profile picture (chosen: BIT core, 320×320)
  pfp-logo.png                ← alternate profile picture (dumbbell logo)
  highlight-covers/           ← 1080×1080; BIT · CLASSES · RANK UP · HOW IT WORKS · DEVLOG
posts/
  01-intro/     slide-1…4.png ← PINNED carousel (4:5)
  02-hero-reel/ ironbit-hero-reel.mp4 ← reel, 1080×1920, 18.7s
  03-classes/   slide-1…4.png ← carousel (4:5)
  04-meme/      meme.png       ← still (4:5)
  05-home/      home-feature.png ← still (4:5)
```

## Upload specs
- **Carousels/stills:** 1080×1350 (4:5). Upload slides in numeric order. Pin post 01 after posting.
- **Reel:** 1080×1920 (9:16). Pick a cover frame with the RANK UP / wordmark moment.
- **Profile pic:** displayed as a circle — `pfp-bit.png` is centered for the crop.
- **Highlight covers:** IG crops to a center circle; icons are centered. The highlight *name* is typed
  in the app (BIT / CLASSES / RANK UP / HOW IT WORKS / DEVLOG).

## Regenerating a still
Source HTML/CSS + fonts are in the session scratchpad (`ig.css`, `ig_all.html`, `ig_all2.html`,
`ig_covers.html`). Serve the folder over localhost and screenshot each `#id` element at CSS scale.
Every color is a real `tokens.dart` value; fonts are the app's PressStart2P + Gotham.
