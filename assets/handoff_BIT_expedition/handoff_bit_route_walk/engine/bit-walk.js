/* ============================================================================
   BIT — Side-View Hover-Glide · portable painter
   ----------------------------------------------------------------------------
   The companion to bit.js (the front-facing mascot engine). This module paints
   BIT in RIGHT-FACING PROFILE for the Adventure route screens: BIT has no legs,
   so "walking the route" is a HOVER-GLIDE — forward-facing glowing screen, a
   trailing back-plate fin, top plate + under-vent, hover-bob, blink, a cyan
   thrust trail, and a crisp route-tinted hover shimmer on the walk line.

   Hand-painted cell-by-cell on a 40×32 native sprite in BIT's canonical METAL
   palette. Integer-scaled, nearest-neighbour. No dependencies. Reduce-motion
   aware (freezes on a static pose).

   ── USE ──────────────────────────────────────────────────────────────────────
     <canvas id="bit" width="40" height="32"
             style="image-rendering:pixelated;width:80px;height:64px"></canvas>
     <script src="bit-walk.js"></script>
     <script>
       const w = BITWALK.mount(document.getElementById('bit'), {
         accent: '#FF6A3D',   // active route accent (tints the hover shimmer)
         speed:  40,          // px/s the WORLD scrolls — gates the thrust trail
         trail:  true,
       });
       w.setAccent('#B14DFF');   // on route change
       w.setSpeed(0);            // BIT idles (no trail) when the world is still
       w.destroy();
     </script>

   For a single static frame (thumbnails, print, PDF export) skip mount() and call
     BITWALK.paint(ctx, scale, t, { accent, blink, motes, shadow });

   The sprite anchors so BIT's feet/contact sit at native y≈29 — place the canvas
   so y29 lands on the route walk line.
   ============================================================================ */
(function (global) {
"use strict";

/* ---- BIT's canonical metal palette (cool machined blue-grey, zero warmth) -- */
const METAL = {
  k:"#0B0B14", d:"#1E1E2E", q:"#0A0A12", m:"#34344E", M:"#2A2A40",
  l:"#4B4B6E", L:"#6E6E92", c:"#00BFFF", C:"#5EE8FF"
};
const RAMP = ["#0A5E72","#11A6C4","#39D6F0","#7CF2FF"];   // screen glow, edge→centre
const NATIVE = { w: 40, h: 32 };

/* ---- auto 1px outline on transparent cells touching the form ---- */
function outlinePass(g){
  const h=g.length, w=g[0].length, out=g.map(r=>r.slice());
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    if(g[y][x]!==".")continue;
    let adj=false;
    for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const nx=x+dx,ny=y+dy;
      if(nx>=0&&nx<w&&ny>=0&&ny<h&&g[ny][nx]!=="."&&g[ny][nx]!=="k"){adj=true;break;}}
    if(adj)out[y][x]="k";
  }
  return out;
}
/* ---- bevelled rounded-rect metal block, top-left lit ---- */
function bevelBlock(w,h,cut){
  const inside=(x,y)=>x>=0&&x<w&&y>=0&&y<h&&(x+y)>=cut&&((w-1-x)+y)>=cut&&(x+(h-1-y))>=cut&&((w-1-x)+(h-1-y))>=cut;
  const g=Array.from({length:h},(_,y)=>Array.from({length:w},(_,x)=>inside(x,y)?"m":"."));
  const isIn=(x,y)=>x>=0&&x<w&&y>=0&&y<h&&g[y][x]!==".";
  const sh=g.map(r=>r.slice());
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    if(g[y][x]===".")continue;
    const up=isIn(x,y-1),dn=isIn(x,y+1),lf=isIn(x-1,y),rt=isIn(x+1,y);
    if(!up)sh[y][x]="L"; else if(!dn)sh[y][x]="d"; else if(!lf)sh[y][x]="l"; else if(!rt)sh[y][x]="M";
  }
  for(let y=1;y<h;y++)for(let x=0;x<w;x++){ if(sh[y][x]==="m"&&sh[y-1][x]==="L")sh[y][x]="l"; }
  return sh;
}
function dot(g,x,y){ if(g[y]&&g[y][x]&&g[y][x]!=="."){ g[y][x]="C"; if(g[y][x+1]&&g[y][x+1]!==".")g[y][x+1]="c"; } }

/* ---- side core: square rounded body mostly filled by the glowing screen with
       a thin metal bezel (BIT's signature). Screen pushed to the forward (right)
       face; the left metal reads as the "back of the head" so he clearly faces
       the direction of travel. ---- */
