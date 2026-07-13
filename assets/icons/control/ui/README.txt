IRONBIT — UI ICONS (approved set)
=================================

Pixel-arcade replacements for the generic glyphs across Home, Quests,
Settings, the workout-complete screen, and the session summary. Same
treatment as the indicator icons and class emblems: muted core +
emissive rim + soft bloom, crisp 4px read.

All PNGs are 384×384, transparent, pixel-art. Scale by integer
multiples (×2/×3) or re-export from "UI Icons.html" in the project root.

WHAT WAS APPROVED  (role  ->  file)
-----------------------------------
 1. Mission footnote star ........ icon_mission_star.png        (amber spark)
 2. Quests nav tab ............... icon_nav_quests.png          (waypoint, rest)
                                   icon_nav_quests_active.png   (waypoint, active)
 3. Daily-quest bullet ........... icon_quest_bullet.png        (check slot, idle)
                                   icon_quest_bullet_done.png   (check slot, complete)
 4. Guild nav tab ................ icon_nav_guild.png           (banner, rest)
                                   icon_nav_guild_active.png    (banner, active)
 5. Body Metrics setting ......... icon_body_metrics.png        (trend)
 6. Suggested loads setting ...... icon_suggested_loads.png     (barbell + nudge)
 7. About setting ................ icon_about.png               (info frame)
 8. Sessions nav tab ............. icon_nav_sessions.png        (battle log, rest)
                                   icon_nav_sessions_active.png (battle log, active)
 9. Session complete ............. RETIRED — the medal was replaced by the
                                   seated BIT companion (session ceremony
                                   handoff); the PNG was deleted.
10. Session logged .............. icon_session_logged.png      (check spark)
11. Next program ................ icon_next_program.png        (signpost)

COLOR LANGUAGE
--------------
Mission star / Session complete .. amber  #FFD700  (reward / earned)
Nav tabs (rest) / quest bullet ... muted  #9A9AC8  on #2E2E50 core
Nav tabs (active) / lit states ... neon   #00FF9C  (the tap-target color)
Settings / logged / next ......... neon   #00FF9C

The "_active" / "_done" variants are the SAME glyph re-tinted neon for
the lit state. Swap between rest and active by changing the asset, OR
tint the rest PNG at runtime — see below.

WHERE / HOW TO IMPLEMENT
------------------------
Sizes below are the on-screen target; assets are 384px so they stay
crisp at any of these. Keep `image-rendering: pixelated` (web) /
`FilterQuality.none` (Flutter) so edges stay sharp.

 1. MISSION FOOTNOTE STAR — 16px, leading the "Time-only XP awarded…"
    line on the mission card. Replaces the lone amber star.

 2. QUESTS NAV TAB — 24px in the bottom nav. Use icon_nav_quests.png at
    rest, icon_nav_quests_active.png when the Quests tab is selected.

 3. DAILY-QUEST BULLET — 18px, leading each quest card in DAILY QUESTS.
    Use icon_quest_bullet.png while incomplete (0/1); switch to
    icon_quest_bullet_done.png when the quest hits its target.

 4. GUILD NAV TAB — 24px bottom nav. icon_nav_guild.png at rest,
    icon_nav_guild_active.png when selected. (Replaces the shield.)

 5. BODY METRICS — 18px on the settings row, left of the title.

 6. SUGGESTED LOADS — 18px settings row. (Replaces the trophy, which
    misread as "reward"; this says "weight suggestion".)

 7. ABOUT — 18px settings row, left of "About".

 8. SESSIONS NAV TAB — 24px bottom nav. icon_nav_sessions.png at rest,
    icon_nav_sessions_active.png when selected.

 9. SESSION COMPLETE — retired. The Workout Complete screen now seats the
    live BIT companion (72px) where the medal glyph used to render.

10. SESSION LOGGED — 16px, leading the "Session logged." confirmation
    on the session summary. Must stay legible small — it's tuned for it.

11. NEXT PROGRAM — 16px, leading "NEXT FULL BODY B · in 2 days".

FLUTTER (recommended — single asset per state)
----------------------------------------------
    Image.asset(
      'assets/icons/ui/icon_nav_quests.png',
      width: 24, height: 24,
      filterQuality: FilterQuality.none,   // keep pixels crisp
    )

  For active nav tabs / completed bullets, swap the asset:
    final asset = selected
        ? 'assets/icons/ui/icon_nav_quests_active.png'
        : 'assets/icons/ui/icon_nav_quests.png';

  Add the folder to pubspec.yaml:
    flutter:
      assets:
        - assets/icons/ui/

WEB / HTML
----------
    <img src="assets/icons/ui/icon_about.png"
         width="18" height="18"
         style="image-rendering:pixelated" alt="">

  Rest → active without a second asset (tint the muted glyph neon) is
  possible via a CSS/canvas recolor, but the baked "_active" PNGs are
  simpler and match the design exactly — prefer those.

RE-EXPORTING / EDITING
----------------------
Geometry lives in ui-icons/renderer.js + ui-icons/defs-1..3.js. The
export page ui-icons/export.html re-renders every approved icon to a
384×384 transparent canvas. To regenerate or add a state, edit the cell
function for that icon and re-run the export.

NOT chosen (left in "UI Icons.html" for reference): the alternate
options per role (e.g. scroll/pennant for Quests, trophy/laurel for
Session Complete). Open that file to compare or switch a pick.
