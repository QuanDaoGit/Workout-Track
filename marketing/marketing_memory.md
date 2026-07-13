# marketing_memory.md — Ironbit social (READ FIRST)

> **Purpose:** the living brief for Ironbit's marketing presence. Any marketing session should read
> this before acting. It carries the account facts, voice guardrails, content system, asset
> inventory, and a running log of what's been posted so we never repeat or contradict ourselves.
> Companion to [CLAUDE.md](CLAUDE.md) (operating brief) and [positioning.md](positioning.md) (value prop).
>
> **Status:** pre-launch, active Android beta (Firebase App Distribution). Building the launch story.
> **Last updated:** 2026-07-10.

---

## The account (Instagram)

| Field | Value |
|-------|-------|
| Handle | **@the_ironbit** (IG); Facebook Page "Ironbit" linked for scheduling |
| Market / language | **Global English** |
| Link in bio | https://ironbitbeta.netlify.app (waitlist / early-access landing) |
| Founder voice | **Erik** — first-person for devlog / build-in-public |
| Profile pic | **BIT drone core**, zoomed + tilted portrait (eye-dominant for the circle crop) — `assets/instagram/identity/pfp-bit.png` 640×640. Alts on file: `pfp-logo.png`, `pfp-bit-v1-original.png`; option sheet: `pfp-options.png`. |
| Platform / CTA | **iOS-forward, waitlist CTA** (chosen 2026-07-10). Public framing: *"coming to iOS"* + join the waitlist. Never link a store — see guardrails. |
| Posting | **Manual / free Meta Business Suite scheduling.** No API automation (chosen 2026-07-10 — marginal at 3–4 posts/wk). All content delivered finished; human presses publish. |

