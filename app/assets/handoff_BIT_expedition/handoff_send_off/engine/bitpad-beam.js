/* ==========================================================================
   BIT HOVER PAD — beam layer (separate from the floor-glow engine).
   A point-source cone of authentic pixel-art light: a ~3-cell bright FOCUS at
   the pad's emitter (the brightness peak), fanning UP and OUT as an upside-down
   triangle, fading completely to zero BEFORE it reaches BIT (clean dark gap so
   BIT keeps salience). No contact, no divergence. Energy travels UPWARD as
   discrete dithered bands. Same cyan ramp + Bayer dither as the floor glow, so
   pad-light and beam read as one emitter. Reduce-motion safe.

   Usage:
     <canvas id="padBeam"></canvas>   // sized + positioned in CSS (mix-blend: screen)
     BitPadBeam.init(canvas, {
       cols, rows,            // low-res cell grid
       apexX, apexY,          // focus cell (cone apex, at the emitter)
       topY,                  // row where the beam has fully faded (above apex)
       halfBase,              // half-width at the apex, in cells (~1.5 = ~3 wide)
       spread,                // half-width growth per row of rise (cone angle)
       bandSpeed, bandPeriod, // travelling-energy speed (rows/s) + spacing (cells)
       fps
     });
   ========================================================================== */
(function () {
  const BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
  ];
  const TIERS = [
    null,
    { c: '30,130,178', a: 0.24 },
    { c: '48,190,232', a: 0.46 },
    { c: '132,232,255', a: 0.70 },
    { c: '214,250,255', a: 0.88 },
  ];

  function init(canvas, cfg) {
    const ctx = canvas.getContext('2d');
    const COLS = cfg.cols, ROWS = cfg.rows;
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

    // ── external control (homecoming): override the auto intensity, and pull the
    //    beam's fade-top DOWN toward the apex so it withdraws INTO the emitter.
    //    topY01: 0 = full height, 1 = fully retracted into the apex (no beam).
    let curTopY = topY;
    let extScale = 1;          // multiplies the auto flicker (1 = normal)

    function field(x, y, t) {
      const HH = ay - curTopY;             // live beam height in rows
      if (y > ay || y < curTopY || HH <= 0) return 0;
      const rise = ay - y;                 // 0 at apex … HH at the fade-top
      const half = halfBase + spread * rise;
      const dxa = Math.abs(x - ax);
      if (dxa > half) return 0;
      let h = (1 - dxa / half);            // bright centre → soft edge
      h = Math.min(1, h * edgeFlat);       // flatten the bright core, keep soft dithered edges
      const up = rise / HH;                // 0 apex … 1 fade-top
      let vert = Math.pow(1 - up, vfade);  // brightness peaks at the base, →0 before BIT
      let v = h * vert;
      // travelling energy — discrete bands climbing upward
      let p = (((rise - t * bandSpeed) % period) + period) % period;
      v *= (p < period * 0.5) ? 1.28 : 0.70;
      return v < 0 ? 0 : v;
    }

    function draw(t, intensity) {
      ctx.clearRect(0, 0, COLS, ROWS);
      for (let y = curTopY; y <= ay; y++) {
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

    // handle: drive the beam from a homecoming sequencer.
    //   set({ scale, topY01 }) — scale multiplies brightness, topY01 retracts.
    const handle = {
      set: function (o) {
        if (o && o.scale != null) extScale = o.scale;
        if (o && o.topY01 != null) curTopY = Math.round(topY + (ay - topY) * o.topY01);
      },
      reset: function () { extScale = 1; curTopY = topY; }
    };

    const reduce = window.matchMedia &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce) { draw(0, 0.85 * extScale); handle.set = function (o) {
      if (o && o.scale != null) extScale = o.scale;
      if (o && o.topY01 != null) curTopY = Math.round(topY + (ay - topY) * o.topY01);
      draw(0, 0.85 * extScale);
    }; return handle; }

    let flick = 0.85, t = 0, dipUntil = 0, nextDipRoll = 0, last = 0;
    function loop(now) {
      requestAnimationFrame(loop);
      if (now - last < frameMs) return;
      const dt = (now - last) / 1000; last = now; t += dt;
      const breath = 0.82 + 0.18 * Math.sin(t * 1.6);
      let target = breath * (0.95 + Math.random() * 0.05);
      if (now > nextDipRoll) { nextDipRoll = now + 90; if (Math.random() < 0.14) dipUntil = now + 50 + Math.random() * 110; }
      if (now < dipUntil) target *= 0.55 + Math.random() * 0.2;
      flick += (target - flick) * 0.55;
      draw(t, flick * extScale);
    }
    requestAnimationFrame(loop);
    return handle;
  }

  window.BitPadBeam = { init };
})();
