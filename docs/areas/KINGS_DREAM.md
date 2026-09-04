# The King's Dream

**Status: designed, not built.** This document is the spec. No code for this
area exists yet. Read `docs/AREA_AUTHORING.md` first; everything here assumes
its contract, its yaw convention and its checklist.

Area id `kings_dream`. Display name **The King's Dream**, subtitle
*"he is what you look like from inside"*.

---

## 1. Premise

The Keep of Hours already tells you what this place is. Behind the throne
tapestry, up a stair into the sky, there is a stone copy of the bedroom of
Flat 5½ hung from nothing by chains, and the words slept into its pillow read:

> I AM THE ONE ASLEEP. THE KING IS WHAT I LOOK LIKE FROM INSIDE.
> IF THEY WAKE HIM IT IS ME THEY WAKE. LET HIM HAVE HIS HOUR.

So the King is the player, seen from the inside, and his dream is the player's
dream about themselves. That single fact decides the whole area: it is not a
new world, it is **every world already in the game, remembered wrong by
someone asleep.**

The place is your own bedroom at roughly fifty times scale, adrift in a
rose-and-gold sky, with the rest of ANTEROOM growing out of the furniture like
mould. You are small in it. Everything is soft, bright, and slightly too
pleased to see you.

**The one-line pitch:** the Slow Sea's palette and whimsy, the Nowhere House's
dread, at the scale of a child under the bed.

## 2. Tone

Take the Slow Sea as the reference for colour and for how nonsense is played
straight, then bend it. The Sea is *serene* nonsense. This is **fever**
nonsense: the same soft palette, but everything is a little too large, a
little too fond of you, and it repeats.

Rules for the writing in this area:

* Nothing threatens you. That is what is wrong with it.
* Every object in the dream is something you have already seen somewhere else
  in the game, at the wrong size or made of the wrong material. A player who
  has been everywhere should recognise a dozen things. A player who has not
  should still feel the place is quoting something.
* Motifs to reuse, in roughly this order of frequency: **half past five**,
  **counting** (tiles, steps, names), **the same house**, **the tall one**,
  **water that has been higher than this**, **nobody drowned**, **down is the
  same as down**, **five and a half**.
* Nothing in this area ever says the word *nightmare*. The dream is having a
  lovely time.

## 3. Where it sits in the world

**Entrance.** The stone telephone in the castle's dream bedroom
(`castle.gd`, `DreamPhone`). It currently reads *"You do not pick it up. It
would be somebody asking to be woken."* Convert it from a `Readable` to an
`Interactable`:

* Without both keepsakes: the existing lines, unchanged.
* Holding **Moth Wings** and **Hourglass** in the inventory: a third line, and
  answering it travels to `kings_dream:from_phone`.
* Set flag `answered_the_phone`.

This is the right door because it is already written, it is already deep in
optional content, and picking up a ringing phone in a dead man's bedroom is
exactly the tone.

**Second entrance, return only.** Add a thirteenth arch to the Anteroom keyed
on flag `visited_kings_dream`, in the style of the existing `cistern` entry in
`nexus.gd`. Locked text: *"A door the colour of the inside of your eyelids."*

**Exits.**

* `kings_dream` → `castle:from_dream` (wake the way you came, down the phone).
* `kings_dream` → `nexus:from_kings_dream`.
* Falling off the furniture calls `World.fall_out()`, which already lands the
  player in the Static. Do not add a floor. **Falling is the failure state and
  it is diegetic**: you fell out of the dream.

**Gating.** Both the Wings and the Hourglass are required to enter, and the
area is unsolvable without both. Declare it so the route solver knows:

```
Puzzle.declare(self, "kings_dream_phone", "answered_the_phone",
    ["keepsake:wings", "keepsake:hourglass"],
    "answer the stone telephone in the King's dream bedroom",
    {"route": "kings_dream:from_phone"})
```

Put that declaration in `castle.gd`, not here, because that is where the route
begins.

## 4. The shape of the place

Nine regions. Each is a piece of furniture from Flat 5½ at giant scale, and
each has quietly become one of the realms. Build them as islands in the sky
with sheer drops between them; the only connective tissue is gliding.

| # | Region | The furniture | What it has become | Gate to reach it |
|---|---|---|---|---|
| 1 | **The Counterpane** | the bed, blankets as terrain | the Hollow Wood: the blanket's weave grown into a low forest of thread-trees | arrival, no gate |
| 2 | **The Sleeper** | the King himself, asleep under the blanket | a landscape that breathes. Ridge of the shoulder, valley of the arm | walk from 1 |
| 3 | **The Wardrobe** | the wardrobe, a tower on its back | the Keep of Hours: banners inside, one coat many times | **Wings** |
| 4 | **The Desk** | the desk, a plateau | the Waiting Halls in miniature: a cubicle farm the size of a chessboard, staffed | **Wings** |
| 5 | **The Basin** | the washbasin | the Cistern: a bowl of still water with tide marks inside it | **Hourglass** (the tap) |
| 6 | **The Clock** | the alarm clock, cathedral-sized | the Clocktower. Its hands are the bridges | **Hourglass** |
| 7 | **The Window** | the window, showing snow | the Static, seen from inside a television | **Wings** + **Hourglass** |
| 8 | **The Rug** | the rug, a plain far below the bed | the Drowned City: its pattern is a street map, flooded | **Wings**, descending |
| 9 | **The Garden Under the Bed** | the gap beneath the bed frame | a garden. Dust for pollen. Paper roses | **Wings**, descending past 8 |

