# marketing/ — Agent operating brief

You are working in the **marketing** workspace for Ironbit (an RPG-gamified, offline-first
workout tracker). Nothing here ships in the app; this is go-to-market material.

## Purpose
Produce and store positioning, messaging, store/ASO copy, ad copy, and campaign plans.
Pre-launch: the job is to build the launch story, not run live campaigns (no data yet).

## What lives here
- `positioning.md` — value prop, target user, key messages, differentiation. The source the rest pulls from.
- `copy/` — reusable copy: taglines, app-store description, ad headlines, social posts.
- `campaigns/` — per-campaign briefs (objective, audience, channels, calendar).
- `assets/` — exported images/banners for marketing (not app assets — those stay in `assets/`).

## Voice & truth
- **Tone:** matches the product — arcade, earned-progression, a little playful, never hype-y or
  body-shaming. The product is **body-neutral** (see [PRODUCT.md](../docs/PRODUCT.md)); marketing
  must be too. No "burn fat fast", no before/after shaming, no weight-loss promises.
- **The hook:** every logged workout makes your character harder to abandon. Lean on identity,
  rank, loot, ritual return, and the fact that the fantasy is fed by real training.
- **Claims:** only claim what the app does. It is offline, no-account, no-tracking, no IAP — these
  are genuine selling points; use them. Don't claim social, AI coaching, or sync (out of scope).

## Common tasks & how to do them well
- *Write store listing* → pull facts from [PRD.md](../docs/PRD.md); keep to Play Store limits;
  produce title (≤30 chars), short desc (≤80), long desc. Save under `copy/`.
- *Draft a campaign* → one file in `campaigns/`, dated, with objective + audience + channels + metrics.
- *Taglines* → keep a running list in `copy/taglines.md` with the chosen one marked.

## Do NOT
- Invent product capabilities to make copy punchier — verify against the PRD.
- Use red/green good-bad or weight-shame framing (violates the body-neutral mandate).
- Put marketing image exports into the app's `assets/` tree.
