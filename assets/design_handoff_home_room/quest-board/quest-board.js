/* ==========================================================================
   IRONBIT — QUEST BOARD (code-painted wall terminal)
   A flush-mounted crate on BIT's wall, painted entirely in code; the QUESTS
   label is the app's font (PressStart2P), crisp at device resolution. Authored
   in a 65×72 design space (9:10) and rendered at any `scale`.

   DESIGN (from review):
   • GLANCE, DON'T TRANSACT. No claim button. Tapping the board routes to the
     Quests tab (the claim juice — gem-fly, BIT cheer — lives there). On the
     wall there is only: QUESTS label · 5-segment weekly bar · one gem pip.
   • ONE SYSTEM. The bar's cyan is the pad's LED cyan; the crate FACE uses the
     room's card/emboss surface (surface-2 / card / border tokens). Bolts only.
   • SUBORDINATE + CALM. Cyan is steady-lit (never a nag, never dark). The ONLY
     thing that moves is the claimable cue, and only when ≥1 reward is ready:
     an ambient amber EDGE-GLOW + a lit amber gem pip, breathing slowly and low.
     Not claimable → the gem sits calm steady-cyan, nothing pulses. (Coordinate
     with the pad's armed-glow so only one accent in the room breathes at once.)
   • prefers-reduced-motion → fully static (lit gem, static edge-glow if ready).

   Usage:
     <canvas id="questBoard"></canvas>
     const qb = QuestBoard.init(canvas, { scale:1, total:5, filled:2, ready:0 });
     qb.set({ filled:3, ready:1 });   // live update
   ========================================================================== */
