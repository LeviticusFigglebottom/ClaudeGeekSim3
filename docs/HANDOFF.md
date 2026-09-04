# Handoff: build the King's Dream

You are picking up an existing, working game with no prior context. Read this
document first and completely. It tells you what the project is, how it is
built, the conventions you must follow, and the one job you have been given.

**Your job: build a new area, `kings_dream`, to the specification in
[`docs/areas/KINGS_DREAM.md`](areas/KINGS_DREAM.md).** That is the whole
assignment. There is no other outstanding work. If you find yourself fixing
something else, it is because it blocks the new area, and you should say so.

Work on the branch `claude/liminal-space-game-5w4if9`. Push with
`git push -u origin claude/liminal-space-game-5w4if9`. Do not open a pull
request unless you are explicitly asked to.

---

## 1. What the project is

**ANTEROOM**, a first-person liminal dark-fantasy dream-exploration game in
**Godot 4.7**, GL Compatibility renderer. You live in a small flat on the
third floor of the Halden Arms. When you sleep you wake in an anteroom of
twelve doors. When you wake, the closet in your bedroom has grown a hallway
longer than the building.

Influences worn openly: *Yume Nikki* for the dream hub and the collectable
"effects", *LSD Dream Emulator* for falling out of worlds into static,
*ENA: Dream BBQ* for the two-toned Usher, *House of Leaves* for the hallway
that measures wrong, and *myhouse.wad* for the house that is a different
house every visit.

Eighteen areas exist and all of them work. The player collects nine
**keepsakes**, each of which is a verb rather than a key. There is no combat,
no failure state except falling out of a dream, and no inventory management.

Read `docs/DESIGN.md` for the pillars and the voice, and `docs/WORLD.md` for
the map of every area, door and secret. Read `docs/AREA_AUTHORING.md` before
you write a line of area code; it is the contract and this document does not
repeat it.

### The nine keepsakes

| Keepsake | Verb | Where it is |
|---|---|---|
| Lantern | light, and reveal `lantern_only` geometry | the hermit's hut, Hollow Wood |
| Small Bell | ring; NPCs turn, doors remember they are doors | the cathedral crypt, Drowned City |
| Paper Crown | be mistaken for someone in charge | the Keep of Hours |
| Hourglass | freeze everything under a `Clockwork` node | the Clocktower |
| Moth Wings | glide by holding jump, flap a limited number of times | the Slow Sea |
| Umbrella | open it; things rain, fill, or wake | the Last Lamp |
| Mirror Shard | see and touch `mirror_only` geometry, stop seeing `normal_only` | the Ossuary |
| Kitchen Knife | cut `Cuttable` things; some NPCs flee | the Furnace |
| Tin Mouse | shrink; pass `big_only` blockers and mouse-holes | the Nowhere House, second visit |

**Your area requires the Moth Wings and the Hourglass** and is unsolvable
without both.

## 2. How to build and check it

```bash
# headless verification: builds every area, checks every door, solves routes
tools/verify.sh                 # must end "0 failures"

# render one area to a PNG with software OpenGL (no GPU needed)
tools/shot.sh <area_id> out.png [spawn] [yaw,pitch] [extra args...]
tools/shot.sh kings_dream /tmp/kd.png default "0,-10" --pos=10,2,0 --give=wings

# the whole visual tour, plus a contact sheet
tools/screenshots.sh                 # all areas
tools/screenshots.sh kings_dream     # one

# run the game (needs a display)
godot --path .
godot --path . -- --area=forest --spawn=from_nexus --no-postfx
```

`tools/ensure_godot.sh` downloads Godot 4.7 into `.bin/` if there is no binary
on the machine. `tools/shot.sh` needs `xvfb-run`.

**Look at the screenshots you render.** They are the acceptance test for this
project, not a nicety. Every area in the game was built by rendering it,
opening the PNG, and fixing what looked wrong. Do the same.

### What the verifier checks

`tools/verify.gd` runs as a *scene* (`res://tools/verify.tscn`) so the
autoloads exist. It will fail your build if:

* a script does not compile or a shader does not load
* a door targets an area or spawn that does not exist
* a spawn is inside solid geometry, or has no ground within three metres
* a `SeamlessTeleport` seam contains a spawn point
* a MapBuilder doorway is blocked by a prop
* a mouse-hole is not crawlable at small-player size
* an area or a keepsake is unreachable from the first sleep by any route
* a `Puzzle` declares a `grants_route` that is not `area:spawn`

