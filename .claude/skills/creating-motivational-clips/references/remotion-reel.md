# Remotion reel — setup, composition, render, verify

Local headless render (no dev server). Vertical 1080×1920, 30fps.

## Setup
```bash
mkdir -p reel/remotion/src reel/remotion/public/clips reel/remotion/out && cd reel/remotion
npm init -y
npm install remotion @remotion/cli @remotion/google-fonts react@18 react-dom@18 --no-audit --no-fund
npm install -D typescript @types/react
# put the final audio at public/final_mix.wav and the used clips at public/clips/*.mp4
```
`src/index.ts`: `import {registerRoot} from 'remotion'; import {RemotionRoot} from './Root'; registerRoot(RemotionRoot);`
`src/Root.tsx`: a `<Composition id="Reel" component={Reel} durationInFrames={DURATION_IN_FRAMES} fps={FPS} width={1080} height={1920} />`.

## src/Reel.tsx (the proven template)
Cuts on VO beats via overlapping `<Sequence>`s (crossfade), per-clip **brightness** to balance
exposure, dark grade + vignette, slow push-in, global fade from/to black, Bebas Neue captions with a
**subtle shadow (not a neon bloom)**, and one pre-mixed audio track. Retune frame windows to YOUR VO.

```tsx
import {AbsoluteFill, Audio, OffthreadVideo, Sequence, interpolate, staticFile, useCurrentFrame} from 'remotion';
import {loadFont} from '@remotion/google-fonts/BebasNeue';
const {fontFamily: BEBAS} = loadFont();

export const FPS = 30;
export const DURATION_IN_FRAMES = 369; // = ceil(audio_seconds * fps)

type ClipDef = {src: string; start: number; end: number; fin: number; fout: number; bright?: number};
const CLIPS: ClipDef[] = [ // windows overlap ~6f so adjacent clips cross-dissolve; cuts land on VO beats
  {src: 'clips/c1.mp4', start: 0,   end: 80,  fin: 15, fout: 8, bright: 1.08},
  {src: 'clips/c2.mp4', start: 74,  end: 184, fin: 8,  fout: 8, bright: 1.05},
  {src: 'clips/c3.mp4', start: 178, end: 246, fin: 8,  fout: 8, bright: 1.0},
  {src: 'clips/c4.mp4', start: 240, end: 286, fin: 8,  fout: 8, bright: 1.0},
  {src: 'clips/c5.mp4', start: 280, end: 336, fin: 8,  fout: 8, bright: 1.45}, // dim clip -> lift
  {src: 'clips/c6.mp4', start: 330, end: 369, fin: 8,  fout: 20, bright: 0.82}, // hazy -> tame
];

const Clip: React.FC<{def: ClipDef}> = ({def}) => {
  const f = useCurrentFrame(); const dur = def.end - def.start;
  const opacity = interpolate(f, [0, def.fin], [0, 1], {extrapolateRight: 'clamp'}) *
                  interpolate(f, [dur - def.fout, dur], [1, 0], {extrapolateLeft: 'clamp'});
  const scale = interpolate(f, [0, dur], [1.06, 1.14]);
  return (<AbsoluteFill style={{opacity}}>
    <OffthreadVideo src={staticFile(def.src)} muted style={{width:'100%',height:'100%',objectFit:'cover',
      transform:`scale(${scale})`, filter:`contrast(1.06) saturate(0.9) brightness(${def.bright ?? 1})`}} />
  </AbsoluteFill>);
};

type CapDef = {text: string; start: number; end: number; big?: boolean};
const CAPTIONS: CapDef[] = [ /* one per VO line, \n = manual break; last one big:true */ ];
const SHADOW = '0 4px 16px rgba(0,0,0,0.6), 0 0 10px rgba(255,255,255,0.20), 0 0 26px rgba(150,200,255,0.14)';
const Caption: React.FC<{def: CapDef}> = ({def}) => {
  const f = useCurrentFrame(); const dur = def.end - def.start;
  const opacity = interpolate(f, [0, 6], [0, 1], {extrapolateRight:'clamp'}) *
                  interpolate(f, [dur-6, dur], [1, 0], {extrapolateLeft:'clamp'});
  const scale = def.big ? interpolate(f,[0,6,12],[0.7,1.08,1.0],{extrapolateRight:'clamp'})
                        : interpolate(f,[0,6],[0.96,1.0],{extrapolateRight:'clamp'});
  return (<AbsoluteFill style={{justifyContent:'center',alignItems:'center',padding:'0 80px'}}>
    <div style={{opacity, transform:`scale(${scale})`, color:'#fff', fontFamily:BEBAS, fontWeight:400,
      fontSize: def.big?180:76, lineHeight:1.0, letterSpacing: def.big?8:4, textAlign:'center',
      textTransform:'uppercase', whiteSpace:'pre-line', WebkitTextStroke:'1px rgba(0,0,0,0.28)', textShadow:SHADOW}}>
      {def.text}</div></AbsoluteFill>);
};

const Grade: React.FC = () => (<AbsoluteFill style={{pointerEvents:'none',
  background:'radial-gradient(ellipse at center, rgba(0,0,0,0) 50%, rgba(0,0,0,0.42) 100%)'}} />);

export const Reel: React.FC = () => (
  <AbsoluteFill style={{backgroundColor:'black'}}>
    {CLIPS.map((d,i)=>(<Sequence key={i} from={d.start} durationInFrames={d.end-d.start}><Clip def={d}/></Sequence>))}
    <Grade />
    {CAPTIONS.map((d,i)=>(<Sequence key={`c${i}`} from={d.start} durationInFrames={d.end-d.start}><Caption def={d}/></Sequence>))}
    <Audio src={staticFile('final_mix.wav')} />
  </AbsoluteFill>
);
```

## Render + verify
```bash
npx remotion render src/index.ts Reel out/reel.mp4
# verify streams
ffprobe -v error -show_entries format=duration:stream=codec_type,codec_name,width,height -of default=noprint_wrappers=1 out/reel.mp4
# eyeball grade + captions: extract frames, tile, then Read the png
for t in 0.9 3.5 7.2 10.3 11.95; do ffmpeg -y -ss $t -i out/reel.mp4 -frames:v 1 "f_$t.png"; done
ffmpeg -y -i f_0.9.png -i f_3.5.png -i f_7.2.png -i f_10.3.png -i f_11.95.png \
 -filter_complex "[0]scale=216:384[a];[1]scale=216:384[b];[2]scale=216:384[c];[3]scale=216:384[d];[4]scale=216:384[e];[a][b][c][d][e]hstack=inputs=5" contact.png
```
Read `contact.png` and fix per-clip `bright` where a shot is crushed/washed, then re-render.
This ffmpeg build lacks glob — pass frame inputs explicitly (no `*.png`).
