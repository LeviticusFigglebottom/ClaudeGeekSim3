# ANTEROOM

*a dream of doors*

A liminal, dark-fantasy exploration game built on **Godot 4.7**. You live in a
small flat on the third floor of the Halden Arms. When you sleep you wake in an
anteroom of twelve doors. When you wake, the closet in your bedroom has grown a
hallway that is longer than the building.

Influences worn openly: *Yume Nikki* (dream hub, collectable "effects",
wordless wandering), *LSD Dream Emulator* (falling out of worlds, the static
between them), *ENA: Dream BBQ* (the two-toned Usher), *House of Leaves* (the
hallway that measures wrong, the five-and-a-half minutes) and *myhouse.wad*
(the house that is a different house each time you visit, the backwards door,
the bathroom that is too big).

![the Anteroom](screenshots/nexus.png)

## Playing

Controls: **WASD** move · mouse look · **E** interact · **F** use the held
keepsake · **Tab / Q** cycle keepsakes · **Space** jump (and glide, with the
wings) · **C** crouch · **J** journal · **hold R** to wake up · **Esc** pause ·
**F11** fullscreen · **F12** screenshot.

The game autosaves when you change areas, into one of **three save slots**
(`user://anteroom_save_<n>.json`); a new dream picks an empty slot, or asks
before it takes a used one. **Settings** (Esc or the title screen) has sliders
for how much PS1 the picture has — pixel dither, vertex wobble, texture warp,
pixel size, colour depth — the glow on things you can use, plus mouse speed,
volume and fullscreen; they live in
`user://settings.json`, apart from the saves. The title screen drifts through
the realms behind the menu.

```
# run (needs Godot 4.7; put the binary at .bin/godot or on PATH)
godot --path .

# jump straight into an area for testing
godot --path . -- --area=forest --spawn=from_nexus --no-postfx
```

## The realms

Seventeen areas, each built in code from the same kit (see `docs/WORLD.md`
for the full graph and `docs/AREA_AUTHORING.md` for how to add one):

| | |
|---|---|
| **Flat 5½** and **the Halden Arms** | the waking world: a small flat, a corridor that goes round, a lift that is not a lift |
| **The Hallway** | the closet that measures wrong (House of Leaves) |
| **The Anteroom** | twelve doors, a plaque, a bell, a well that counts what you carry |
| **The Hollow Wood** | giant trees, standing stones, a hermit with a lantern |
| **The Drowned City** | streets that wrap, a cathedral with four bells, a palace of stone knights |
| **The Last Lamp** | a tavern with a riddle, a bard, and a back door that goes somewhere different every time |
| **The Nowhere House** | a different house each visit (myhouse.wad): mirrored, then bigger, then wrong |
| **The Keep of Hours** | a sleeping king, rooms that turn, a library with no end |
| **The Slow Sea** | a pastel shore under a colour-shifting sky, sleeping faces, platforms that drift |
| **The Ossuary** | skull corridors, a reflecting pool, paths only the lantern shows |
| **The Furnace** | below the below: a pit of slow fire, a chained giant, a choir of shadows |
| **The Cistern** | poolrooms: white tile, cyan tile, knee-deep water, a voice reading aloud |
| **The Waiting Halls** | a yellow office where your number is never called until it is |
| **The Clocktower** | a spiral of steps and two great gears; every hour is the same hour |
| **The Static**, **the Other Anteroom**, **the Workshop** | between channels; the mirror side; every prop on a plinth |
| **The King's Dream** | eight hedged squares joined by brooks that are seams, every realm above quoted by a sleeping man who has only heard them described; in through the woken King, out through a tablecloth |

## Verifying without a screen

Everything can be checked headlessly, which is how the project is developed:

```
tools/verify.sh            # downloads Godot 4.7 into .bin/ if needed, imports,
                           # compiles every script, builds every area, checks
                           # every door target and spawn, solves the route
                           # graph (can every keepsake be reached from the
                           # first sleep?), round-trips a save file
tools/shot.sh forest out.png from_nexus "0,-6"   # render one view (Xvfb + Mesa)
tools/screenshots.sh       # render every area into screenshots/tour/
```

