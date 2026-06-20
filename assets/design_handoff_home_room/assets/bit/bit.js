/* ============================================================================
   BIT — Ironbit's machine companion · standalone animated engine
   ----------------------------------------------------------------------------
   Canonical source for the mascot. Painted cell-by-cell on a 44×44 canvas
   (32×32 sprite + margin). Core + four detached plates are drawn as separate
   grids so the plates animate (drift / spread / tuck). The glowing cyan
   screen-face carries the mood via eyes + screen-tint. Idle motion (hover-bob,
   plate breathe, blink, glow pulse) runs forever; every animation has a
   reduce-motion static fallback.

   No dependencies. Drop the file in and:

     <div id="bit" style="width:120px;height:120px"></div>
     <script src="bit.js"></script>
     <script>
       const bit = BIT.mount(document.getElementById('bit'), { mood: 'NEUTRAL' });
       bit.setMood('CHEER');   // NEUTRAL · CHEER · ALERT · REST
       bit.replay();           // re-play the "BIT online" power-on
     </script>

   mount(host, opts) options:
     px         render size in CSS px (default = host width, else 120)
     mood       'NEUTRAL' | 'CHEER' | 'ALERT' | 'REST'   (default NEUTRAL)
     static     true → freeze on a single pose (no idle loop)
     scanlines  CRT scanlines on the screen-face (default true)
     groundGlow soft cyan hover-glow beneath BIT (default true)
     plateBias  nudge plate spread; negative = tuck tighter (toast sizes)
   ============================================================================ */
(function (global) {
"use strict";

const NATIVE = 44;
const GX = 2, GY = 2;            // sprite origin inside the canvas

/* ---- metal palette (cool machined blue-grey, zero warmth) ---- */
const METAL = {
  k: "#0B0B14",   // outline / deepest shadow
  d: "#1E1E2E",   // dark underside
  q: "#0A0A12",   // screen recess (off)
  m: "#34344E",   // base metal
  M: "#2A2A40",   // right-side mid shade
  l: "#4B4B6E",   // left bevel light
  L: "#6E6E92",   // top highlight
  c: "#00BFFF",   // cyan accent
  C: "#5EE8FF",   // bright cyan accent dot
};

/* ---- auto 1px outline on transparent cells touching the form ---- */
function outlinePass(g) {
  const h = g.length, w = g[0].length;
  const out = g.map((r) => r.slice());
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (g[y][x] !== ".") continue;
    let adj = false;
    for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]]) {
      const nx = x+dx, ny = y+dy;
      if (nx>=0 && nx<w && ny>=0 && ny<h && g[ny][nx] !== "." && g[ny][nx] !== "k") { adj = true; break; }
    }
    if (adj) out[y][x] = "k";
  }
  return out;
}

/* ---- bevelled rounded-rect metal block, top-left lit ---- */
function bevelBlock(w, h, cut) {
  const inside = (x, y) =>
    x>=0 && x<w && y>=0 && y<h &&
    (x + y) >= cut &&
    ((w-1-x) + y) >= cut &&
    (x + (h-1-y)) >= cut &&
    ((w-1-x) + (h-1-y)) >= cut;
  const g = Array.from({length:h}, (_, y) => Array.from({length:w}, (_, x) => inside(x,y) ? "m" : "."));
  const isIn = (x,y) => x>=0 && x<w && y>=0 && y<h && g[y][x] !== ".";
  const shaded = g.map((r) => r.slice());
  for (let y=0; y<h; y++) for (let x=0; x<w; x++) {
    if (g[y][x] === ".") continue;
    const up=isIn(x,y-1), dn=isIn(x,y+1), lf=isIn(x-1,y), rt=isIn(x+1,y);
    if (!up) shaded[y][x] = "L";
    else if (!dn) shaded[y][x] = "d";
    else if (!lf) shaded[y][x] = "l";
    else if (!rt) shaded[y][x] = "M";
  }
  for (let y=1; y<h; y++) for (let x=0; x<w; x++) {
    if (shaded[y][x] === "m" && shaded[y-1][x] === "L") shaded[y][x] = "l";
  }
  return shaded;
}

