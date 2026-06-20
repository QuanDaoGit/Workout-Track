/* ==========================================================================
   BIT HOVER PAD — pixel-art light engine.   [COLOUR-FIXED]
   Renders a chunky, ordered-dithered glow on a LOW-RES canvas that CSS then
   scales up nearest-neighbour (image-rendering:pixelated) — so the light is
   authentic pixel art, never a smooth CSS gradient.

   COLOUR FIX: the emitter ramp was recovery-cyan (#00BFFF family), which is a
   loaded signal hue. It is now BIT's reserved TURQUOISE identity (#23D6CC
   family) so the pad reads as BIT's own machine light, not a recovery cue.
   Geometry, dither, breathing + flicker animation are all unchanged.

   The field is a radial focus at the centre that spreads out widely (set rx
   wide so it reads wider than BIT) and pools downward on the floor (ryUp keeps
   the halo from climbing the pillars). Animated with a slow breathing fade + a
   flicker that drops chunks of pixels out (authentic, not just opacity).
   Reduce-motion safe.

   NOTE: the pad→BIT tether beam is intentionally NOT part of this engine — it
   is designed as a separate element (bitpad-beam.js).

   Usage:
     <canvas id="padGlow"></canvas>   // sized + positioned in CSS
     BitPadLight.init(canvas, {
       cols, rows,          // low-res cell grid (canvas.width/height)
       cx, cy, rx, ry,      // focus centre + radii, in cells (ry = downward)
       ryUp,                // optional tighter upward radius (default = ry)
       fps,                 // default 14 (chunky)
       tiers                // optional override ramp (defaults to BIT turquoise)
     });
   ========================================================================== */
(function () {
  const BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
  ];
  // BIT turquoise ramp — deep → bright → near-white core (rgb, base alpha)
  const TIERS_DEFAULT = [
    null,
    { c: '26,150,142',  a: 0.24 },   // deep turquoise
    { c: '40,206,194',  a: 0.46 },   // bright turquoise
    { c: '128,240,228', a: 0.70 },   // light turquoise
    { c: '210,255,250', a: 0.88 },   // near-white core
  ];

  function init(canvas, cfg) {
    const ctx = canvas.getContext('2d');
    const COLS = cfg.cols, ROWS = cfg.rows;
    const TIERS = cfg.tiers || TIERS_DEFAULT;
    canvas.width = COLS; canvas.height = ROWS;
    ctx.imageSmoothingEnabled = false;
    const cx = cfg.cx, cy = cfg.cy, rx = cfg.rx, ry = cfg.ry;
    const ryUp = cfg.ryUp || ry;          // tighter upward = floor pool, not a halo up the pillars
    const frameMs = 1000 / (cfg.fps || 14);

    function field(x, y) {
      // radial focus — wide horizontally, asymmetric vertically (pools downward)
      const dx = (x - cx) / rx;
      const dy = (y < cy) ? (y - cy) / ryUp : (y - cy) / ry;
      let v = 1 - Math.hypot(dx, dy);
      if (v < 0.10) v = 0;                 // trim stray far specks
      return v < 0 ? 0 : v;
    }

    function draw(intensity) {
      ctx.clearRect(0, 0, COLS, ROWS);
      for (let y = 0; y < ROWS; y++) {
        for (let x = 0; x < COLS; x++) {
          let v = field(x, y) * intensity;
          if (v <= 0) continue;
          const th = (BAYER[y & 3][x & 3] + 0.5) / 16;
          let q = v * 4, lvl = Math.floor(q);
          if (q - lvl > th) lvl++;
          if (lvl <= 0) continue;
          if (lvl > 4) lvl = 4;
          const t = TIERS[lvl];
          ctx.fillStyle = 'rgba(' + t.c + ',' + t.a + ')';
          ctx.fillRect(x, y, 1, 1);
        }
      }
    }

    const reduce = window.matchMedia &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce) { draw(0.85); return; }

    let flick = 0.85, t = 0, dipUntil = 0, nextDipRoll = 0, last = 0;
    function loop(now) {
      if (!canvas.isConnected) return;   // auto-stop when the canvas is removed
      requestAnimationFrame(loop);
      if (now - last < frameMs) return;
      const dt = (now - last) / 1000; last = now; t += dt;
      // slow breathing fade
      const breath = 0.80 + 0.20 * Math.sin(t * 1.6);
      // flicker: per-frame jitter + occasional brief dropouts
      let target = breath * (0.94 + Math.random() * 0.06);
      if (now > nextDipRoll) { nextDipRoll = now + 90; if (Math.random() < 0.16) dipUntil = now + 50 + Math.random() * 130; }
      if (now < dipUntil) target *= 0.5 + Math.random() * 0.22;
      flick += (target - flick) * 0.55;
      draw(flick);
    }
    requestAnimationFrame(loop);
  }

  window.BitPadLight = { init };
})();