`tools/verify.gd` runs as a scene so the autoloads exist. It exits 1 on any
failure and prints a line per area (spawns, doors, pickups, puzzles). The
GitHub Actions workflow in `.github/workflows/verify.yml` runs the same thing
and uploads a screenshot tour rendered with software OpenGL.

## Playing it in a browser

The project exports to WebAssembly and deploys to Vercel as static files —
same game, same renderer, same verification gate:

```
tools/export_web.sh        # verify, then build build/web/ (~43 MB)
tools/serve_web.sh         # preview at http://localhost:8060
node tools/verify_web.mjs  # boot it in a real browser, screenshot it, check for errors
```

`vercel.json` has the build wired up already: import the repository on Vercel,
pick *Other* as the framework, and deploy. The build machine fetches Godot and
— using HTTP range requests against Godot's 1.3 GB template archive — only the
10 MB of web export template it actually needs. Threads are on, so the page is
served cross-origin isolated; the headers for that are in `vercel.json`, and
`web/_headers` carries them for other static hosts. See `docs/DEPLOY.md`.

## Assets are generated

There are no hand-drawn files in the repository. Every texture, model and
sound is produced by the Python pipeline in `tools/gen_assets/` and committed:

```
python3 -m pip install pillow numpy
python3 tools/gen_assets/textures.py --sheet   # 200+ PS1-style tileable textures
python3 tools/gen_assets/models.py             # 240+ low-poly GLB props
python3 tools/gen_assets/audio.py              # ambience loops + sound effects
```

Generators are deterministic (seeded by name), so re-running produces
byte-identical output. Change a palette in `textures.py`, re-run, and every
area that uses it changes. See `docs/DESIGN.md` for the art direction.

## Layout

```
project.godot            Godot 4.7, GL Compatibility renderer
src/core/                Game (state, keepsakes, journal, save), World (travel), Audio
src/main/                Main scene: low-res SubViewport upscale + dither post-process
src/player/              first-person controller and keepsake behaviours
src/ui/                  HUD, dialogue, journal, title, pause; theme from bundled OFL fonts
web/                     browser loading screen and static-host headers
src/kit/                 Kit (geometry/materials), MapBuilder (ASCII interiors),
                         Realm (environment presets), Props (GLB placement)
src/world/               Interactable, Door, Pickup, Readable, NPC, Puzzle, Brazier,
                         Switch, Bed, Mirror, SeamlessTeleport, LookAway, Clockwork,
                         Cuttable, Usher, Dog
src/areas/<id>/          one folder per realm (scene + build script)
src/data/areas.gd        the area registry (single source of truth for the verifier)
src/shaders/             PS1 surface shaders, sky dome, water, static, mirror, post-fx
assets/                  generated textures, models, audio; fonts (OFL)
tools/                   verification, screenshots, asset generators
docs/                    HANDOFF (start here), DESIGN, WORLD (the map of
                         everything), AREA_AUTHORING, ENDINGS, areas/
```

## Documentation

* [`docs/HANDOFF.md`](docs/HANDOFF.md) — start here if you are picking the
  project up: what it is, how to build and verify it, the conventions, and the
  one piece of work outstanding.
* [`docs/DESIGN.md`](docs/DESIGN.md) — pillars, the look, the systems.
* [`docs/WORLD.md`](docs/WORLD.md) — every area, every connection, every keepsake and its route.
* [`docs/AREA_AUTHORING.md`](docs/AREA_AUTHORING.md) — how to add a realm in an afternoon.
* [`docs/areas/KINGS_DREAM.md`](docs/areas/KINGS_DREAM.md) — the specification
  for the King's Dream, a Wonderland of eight squares; `KINGS_MIND.md`,
  `PROMOTION.md` and `STATIC_END.md` beside it cover the areas past it.
* [`docs/ENDINGS.md`](docs/ENDINGS.md) — the three ends that exist as choices,
  the one outlined, and what is open.

## Licence notes

Fonts in `assets/fonts` are under the SIL Open Font License (see the OFL-*.txt
files). Everything else in this repository was generated for this project.
