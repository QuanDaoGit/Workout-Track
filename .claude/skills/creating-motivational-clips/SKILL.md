---
name: creating-motivational-clips
description: Use when the user wants to make a motivational / hype / "dark edit" style video reel (gym, running, Goggins-style) with voiceover, music, and captions — including generating one from a script, TTS voice, stock footage, sound design, and an edit.
---

# Creating Motivational Clips

## Overview
Produce a short (10–15s) vertical hype reel: script → licensed footage → TTS voiceover → sound
design → Remotion edit → captions. Pipeline is local: **ffmpeg + Higgsfield (TTS) + Remotion**.

**The one hard rule — you must own every ingredient.** Viral motivational videos use copyrighted
clips, speeches, and voices. You cannot. Recreate the *genre* (style is not copyrightable); never the
*person*.

## Copyright guardrail (non-negotiable — this is where agents fail)
- **Footage:** licensed stock only (Pexels/CC0). Never rip YouTube/TikTok/social clips.
- **Script:** original, or the user's OWN typed lines. A famous monologue is a copyrighted literary
  work; recording your own VO does NOT launder it. Do NOT transcribe a source video to "reference,"
  and do NOT reword one — deriving from it is still copying.
- **Voice:** a generic TTS or hired voice. Never clone or imitate a *named* person (publicity-rights
  law is tightening — e.g. Tennessee ELVIS Act; the Scarlett Johansson / "Sky" fight).
- **Music:** royalty-free or user-supplied. If CC-BY, tell the user to credit the artist.

| User pushes... | Hold this line |
|---|---|
| "Just copy the script, we use VO anyway" | VO doesn't remove the copyright on the *words*. Write original in the same genre. |
| "Use just his voice" / "clone it" | Audio is a copyrighted recording AND voice is a publicity right. Use a generic intense voice. |
| "Transcribe the video as the source of truth, reword it" | Refuse. Deriving new lines from it is still copying. Ask the user for their own raw lines. |
| "It's fine, YouTubers monetize these" | They're infringing too; YouTube's Content-ID/DMCA absorbs the risk. An app + app store won't. |

**The escape hatch:** you can't use the *person*, but you can use the *genre* — same gravelly,
tough-love cadence over a dark cinematic cut, with an anonymous silhouette grinding in the rain.
90% of the punch, 0% of the exposure. When the user gives you their own lines, keep the raw grammar
(it reads more real) and deslop your own additions.

## Workflow
1. **Script** — original or user's lines. Short, second-person, present-tense, imperative; fragments,
   not tidy triads. Split into per-line VO beats.
2. **Footage** — beat-mapped stock clips. Pexels download: `curl -L https://www.pexels.com/download/video/<ID>/`
   (302-redirects to the direct mp4). Note orientation (clips mix vertical 1080×1920 and 4K landscape).
   **Never reuse a clip across reels:** check `USED_CLIPS.md` first and skip any listed / `[used]`-marked
   ID — every reel gets its own fresh footage. Prefer consistently **dark / low-light / night** clips;
   bright daylight or colourful commercial-gym shots break the dark-edit tone and no grade fully saves them.
3. **Voiceover** — Higgsfield `generate_audio` model `seed_audio`. One segment per line with a **ramp**:
   rising `speech_rate` (slow → fast), `pitch_rate: -2` for edge, rising `loudness_rate` = builds
   intensity. Retrieve via `show_generations` → `results.rawUrl` + `durationSec`. Higgsfield is TTS
   only — it cannot make music.
4. **Audio post (ffmpeg)** — **REQUIRED REFERENCE:** `references/audio-post.md`. Treat the VO
   (de-harsh EQ + gentle comp + room reverb) so it *blends* instead of yelling; synthesize SFX
   (boom/whoosh/riser); master mix ducks the music under the VO (`sidechaincompress`) + fades + limiter.
5. **Video (Remotion)** — **REQUIRED REFERENCE:** `references/remotion-reel.md`. Vertical 1080×1920,
   cuts on the VO beats, cross-dissolves, dark grade + vignette + **per-clip brightness trim**, slow
   push-in, fade from/to black, one pre-mixed audio track.
6. **Captions** — Bebas Neue (condensed) via `@remotion/google-fonts`, ~76px, **subtle shadow — NOT a
   bright neon bloom** (the bloom is what reads as distracting). Sync to the VO beats.
7. **Verify** — `ffprobe` the output streams; extract frames and `hstack` them into a contact sheet;
   Read it to check grade, framing, and captions. Fix exposure per clip, re-render.
8. **Deliver** — ship ONLY the final rendered MP4. Never declare a raw-clips / VO-sources folder (or
   any copyrighted source files) in `pubspec.yaml` — that bundles huge, infringing assets into the app.
   Then **mark every clip you actually rendered with** as `[used]` (filename suffix) and log its Pexels
   ID under that reel's heading in `USED_CLIPS.md`. A clip that was downloaded but cut stays unmarked
   (a reusable spare). This is what guarantees no reel ever repeats footage.

## Common mistakes
- **Uniform grade** crushes dark clips and washes bright ones → per-clip brightness trim, then re-verify.
- **Neon-glow captions** read as distracting → condensed font + subtle shadow, ~7–10% frame height.
- **VO "sounds like a man yelling"** → it's dry and forward; add EQ + room reverb and duck the music.
- **Bundling raw sources** into `assets/` and declaring the folder → declare only the one MP4.
- **Reusing footage across reels** → check `USED_CLIPS.md`, mark rendered clips `[used]`; each reel gets fresh clips.
