# Authoring an area

Every realm in ANTEROOM is one folder under `src/areas/<id>/` with a scene and a
script:

```
src/areas/forest/forest.tscn   # root Node3D with the script and area_id set
src/areas/forest/forest.gd     # extends AreaBase, builds everything in build()
```

Register it in `src/data/areas.gd` (`AreaRegistry.AREAS`) with a scene path,
display name, subtitle, realm preset and ambience name. The headless verifier
(`tools/verify.sh`) then builds it, checks every door and solves the routes.

## The contract

```gdscript
extends AreaBase

func build() -> void:
    Realm.apply(self, "forest")                  # fog, ambient, sun, sky dome
    ...geometry, props, doors, pickups...
    add_spawn("default", Vector3(0, 0.1, 0), 0.0) # required
    add_spawn("from_nexus", ..., yaw)             # one per door that leads here
```

* `build()` runs once per visit from `_ready()`. Areas are rebuilt every time
  they are entered, so *state lives in `Game` flags*, never in the area.
* `visit_count` (1 on the first visit) and `Game.has_flag()` are how an area
  decides to be a different place the second time.
* Spawn ids are strings. A door in another area that targets you names one of
  them: `Door.create(parent, pos, yaw, "forest", "from_nexus")`. The verifier
  fails if it does not exist.
* Yaw is in degrees around +Y: 0 faces north (-Z), 90 faces west (-X),
  -90 faces east (+X), 180 faces south (+Z). Spawns face the way the player
  will look on arrival.
* Godot front faces are clockwise. The Kit handles that; if you hand-build
  meshes, wind clockwise as seen from the visible side.
* Hooks: `on_enter(spawn_id, n)`, `on_exit()`, `on_bell(origin)`,
  `on_umbrella(open)`, `on_time_frozen(frozen)`, `on_lantern(lit)`,
  `on_mirror_sight(active)`.
* `can_wake = false` for waking-world places (holding R does nothing).

## Building blocks

### Kit (static)
| call | what |
|---|---|
| `Kit.box(parent, centre, size, tex, opts)` | textured solid box; `faces` subset, `tile` size, `solid`, `tint`, `unshaded`, `emission` |
| `Kit.floor / Kit.ceiling(parent, centre, Vector2 size, tex)` | thin slabs |
| `Kit.wall(parent, from, to, height, tex)` | a wall between two ground points |
| `Kit.ring(parent, centre, r_in, r_out, segments, tex, {down})` | discs and rings |
| `Kit.round_wall(parent, centre, radius, height, segments, tex, {gaps})` | circular rooms |
| `Kit.stairs(parent, pos, yaw, width, steps, step_h, step_d, tex)` | flights (negative `step_h` descends) |
| `Kit.ramp`, `Kit.arch`, `Kit.cylinder`, `Kit.terrain(parent, pos, size, res, height_fn, tex)` | more geometry |
| `Kit.water(parent, pos, size, tex)` | animated water plane |
| `Kit.sign(parent, tex, pos, yaw, size)` | a flat picture on a wall |
| `Kit.label(parent, text, pos, yaw, size, color, kind)` | 3D text (kind: title / display / body) |
| `Kit.light(parent, pos, color, energy, range)` / `Kit.sun` / `Kit.spot` | lights |
| `Kit.particles(parent, pos, kind, extent, amount)` | motes, embers, rain, snow, ash, fog |
| `Kit.blocker(parent, pos, size, layer)` | invisible collision |
| `Kit.trigger(parent, pos, size, callable, {once})` | player-entered volume |
| `Kit.lantern_only(node)` / `mirror_only` / `normal_only` / `big_only` | things that exist only under a keepsake |
| `Kit.mouse_gap(parent, pos, yaw)` | a hole only the Tin Mouse fits through |
| `Kit.polar(r, angle_deg, y)`, `Kit.yaw_to_center(angle)` | round-room helpers |

Textures are named `group/name` from `assets/textures` (see the manifest).
Missing ones become magenta checkers, so the game never crashes on a typo.

### MapBuilder
Draw interiors as ASCII. `#` wall, `.` floor, ` ` void, `D` doorway (with a
lintel), `O` open cell (no walls, no lintel — where two room maps meet),
`~` water, `:` open to the sky, any letter/digit = floor + marker.