**Bio (fits IG's 150-char limit):**
```
⚔️ Every rep builds a real RPG character.
📱 Coming to iOS · offline · no account · free
👇 Join the waitlist
```

**Highlight covers:** BIT · CLASSES · RANK UP · FEATURES · DEVLOG (arcade palette).

---

## Voice & non-negotiable guardrails

Tone: **arcade, earned-progression, a little playful, never hype-y or body-shaming.** Match the product.

**Hard claim rules (violating these is a launch-credibility risk):**
- ❌ **Never** say "no tracking" or "data never leaves your device." The app ships **anonymous,
  opt-out Firebase analytics + opt-in Sentry crash reporting** (ADR 0001). The true, safe framing:
  *"offline-first · no account · your training data stays on your device; anonymous usage analytics
  are opt-out."*
- ❌ No weight-loss promises, before/after, or body-shaming — the product is **body-neutral**. No
  red/green good-bad framing.
- ❌ Don't claim **social, AI coaching, or sync** features — out of scope, not in the product.
- ❌ **Never claim iOS is available or downloadable.** No iOS build, TestFlight, or App Store page
  exists yet. Public framing is **"coming to iOS" + a waitlist** only; the CTA links to the waitlist
  landing (`ironbitbeta.netlify.app`), **never a store badge**. *(Reality for future sessions: the
  live working build is the **Android** beta via Firebase App Distribution — iOS is roadmap. Per the
  founder's direction we don't feature Android publicly, but we must never imply iOS ships today.)*
- ✅ True to say: offline-first, no account, no ads, no IAP (free), RPG stats/levels/ranks/classes/
  quests/loot all earned from real logged training, pixel-arcade world, **coming to iOS (waitlist open)**.
- Privacy policy: https://quandaogit.github.io/ironbit-privacy/

---

## Content engine — BIT + gameplay (faceless, on-brand)

No AI-human "creators." The mascot **BIT** hosts; real gameplay is the proof. Five pillars:

1. **Payoff moments** — RANK UP, stat gains, level bar, loot reveals. The dopamine hits; scroll-stoppers.
2. **BIT the host** — the mascot is the account's face: reactions, one-liners, personality.
3. **Feature-in-30s** — one feature per reel (coverage body map, quests, classes, guild, strength dossier). Product proof.
4. **Pixel gym-RPG memes** — carousels/stills on lifting-as-leveling, anti-shame humor. Cheap, shareable, top-of-funnel.
5. **Build-in-public devlog** — Erik, first person: "making a fitness RPG solo." The indie-game×fitness crossover that earns early follows.

**Cadence (pre-launch):** 3–4 posts/week. Reels > carousels > stills for reach. 1 light story/day optional.

---

## Asset inventory (already in `marketing/`)

| Asset | Path | Use |
|-------|------|-----|
| Promo master (1080×1920) | `assets/promo-videos/ironbit-promo-v3.mp4` | hero reel source |
| Animated end card (5s) | `assets/promo-videos/ironbit-end-card-animated.mp4` | reel outro |
| End card still (1080×1920) | `assets/promo-videos/ironbit-end-card-1080x1920.png` | carousel end slide |
| AI hook shot (3s) | `assets/promo-videos/ironbit-hook-shot.mp4` | opener beat (near-black 1st frame — trim) |
| Class art | `assets/landing/class_{assassin,bruiser,tank}.png` | classes carousel |
| Class sigils | `landing/img/sigil_{assassin,bruiser,tank}.png` | classes carousel |
| BIT sprites | `landing/img/bit_{neutral,cheer,alert,rest}.png` | BIT host / pfp |
| App wordmark/logo | `assets/landing/app_logo.png`, `landing/img/logo.png` | branding |
| Screenshots | `landing/img/{home,stats,profile,summary,quests}.webp` | feature posts |
| Recut EDL | `campaigns/2026-07-08-promo-recut-edl.md` | hero reel plan |

---

## Higgsfield (AI video/image)

- Plan: Plus. **Balance: ~504 credits** (as of 2026-07-10; 12 spent so far). **Budget: existing credits only.**
- Model: `kling3_0_turbo`. Output: 720×1280 (upscale for full-res holds).
- **Discipline:** always run `get_cost: true` preflight before generating; log spend below.

---

## Meta Ads (paid) — connector live

- **Meta Ads MCP connector** (`https://mcp.facebook.com/ads`) is connected to Claude Code (2026-07-10).
  Lets the agent read/analyze + build campaigns; **every action needs the user's approval, and nothing
  spends without a payment method.**
- **Ad account `794963308279471`** — ACTIVE, currency **VND**, min ≈ **26,481 VND/day (~$1)**,
  **no payment method yet** (safety gate). Page **Ironbit** `1143418815530416` + IG **@the_ironbit** linked.
  0 campaigns (clean slate). The list-IG-accounts tool is still gated ("gradually rolling out").
- **Stance:** don't run install ads pre-iOS. A **waitlist-traffic test** *is* a valid pre-launch spend.
  Full parked plan → [ads/2026-07-10-launch-campaign-plan.md](ads/2026-07-10-launch-campaign-plan.md).
- **Competitive intel** → [ads/2026-07-10-competitive-research.md](ads/2026-07-10-competitive-research.md):
  the fitness-RPG ad niche is nearly empty; one direct competitor (**Fitness Empire Online**, same
  pre-launch stage, hooks "level up / choose your class / earn XP / join waitlist", realistic-fantasy art).
  **Pixel-arcade positioning is uncontested — lean into it.**

## Produced kit (`assets/instagram/`)

| Post | Format | Files |
|------|--------|-------|
| Identity | pfp + covers | `identity/pfp-bit.png` (chosen), `identity/pfp-logo.png` (alt), `identity/highlight-covers/{bit,class,rank,info,dev}.png`, `identity/fb-cover.png` (Facebook Page cover, 851×315 @2×) |
| 1 · This is Ironbit (pinned) | carousel ×4 | `posts/01-intro/slide-1…4.png` |
| 2 · Hero reel | reel 1080×1920 18.7s | `posts/02-hero-reel/ironbit-hero-reel.mp4` |
| 3 · Which build are you? | carousel ×4 | `posts/03-classes/slide-1…4.png` |
| 4 · Every rep has a receipt | still | `posts/04-meme/meme.png` |
| 5 · A home, not a log | still | `posts/05-home/home-feature.png` |

All stills 1080×1350 (4:5), token-accurate, real fonts, real app screens where shown. Captions +
hashtags + schedule live in [campaigns/2026-07-10-instagram-launch-kit.md](campaigns/2026-07-10-instagram-launch-kit.md).

## Posting log

**Batch 1 scheduled 2026-07-11 via Meta Business Suite → FB Page "Ironbit" + IG @the_ironbit.**

| Date (ICT) | Post | Format | Status |
|------|------|--------|--------|
| Jul 11 | 1 · pinned intro | carousel | scheduled ✓ (pin after it posts) |
| Jul 14, 9pm | 2 · hero reel | reel | scheduled ✓ |
| Jul 16, 9pm | 3 · classes | carousel | scheduled ✓ |
| Jul 19, 9pm | 4 · meme | still | scheduled ✓ |
| Jul 22, 9pm | 5 · home | still | scheduled ✓ |

Next: review reach/saves after batch runs (~Jul 23) → plan batch 2.

---

## Open items / next actions

- [ ] Confirm @ironbit.app handle availability at account setup.
- [x] Profile identity — pfp (BIT core) + 5 highlight covers.
- [x] 2-week posting calendar (in launch-kit brief).
- [x] All 5 posts produced (see Produced kit above).
- [ ] **User:** create @ironbit.app, set pfp/bio/covers, schedule the batch (Business Suite).
- [ ] Capture a clean muscle-coverage body-map screenshot → enables the "every muscle lights up" post.
- [ ] Batch 2 (weeks 3–4) once week-1 reach data exists.
- [ ] Swap waitlist CTA → real App Store badge once the iOS TestFlight/listing is live.
