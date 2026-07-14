/* ============================================================================
   holo-bit.js — BIT's HOLOGRAM (the "away" state) as a portable reference.

   Pixel-authentic holographic projection of BIT, built by post-processing his
   LIVE sprite canvas (so his idle bob/blink keep playing inside the holo) and
   framing him in a structured PROJECTION RIG drawn on a room-level FX canvas.

   This is the web reference for the Flutter port — see IMPLEMENTATION.md.

   Two canvases:
     • holoCanvas  — sized ~112x112, positioned over the pad; the hologram of BIT.
     • fxCanvas    — room-sized; the projection rig (emitter field, brackets,
                     scan-planes) is drawn here BEHIND the hologram (lower z).

   Usage:
     const holo = HoloBit.create({
       holoCanvas, fxCanvas,
       bitCanvas: () => window.__bit.el,   // getter for BIT's live canvas
       ax: 185, emY: 390,                  // projection axis x · emitter plane y (room coords)
       reduceMotion: matchMedia('(prefers-reduced-motion: reduce)').matches
     });
     holo.start();   // power-on fade, begins the ~20fps loop
     holo.stop();    // tear down (BIT comes home / relaunches)
   ============================================================================ */
const HoloBit = (function () {
  const BAYER4 = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]];

  function create(cfg) {
    const holoCanvas = cfg.holoCanvas, fxCanvas = cfg.fxCanvas;
    const hctx = fxCanvas.getContext('2d');
    const holoCtx = holoCanvas.getContext('2d');
    const getBit = cfg.bitCanvas;
    const ax = cfg.ax != null ? cfg.ax : 185;
    const emY = cfg.emY != null ? cfg.emY : 390;
    const topY = cfg.topY != null ? cfg.topY : 286;     // top of the projected volume
    const RM = !!cfg.reduceMotion;

    let raf = 0, t0 = 0, last = 0, fade = 0, flick = 1;

    // ── the projection RIG (drawn on the room FX canvas, behind the hologram) ──
    function drawRig(t) {
      const halfBot = 30, halfTop = 38, span = emY - topY;
      const halfAt = (y) => { const u=(emY-y)/span; return halfBot + (halfTop-halfBot)*u; };
      const T = [null, '#1c6e92', '#2bb2dc', '#57dbff'], TH = [0,0.16,0.30,0.48];
      function plot(x,y,v,br){
        if (v<=0) return;
        const th=(BAYER4[y&3][x&3]+0.5)/16; let q=v*3, lvl=Math.floor(q); if(q-lvl>th) lvl++;
        if(lvl<=0) return; if(lvl>3) lvl=3;
        hctx.globalAlpha = TH[lvl]*(br!=null?br:1)*flick; hctx.fillStyle = T[lvl];
        hctx.fillRect(x,y,1,1);
      }
      // 1) EMITTER FIELD — dithered pulsing data-band at the pad mouth
      const pulse = 0.55 + 0.45*Math.sin(t*5);
      for (let y=emY; y<=emY+5; y++)
        for (let x=ax-32; x<=ax+32; x++){
          const dxn = Math.abs(x-ax)/32; if (dxn>1) continue;
          plot(x,y, (1-dxn*dxn)*pulse*0.9);
        }
      // 2) CONTAINMENT BRACKETS — corner frames top & bottom of the volume
      function bracket(y, dir){
        const hw = Math.round(halfAt(y)), L = 9;
        hctx.globalAlpha = 0.7*flick; hctx.fillStyle = '#7cf2ff';
        hctx.fillRect(ax-hw, y, L, 1); hctx.fillRect(ax+hw-L+1, y, L, 1);
        for (let i=0;i<4;i++){ hctx.fillRect(ax-hw, y+dir*i, 1, 1); hctx.fillRect(ax+hw, y+dir*i, 1, 1); }
        hctx.globalAlpha = 0.4*flick;
        for (let cx=ax-hw+L; cx<=ax+hw-L; cx+=3) hctx.fillRect(cx, y, 1, 1);
      }
      bracket(topY, 1); bracket(emY-2, -1);
      // 3) SCAN-PLANES — 2 horizontal dithered lines sweeping UP the volume
      for (let p=0; p<2; p++){
        const prog = ((t*0.32 + p*0.5) % 1);
        const py = Math.round(emY - prog*span), hw2 = Math.round(halfAt(py));
        const bright = 0.5 + 0.5*Math.sin(prog*Math.PI);
        for (let sx=ax-hw2; sx<=ax+hw2; sx++){
          const edge = 1 - Math.abs(sx-ax)/hw2*0.35;
          plot(sx, py, 0.7*edge*bright, 1.0);
        }
      }
      hctx.globalAlpha = 1;
    }

    // ── the HOLOGRAM of BIT (post-processed from his live canvas) ──
    function drawBit(t) {
      holoCtx.clearRect(0,0,holoCanvas.width,holoCanvas.height);
      const bitCanvas = getBit && getBit();
      if (!bitCanvas || !bitCanvas.width) return;
      holoCtx.imageSmoothingEnabled = false;
      const W = bitCanvas.width, H = bitCanvas.height, DW = W*2, DH = H*2;   // integer 2× — crisp
      const ox = Math.round((holoCanvas.width - DW)/2);
      const oy = Math.round((holoCanvas.height - DH)/2);
      const jit = (Math.random() < 0.07) ? (Math.random()*3 - 1.5) : 0;      // vertical jitter
      // 1) BIT, transparent + flickering
      holoCtx.globalAlpha = (0.44 + 0.12*Math.sin(t*6)) * flick * fade;
      holoCtx.drawImage(bitCanvas, 0,0,W,H, ox, Math.round(oy + jit), DW, DH);
      // 2) cyan tint, BIT pixels only
      holoCtx.globalCompositeOperation = 'source-atop';
      holoCtx.globalAlpha = 0.32 * fade; holoCtx.fillStyle = '#7cf2ff';
      holoCtx.fillRect(0,0,holoCanvas.width,holoCanvas.height);
      // 3) CRT scanlines, every 2px
      holoCtx.globalAlpha = 0.42 * fade; holoCtx.fillStyle = '#02141e';
      for (let y=0; y<holoCanvas.height; y+=2) holoCtx.fillRect(0,y,holoCanvas.width,1);
      // 4) sweeping roll bar
      const roll = Math.floor((t*46) % (holoCanvas.height + 16)) - 8;
      holoCtx.globalAlpha = 0.12 * fade; holoCtx.fillStyle = '#cdf6ff';
      holoCtx.fillRect(0, roll, holoCanvas.width, 6);
      holoCtx.globalCompositeOperation = 'source-over'; holoCtx.globalAlpha = 1;
      // 5) occasional glitch slice
      if (Math.random() < 0.05){
        const gy = Math.floor(Math.random()*(holoCanvas.height-8));
        const gh = 2 + Math.floor(Math.random()*5), gdx = Math.floor(Math.random()*7 - 3);
        try { const sl = holoCtx.getImageData(0,gy,holoCanvas.width,gh);
          holoCtx.clearRect(0,gy,holoCanvas.width,gh); holoCtx.putImageData(sl,gdx,gy); } catch(e){}
      }
    }

    function frame(now) {
      raf = requestAnimationFrame(frame);
      now = now || performance.now();
      if (now - last < 48) return;                  // ~20fps, chunky on purpose
      last = now;
      const t = (now - t0)/1000;
      fade = Math.min(1, (now - t0)/450);           // projector powers on
      flick = 0.82 + 0.18*Math.sin(t*7) - (Math.random() < 0.08 ? Math.random()*0.3 : 0);
      hctx.clearRect(0,0,fxCanvas.width,fxCanvas.height);
      drawRig(t); drawBit(t);
    }

    return {
      start() {
        holoCanvas.style.display = 'block';
        if (RM){ fade = 1; flick = 1;                // reduced motion → static still
          hctx.clearRect(0,0,fxCanvas.width,fxCanvas.height); drawRig(0); drawBit(0); return; }
        if (raf) return;
        t0 = performance.now(); last = 0;
        raf = requestAnimationFrame(frame);
      },
      stop() {
        if (raf){ cancelAnimationFrame(raf); raf = 0; }
        holoCanvas.style.display = 'none';
        holoCtx.clearRect(0,0,holoCanvas.width,holoCanvas.height);
        hctx.clearRect(0,0,fxCanvas.width,fxCanvas.height);
      }
    };
  }
  return { create };
})();
if (typeof module !== 'undefined') module.exports = HoloBit;