(function () {
  const BASE_W = 65, BASE_H = 72;
  const C = {
    // crate FACE — room card / emboss surface tokens
    border: '#36365e', faceLit: '#45437a', face: '#232342', faceCard: '#1c1c34', emboss: '#14142a',
    boltDk: '#101024',
    // recessed screen
    scrEdge: '#0b0b18', scr: '#0e0e1c', scrTop: '#070712',
    bar: '#0a0a18', barEdge: '#070712',
    // cyan — matched to the pad LED (BitPad ramp: #30bee8 / #84e8ff)
    cy: '#30bee8', cyHi: '#84e8ff', cyCell: '#1c5f74', cyDim: '#1d6f88',
    cellOff: '#1a1a30', cellOffIn: '#121226', cellTop: '#23233f',
    // amber — claimable cue only
    am: '#f5c43c', amHi: '#ffe27a', amDk: '#b07d18',
    txt: '#e2e5ff', txtDim: '#8a8fb5',
  };

  function init(canvas, cfg) {
    cfg = cfg || {};
    const scale = cfg.scale || 1, DPR = 2, dev = scale * DPR;
    const W = BASE_W, H = BASE_H;
    let total = cfg.total != null ? cfg.total : 5;
    let filled = cfg.filled != null ? cfg.filled : 2;
    let ready = cfg.ready != null ? cfg.ready : 0;
    const reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    let motion = cfg.motion != null ? cfg.motion : !reduce;
    const frameMs = 1000 / (cfg.fps || 18);

    const ctx = canvas.getContext('2d');
    canvas.width = Math.round(W * dev); canvas.height = Math.round(H * dev);
    canvas.style.width = (W * scale) + 'px'; canvas.style.height = (H * scale) + 'px';

    const rc = (x, y, w, h, c) => { ctx.fillStyle = c; ctx.fillRect(x, y, w, h); };
    const cham = (x, y, w, h, c, k) => {
      ctx.fillStyle = c;
      ctx.fillRect(x + k, y, w - 2 * k, h);
      ctx.fillRect(x, y + k, w, h - 2 * k);
    };
    const glowOn = (color, blur) => { ctx.shadowColor = color; ctx.shadowBlur = blur; };
    const glowOff = () => { ctx.shadowBlur = 0; ctx.shadowColor = 'transparent'; };
    const cyA = (a) => 'rgba(48,190,232,' + a.toFixed(3) + ')';
    const amA = (a) => 'rgba(245,196,60,' + a.toFixed(3) + ')';

    // thin frame (~halved) → a slightly larger screen, same 65×72 board
    const sx = 3, sy = 3, sw = W - 6, sh = H - 6;

    function bolt(x, y) {
      const s = 6;
      cham(x, y, s, s, C.boltDk, 2);
      cham(x + 1, y + 1, s - 2, s - 2, C.faceLit, 2);
      cham(x + 1, y + 2, s - 2, s - 3, C.face, 2);
      rc(x + 2, y + 2, 3, 3, C.emboss);
      rc(x + 2, y + 2, 3, 1, C.boltDk); rc(x + 2, y + 2, 1, 3, C.boltDk);
      rc(x + 4, y + 3, 1, 2, C.faceLit);
    }

    function progressBar(by) {
      const bx = sx + 6, bw = sw - 12, bh = 12;
      cham(bx, by, bw, bh, C.barEdge, 3);
      cham(bx + 1, by + 1, bw - 2, bh - 2, C.bar, 3);
      rc(bx + 3, by + 1, bw - 6, 1, '#050510');
      const ix = bx + 3, iy = by + 3, iw = bw - 6, ih = bh - 6, gap = 1.2;
      const cw = (iw - (total - 1) * gap) / total;
      for (let i = 0; i < total; i++) {
        const cxp = ix + i * (cw + gap);
        if (i < filled) {                      // STEADY cyan (pad LED) — no pulse
          glowOn(cyA(0.2), 2.5);
          rc(cxp, iy, cw, ih, C.cyCell);
          glowOff();
          rc(cxp, iy, cw, 1, C.cy);
          rc(cxp, iy, Math.max(1, cw * 0.4), 1, C.cyHi);
        } else {
          rc(cxp, iy, cw, ih, C.cellOff);
          rc(cxp, iy + 1, cw, ih - 1, C.cellOffIn);
          rc(cxp, iy, cw, 1, C.cellTop);
        }
      }
    }

    // the single status token — a gem pip. amber+breathe when claimable,
    // else calm steady cyan. never dark.
    function gemPip(cx, cy, claim, g) {
      const r = 3.2;
      const col = claim ? C.am : C.cyDim;
      const hi = claim ? C.amHi : C.cy;
      glowOn(claim ? amA(0.42 + 0.36 * g) : cyA(0.18), claim ? (5 + 3 * g) : 2.5);
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.moveTo(cx, cy - r); ctx.lineTo(cx + r, cy); ctx.lineTo(cx, cy + r); ctx.lineTo(cx - r, cy);
      ctx.closePath(); ctx.fill();
      glowOff();
      ctx.fillStyle = hi;                      // top-left facet glint
      ctx.beginPath();
      ctx.moveTo(cx, cy - r); ctx.lineTo(cx - r * 0.62, cy - r * 0.18); ctx.lineTo(cx, cy - r * 0.2);
      ctx.closePath(); ctx.fill();
    }

    // ambient amber edge-glow inside the screen — the claimable cue (bloom, not a hard border)
    function edgeGlow(g) {
      glowOn(amA(0.6 * g), 8);
      ctx.strokeStyle = amA(0.09 + 0.14 * g); ctx.lineWidth = 1;
      ctx.strokeRect(sx + 3, sy + 3, sw - 6, sh - 6);
      ctx.strokeStyle = amA(0.05 + 0.09 * g);
      ctx.strokeRect(sx + 5, sy + 5, sw - 10, sh - 10);
      glowOff();
    }

    function paint(t, anim) {
      const claim = ready > 0;
      const g = (anim && claim) ? 0.5 + 0.5 * Math.sin(t * 2.25) : (claim ? 0.6 : 0);  // slow amber breathe (1.5× faster)

      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.setTransform(dev, 0, 0, dev, 0, 0);
      ctx.imageSmoothingEnabled = true;
      ctx.textBaseline = 'alphabetic';
      ctx.textAlign = 'center';

      // ── crate FACE (room card/emboss surface), THIN flush bezel ──
      cham(0, 0, W, H, C.border, 3);
      cham(1, 1, W - 2, H - 2, C.faceLit, 2);     // emboss highlight (top-left)
      cham(1, 2, W - 2, H - 4, C.face, 2);        // surface-2 face (leaves 1px lit top)
      rc(2, H - 3, W - 4, 1, C.emboss);           // thin bottom emboss shade

      // ── recessed screen ──
      cham(sx, sy, sw, sh, C.scrEdge, 3);
      cham(sx + 1, sy + 1, sw - 2, sh - 2, C.scr, 3);
      rc(sx + 3, sy + 1, sw - 6, 1, C.scrTop);
      ctx.fillStyle = 'rgba(150,170,255,0.035)';   // static dim scanlines (powered, calm)
      for (let yy = sy + 3; yy < sy + sh - 1; yy += 3) ctx.fillRect(sx + 2, yy, sw - 4, 1);

      // ── centred content: QUESTS · bar · gem pip ──
      const cx = W / 2;
      const titleH = 8, g1 = 6, barH = 12, g2 = 7, pipH = 7;
      const blockH = titleH + g1 + barH + g2 + pipH;
      const top = sy + (sh - blockH) / 2;

      ctx.font = "6px 'PressStart2P', monospace";
      ctx.fillStyle = C.txt;
      ctx.fillText('QUESTS', cx, top + titleH);

      progressBar(top + titleH + g1);
      gemPip(cx, top + titleH + g1 + barH + g2 + pipH / 2, claim, g);

      // ── claimable cue: ambient amber edge-glow ──
      if (claim) edgeGlow(g);

      // ── flush-mount bolts (only chrome) ──
      bolt(0, 0); bolt(W - 6, 0); bolt(0, H - 6); bolt(W - 6, H - 6);
    }

    function performanceNow() { return (window.performance && performance.now) ? performance.now() : Date.now(); }
    const t0 = performanceNow();
    let timer = null;
    // only run a loop when there's actually something to animate (claimable +
    // motion) — idle is genuinely static, so nothing on the wall nags.
    const shouldAnim = () => motion && !reduce && ready > 0;
    function sync() {
      if (shouldAnim()) {
        if (!timer) timer = setInterval(() => paint((performanceNow() - t0) / 1000, true), frameMs);
        paint((performanceNow() - t0) / 1000, true);   // immediate, in case the interval is throttled
      } else {
        if (timer) { clearInterval(timer); timer = null; }
        paint(0, false);
      }
    }

    paint(0, false);
    sync();
    if (document.fonts && document.fonts.load) {
      document.fonts.load("6px 'PressStart2P'").then(() => { if (!shouldAnim()) paint(0, false); }).catch(() => {});
    }

    return {
      set(o) {
        o = o || {};
        if (o.total != null) total = o.total;
        if (o.filled != null) filled = o.filled;
        if (o.ready != null) ready = o.ready;
        if (o.motion != null) motion = o.motion;
        sync();
      },
      repaint() { paint(0, false); },
    };
  }

  window.QuestBoard = { init };
})();