and it warns if an item can be gained but nothing ever asks for it.

**A route the verifier cannot see does not exist.** If a way through only
appears after something is counted, declare it:

```gdscript
Puzzle.declare(self, "id", "", [], "human readable hint",
    {"route": "cistern:from_basement"})
```

`tools/verify.sh` also runs an input-driven playtest smoke test. If you add a
new failure mode, add a check for it; that is how this codebase has stayed
correct.

## 3. Layout

```
project.godot           autoloads: Settings, Game, World, Audio
src/core/               game state, world travel, settings, audio director
src/data/areas.gd       AreaRegistry: the single source of truth for areas
src/kit/                Kit (geometry), MapBuilder (ASCII floor plans),
                        Props (GLB placement), Realm (environment presets)
src/world/              area_base, door, pickup, readable, interactable, npc,
                        puzzle, seamless_teleport, mirror, cuttable, clockwork,
                        look_away, usher, dog, aura, bed, brazier, switch
src/player/player.gd    movement, keepsake verbs, interaction
src/ui/hud.gd           title, menus, settings, dialogue, journal, fades
src/shaders/            ps1.gdshader, postfx.gdshader, aura.gdshader
src/areas/<id>/         one folder per area: <id>.tscn and <id>.gd
assets/textures         generated PNGs, named group/name
assets/models           generated GLBs, one per prop
tools/gen_assets/       the Python generators for all of the above
tools/verify.gd         the headless verifier
docs/                   DESIGN, WORLD, AREA_AUTHORING, DEPLOY, ENDINGS,
                        areas/KINGS_DREAM.md
```

An area is registered in `src/data/areas.gd` with a scene path, name,
subtitle, realm preset and ambience. Register it there and the verifier starts
checking it. Add the id to the list in `tools/screenshots.sh` too.

## 4. Conventions you must follow

These are load-bearing. Most of them were learned by getting them wrong.

* **Godot front faces are clockwise.** Verified empirically with
  `tools/winding_probe.gd`. Every wall in the game was once invisible from one
  side because of this. The Kit handles winding for you; if you hand-build a
  mesh, wind clockwise as seen from the visible side.
* **Yaw is degrees around +Y.** 0 faces north, which is -Z. 90 faces west
  (-X). -90 faces east (+X). 180 faces south (+Z). Props, signs and readables
  face -Z at yaw 0, so a picture on the **north** wall gets yaw 180, on the
  **south** wall yaw 0, on the **west** wall yaw -90, on the **east** wall
  yaw 90. Get this wrong and you are looking at the back of everything.
* **`SeamlessTeleport` sizes are in the seam's LOCAL frame:**
  `Vector3(across, height, depth)`, forward being -Z rotated by the yaw. This
  has caused real bugs. The verifier fails a seam that contains a spawn.
* **Areas are rebuilt from scratch on every entry.** `build()` runs once per
  visit from `_ready()`. **State lives in `Game` flags and counters, never in
  the area.** `visit_count` is 1 on the first visit. An area deciding to be a
  different place the second time is the house style, not an exception.
* **Textures are named `group/name`** from `assets/textures`. A typo becomes
  magenta checkers rather than a crash, so check your screenshots.
* **Never let two thin-walled MapBuilder maps share a wall plane.** Prefer one
  map per building.
* **A `D` cell on a map's outer edge must be a single cell.** Two stacked edge
  doorways wall off each other's void side. This bug hid the cathedral crypt
  for a while.
* **Light every room.** At least three sources per space. Several areas
  shipped as black screens because a room had none.
* **Do not stand a prop in a doorway.** The verifier checks this now, but it
  only checks MapBuilder doorways.

## 5. The house style

Read a few areas before you write one. `src/areas/sea/sea.gd` for a dreamlike
outdoor realm, `src/areas/house/house.gd` for a rasterised interior that
changes between visits, `src/areas/cistern/cistern.gd` for a smaller complete
one. Match what you find.

On the writing, which matters as much as the geometry:

* Short declarative sentences. No adjectives doing work a noun could do.
* The game never explains itself and never winks. Nothing is described as
  creepy, eerie, liminal or uncanny.
* Recurring motifs are load-bearing, not decoration. Every clock in the game
  says **half past five**. The player's flat is **5½**. Things are **counted**:
  tiles, steps, names, bells. **Down is the same as down.** **The house is the
  same house.** Water **has been higher than this**. Somebody **tall** is
  standing where you are not looking.