function addDot(g, x, y) {
  if (y>=0 && y<g.length && x>=0 && x<g[0].length && g[y][x] !== ".") {
    g[y][x] = "C";
    if (g[y][x+1] && g[y][x+1] !== ".") g[y][x+1] = "c";
  }
}

/* ---- CORE: 16×16 rounded block with inset screen + left port ---- */
function buildCore() {
  const g = bevelBlock(16, 16, 3);
  for (let y=2; y<=13; y++) for (let x=2; x<=13; x++) {
    const ring = (x===2 || x===13 || y===2 || y===13);
    if (x>=3 && x<=12 && y>=3 && y<=12) g[y][x] = "q";
    else if (ring) g[y][x] = (x===2 || y===2) ? "d" : "k";
  }
  for (let y=5; y<=10; y++) { g[y][1] = "d"; }
  g[5][1] = "k"; g[10][1] = "k"; g[7][2] = "l";
  return outlinePass(g);
}
function buildTopPlate()    { const g = bevelBlock(18, 5, 3); addDot(g, 3, 3); addDot(g, 13, 3); return outlinePass(g); }
function buildBottomPlate() { const g = bevelBlock(18, 5, 3); addDot(g, 3, 1); addDot(g, 13, 1); return outlinePass(g); }
function buildLeftPlate()   { const g = bevelBlock(5, 14, 2); addDot(g, 2, 2); addDot(g, 2, 11); return outlinePass(g); }
function buildRightPlate()  { const g = bevelBlock(5, 14, 2); addDot(g, 1, 2); addDot(g, 1, 11); return outlinePass(g); }

const CORE = buildCore();
const CORE_X = 12, CORE_Y = 12;
const PLATES = [
  { key: "top",    grid: buildTopPlate(),    x: 11, y: 5,  dir: [0, -1] },
  { key: "bottom", grid: buildBottomPlate(), x: 11, y: 30, dir: [0,  1] },
  { key: "left",   grid: buildLeftPlate(),   x: 5,  y: 13, dir: [-1, 0] },
  { key: "right",  grid: buildRightPlate(),  x: 30, y: 13, dir: [1,  0] },
];

/* ---- orbit geometry: each plate's home vector from the core centre ----------
   Used both for resting layout AND for the press-to-spin orbit. At angle 0 the
   formula reproduces the normal spread layout exactly, so plates start/end home. */
const CORE_CX = CORE_X + 8, CORE_CY = CORE_Y + 8;   // core centre = (20, 20)
for (const p of PLATES) {
  p.hw = p.grid[0].length / 2;
  p.hh = p.grid.length / 2;
  p.nvx = (p.x + p.hw) - CORE_CX;   // home offset from core centre
  p.nvy = (p.y + p.hh) - CORE_CY;
}
const SPIN_MS = 950;   // one full revolution
function easeInOutCubic(t){ return t < 0.5 ? 4*t*t*t : 1 - Math.pow(-2*t+2, 3)/2; }

/* ============================================================================
   SCREEN MOODS — ramp (edge..centre) + glow colour + eyes/mouth cells
   ============================================================================ */
