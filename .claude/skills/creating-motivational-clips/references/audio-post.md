# Audio post (ffmpeg) — VO treatment, SFX, master mix

All commands assume a working dir with `vo_final.wav` (stitched VO) and `music_bed.mp3` (or a
user-supplied track). Everything below is synthesized or user-owned — no licensing exposure.

## 0. VO from Higgsfield segments → stitched VO with a ramp
Generate one segment per line with `seed_audio`, rising `speech_rate` and `loudness_rate` (e.g.
line1 `-8`, mid `0`, hard `+14`, final snap `+18`), `pitch_rate: -2` throughout. Download each
`results.rawUrl`. Then stitch with **decreasing** silence gaps (tension early → acceleration late)
and a synthesized inhale before the final word:

```bash
SR=44100
for i in 1 2 3 4; do ffmpeg -y -i seg$i.mp3 -ar $SR -ac 1 -c:a pcm_s16le s$i.wav; done
for g in "g1 0.50" "g2 0.40" "g3a 0.18" "g3b 0.12"; do set -- $g; \
  ffmpeg -y -f lavfi -i anullsrc=r=$SR:cl=mono -t $2 -c:a pcm_s16le $1.wav; done
# synthesized inhale (brown noise, band-passed, rising-then-cut envelope)
ffmpeg -y -f lavfi -i anoisesrc=color=brown:r=$SR:d=0.50 \
 -af "highpass=f=280,lowpass=f=1700,afade=t=in:st=0:d=0.34,afade=t=out:st=0.36:d=0.14,volume=0.32" \
 -ac 1 -c:a pcm_s16le breath.wav
printf "file 's1.wav'\nfile 'g1.wav'\nfile 's2.wav'\nfile 'g2.wav'\nfile 's3.wav'\nfile 'g3a.wav'\nfile 'breath.wav'\nfile 'g3b.wav'\nfile 's4.wav'\n" > list.txt
ffmpeg -y -f concat -safe 0 -i list.txt -ar $SR -ac 1 vo_raw.wav
DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 vo_raw.wav)
ffmpeg -y -i vo_raw.wav -af "loudnorm=I=-15:TP=-1.5,afade=t=in:d=0.12,afade=t=out:st=$(awk "BEGIN{print $DUR-0.35}"):d=0.35" vo_final.wav
```

## 1. VO treatment — stop it "yelling", make it blend
De-harsh (dip ~3 kHz shout, roll off highs), warmth, gentle comp, and **room reverb** (`aecho`):

```bash
ffmpeg -y -i vo_final.wav -af \
"highpass=f=85,equalizer=f=180:t=q:w=1.0:g=2,equalizer=f=3000:t=q:w=1.4:g=-4.5,lowpass=f=8600,\
acompressor=threshold=-18dB:ratio=3:attack=15:release=220,\
aecho=0.8:0.88:55|120|190:0.30|0.20|0.12,volume=1.4,alimiter=limit=0.95" \
-ar 44100 -ac 2 vo_wet.wav
```

## 2. SFX — synthesized, royalty-free
```bash
# intro boom (40+80 Hz)
ffmpeg -y -f lavfi -i "sine=f=40:d=1.4" -f lavfi -i "sine=f=80:d=1.4" -filter_complex \
"[0]volume=1[a];[1]volume=0.5[b];[a][b]amix=inputs=2:normalize=0,afade=t=in:d=0.02,afade=t=out:st=0.25:d=1.1,lowpass=f=200,volume=1.6[o]" -map "[o]" -ar 44100 -ac 2 sfx_boom_intro.wav
# hit on the final word (44 Hz + click)
ffmpeg -y -f lavfi -i "sine=f=44:d=0.8" -f lavfi -i "anoisesrc=color=white:d=0.06" -filter_complex \
"[0]afade=t=out:st=0.1:d=0.65,volume=1.8[a];[1]highpass=f=1500,volume=0.5[c];[a][c]amix=inputs=2:normalize=0,lowpass=f=3200[o]" -map "[o]" -ar 44100 -ac 2 sfx_boom_hit.wav
# whoosh (transitions)
ffmpeg -y -f lavfi -i "anoisesrc=color=white:d=0.6" -af "bandpass=f=1800:width_type=h:w=2500,afade=t=in:d=0.3,afade=t=out:st=0.3:d=0.28,volume=1.4" -ar 44100 -ac 2 sfx_whoosh.wav
# riser (into the climax)
ffmpeg -y -f lavfi -i "anoisesrc=color=white:d=3" -af "highpass=f=800,volume='0.05+0.5*min(1\,t/3)':eval=frame,afade=t=out:st=2.8:d=0.2" -ar 44100 -ac 2 sfx_riser.wav
```

## 3. Master mix — duck music under VO, place SFX on beats, master
`sidechaincompress` ducks the music whenever the VO speaks. Place SFX with `adelay` (ms). `[0]` is the
music (real track normalized to ~-18 LUFS, or the synth bed):

```bash
ffmpeg -y -i music.wav -i vo_wet.wav -i sfx_boom_intro.wav -i sfx_whoosh.wav -i sfx_riser.wav -i sfx_boom_hit.wav \
 -filter_complex "\
[0:a]atrim=0:12.3,asetpts=PTS-STARTPTS,volume=1.0[m0];\
[1:a]asplit=2[vo][key];\
[m0][key]sidechaincompress=threshold=0.06:ratio=6:attack=20:release=350[mduck];\
[2:a]adelay=0|0,volume=0.7[bo];\
[3:a]asplit=3[wa][wb][wc];\
[wa]adelay=2100|2100,volume=0.30[w1];[wb]adelay=5900|5900,volume=0.34[w2];[wc]adelay=9400|9400,volume=0.38[w3];\
[4:a]adelay=9000|9000,volume=0.26[ris];\
[5:a]adelay=11800|11800,volume=0.7[bh];\
[mduck][vo][bo][w1][w2][w3][ris][bh]amix=inputs=8:normalize=0[mx];\
[mx]afade=t=in:st=0:d=0.25,afade=t=out:st=11.65:d=0.6,alimiter=limit=0.95,loudnorm=I=-14:TP=-1.2[out]" \
 -map "[out]" -t 12.3 -ar 44100 -ac 2 final_mix.wav
```

**User-supplied music:** slice a section and normalize to a predictable bed level, then feed as `[0]`:
```bash
DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "track.mp3")
START=$(awk "BEGIN{s=$DUR/2-6.5; if(s<0)s=0; print s}")   # middle section
ffmpeg -y -ss "$START" -t 13 -i "track.mp3" -af "loudnorm=I=-18:TP=-2,afade=t=in:d=0.3" -ar 44100 -ac 2 music.wav
```

Tune adelay times and gap durations to YOUR VO's actual beat timings (read them from each segment's
`durationSec` / `ffprobe`).
