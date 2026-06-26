// build_flat_masks.mjs
// Converts the colored region extractions in  source/{front,back}/*.png
// into FLAT, UNCOLORED white-alpha masks in  masks/{front,back}/*.png
//
// The source PNGs are the registered glow extractions from the prototype
// (teal + bloom baked in). This strips all color and the bloom tail, leaving
// a clean white silhouette whose ALPHA = the muscle's lit shape. In the app
// you tint this with kNeon, set its opacity to the ramp value, and add the
// glow in code (see README "Compositing model" + "Ramp").
//
// Run:  npm i sharp   &&   node build_flat_masks.mjs
//
// Remap (identical to the prototype):  aOut = clamp((aIn - FLOOR) / SPAN, 0, 1)
//   FLOOR drops the faint outer bloom; SPAN solidifies the core.
//   Tune FLOOR up for tighter shapes, down for softer/larger.

import sharp from 'sharp';
import { readdir, mkdir } from 'node:fs/promises';

const FLOOR = 0.35;
const SPAN  = 0.50;

async function convert(inPath, outPath) {
  const img = sharp(inPath).ensureAlpha();
  const { width, height } = await img.metadata();
  const buf = await img.raw().toBuffer(); // RGBA, 8-bit
  for (let i = 0; i < buf.length; i += 4) {
    let a = buf[i + 3] / 255;
    a = (a - FLOOR) / SPAN;
    a = a < 0 ? 0 : a > 1 ? 1 : a;
    buf[i] = 255; buf[i + 1] = 255; buf[i + 2] = 255; // white
    buf[i + 3] = Math.round(a * 255);                 // shape = alpha
  }
  await sharp(buf, { raw: { width, height, channels: 4 } }).png().toFile(outPath);
  console.log('mask:', outPath);
}

for (const side of ['front', 'back']) {
  await mkdir(`masks/${side}`, { recursive: true });
  for (const f of await readdir(`source/${side}`)) {
    if (f.endsWith('.png')) await convert(`source/${side}/${f}`, `masks/${side}/${f}`);
  }
}
console.log('done — flat masks written to masks/front and masks/back');
