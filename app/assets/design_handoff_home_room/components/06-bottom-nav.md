# Component · Bottom Nav

Five destinations with a **raised center TRAIN** commit button — the primary action,
visually promoted above the rail. Fixed below the screen.

## Markup

```html
<nav class="nav">
  <button class="nav-item">
    <div class="nav-icon active" style="-webkit-mask-image:url(assets/icon_map.png); mask-image:url(assets/icon_map.png);"></div>
    <span class="nav-label active">HOME</span>
  </button>
  <button class="nav-item">
    <div class="nav-icon" style="…icon_character.png…"></div>
    <span class="nav-label">HERO</span>
  </button>
  <div class="nav-train">
    <button class="nav-train-btn">
      <div class="nav-icon" style="…icon_sword.png…"></div>
    </button>
    <span class="nav-train-label">TRAIN</span>
  </div>
  <button class="nav-item">
    <div class="nav-icon" style="…icon_scroll.png…"></div>
    <span class="nav-label">QUESTS</span>
  </button>
  <button class="nav-item">
    <div class="nav-icon" style="…icon_bag.png…"></div>
    <span class="nav-label">BAG</span>
  </button>
</nav>
```

## The five items

| slot | label | icon | role |
|---|---|---|---|
| 1 | **HOME** | `icon_map.png` | this screen (active state) |
| 2 | **HERO** | `icon_character.png` | character / progression |
| 3 | **TRAIN** | `icon_sword.png` | **raised commit button** — start a session (mints Core/XP) |
| 4 | **QUESTS** | `icon_scroll.png` | effort → Gems |
| 5 | **BAG** | `icon_bag.png` | inventory / loot |

## Styling notes

- **Icons are PNG masks** tinted by CSS (so one art file → any state color). Active = bright
  token color; inactive = muted.
- **Active state:** `.nav-icon.active` + `.nav-label.active` get the active tint + the label
  brightens. Home is active on this screen.
- **TRAIN** (`.nav-train` / `.nav-train-btn`) is a circular button **lifted above** the rail
  (the FAB-style commit action), with its label below. It's the screen's primary CTA and
  echoes the feed card's "START ON TRAIN →".
- Labels: PressStart2P / small uppercase.

## Rules

- Every tap target **≥44px** (GUARDRAILS #10). The raised TRAIN button especially — make
  the circle generous.
- TRAIN is the one promoted action; the other four are equal-weight. Don't add a sixth.
- Match the active/inactive tint to the tokens.

## Native notes

A `BottomAppBar` / custom `Row`, with the center TRAIN as an overlapping
`FloatingActionButton`-style circle (notch optional). Icons via `ImageIcon` +
`ColorFiltered` from the packed sprite. Wire each to its route; Home shows active.