The player arrives on the Counterpane, which is safe, large and walkable, and
can see all nine regions from it. **Everything else is a decision.**

### Traversal

The sky between islands is empty. Standard jump distance never crosses it.
Glide distance does, but only just, and the Wings' flaps are limited
(`Player.MAX_FLAPS`), so each crossing should be tuned to need **one glide and
at most one flap**. Land the player slightly below their launch point every
time: the dream is always sinking.

## 5. The Wings gates

Four crossings, in ascending difficulty:

1. **Counterpane → Wardrobe.** A straight glide with a wide landing. This is
   the tutorial; make it impossible to miss and impossible to die on.
2. **Wardrobe → Desk.** Requires one flap at the apex. The Desk is smaller.
3. **Desk → Window.** Long, and the window sill is narrow. Combined with an
   Hourglass gate, see below.
4. **Counterpane → Rug → Garden.** A long controlled descent down the outside
   of the bed frame, past the Rug, into the dark under the bed. Falling here
   is the most likely fall in the game, so put a wide ledge two thirds of the
   way down as a checkpoint.

Set `requires_keepsake: "wings"` on any `Pickup` that sits on the far side of
a glide, so the route solver understands the gate.

## 6. The Hourglass gates

The Hourglass sets `Game.time_frozen` and every `Clockwork` node freezes with
it. Four uses, each a different verb:

1. **The clock hands are bridges.** The minute hand sweeps. Frozen, it is a
   walkway from the Clock to the Window. Build it with
   `Clockwork.create(..., {"mode": "rotate", "axis": Vector3.UP})` and let the
   player stand on it. Unfrozen, standing on it carries you round and
   eventually off, which is a fall.
2. **The moth stream.** A ring of `moth_giant` props orbiting between the
   Desk and the Basin. Frozen, they are stepping stones. This quotes the Slow
   Sea's moth directly and is the prettiest gate.
3. **The tap.** The basin's tap runs. Frozen, the falling water is a solid
   glass column you can climb. Nothing else in the game turns water into
   architecture; make this the memorable one.
4. **The turning over.** Periodically the whole world tilts, because the
   sleeper turns over. Implement as a slow root rotation on a `Clockwork`
   parent covering regions 1 and 2 only, with a hard ceiling of about eight
   degrees so it reads as unease and not as a physics puzzle. Freezing time
   mid-tilt holds the world at an angle, which is the only way to reach one
   ledge on the Sleeper's shoulder. Warn with sound before every tilt.

`on_time_frozen(frozen)` is the area hook. When frozen, drop the ambience
pitch, stop the particles, and have every face in the area open its eyes.

## 7. The garden, and the third rose

Under the bed. Reached only by the descent in §5.4, and it should feel like a
mistake to go there.

* Grey-gold light from nowhere. Dust motes as pollen
  (`Kit.particles(..., "motes", ...)`). The floor is the underside of the
  world: floorboards seen from below, with the Nowhere House's between-walls
  crawlspace visible as a lit slot in the distance, unreachable.
* **Beds of paper roses**, all folded from pages, all blank. `item_rose` at
  various scales, scattered as props with no collision.
* **One rose has writing on it.** That is the third Paper Rose:
  `Pickup.create(self, ..., {"item": "rose", "name": "GardenRose", "key": "picked_rose_garden"})`.
  Its page is the missing half of the torn book in the castle library, the
  half that was about a king dreaming of a garden.
* **The Usher is the gardener.** He is on his knees with his back to you,
  doing something gentle, and he does not vanish when you look at him. This
  is the only place in the game where the tall one is not a threat, and it
  should be more unsettling than any of his appearances. He has three lines
  and will not turn round.
* A `gravestone_blank` at the far end of the beds, with nothing on it yet.
  This is the hook for the fifth-name thread in `docs/ENDINGS.md`; the
  `gravestone_you` prop already exists for its solved state.

## 8. Inhabitants

* **The King**, asleep, region 2. `king_sleeping` at enormous scale. His hand
  lies open on the counterpane and is reachable on foot. Putting a rose in it
  is an `Interactable` and is the trigger for the Gardener ending.
* **The Usher**, region 9, as above.
* **The Dog**, region 1, if `dog_friend`. He is the only thing here that is
  the right size, and he is delighted. Use `Dog.maybe_spawn`.
* **The Cubicle Staff**, region 4, six `figure_shadow` props at one tenth
  scale, seated, all facing a tiny NOW SERVING display that reads 5½.
* **The Faces**, scattered. Reuse `face_sea_sleep` / `face_sea_awake` from the
  Slow Sea, and open their eyes when time is frozen.
