# Ironbit promo re-cut — Edit Decision List (2026-07-08)

**Objective:** turn the existing 46s feature-tour screen recording into an 18s social cut
(Reels / TikTok / Shorts) with a payoff-first hook, on-mute captions, and a real CTA.
**Source:** `campaigns/snapsave.vn_facebook_6a4e159c5aa1b.mp4` (592×1280, 46.4s, music + SFX, no VO).
**Audience:** lifters/beginners scrolling social; assume muted autoplay, ~2s decision window.
**Zero-cost pass:** every shot below except the end card comes from the existing footage.

---

## Timeline (18s target)

| # | Target | Source (in–out) | Content | Caption overlay |
|---|--------|-----------------|---------|-----------------|
| 1 | 0:00–0:02.5 | **0:23–0:25.5** | RANK UP screen — "STR C → B" pulse + stat gains rolling (STR +99 / AGI +73 / END +18). Open mid-fanfare, no logo. | **"Your workout just leveled you up."** |
| 2 | 0:02.5–0:05 | **0:05–0:07.5** | Select Workout — Chest chip tap → both body silhouettes light up green. | **"Pick your targets."** |
| 3 | 0:05–0:08 | **0:15–0:18** | Bench-press pixel animation (muscle outlines flashing) → hard cut to set logged / check-circle fill + "Rest timer started". | **"Log real lifts."** |
| 4 | 0:08–0:11 | **0:21–0:24** | SESSION COMPLETE medal → +160 XP tally → yellow level bar filling into the RANK UP flash (cut before the full screen repeats shot 1). | **"Earn XP. Rank up. Collect loot."** |
| 5 | 0:11–0:14 | **0:40–0:43** | Inferno Frame (fire) → Void Frame (nebula) previews on the avatar. Keep the source bass-drop. | **"Deck out your character."** |
| 6 | 0:14–0:18 | **end card (new)** | Static end card, 4s hold (spec below). | Card carries its own text. |

**Total source used:** ~14s of the original 46s. Everything menu/keypad-heavy
(source 0:03–0:05, 0:08–0:15 keypad, 0:26–0:39 dashboard/expedition/guild) is dropped — it's
store-listing material, not ad material.

## Cut notes

- **Shot 1 is the hook — start mid-animation.** Do not start at the screen's first frame
  (it reads as a settled menu). Enter as the yellow "RANK UP" text pulses.
- **Shot 4 → 5 transition:** cut on the source bass-drop at ~0:41; it lands as a beat-synced reveal.
- **Trim all transition fades.** Source has near-black dissolve frames (~0:26, ~0:39); use hard
  cuts throughout — arcade language, and no dead air in 18s.
- **Audio:** keep the source lo-fi synth + SFX bed (the level-up fanfare, dings, bass drop are
  assets). Duck music −6 dB under the end card's final note.
- **Loop-friendly:** the end card's last 0.5s should settle to near-black so the loop back into
  the RANK UP flash of shot 1 reads as intentional.

## End card spec (the one new asset)

- Background: `kBg` #11111F with subtle scanline/glitch texture (match app's CRT look).
- Center: **IRONBIT** logotype in the neon green #00FF9C, PressStart2P (or the existing logo mark).
- Line 2 (Gotham/body font, #E8E8FF): **"Train. Level up. Keep every gain."**
- Line 3 (muted #9494B8, smaller): **"Offline. No account. No ads in your face."** ← verify the
  final claim wording against PRD before shipping; do NOT say "no tracking".
- Bottom: Google Play badge (only once the listing is live; until then "Coming to Google Play").

## Caption/overlay style rules

- Font: PressStart2P for the 1–3 word punch lines, sentence case Gotham for longer lines.
- Color: #E8E8FF on a 40% #11111F backing bar; accent words in #00FF9C. Never red/green
  good-bad framing; never body-transformation language (body-neutral mandate).
- Timing: caption enters 100–150ms after its cut (motion first, words second), exits with the cut.
- Safe area: keep captions in the middle 80% vertically (platform UI covers top/bottom).

## Copy bank (approved-tone alternates)

Hook: "Your workout just leveled you up." / "This set = +99 STR." / "Finish a set. Watch your stats move."
CTA: "Train. Level up. Keep every gain." / "Real lifts feed the fantasy." / "Your character remembers every rep."
(Claims to avoid: weight-loss promises, "no tracking", AI coaching, social features.)

## Follow-ups (separate passes)

1. AI-generated hook/CTA motion shots via Higgsfield (Kling 3.0) to replace the static end card —
   cost-preflight first.
2. 30–45s store-listing version: keep the dropped usage scenes; this EDL's cut is social-only.
3. Re-export master at 1080×1920 if the project file exists — 592×1280 source is below Reels'
   preferred resolution; avoid double-compression by cutting from the original recording, not
   the snapsave re-download.