const SCRX=5, SCRY=4, SCRW=7, SCRH=7;          // core-local screen well (shared)
function buildSideCore(){
  const g=bevelBlock(15,15,3);
  for(let y=SCRY-1;y<=SCRY+SCRH;y++)for(let x=SCRX-1;x<=SCRX+SCRW;x++){
    if(g[y]&&g[y][x]!==undefined&&g[y][x]!=="."){
      const inner=(x>=SCRX&&x<SCRX+SCRW&&y>=SCRY&&y<SCRY+SCRH);
      if(inner) g[y][x]="q";
      else g[y][x]=(x<SCRX||y<SCRY)?"d":"k";    // recessed bezel ring
    }
  }
  g[5][1]="k"; g[6][1]="d"; g[7][1]="d"; g[8][1]="d"; g[9][1]="k"; g[7][2]="l";  // back-of-head vents
  return outlinePass(g);
}
const CORE      = buildSideCore();
const TOPPLATE  = (()=>{const g=bevelBlock(13,4,2); dot(g,3,1); dot(g,9,1); return outlinePass(g);})();
const BACKPLATE = (()=>{const g=bevelBlock(5,11,2); dot(g,2,2); dot(g,2,8); return outlinePass(g);})();
const UNDERVENT = (()=>{const g=bevelBlock(10,3,1); dot(g,2,1); dot(g,7,1); return outlinePass(g);})();

function drawGrid(ctx,grid,s,ox,oy){
  ox=Math.round(ox); oy=Math.round(oy);
  for(let y=0;y<grid.length;y++)for(let x=0;x<grid[y].length;x++){
    const ch=grid[y][x]; if(ch===".")continue; const c=METAL[ch]; if(!c)continue;
    ctx.fillStyle=c; ctx.fillRect(ox+x*s, oy+y*s, s, s);
  }
}
/* screen: fills the face; ramp glow + forward-looking eyes. Sized from the shared
   SCR* constants so the drawn screen always lands inside the well. */
function drawScreen(ctx,s,ox,oy,blink){
  ox=Math.round(ox); oy=Math.round(oy);
  const cx=(SCRW-1)/2, cy=(SCRH-1)/2;
  for(let y=0;y<SCRH;y++)for(let x=0;x<SCRW;x++){
    const d=Math.sqrt((x-cx)*(x-cx)+(y-cy)*(y-cy));
    const idx=d<1.2?3:d<2.4?2:d<3.4?1:0;
    ctx.fillStyle=RAMP[idx]; ctx.fillRect(ox+x*s, oy+y*s, s, s);
  }
  ctx.fillStyle="#FFFFFF";                        // eyes, shifted to the forward (right) half
  if(blink){ ctx.fillRect(ox+3*s, oy+3*s, s, s); ctx.fillRect(ox+5*s, oy+3*s, s, s); }
  else { ctx.fillRect(ox+3*s, oy+2*s, s, s); ctx.fillRect(ox+5*s, oy+2*s, s, s);
         ctx.fillRect(ox+3*s, oy+3*s, s, s); ctx.fillRect(ox+5*s, oy+3*s, s, s); }
  ctx.fillStyle="#7CF2FF"; ctx.fillRect(ox+4*s, oy+5*s, s, s);   // mouth glint
}

const A=1.5, PER=300;                             // hover amplitude (px) + period
const bobAt=(t,lag)=>Math.round(A*Math.sin((t-lag)/PER));

/* ----------------------------------------------------------------------------
   paint() — one frame at integer scale `s`. opts:
     accent  hover-shimmer tint (route accent hex). default cyan.
     blink   draw the closed-eye pose
     motes   array of {x,y,life} thrust motes (native coords) — drawn behind
     shadow  false → omit the ground shimmer/contact (for off-route thumbnails)
   -------------------------------------------------------------------------- */