```gdscript
var m := MapBuilder.build(self, [
    "#########",
    "#..k....#",
    "#...@...D....",
    "#########",
], {"cell": 2.0, "height": 3.0, "floor": "wood/planks_warm", "wall": "wall/plaster_tavern",
    "ceiling": "wood/planks_dark", "origin": Vector3(-9, 0, -4)})
var bar_pos: Vector3 = m.first.call("k")   # floor-level centre of the marker
add_spawn("default", m.first.call("@"), 0.0)
```

Options: `floors {ch: tex}` per-character floor textures, `walls {ch: tex}`
alternate wall characters, `no_ceiling "chars"`, `open_edges`, `door_h`,
`tile`. Thin-walled rooms: build each room as its own map with no `#` cells;
the edges beside void grow 0.3 m walls automatically.

### Props
`Props.place(parent, "tree_oak_1", pos, yaw, scale, {collision: "cylinder"})`
places a generated GLB from `assets/models`. Named parts can be animated:
`Props.part(inst, "Leaf")`, `"Fire"`, `"Screen"`, `"Head"`, `"Hand"`, `"Lid"`.
Run `python3 tools/gen_assets/models.py --list` for the catalogue, or visit
the Workshop in game (ring the bell 13 times in the Anteroom).

### Things to interact with
```gdscript
Door.create(self, pos, yaw, "city", "from_forest", {"kind": "iron", "label": "The gate",
    "requires_keepsake": "lantern", "locked_text": "Too dark to find the latch."})
Pickup.create(self, pos, {"keepsake": "lantern"})            # or {"item": "coin"}
Readable.create(self, pos, yaw, "Read the sign", ["line 1", "line 2"], {"sign": "signs/menu", "sign_size": Vector2(1, 0.75)})
NPC.create(self, pos, yaw, "The Barkeep", {"model": "barkeep", "lines": [...], "reactions": {"crown": [...]}, "on_talk": _riddle})
Interactable.make(self, pos, size, "Pull the chain", func(player, it): ...)
Brazier.create(self, pos, {"index": 0})  ;  Switch.create(...)  ;  Bed.create(...)  ;  Mirror.create(...)
Cuttable.create(self, pos, yaw, size, {"tex": "fabric/tapestry", "flag": "tapestry_cut"})
SeamlessTeleport.create(self, from_pos, from_yaw, to_pos, to_yaw, size)   # non-euclidean seams
SeamlessTeleport.link(self, a_pos, a_yaw, b_pos, b_yaw)                    # two-way loop
LookAway.create(self, pos, func(l): ..., {"delay": 2.0})                   # fires when not looked at
Clockwork.create(self, pos, {"mode": "rotate", "axis": Vector3.UP, "speed_deg": 20})
Usher.spawn(self, pos)  ;  Dog.maybe_spawn(self, pos)
Puzzle.declare(self, "id", "flag_it_sets", ["keepsake:bell", "item:coin"], "hint", {"item": "granted_item"})
```

Doors remember requirements; `unstable` doors take a Callable returning
`[area, spawn]` and must list `possible_targets` for the verifier.

Dialogue: `await World.hud.say("Name", ["..."])`, choices:
`var i: int = await World.hud.ask("Name", "Question?", ["A", "B"])`.
Journal: `Game.note(key, title, text)`. Toasts: `Game.toast.emit("...")`.
Sounds: `Audio.sfx("bell_big", position)`; ambience is chosen by the registry.

### Keepsake hooks that areas should honour
* Lantern: hide inscriptions/paths with `Kit.lantern_only(node)`.
* Bell: override `on_bell(origin)`; NPCs turn toward it automatically.
* Umbrella: `on_umbrella(open)` — start rain, fill a well, wake something.
* Hourglass: put moving things under `Clockwork` and they freeze.
* Mirror Shard: `Kit.mirror_only` / `Kit.normal_only` geometry, `Mirror.create` doors.
* Tin Mouse: `Kit.mouse_gap` openings and `Kit.big_only` blockers.
* Knife: `Cuttable` things; NPCs with `flee_knife`.
* Crown / Wings: check `Game.active_is("crown")` in `on_talk`; put pickups on ledges and set `requires_keepsake: "wings"` on the Pickup so the solver knows.

## Checklist before you call an area done
1. `tools/verify.sh` is green (every door target exists, routes solve).
2. `tools/shot.sh <id> out.png [spawn] [yaw,pitch]` looks like a place, not a box:
   at least three light sources, a floor/ceiling/sky, props with silhouettes, one
   readable thing, one secret.
3. Something happens when you come back (visit_count / flags).
4. A journal note for the thing you are supposed to discover.
