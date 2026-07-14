/* ============================================================================
   coffer-paint.js — the code-painted HAUL CACHE (Option B "Banded Coffer").
   Pixel-by-pixel into a 28x20 native buffer; blit at an INTEGER scale only,
   nearest-neighbour. This is the web reference for the Flutter CustomPainter.

   ⚠ SCALE RULE: only ever draw at an integer multiple of 28x20 with
   imageSmoothingEnabled=false (Flutter: FilterQuality.none, isAntiAlias:false).
   A non-integer upscale shatters the pixel grid — code-paint instead of scaling.

   Usage:
     const off = COFFER.bake('none');     // 'none' | 'tracer' | 'maze' | 'iron'
     const cv  = COFFER.blit(off, 2);     // 56x40 canvas, integer x2
     document.body.appendChild(cv);

   Dissolve / fabricate (see IMPLEMENTATION.md) drive a Set of dropped 2x2
   blocks; pass it to blit() to render a partial coffer.
   ============================================================================ */
const COFFER = (function () {
  const NW = 28, NH = 20;

  // pad metal family (sampled from bit_pad.png) + magenta gem (sampled from gem.png)
  const C = {
    OUT:'#0b0c16', D2:'#15172a', D1:'#212439', M:'#2e3150',
    L1:'#3d4262', L2:'#525879', L3:'#6b72a0',
    gDk:'#961c8c', gMid:'#e028a0', g:'#ff4dcd', gHi:'#ff96e6'   // gem ramp: deep facet -> mid -> core -> highlight
  };

  // route-seal tints (the latch gem). 'none' = the magenta currency itself.
  const ROUTE = {
    none:   { dk:'#961c8c', md:'#ff4dcd', hi:'#ff96e6' },
    tracer: { dk:'#1c6e92', md:'#2bb2dc', hi:'#aeeeff' },
    maze:   { dk:'#5e2a9c', md:'#B14DFF', hi:'#E0B8FF' },
    iron:   { dk:'#8e1430', md:'#FF2D55', hi:'#FF93A9' }
  };

  function P(ctx) {
    return {
      px:(x,y,c)=>{ ctx.fillStyle=c; ctx.fillRect(x,y,1,1); },
      rect:(x,y,w,h,c)=>{ ctx.fillStyle=c; ctx.fillRect(x,y,w,h); },
      h:(x,y,w,c)=>{ ctx.fillStyle=c; ctx.fillRect(x,y,w,1); },
      v:(x,y,h,c)=>{ ctx.fillStyle=c; ctx.fillRect(x,y,1,h); }
    };
  }

  // beveled metal block: outline + fill, top/left lit, bottom/right shadowed
  function bevelBox(p,x,y,w,h,fill,lit,shade,top){
    p.rect(x,y,w,h,C.OUT); p.rect(x+1,y+1,w-2,h-2,fill);
    p.h(x+1,y+1,w-2,top||lit); p.v(x+1,y+1,h-2,lit);
    p.h(x+1,y+h-2,w-2,shade);  p.v(x+w-2,y+1,h-2,shade);
  }

  // 2x2 faceted magenta gem (highlight TL, core TR/BL, deep facet BR)
  function gem(p,x,y){ p.px(x,y,C.gHi); p.px(x+1,y,C.g); p.px(x,y+1,C.g); p.px(x+1,y+1,C.gDk); }

  // route-tinted seal plate: recessed dark plate + glowing gem core
  function sealPlate(p,cx,cy,rt){
    p.rect(cx-3,cy-3,6,7,C.OUT); p.rect(cx-2,cy-2,4,5,C.D2); p.h(cx-2,cy-2,4,C.D1);
    p.px(cx-1,cy,rt.md); p.px(cx,cy,rt.hi); p.px(cx+1,cy,rt.md);
    p.px(cx-1,cy-1,rt.dk); p.px(cx,cy-1,rt.md); p.px(cx+1,cy-1,rt.dk);
    p.px(cx-1,cy+1,rt.dk); p.px(cx,cy+1,rt.md); p.px(cx+1,cy+1,rt.dk); p.px(cx,cy+2,rt.dk);
  }

  // OPTION B — BANDED COFFER : stepped top + slat vents bleeding gem-light
  function paintCoffer(p,rt){
    bevelBox(p,2,12,24,7,C.M,C.L1,C.D2);              // wide base
    bevelBox(p,5,6,18,7,C.M,C.L2,C.D1,C.L3);          // stacked top tier
    p.h(5,12,18,C.D2);                                 // step seam shadow
    bevelBox(p,7,12,3,7,C.L1,C.L3,C.D2);              // strap L
    bevelBox(p,18,12,3,7,C.L1,C.L3,C.D2);             // strap R
    for (let i=0;i<4;i++){ const sx=8+i*3;             // slatted vents w/ magenta gem-bleed
      p.v(sx,8,3,C.OUT); p.px(sx+1,8,C.gDk); p.px(sx+1,9,C.g); p.px(sx+1,10,C.gMid); }
    sealPlate(p,14,15,rt);                             // route latch
    gem(p,11,4); gem(p,14,3); gem(p,16,4);             // gem spill over the rim
    p.px(13,5,C.gHi); p.px(18,5,C.g); p.px(10,5,C.gDk);
  }

  // build order for the COLLECT dissolve / homecoming fabricate (bottom rows first)
  const BUILD = [];
  for (let by=9; by>=0; by--) for (let bx=0; bx<14; bx++) BUILD.push(bx+','+by);

  function bake(routeKey){
    const off = document.createElement('canvas'); off.width=NW; off.height=NH;
    const ctx = off.getContext('2d'); ctx.imageSmoothingEnabled=false;
    paintCoffer(P(ctx), ROUTE[routeKey] || ROUTE.none);
    return off;
  }

  // blit at an integer scale. `dropped` (optional Set of "bx,by" 2x2 blocks)
  // renders a partial coffer for the dissolve / fabricate.
  function blit(off, scale, dropped){
    const cv = document.createElement('canvas');
    cv.width = NW*scale; cv.height = NH*scale;
    const ctx = cv.getContext('2d'); ctx.imageSmoothingEnabled=false;
    if (!dropped){ ctx.drawImage(off,0,0,NW,NH,0,0,NW*scale,NH*scale); return cv; }
    for (let y=0;y<NH;y++) for (let x=0;x<NW;x++){
      if (dropped.has((x>>1)+','+(y>>1))) continue;
      ctx.drawImage(off, x,y,1,1, x*scale,y*scale, scale,scale);
    }
    return cv;
  }

  return { NW, NH, C, ROUTE, BUILD, P, bevelBox, gem, sealPlate, paintCoffer, bake, blit };
})();
if (typeof module !== 'undefined') module.exports = COFFER;