* Every discovery worth making gets a journal note: `Game.note(key, title,
  text)`. The journal is the only place the game is allowed to be explicit.
* Secrets are not marked. The game has an aura system that glows faintly on
  interactables; a genuinely hidden thing is hidden by being somewhere you have
  to think to look, never by being invisible.

## 6. Assets

Props and textures are generated by Python, not hand-authored. To add a prop:

```bash
python3 tools/gen_assets/models.py --list          # the catalogue
# add a builder function to tools/gen_assets/models_extra.py, then
python3 tools/gen_assets/models.py
python3 tools/gen_assets/textures.py
```

The generated GLBs land in `assets/models` and are placed with
`Props.place(parent, "name", pos, yaw, scale, opts)`. Named parts can be
animated with `Props.part(inst, "Fire")` and similar. There is an in-game
gallery of every prop, the Workshop, reached by ringing the Small Bell thirteen
times in the Anteroom, and `tools/shot.sh workshop out.png` renders it.

Before you generate a new prop, check the catalogue. There are already pastel
arches, pillars, stairs, discs and clouds that were made for exactly the
palette your area needs.

## 7. Committing

* Branch `claude/liminal-space-game-5w4if9`, always.
* `tools/verify.sh` green before every commit.
* Commit messages are prose, not bullet lists of file names: say what changed
  and why it was wrong before. Use `git commit -F <file>` for long ones; long
  `-m` strings get mangled by the shell.
* Never put a model name or identifier in a commit message, a PR body, a code
  comment or anything else that is pushed.
* Do not open a pull request unless asked.

## 8. The job

Build `kings_dream` exactly as specified in
[`docs/areas/KINGS_DREAM.md`](areas/KINGS_DREAM.md). Read that document in
full before starting. In summary, so you know what you are getting into:

It is the Red King's dream, from *Through the Looking-Glass*, where the player
is told they are only a thing in someone else's sleep. The structure is the
book's chess problem: **eight biome squares, about ninety metres each, hedged,
with a brook on the far edge of every one.** Crossing a brook is a
`SeamlessTeleport`, so the squares sit hundreds of metres apart in world space
and feel adjacent to walk. The board is fragmented in truth and continuous in
experience. Two brooks run backwards.

Each square is one Alice set piece rebuilt out of ANTEROOM's own parts: the
garden of live flowers, the railway carriage that is the Halden Arms corridor,
the wood where things have no names with the King asleep in it, the shop that
sells nothing and becomes a river, the wall with someone very round on it, the
tea table that finally explains why every clock in the game says half past
five, the croquet ground and the trial, and the eighth square where the Paper
Crown the player is already carrying is put on their head.

A coverage table in the spec names where all eighteen existing realms
reappear. **The area is not done until every row of that table is built.**

The Wings are used four times and the Hourglass five, each a different verb.
The third paper rose is hidden in the first square's hedge maze, which is a
maze from the ground and a shape from the air, so the glide is the only hint
and there must be no marker on it.

**This is meant to be the largest and most ambitious area in the game.** The
current largest is the Drowned City at 996 lines and the widest is the Static
at 160 metres. The spec sets targets above both and asks you to split the
script into one file per square. Do not scale it down.

### Order of work

The spec's §10 gives the full ordered plan. The short version:

1. Register the area and add a realm preset. Get a skeleton verifying green.
2. Build the board and the brooks with nothing in the squares. **The brooks
   are the risk; get them right before any square has content.**
3. Square 2, the garden, complete to shipping quality including the maze and
   the rose. It is the arrival and it sets the tone.
4. Square 4, the wood and the King. It is the thesis.
5. The rest of the squares.
6. The entrance: convert the stone telephone in `castle.gd`, declare the
   route, build the fall, add the Anteroom return arch.
7. Second and third visit variants, journal notes, ambience.

Render screenshots at every step and look at them.

## 9. Things that are not your job

* **Endings are undesigned and are not yours to design.** `docs/ENDINGS.md`
  records one decided rule and marks the rest open. Do not invent endings, do
  not build the well descent, do not give the Paper Rose or the Candle Stub a
  use. Your area produces the third rose and stops there.
* There is no roadmap and no backlog. Known imperfections that are not worth
  your time: some faces on the Slow Sea are flat sprites, round moving
  platforms use box collision, the Drowned City's main street does not flood
  on the third visit, and the fog is a sprite rather than volumetric. Leave
  them alone unless one blocks you.
* Do not refactor working areas. If the Kit is missing something your area
  needs, add it to the Kit rather than working around it, and say so.