const RAMPS = {
  NEUTRAL: ["#0A5E72", "#11A6C4", "#39D6F0", "#7CF2FF"],
  CHEER:   ["#0C6E5E", "#16C49A", "#3CE8C0", "#9CFFE2"],
  ALERT:   ["#7A5600", "#C99800", "#F0C436", "#FFE680"],
  REST:    ["#063642", "#0A5666", "#11788C", "#2C9DB8"],
};
const GLOW   = { NEUTRAL: "#00BFFF", CHEER: "#00FFC8", ALERT: "#FFC400", REST: "#0E5E72" };
const EYECOL = { NEUTRAL: "#FFFFFF", CHEER: "#FFFFFF", ALERT: "#FFFCEF", REST: "#CFEFF7" };
const EYES = {
  NEUTRAL: [[3,3],[3,4],[6,3],[6,4]],
  CHEER:   [[2,2],[3,2],[2,3],[3,3],[6,2],[7,2],[6,3],[7,3]],
  ALERT:   [[2,4],[3,4],[6,4],[7,4]],
  REST:    [[2,5],[3,5],[6,5],[7,5]],
};
const BLINK_EYES = {
  NEUTRAL: [[3,4],[6,4]],
  CHEER:   [[2,3],[3,3],[6,3],[7,3]],
  ALERT:   [[2,4],[3,4],[6,4],[7,4]],
  REST:    [[2,5],[3,5],[6,5],[7,5]],
};
const MOUTH = {
  NEUTRAL: [[4,6],[5,6]],
  CHEER:   [[4,6],[5,6],[4,7],[5,7]],
  ALERT:   [[4,6],[5,6]],
  REST:    [],
};
const MOOD_SPREAD = { NEUTRAL: 0, CHEER: 4, ALERT: -1, REST: -1 };

/* ---- colour helpers ---- */
function hex2rgb(h){ return [parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)]; }
function lerpHex(a,b,t){ const A=hex2rgb(a),B=hex2rgb(b); const r=(i)=>Math.round(A[i]+(B[i]-A[i])*t); return `rgb(${r(0)},${r(1)},${r(2)})`; }
function lerpRamp(a,b,t){ return [0,1,2,3].map((i)=>lerpHex(a[i],b[i],t)); }

/* ---- low-level grid draw ---- */
function drawGrid(ctx, grid, scale, ox, oy, sil) {
  ox = Math.round(ox); oy = Math.round(oy);
  for (let y=0; y<grid.length; y++) {
    const row = grid[y];
    for (let x=0; x<row.length; x++) {
      const ch = row[x];
      if (ch === ".") continue;
      const c = sil ? "#08080E" : METAL[ch];
      if (!c) continue;
      ctx.fillStyle = c;
      ctx.fillRect(ox + x*scale, oy + y*scale, scale, scale);
    }
  }
}

const SCREEN_W = 10;
function drawScreen(ctx, ramp, mood, blink, flash, alpha, scale, ox, oy, scan) {
  ox = Math.round(ox); oy = Math.round(oy);
  ctx.save();
  ctx.globalAlpha = alpha;
  for (let y=0; y<SCREEN_W; y++) for (let x=0; x<SCREEN_W; x++) {
    const dx = x-4.5, dy = y-4.5, d = Math.sqrt(dx*dx + dy*dy);
    const idx = d<1.5 ? 3 : d<2.9 ? 2 : d<4.2 ? 1 : 0;
    ctx.fillStyle = ramp[idx];
    ctx.fillRect(ox + x*scale, oy + y*scale, scale, scale);
  }
  if (scan) { ctx.fillStyle = "rgba(2,8,12,0.18)"; for (let y=0; y<SCREEN_W; y+=2) ctx.fillRect(ox, oy + y*scale, SCREEN_W*scale, scale); }
  const eyes = blink ? BLINK_EYES[mood] : EYES[mood];
  ctx.fillStyle = EYECOL[mood];
  for (const [x,y] of eyes) ctx.fillRect(ox + x*scale, oy + y*scale, scale, scale);
  for (const [x,y] of MOUTH[mood]) ctx.fillRect(ox + x*scale, oy + y*scale, scale, scale);
  if (flash > 0.01) { ctx.globalAlpha = Math.min(0.55, flash*0.65) * alpha; ctx.fillStyle = "#F2FFFF"; ctx.fillRect(ox, oy, SCREEN_W*scale, SCREEN_W*scale); }
  ctx.restore();
}

/* ============================================================================
   INSTANCE MODEL — each rendered BIT (live or static)
   ============================================================================ */
const RM = global.matchMedia && global.matchMedia("(prefers-reduced-motion: reduce)").matches;
const LIVE = [];

