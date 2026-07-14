# Component · Identity + Resource HUD

Two small persistent readouts: **who you are** (top-left, in the room) and **what you
have** (the screen-pinned topbar). Per principle 2, identity rests on BIT (the face) —
this text is the supporting nameplate, deliberately quiet.

---

## Identity (in-room, top-left)

```html
<div class="identity">
  <div class="identity-name">VALEN</div>
  <div class="identity-rank">
    <span class="identity-lv">LV.7</span>
    <span class="identity-sep"></span>
    <span class="identity-title">KNIGHT</span>
  </div>
</div>
```
```css
.identity       { position:absolute; z-index:8; left:16px; top:56px;
                  display:flex; flex-direction:column; gap:8px; }
.identity-name  { font-family:'PressStart2P'; font-size:14px; color:#E8E8FF;
                  letter-spacing:.5px; text-shadow:0 0 12px rgba(232,232,255,.25); }
.identity-rank  { display:flex; align-items:center; gap:8px; }
.identity-lv    { font-family:'ShareTechMono'; font-size:13px; color:#9494B8; }
.identity-sep   { width:1px; height:11px; background:rgba(255,215,0,.4); }
.identity-title { font-family:'PressStart2P'; font-size:9px; color:#FFD700;
                  letter-spacing:.5px; text-shadow:0 0 10px rgba(255,215,0,.35); }
```

- **Name** — PressStart2P, soft white `#E8E8FF`, faint glow.
- **LV** — ShareTechMono, muted `#9494B8`. **Title** — PressStart2P, gold `#FFD700`,
  separated by a thin gold rule.
- Quiet by design — it must not compete with BIT.

## Resource HUD (topbar, screen-pinned)

```html
<div class="topbar">
  <span class="topbar-name">Ironbit</span>
  <div class="topbar-resources">
    <div class="res res-lck"><div class="res-icon-diamond"></div><span class="res-val">2.0x</span></div>
    <div class="res res-gems"><div class="res-icon-mask"></div><span class="res-val">0</span></div>
    <div class="res res-vit"><div class="res-icon-mask"></div><span class="res-val">72</span></div>
  </div>
</div>
```

Three resources, each an **icon + value**:

| res | icon | token color | meaning |
|---|---|---|---|
| **LCK** | diamond (CSS) | gold `#FFD700` | luck / multiplier (e.g. `2.0x`) |
| **Gems** | `assets/icon_coin.png` mask | mint `#00E5A0` | Quests convert effort → Gems |
| **VIT** | drop mask | (vit color) | recharges between sessions — the calm energy meter |

Icons are PNG **masks** tinted by the token color:
```css
.res-gems .res-icon-mask { background-color:#00E5A0;
  -webkit-mask-image:url(assets/icon_coin.png); mask-image:url(assets/icon_coin.png); }
```

## Rules

- The HUD is **glanceable**, not a dashboard — three values, no charts (GUARDRAILS #12: no
  data slop).
- **VIT is anti-guilt:** it *recharges* between sessions — frame it as natural recovery,
  never "depleted, you failed". No red, no warnings.
- Values come from game state; keep them terse (ShareTechMono).

## Native notes

Identity = a `Column` of `Text` (the two display fonts). HUD = a `Row` of icon+value
chips; icons via `ColorFiltered`/`ImageIcon` from the packed sprites. Topbar pinned to the
screen (not scrolling with the room).
