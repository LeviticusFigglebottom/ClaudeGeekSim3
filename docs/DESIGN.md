# Design

## Pillars

1. **Places before plot.** The game is a set of places to be in. Text is short
   and rare; the journal fills itself in. Nothing is explained twice.
2. **Doors, not levels.** Everything is reachable from everything else if you
   know which door, and the doors remember what you have done. Backtracking is
   the content: a place you have visited is never quite the same place.
3. **The house is wrong in small ways.** Non-euclidean tricks are used sparingly
   and precisely: a corridor that repeats once, a room that is larger than its
   walls, a stair that goes down three times. The player should be able to
   *prove* something is wrong (the tape measure) rather than just feel it.
4. **Keepsakes change how the world treats you**, not how you fight it. There
   is no combat. The knife cuts tapestries and conversations.
5. **Charm over fidelity.** PlayStation-era rendering, chunky props, saturated
   sombre palettes, one colour identity per realm.

## The look

* 3D is rendered at one third of the window (426×240 at 720p) in a SubViewport
  and upscaled with nearest filtering. A post-process adds ordered dithering,
  a gentle vignette and faint scanlines (`src/shaders/postfx.gdshader`).
* Surfaces use `ps1.gdshader`: vertex snapping to a coarse grid, mild affine
  texture warping, nearest sampling, optional alpha scissor, tint, emission and
  vertex colour. Sky domes are gradient textures sampled by elevation.
* Textures are 64 px (surfaces) or 128 px (pictures, signs), quantised to ~12
  levels per channel with Bayer dithering. Each realm has a palette in
  `tools/gen_assets/textures.py` (`P`).
* Props are low-poly GLBs with vertex colours and named materials that the Kit
  restyles (`tex:` textured, `glow:` emissive, otherwise lit vertex colour).
* Lighting is mostly point lights with warm/cold contrast plus per-realm fog.
  Realms are deliberately dark; light sources are placed like set dressing.

## The systems

| system | file | notes |
|---|---|---|
| state | `src/core/game.gd` | flags, counters, keepsakes, items, visits, journal; JSON save |
| travel | `src/core/world.gd` | `travel(area, spawn)`, wake, fall-out; areas rebuild on entry |
| player | `src/player/player.gd` | first-person; glide/flap, shrink, crouch, lantern, cull-mask and collision-mask driven by keepsakes |
| interaction | `src/world/interactable.gd` | Area3D on the Interact layer; raycast from the camera |
| doors | `src/world/door.gd` | requirements, unstable targets, walk-through, opens the leaf |
| non-euclid | `seamless_teleport.gd`, `look_away.gd`, `clockwork.gd` | seams keep velocity and view; look-away triggers; clockwork stops with the Hourglass |
| building | `src/kit/*` | Kit geometry, ASCII MapBuilder, Realm presets, Props |

### Keepsakes (Yume Nikki's effects)

| keepsake | passive | active (F) |
|---|---|---|
| Lantern | reveals lantern-only geometry and inscriptions (visual layer 2, physics layer 10) | light / snuff |
| Moth Wings | glide while holding jump; up to three flaps | — |
| Tin Mouse | — | shrink: fit through mouse gaps (BigOnly blockers on layer 5 stop the full-size player) |
| Paper Crown | NPCs and statues react | — |
| Small Bell | — | ring: `Game.bell_rung`; NPCs turn, areas override `on_bell` |
| Kitchen Knife | NPCs with `flee_knife` | cut `Cuttable` things |
| Umbrella | — | open: areas override `on_umbrella` (rain, wells fill) |
| Hourglass | — | freeze every `Clockwork` |
| Mirror Shard | — | look through: mirror-only geometry appears, normal-only disappears; `Mirror` doors open |

### Verification as design tool

`tools/verify.gd` instantiates every area headlessly and reads the Door, Pickup,
Puzzle, Bed and Mirror nodes to solve the world as a graph. This keeps the
"routes that require backtracking" honest: the solver starts with nothing and
must be able to reach every area and every keepsake. When you add a lock, you
add a key somewhere the solver can find, or the build fails.

## Voice

Second person, present tense. Short sentences. Understated. The world is
tired rather than hostile. Warmth is allowed, briefly, and mostly about the dog.