function makeInst(ctx, opts) {
  const mood = opts.mood || "NEUTRAL";
  return {
    ctx, glow: opts.glow || null, scale: opts.scale || 1,
    mood, _target: mood, _from: mood, _mt: 1, _mood: mood,
    _spread: MOOD_SPREAD[mood] + (opts.plateBias || 0),
    _cheer: 0, _appear: opts.appear === false ? 1 : (opts.appear || 1),
    _blinkT: 2000 + Math.random()*4000, _blink: 0, _blinkDur: 0,
    _spinning: false, _spinT: 0, _preMood: mood,
    plateBias: opts.plateBias || 0,
    static: !!opts.static, sil: !!opts.sil, reduce: RM,
    scan: opts.scanlines !== false, glowOn: opts.groundGlow !== false,
    clock: Math.random()*4000,
  };
}

function setMood(inst, mood) {
  if (!RAMPS[mood] || mood === inst._target) return;
  inst._from = inst._target;
  inst._target = mood;
  inst._mt = 0;
  if (mood === "CHEER") inst._cheer = 1;
}

/* ---- press → cheer + orbit the four plates exactly one full round ---- */
function spinInst(inst) {
  if (inst._spinning) return;                    // ignore re-press mid-spin
  if (inst.static || inst.reduce) {              // no orbit when motion is off — just cheer
    setMood(inst, "CHEER"); inst._cheer = 1; renderInst(inst);
    return;
  }
  inst._preMood = inst._target;                  // remember where to return
  inst._spinning = true; inst._spinT = 0;
  setMood(inst, "CHEER"); inst._cheer = 1;       // cheer up
}

function updateInst(inst, dt) {
  inst.clock += dt;
  // press-spin: advance one revolution, then settle back to the prior mood
  if (inst._spinning) {
    inst._spinT += dt / SPIN_MS;
    if (inst._spinT >= 1) { inst._spinT = 0; inst._spinning = false; setMood(inst, inst._preMood); }
  }
  if (inst._mt < 1) { inst._mt = Math.min(1, inst._mt + dt/200); if (inst._mt >= 0.5) inst._mood = inst._target; }
  if (inst._mood === undefined) inst._mood = inst._target;
  const targetSpread = MOOD_SPREAD[inst._target] + inst.plateBias;
  inst._spread += (targetSpread - inst._spread) * Math.min(1, dt/120);
  if (inst._appear < 1) inst._appear = Math.min(1, inst._appear + dt/350);
  if (inst._cheer > 0) inst._cheer = Math.max(0, inst._cheer - dt/650);
  if (!inst.static && !inst.reduce) {
    if (inst._blink > 0) { inst._blinkDur -= dt; if (inst._blinkDur <= 0) { inst._blink = 0; inst._blinkT = 2600 + Math.random()*4400; } }
    else { inst._blinkT -= dt; if (inst._blinkT <= 0) { inst._blink = 1; inst._blinkDur = 110; } }
  }
}