* **No hostiles.** There are none in ANTEROOM and there should be none here.

## 9. Returning

`visit_count` behaviour, in the house style:

* **Visit 1.** As described.
* **Visit 2.** The furniture has been rearranged, the way a room is when you
  dream it twice. Shuffle the island positions with a fixed permutation, not
  a random one, so it is reproducible. One region is missing entirely and the
  gap where it stood has a `gravestone_blank` in it.
* **Visit 3.** The King is not in the bed. The blanket holds his shape. Every
  clock in the area reads twenty-five to six.

## 10. What the area grants

| Grant | Where | Requires |
|---|---|---|
| flag `visited_kings_dream` | automatic on arrival | — |
| item `rose` (third) | the garden | wings |
| flag `garden_found` | entering region 9 | wings |
| flag `king_given_rose` | the King's hand | three roses |
| note `kings_dream_garden` | the garden | — |
| note `the_gardener` | seeing the Usher garden | — |

No keepsakes. The nine are complete and this area comes after them.

## 11. Implementation plan

Ordered, each step independently verifiable with `tools/verify.sh`.

1. **Registry.** Add `kings_dream` to `AreaRegistry.AREAS` with scene path,
   name, subtitle, `"realm": "kings_dream"`, `"ambience": "sea"` as a
   placeholder until a track exists. Add `kings_dream` to the area list in
   `tools/screenshots.sh`.
2. **Realm preset.** Add to `Realm.PRESETS`. Proposed values, tuned from the
   `sea` preset toward gold:
   `{"bg": "#3a2450", "ambient": "#e8c4d8", "ambient_energy": 1.30, "fog": "#e8c4d8", "fog_density": 0.011, "sun": [-35, -70, "#fff0c8", 0.75], "sky": "sky/sea"}`
   Generate a `sky/kings_dream` texture later; `sky/sea` is close enough to
   start and keeps the first pass unblocked.
3. **Scene and script skeleton.** `src/areas/kings_dream/kings_dream.tscn` and
   `.gd` extending `AreaBase`. `add_spawn("default", ...)`,
   `add_spawn("from_phone", ...)`, `add_spawn("from_nexus", ...)`. Verify
   green with nothing but the Counterpane built.
4. **Region 1 and 2.** `Kit.terrain` for the counterpane with a height
   function that reads as folded cloth, and the sleeping King on top of it.
   These two carry the arrival, so get them looking finished before anything
   else. Screenshot from four angles.
5. **The sky and the drops.** No floor anywhere else. Confirm
   `World.fall_out()` fires and lands in the Static.
6. **Regions 3, 4 and 8**, the three pure Wings islands, and tune the glides.
   Test with `tools/shot.sh kings_dream out.png default 0,-20 --give=wings`.
7. **Regions 5, 6 and 7** and the four Hourglass gates. The tilt is the
   riskiest piece; build it last of the three and cap the angle hard.
8. **Region 9**, the garden, the third rose, the Usher.
9. **The entrance.** Convert `DreamPhone` in `castle.gd`, add the
   `Puzzle.declare` for the route, add the Anteroom return arch.
10. **Visit 2 and visit 3 variants.**
11. **Journal notes, ambience, and the endings hooks** in
    `docs/ENDINGS.md`.

### Props to generate

Everything can be built from the existing catalogue at unusual scales, with
these exceptions worth adding to `tools/gen_assets/models_extra.py`:

* `blanket_fold` — a soft ridge for terrain detail on the counterpane.
* `rose_bed` — a clump of folded paper roses, for scattering in the garden.
* `clock_alarm_big` — a bedside alarm clock, since the Clocktower's parts are
  the wrong silhouette at this scale.
* `thread_tree` — a tree made of one loop of thread, for the Counterpane
  forest.

`arch_pastel`, `pillar_pastel`, `stair_pastel`, `platform_disc_*`, `cloud`,
`moon_face`, `moth_giant`, `item_rose`, `gravestone_blank` and
`gravestone_you` already exist and were made for exactly this palette.

### Gotchas specific to this area

* **Scale breaks the PS1 vertex snap.** The wobble shader snaps in view space,
  so very large flat surfaces close to the camera crawl. Break the counterpane
  into many smaller quads via `Kit.terrain`'s resolution rather than a few
  huge ones.
* **Gliding over a `SeamlessTeleport` is untested.** Do not use seams here.
  Every crossing is real geometry over real emptiness.
* **The verifier probes spawns for ground within 3 m.** Every spawn must be on
  an island, not in the air.
* **The tilt must not move spawn points or doors.** Put only regions 1 and 2
  under the tilting parent, and keep the phone door out of it.
* `can_wake` stays `true`. Holding R here should work, and should feel like
  the wrong thing to do.

### Definition of done

The `docs/AREA_AUTHORING.md` checklist, plus:

* Reachable and solvable holding exactly the Wings and the Hourglass, proved
  by the route solver.
* No route through the area requires a fall.
* Nine regions, each recognisably quoting a realm the player has been to.
* The third rose obtainable, and the two ending hooks firing.
