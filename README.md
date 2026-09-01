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
**F12** screenshot.

The game autosaves when you change areas. There is one save slot
(`user://anteroom_save.json`).

```
# run (needs Godot 4.7; put the binary at .bin/godot or on PATH)
godot --path .

# jump straight into an area for testing
godot --path . -- --area=forest --spawn=from_nexus --no-postfx
```

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
docs/                    DESIGN, WORLD (the map of everything), AREA_AUTHORING, ROADMAP
```

## Documentation

* [`docs/DESIGN.md`](docs/DESIGN.md) — pillars, the look, the systems.
* [`docs/WORLD.md`](docs/WORLD.md) — every area, every connection, every keepsake and its route.
* [`docs/AREA_AUTHORING.md`](docs/AREA_AUTHORING.md) — how to add a realm in an afternoon.
* [`docs/ROADMAP.md`](docs/ROADMAP.md) — what the next iterations are for.

## Licence notes

Fonts in `assets/fonts` are under the SIL Open Font License (see the OFL-*.txt
files). Everything else in this repository was generated for this project.