function renderInst(inst) {
  const ctx = inst.ctx, s = inst.scale, sil = inst.sil;
  const t = inst.clock;
  ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);

  const frozen = inst.static || inst.reduce;
  const bob = frozen ? 0 : 1.5 * Math.sin(t/390);   // home-room hero: 2× faster, 1.5× range
  const breathe = frozen ? 0 : Math.round(Math.sin(t/610 + 1.3));
  const appearOut = Math.round((1 - inst._appear) * 9);

  const ramp = lerpRamp(RAMPS[inst._from], RAMPS[inst._target], inst._mt);
  const glowCol = lerpHex(GLOW[inst._from], GLOW[inst._target], inst._mt);

  if (inst.glow) {
    if (!inst.glowOn || sil) { inst.glow.style.opacity = 0; }
    else {
      inst.glow.style.background = `radial-gradient(ellipse at center, ${glowCol} 0%, rgba(0,0,0,0) 70%)`;
      const base = inst._target === "REST" ? 0.32 : 0.5;
      inst.glow.style.opacity = (frozen ? base : base + 0.16*Math.sin(t/390)) * inst._appear;
    }
  }

  const cheer = inst._cheer;
  const shake = (cheer > 0.02 && !frozen) ? (Math.random()-0.5)*2.4*cheer : 0;
  const droop = inst._target === "REST" ? 2 : 0;
  const spreadF = inst._spread + breathe + cheer*3 + appearOut;

  // plates orbit the core: angle 0 = normal spread layout; press → one full turn
  const theta = inst._spinning ? easeInOutCubic(inst._spinT) * Math.PI * 2 : 0;
  const cos = Math.cos(theta), sin = Math.sin(theta);
  const ocx = GX + CORE_CX, ocy = GY + CORE_CY + bob;
  for (const p of PLATES) {
    const ex = p.nvx + p.dir[0]*spreadF;   // home vector pushed out by current spread
    const ey = p.nvy + p.dir[1]*spreadF;
    const rvx = ex*cos - ey*sin;           // rotate around the core
    const rvy = ex*sin + ey*cos;
    drawGrid(ctx, p.grid, s, (ocx + rvx - p.hw + shake)*s, (ocy + rvy - p.hh + droop)*s, sil);
  }
  drawGrid(ctx, CORE, s, (GX + CORE_X)*s, (GY + CORE_Y + bob)*s, sil);
  if (!sil) {
    const sa = inst._appear * inst._appear;
    drawScreen(ctx, ramp, inst._mood || inst._target, !!inst._blink, cheer, sa, s, (GX + CORE_X + 3)*s, (GY + CORE_Y + 3 + bob)*s, inst.scan);
  }
}

/* ============================================================================
   ANIMATION LOOP (single shared rAF for every live BIT on the page)
   ============================================================================ */
let last = performance.now();
let started = false;
function tick(now) {
  const dt = Math.min(60, now - last);
  last = now;
  for (const inst of LIVE) { updateInst(inst, dt); renderInst(inst); }
  requestAnimationFrame(tick);
}

/* ============================================================================
   PUBLIC API
   ============================================================================ */
function mount(host, opts) {
  opts = opts || {};
  const px = opts.px || host.clientWidth || 120;

  // host becomes the positioning context for the ground glow
  const cs = global.getComputedStyle ? getComputedStyle(host) : null;
  if (!cs || cs.position === "static") host.style.position = "relative";

  const glow = document.createElement("div");
  Object.assign(glow.style, {
    position: "absolute", left: "50%", bottom: "4%", transform: "translateX(-50%)",
    width: "64%", height: "16%", pointerEvents: "none", borderRadius: "50%",
    filter: "blur(2px)", opacity: "0",
  });

  const cv = document.createElement("canvas");
  cv.width = NATIVE; cv.height = NATIVE;
  cv.style.width = px + "px"; cv.style.height = px + "px";
  cv.style.display = "block";
  cv.style.imageRendering = "pixelated";
  cv.style.position = "relative";
  cv.style.zIndex = "2";
  cv.style.cursor = "pointer";
  cv.title = "BIT";

  host.appendChild(glow);
  host.appendChild(cv);

  const inst = makeInst(cv.getContext("2d"), Object.assign({ glow }, opts));
  updateInst(inst, 16);
  renderInst(inst);                       // guarantee a first paint

  if (!inst.static && !inst.reduce) {
    LIVE.push(inst);
    if (!started) { started = true; requestAnimationFrame(tick); }
  }

  // press BIT → cheer up + orbit the plates one full round
  cv.addEventListener("click", () => spinInst(inst));

  return {
    el: cv,
    setMood: (m) => setMood(inst, m),
    spin: () => spinInst(inst),                               // press reaction
    replay: () => { inst._appear = 0; inst._cheer = 0.6; },   // re-play "BIT online"
    cheer: () => { inst._cheer = 1; },                        // one-shot celebration flash
    destroy: () => {
      const i = LIVE.indexOf(inst); if (i >= 0) LIVE.splice(i, 1);
      glow.remove(); cv.remove();
    },
    _inst: inst,
  };
}

global.BIT = {
  NATIVE,
  MOODS: ["NEUTRAL", "CHEER", "ALERT", "REST"],
  mount,
  setMood,
  spin: spinInst,
};

})(typeof window !== "undefined" ? window : this);