function paint(ctx, s, t, opts){
  opts=opts||{};
  ctx.clearRect(0,0,ctx.canvas.width,ctx.canvas.height);
  const CX=13, CY=8;                              // core top-left (native)
  const cb=bobAt(t,0);

  // ground contact — crisp, route-tinted hover shimmer (no soft blur).
  // Echoes the route walk-line's dashed motif; brighter at centre, gently pulsing.
  if(opts.shadow!==false){
    const ax = opts.accent || "#00BFFF";
    const cxn = CX+6, gy = 29;
    const pulse = 0.55 + 0.45*Math.sin(t/300);
    ctx.save();
    ctx.globalAlpha = 0.26; ctx.fillStyle = "#05050C";          // faint dark contact
    ctx.fillRect((cxn-5)*s, gy*s, 11*s, s);
    ctx.fillStyle = ax;                                          // dashed accent glints
    const dashes = [[-5,0.10],[-3,0.18],[-1,0.50],[1,0.50],[3,0.18],[5,0.10]];
    for(const [dx,a] of dashes){ ctx.globalAlpha = a*pulse; ctx.fillRect((cxn+dx)*s, gy*s, s, s); }
    ctx.restore();
    ctx.globalAlpha = 1;
  }

  // thrust motes (cyan — BIT's engine identity), drawn behind the body
  if(opts.motes){
    for(const m of opts.motes){
      const a=Math.max(0,m.life);
      ctx.globalAlpha=a;
      ctx.fillStyle = a>0.55 ? "#5EE8FF" : "#00BFFF";
      const sz = a>0.55?2:1;
      ctx.fillRect(Math.round(m.x)*s, Math.round(m.y)*s, sz*s, sz*s);
    }
    ctx.globalAlpha=1;
  }

  // back plate (trailing fin), top plate, under-vent — each lags the core's bob
  const backX = CX-7 - Math.round(Math.sin((t-200)/PER));       // floats behind, sways
  drawGrid(ctx, BACKPLATE, s, backX*s,  (CY+2+bobAt(t,200))*s);
  drawGrid(ctx, TOPPLATE,  s, (CX+1)*s, (CY-4+bobAt(t,140))*s);
  drawGrid(ctx, UNDERVENT, s, (CX+3)*s, (CY+14+bobAt(t,90))*s);

  // core + glowing forward face
  drawGrid(ctx, CORE, s, CX*s, (CY+cb)*s);
  drawScreen(ctx, s, (CX+SCRX)*s, (CY+SCRY+cb)*s, opts.blink);
}

/* ----------------------------------------------------------------------------
   mount() — animate BIT on a canvas with its own rAF loop. opts:
     accent  route accent hex (hover-shimmer tint)
     speed   px/s the WORLD scrolls — gates + scales the thrust trail
     trail   emit the thrust trail (default true)
     static  freeze on a single pose (also auto when prefers-reduced-motion)
   Returns { setAccent, setSpeed, setTrail, setPlaying, destroy, canvas }.
   -------------------------------------------------------------------------- */
function mount(canvas, opts){
  opts=opts||{};
  const ctx=canvas.getContext("2d");
  const RM = global.matchMedia && global.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const st = {
    accent: opts.accent || "#00BFFF",
    speed: opts.speed!=null ? opts.speed : 40,
    trail: opts.trail!==false,
    playing: true,
    frozen: !!opts.static || RM,
    clock: 0, last: performance.now(),
    blink: 0, blinkDur: 0, blinkT: 2600 + Math.random()*3000,
    motes: [], moteT: 0, raf: 0,
  };

  function emit(dt){
    if(!st.trail || st.speed<=4){ return; }
    st.moteT -= dt;
    if(st.moteT<=0){
      st.moteT = 70;
      st.motes.push({ x:7, y:24+bobAt(st.clock,90)+(Math.random()*2-1),
                      vx:-(0.05+st.speed*0.0009), vy:0.012, life:1 });
    }
    for(const m of st.motes){ m.x+=m.vx*dt; m.y+=m.vy*dt; m.life-=dt/520; }
    st.motes = st.motes.filter(m=>m.life>0 && m.x>-1);
  }

  function frame(now){
    const dt=Math.min(50, now-st.last); st.last=now;
    if(st.playing && !st.frozen){
      st.clock += dt;
      if(st.blink){ st.blinkDur-=dt; if(st.blinkDur<=0){ st.blink=0; st.blinkT=2600+Math.random()*4000; } }
      else { st.blinkT-=dt; if(st.blinkT<=0){ st.blink=1; st.blinkDur=110; } }
      emit(dt);
    }
    paint(ctx, 1, st.clock, { accent:st.accent, blink:!!st.blink, motes: st.trail?st.motes:null });
    st.raf = requestAnimationFrame(frame);
  }

  // guarantee a first paint even if rAF is throttled (hidden tab / capture)
  paint(ctx, 1, 0, { accent:st.accent, blink:false, motes:[] });
  if(!st.frozen) st.raf = requestAnimationFrame(frame);

  return {
    canvas,
    setAccent: (hex)=>{ st.accent = hex || st.accent; },
    setSpeed:  (v)=>{ st.speed = +v||0; },
    setTrail:  (on)=>{ st.trail = !!on; if(!on) st.motes.length=0; },
    setPlaying:(on)=>{ st.playing = !!on; },
    destroy:   ()=>{ if(st.raf) cancelAnimationFrame(st.raf); },
    _state: st,
  };
}

global.BITWALK = { NATIVE, METAL, RAMP, paint, mount };

})(typeof window !== "undefined" ? window : this);
