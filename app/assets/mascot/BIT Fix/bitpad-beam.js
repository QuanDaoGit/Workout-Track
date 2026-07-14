/* ==========================================================================
   BIT HOVER PAD — beam layer (separate from the floor-glow engine).  [COLOUR-FIXED]
   A point-source cone of authentic pixel-art light: a ~3-cell bright FOCUS at
   the pad's emitter (the brightness peak), fanning UP and OUT as an upside-down
   triangle, fading completely to zero BEFORE it reaches BIT (clean dark gap so
   BIT keeps salience). No contact, no divergence. Energy travels UPWARD as
   discrete dithered bands.

   COLOUR FIX: the beam shared the recovery-cyan ramp; it now uses BIT's reserved
   TURQUOISE identity (#23D6CC family) so pad-light and beam read as one BIT
   emitter rather than a recovery signal. Cone shape, dither, travelling bands
   and the breathing/flicker animation are unchanged. Reduce-motion safe.

   Usage:
     <canvas id="padBeam"></canvas>   // sized + positioned in CSS (mix-blend: screen)
     BitPadBeam.init(canvas, {
       cols, rows,            // low-res cell grid
       apexX, apexY,          // focus cell (cone apex, at the emitter)
       topY,                  // row where the beam has fully faded (above apex)
       halfBase,              // half-width at the apex, in cells (~1.5 = ~3 wide)
       spread,                // half-width growth per row of rise (cone angle)
       bandSpeed, bandPeriod, // travelling-energy speed (rows/s) + spacing (cells)
       fps,
       tiers                  // optional override ramp (defaults to BIT turquoise)
     });
   ========================================================================== */
(function () {
  const BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
  ];
  // BIT turquoise ramp — matches bitpad-light.js so beam + pool read as one emitter
  const TIERS_DEFAULT = [
    null,
    { c: '26,150,142',  a: 0.24 },
    { c: '40,206,194',  a: 0.46 },
    { c: '128,240,228', a: 0.70 },
    { c: '210,255,250', a: 0.88 },
  ];

  function init(canvas, cfg) {
    const ctx = canvas.getContext('2d');
    const COLS = cfg.cols, ROWS = cfg.rows;
    const TIERS = cfg.tiers || TIERS_DEFAULT;
    canvas.width = COLS; canvas.height = ROWS;
    ctx.imageSmoothingEnabled = false;
    const ax = cfg.apexX, ay = cfg.apexY, topY = cfg.topY;
    const halfBase = cfg.halfBase != null ? cfg.halfBase : 1.5;
    const spread = cfg.spread != null ? cfg.spread : 0.3;
    const edgeFlat = cfg.edgeFlat != null ? cfg.edgeFlat : 1.12;   // >1 = flatter bright core, softer edge
    const vfade = cfg.vfade != null ? cfg.vfade : 1.4;            // vertical fade exponent (lower = column holds longer)
    const bandSpeed = cfg.bandSpeed != null ? cfg.bandSpeed : 5;
    const period = cfg.bandPeriod != null ? cfg.bandPeriod : 4.5;
    const frameMs = 1000 / (cfg.fps || 14);
    const H = ay - topY;                 // beam height in rows

    function field(x, y, t) {
      if (y > ay || y < topY) return 0;  // only between apex and fade-top
      const rise = ay - y;               // 0 at apex … H at the fade-top
      const half = halfBase + spread * rise;
      const dxa = Math.abs(x - ax);
      if (dxa > half) return 0;
      let h = (1 - dxa / half);          // bright centre → soft edge
      h = Math.min(1, h * edgeFlat);     // flatten the bright core, keep soft dithered edges
      const up = rise / H;               // 0 apex … 1 fade-top
      let vert = Math.pow(1 - up, vfade);  // brightness peaks at the base, →0 before BIT
      let v = h * vert;
      // travelling energy — discrete bands climbing upward
      let p = (((rise - t * bandSpeed) % period) + period) % period;
      v *= (p < period * 0.5) ? 1.28 : 0.70;
      return v < 0 ? 0 : v;
    }

    function draw(t, intensity) {
      ctx.clearRect(0, 0, COLS, ROWS);
      for (let y = topY; y <= ay; y++) {
        for (let x = 0; x < COLS; x++) {
          let v = field(x, y, t) * intensity;
          if (v <= 0) continue;
          const th = (BAYER[y & 3][x & 3] + 0.5) / 16;
          let q = v * 4, lvl = Math.floor(q);
          if (q - lvl > th) lvl++;
          if (lvl <= 0) continue;
          if (lvl > 4) lvl = 4;
          const tt = TIERS[lvl];
          ctx.fillStyle = 'rgba(' + tt.c + ',' + tt.a + ')';
          ctx.fillRect(x, y, 1, 1);
        }
      }
    }

    const reduce = window.matchMedia &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce) { draw(0, 0.85); return; }

    let flick = 0.85, t = 0, dipUntil = 0, nextDipRoll = 0, last = 0;
    function loop(now) {
      if (!canvas.isConnected) return;   // auto-stop when the canvas is removed
      requestAnimationFrame(loop);
      if (now - last < frameMs) return;
      const dt = (now - last) / 1000; last = now; t += dt;
      const breath = 0.82 + 0.18 * Math.sin(t * 1.6);
      let target = breath * (0.95 + Math.random() * 0.05);
      if (now > nextDipRoll) { nextDipRoll = now + 90; if (Math.random() < 0.14) dipUntil = now + 50 + Math.random() * 110; }
      if (now < dipUntil) target *= 0.55 + Math.random() * 0.2;
      flick += (target - flick) * 0.55;
      draw(t, flick);
    }
    requestAnimationFrame(loop);
  }

  window.BitPadBeam = { init };
})();
