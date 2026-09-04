# The King's Dream

**Status: built.** This document is the spec the area was built to. Two
things were changed by instruction during the build: the way in is the
sleeping King in the Keep (woken, with the tapestry behind him cut, holding
both keepsakes; he hints otherwise), not the stone telephone; and there is
no Anteroom arch back in. The way out still lands beside the Anteroom's
well, at a plain spawn. The code is in `src/areas/kings_dream/`, one file per
square plus `kd.gd` for what the squares share; `tools/brooks_test.gd` walks
every seam under `tools/verify.sh`. Read `docs/AREA_AUTHORING.md` first; everything here assumes its
contract, its yaw convention, its kit and its checklist.

Area id `kings_dream`. Display name **The King's Dream**, subtitle
*"he is dreaming about you"*.

This is a full rewrite. An earlier draft built the area as a giant bedroom
with the other realms growing out of the furniture. **That concept is
scrapped.** Nothing here overlays a room. The area is a fragmented Wonderland.

---

## 1. The thesis

*Through the Looking-Glass*, chapter four. Alice finds the Red King asleep
under a tree and Tweedledee tells her:

> He's dreaming now, and what do you think he's dreaming about? ... About
> *you!* And if he left off dreaming about you, where do you suppose you'd
> be? ... You'd be nowhere. Why, you're only a sort of thing in his dream!

ANTEROOM has already written its half of that, in the pillow of the Keep's
stone bedroom:

> I AM THE ONE ASLEEP. THE KING IS WHAT I LOOK LIKE FROM INSIDE.

So the King's Dream is the Red King's dream, and the player is a thing in it.
Every other realm in the game appears here, but recalled by a sleeping man who
has never been to any of them and has only heard them described. Nothing is
where it was. Everything is somewhere.

**One line:** Wonderland, reassembled out of ANTEROOM's own parts, by someone
with a fever.

## 2. What the area must be

Non-negotiables, in the order they were given:

* **Fragmented.** Not one continuous world. It is built as separate pockets of
  geometry that are made to feel adjacent by seams. The truth of the layout
  and the experience of the layout disagree, on purpose.
* **A fever dream.** Bright, warm, over-saturated, too pleased to see you.
  Nothing threatens you and that is what is wrong with it.
* **Several biomes.** Eight, one per square, each with its own ground, sky
  tint, palette, ambience and weather.
* **Past themes reappear.** Every one of the eighteen registered areas is
  quoted somewhere. The table in §5 is the contract for that; the area is not
  done until every row is built.
* **The largest and most ambitious area in the game.** Targets in §9.
* **The third paper rose is hidden in it**, in a garden, and it is not on the
  critical path.
* **Alice.** Not a pastiche and not a set of references. The *structure* is
  Alice: a chess problem walked from the second square to the eighth, with a
  brook between each square and the scene changing the instant you cross.

## 3. The board

*Through the Looking-Glass* is a chess problem. The countryside is divided
into squares by brooks and hedges, Alice enters as a white pawn on the second
square, and every brook she crosses advances her one square and changes the
world completely. On the eighth square she is crowned; the player is not,
and is asked instead what the cloth means.

That is the whole layout of this area.

* **Eight squares.** Each is a biome, roughly ninety metres across, hedged on
  all four sides.
* **A brook on the far edge of each.** Crossing it is a `SeamlessTeleport`.
  Stepping over a stream is all the player sees. What they do not see is that
  the two banks are hundreds of metres apart in world space and often at
  different heights.
* **The other files of the board are a lie.** Beyond the hedges, in every
  direction, are more coloured squares receding into fog. They are flat
  painted ground with no collision and no way in. The board looks enormous and
  is a corridor.
* **Gliding up reveals a different board.** With the Wings, from the high
  points, the player can see the squares laid out. The arrangement they see is
  not the arrangement they walked.
* **Some brooks run backwards.** Two of the eight lead to a square the player
  has already crossed, entered from a different edge, changed. Both are
  optional and both hold secrets.

Squares are numbered by rank, as in the book: the player arrives on the second
and reaches the banquet on the eighth.

## 4. The eight squares

### Square 2 — The Garden of Live Flowers

*Alice: the flowers that talk, the Red Queen who runs to stay in place, the
gardeners painting the white roses red.*

The arrival square. Warm afternoon light and too many colours. Beds of paper
roses, all folded from pages, all blank, planted in rows. Three thin figures
with brushes are painting them, and have been for a long time; the paint is
the wrong colour and they know it.

The flowers talk, and they are the sleeping faces from the Slow Sea grown on
stems. They give directions and none of the directions agree.

At the centre, a hedge maze. From the ground it is a maze. From the air it is
a word.

**This is where the third rose is.** See §6.

Quotes: the Hollow Wood, the field of the Nowhere House, the Slow Sea.

### Square 3 — The Carriage

*Alice: the railway carriage, the guard who examines her through a telescope,
a microscope and a pair of opera glasses, the chorus of "she must go back as
luggage".*

You cross a brook and you are on a train, moving, and the train is the
corridor of the Halden Arms with the doors numbered on both sides and no end
to it. Somewhere along it, door 5½. It is locked and it is your own front
door and there is a keypad on it.

The guard wants a ticket. There is a ticket dispenser bolted to the wall and
it gives you the same number every time.

The train does not stop. **Freezing time is the only way off**, and the place
you get off between stations is not on the board at all.

Quotes: the Halden Arms, the Waiting Halls, Flat 5½.

### Square 4 — The Wood Where Things Have No Names

*Alice: the wood where she forgets her own name, and walks out of it with a
fawn who runs away the moment they both remember.*

The Hallway, grown into a forest: the same grey walls, but as trunks, in rows,
receding further than the square is wide. Nothing here has a label, including
the interactables, whose prompts are blank while you stand among the trees.
The journal will not write in here.

**The Red King is asleep in the middle of it**, enormous, under a tree, and
two identical figures stand beside him and explain to you, kindly, what you
are. His snoring moves the whole wood in and out like breathing, and crossing
the last stretch to him needs the **Hourglass** to hold the trees still.

This square is the thesis and should be built third or fourth, never last.

Quotes: the Hallway, the Keep of Hours.

### Square 5 — The Shop and the River

*Alice: the sheep's shop where the shelves are always empty wherever she
looks, which turns into a boat, on a river, among rushes that fade the moment
they are picked.*

A tavern that sells nothing. The shelves are full until you look at them.
Behind the bar, the room becomes a boat without transition, and you are on
water that is the Slow Sea's colour and the Cistern's temperature, with tide
marks on the banks at three heights.

Scented rushes grow along the bank. Picking one gives you a rush that fades
before you reach the shore. There is one that does not fade and it is at the
far bank, which needs the **Wings**.

Quotes: the Last Lamp, the Slow Sea, the Cistern.

### Square 6 — The Wall

*Alice: Humpty Dumpty on a high narrow wall, who tells her that a word means
what he chooses it to mean, and who falls.*

A flooded street of the Drowned City, and across it, high up, one wall with
someone very round sitting on it. He explains the words on every sign you have
read in the whole game and every explanation is wrong and internally perfect.

He falls. He always falls. Afterwards all the king's horses and all the king's
men arrive, and they are the Ossuary's bone knights, and they are unhurried,
and they cannot put him together.

The wall is only reachable by **gliding**, and the drop from it is the longest
in the area.

Quotes: the Drowned City, the Ossuary.

### Square 7 — The Tea Table

*Alice: the tea party where it is always six o'clock, because the Hatter
quarrelled with Time and now Time will not do a thing he asks.*

Every clock in ANTEROOM says half past five. This square is why.

A table long enough to vanish into fog in both directions, laid for a great
many more people than are at it, and the whole thing is turning, slowly, so
that the guests never stay with the same cups. There is one empty chair and it
is always one seat ahead of you.

**Freezing time stops the table**, and that is the only way to sit down. What
the guests say when you finally sit is the most important dialogue in the
area, and it should be short.

The Clocktower's keeper is here. So is the Anteroom's instruction to wait.

Quotes: the Clocktower, the Last Lamp, the Anteroom.

### Square 8a — The Croquet Ground and the Trial

*Alice: croquet with flamingos and hedgehogs and no rules anyone will state,
then a trial where the sentence comes first and the verdict afterwards.*

Red ground, red light, the Furnace's heat without its fire. The mallets hang
on hooks. The game has rules and nobody will tell you them, and the score is
displayed on a Waiting Halls number board that only counts up.

Then a courtroom, and someone is on trial, and it takes a while to work out
that it is you, and nobody says so. The jury are shadows at desks. The
sentence is read before the evidence.

**Freezing time during the sentence** is the only way to read the charge.

Quotes: the Furnace, the Waiting Halls, the Ossuary.

### Square 8 — The Eighth Square

*Alice: something heavy settles on her head, she is a Queen, and the banquet
goes wrong until she pulls the tablecloth off the table.*

A rotunda that is the Anteroom, but the twelve doors are all open and all show
static. At the centre, where the well should be, nothing is put on the
player's head: there is no coronation, nobody is there to do it, and the
banquet starts anyway. (An earlier build crowned the player here and left the
Paper Crown on their head, which stopped the King offering the dream again.
That is gone; the dream can be re-entered any number of times.)

The banquet. The candles grow to the ceiling. The food introduces itself.
Everything accelerates. Once it has begun the Usher stands across the table,
the closest he has ever been, and a cable runs from under the cloth at the
player's place to a socket in the wall between two doors. The way out is to
take hold of the cloth and pull, and taking hold of it asks what you mean:

1. **No. Pull the cloth, and go back.** Default. The Anteroom,
   `nexus:from_kings_dream`.
2. **Accept the promotion. Stay on the board, as a piece. (an ending)**
   Asks again, "No" first. The Last Rank, `docs/areas/PROMOTION.md`.
3. **Pull the plug. (an ending)** Asks again. Off Air,
   `docs/areas/STATIC_END.md`.

Before the banquet has begun the cloth is only the way back. See
`docs/ENDINGS.md`.

Quotes: the Anteroom, the Static, the Other Anteroom, the Workshop.

## 5. Coverage: every prior realm, quoted

The area is not done until each of these is built and recognisable.

| Realm | Where it reappears | As what |
|---|---|---|
| Flat 5½ | Square 3 | door 5½ on the train, locked, with a keypad |
| The Halden Arms | Square 3 | the carriage is that corridor, numbered, endless |
| The Hallway | Square 4 | grown into a wood of grey walls, where names stop |
| The Anteroom | Squares 7, 8 | the instruction to wait; the rotunda at the end |
| The Hollow Wood | Square 2 | the garden's trees and the hedge maze |
| The Drowned City | Square 6 | the flooded street under the wall |
| The Last Lamp | Squares 5, 7 | the shop that sells nothing; the tea table |
| The Nowhere House | Square 2 | the field, the mailbox with your number in pencil |
| The Keep of Hours | Square 4 | the Red King himself, and the two who explain him |
| The Slow Sea | Squares 2, 5 | faces on stems; the river's colour |
| The Ossuary | Squares 6, 8a | the king's men who cannot mend him; the jury |
| The Furnace | Square 8a | the croquet ground's heat and hooks |
| The Cistern | Square 5 | the river's tide marks, at three heights |
| The Waiting Halls | Squares 3, 8a | the ticket; the scoreboard that only counts up |
| The Clocktower | Square 7 | the keeper, and why it is always half past five |
| The Static | Square 8 | what is behind all twelve doors |
| The Other Anteroom | Square 8 | the rotunda is subtly the mirrored one |
| The Workshop | Square 8 | one plinth at the banquet, with nothing on it |

## 6. The third rose

In the garden, Square 2, and off the critical path.

Every rose in the beds is paper, folded from a page, and blank. The three
painters are working through them. None of the roses in the beds is the one
you want, and a player who searches the beds will find nothing, which is the
point.

The hedge maze at the centre of the square is a maze from the ground. **From
the air it is a shape**, and the shape tells you where to walk. The Wings are
the only way to see it. Glide over it once, land, walk it, and at the middle
there is one rose that nobody has painted, with writing still on it.

* `Pickup.create(self, ..., {"item": "rose", "name": "MazeRose", "key": "picked_rose_maze", "requires_keepsake": "wings"})`
* Its page is the half missing from the torn book in the castle library, the
  half that was about a king dreaming of a garden.
* Set flag `maze_walked` when the centre is reached, so the journal can record
  it even if the player somehow arrives without the Wings.

Do not put a marker, a light or an aura on the maze entrance. The glide is the
hint and the shape is the answer.

## 7. The Wings and the Hourglass

Both are required to enter and both are required to finish. Neither is
optional anywhere in this area.

**Wings.** Four uses, in ascending difficulty:

1. Square 2, over the hedge maze, to read it. This is the tutorial and must be
   forgiving.
2. Square 5, across the river to the rush that does not fade.
3. Square 6, up to the wall, and the long descent after the fall.
4. Square 8a, across the croquet ground, which is the only crossing that needs
   a flap at the apex.

**Hourglass.** Five uses, each a different verb:

1. Square 3, to get off a moving train.
2. Square 4, to hold the breathing wood still and reach the King.
3. Square 5, to stop the shop's shelves emptying long enough to read one.
4. Square 7, to stop the turning table and sit down.
5. Square 8a, to read the charge before the sentence finishes.

Put every moving thing under `Clockwork` so it freezes for free. Override
`on_time_frozen(frozen)` on the area: when frozen, drop the ambience pitch,
stop all particles, and have every face in the area open its eyes.

## 8. Getting in and out

**In.** The Red King himself, asleep in the Keep's dream bedroom
(`castle.gd`). Once the player has disturbed him (`king_disturbed`) and cut
the tapestry (`tapestry_cut`), talking to him again is the way in:

* Without both keepsakes: he mutters a hint about what is missing (the Wings,
  the Hourglass, or both).
* Holding **Moth Wings** and **Hourglass**: you fall.

The fall is the rabbit hole and is the area's opening shot. Two or three
seconds, drifting past shelves of objects from every realm the player has been
to, arranged like a museum with the labels swapped. Land unhurt on Square 2.

The route is declared in `castle.gd`, where it begins:

```
Puzzle.declare(self, "kings_dream_door", "kings_dream_entered",
    ["keepsake:wings", "keepsake:hourglass", "flag:king_disturbed", "flag:tapestry_cut"],
    ..., {"route": "kings_dream:from_king"})
```

The stone telephone is untouched; there is no arch to the dream in the
Anteroom.

**Out.** Square 8 exits to `nexus:from_kings_dream`: a plain spawn beside the
well, no door. The way back in is the King again.

**Falling.** Off a hedge, off the wall, off the board: `World.fall_out()`,
which already lands the player in the Static. Falling out of the Red King's
dream and landing between channels is correct and needs no new code.

**Waking.** `can_wake` stays `true`. Holding R here should work and should
feel like the wrong thing to do.

## 9. Ambition targets

The area must be the largest in the game. For reference, the current largest
are the Drowned City at 996 lines, the Keep of Hours at 959, and the Slow Sea
at 806, and the widest are the Static at 160 m and the Hollow Wood at 140 m.

| Metric | Current best | Target |
|---|---|---|
| script length | 996 lines | 1600 or more, split into `kings_dream.gd` plus one file per square |
| world extent | 160 m | 900 m along the march, squares 90 m each |
| distinct biomes | 1 per area | 8 |
| readables | 28 (castle) | 40 or more |
| named characters | 10 (tavern) | 12 or more |
| keepsake gates | 2 (city) | 2, used 9 times |

**Split the script.** No other area needs this, but this one will not stay
readable in a single file. Proposed layout:

```
src/areas/kings_dream/kings_dream.tscn
src/areas/kings_dream/kings_dream.gd        # build(), the board, the brooks
src/areas/kings_dream/sq_garden.gd          # square 2
src/areas/kings_dream/sq_carriage.gd        # square 3
src/areas/kings_dream/sq_wood.gd            # square 4
src/areas/kings_dream/sq_river.gd           # square 5
src/areas/kings_dream/sq_wall.gd            # square 6
src/areas/kings_dream/sq_table.gd           # square 7
src/areas/kings_dream/sq_trial.gd           # square 8a
src/areas/kings_dream/sq_eighth.gd          # square 8
```

Each square file is a `RefCounted` with a single static `build(area, origin)`.
The area script owns the brooks, the spawns, the hooks and the doors. Nothing
in a square file may create a spawn or a door.

## 10. Implementation plan

Ordered. Each step ends green under `tools/verify.sh`.

1. **Registry.** Add `kings_dream` to `AreaRegistry.AREAS` with the scene
   path, name, subtitle, `"realm": "kings_dream"` and `"ambience": "sea"` as a
   placeholder. Add the id to the list in `tools/screenshots.sh`.
2. **Realm preset.** Add to `Realm.PRESETS`, tuned warmer and brighter than
   the Slow Sea. Proposed start:
   `{"bg": "#4a2a58", "ambient": "#f0cfc0", "ambient_energy": 1.34, "fog": "#f0cfc0", "fog_density": 0.010, "sun": [-38, -65, "#fff2cf", 0.8], "sky": "sky/sea"}`
   Each square then overrides fog colour and density locally so the biomes
   read differently. Generate `sky/kings_dream` later; `sky/sea` unblocks the
   first pass.
3. **Skeleton and the board.** `kings_dream.gd` with the eight square origins
   laid out far apart, `add_spawn("from_phone", ...)` and
   `add_spawn("from_nexus", ...)`, plus flat ground and a hedge per square and
   nothing else. Walk the whole march. Get the brooks right before any square
   has content in it, because the brooks are the risk.
4. **The brooks.** Eight `SeamlessTeleport` seams, one per square edge, plus
   the two that run backwards. Remember that seam sizes are LOCAL,
   `Vector3(across, height, depth)`, and that the verifier fails a seam
   containing a spawn. Test every brook in both directions.
5. **Square 2, the garden**, complete including the maze and the third rose.
   This is the arrival and it sets the tone for everything, so finish it to
   shipping quality before starting another square.
6. **Square 4, the wood and the Red King.** The thesis. Build it early so the
   area has a point before it has content.
7. **Squares 7 and 3**, the two best Hourglass set pieces.
8. **Squares 5, 6 and 8a.**
9. **Square 8**, the coronation and the banquet, and the exit.
10. **The entrance.** Convert `DreamPhone`, add the `Puzzle.declare`, build
    the fall, add the Anteroom return arch.
11. **Visit 2 and visit 3.** See §12.
12. **Journal notes, ambience, sound.**

### Props to generate

`tools/gen_assets/models_extra.py`. Everything else can be built from the
existing catalogue at unusual scales.

* `chess_pawn`, `chess_queen`, `chess_knight` — white and red tints via
  `Props.place` opts.
* `hedge_block` — a hedge segment, for the maze and the square borders.
* `rose_paper_planted` — a folded paper rose on a stem, for the beds.
* `carriage_seat`, `carriage_window` — the train's interior.
* `egg_large` — the one on the wall.
* `teapot_tall`, `teacup_stack` — the table.
* `mallet_hook` — the croquet mallets, hung.
* `signpost_contradictory` — arrows that disagree.

Already in the catalogue and made for this palette: `arch_pastel`,
`pillar_pastel`, `stair_pastel`, `platform_disc_small/medium/large`, `cloud`,
`moon_face`, `moth_giant`, `mushroom_glow_big`, `mushroom_glow_small`,
`mushroom_pale`, `mushroom_red`, `table_long`, `table_feast`, `chair_white`,
`eye_stalk`, `face_sea_sleep`, `face_sea_awake`, `face_sea_sad`,
`king_sleeping`, `figure_shadow`, `usher`, `statue_knight_bone`, `meat_hook`,
`item_rose`, `ticket_dispenser`, `number_display`, `clock_grandfather`.

### Gotchas specific to this area

* **Seams and gliding.** Crossing a brook while airborne is untested. Put every
  brook on flat walkable ground, hedge the approach so the player cannot glide
  into one, and never place a brook at the end of a glide.
* **Draw distance.** Eight biomes in one scene will be the heaviest area in
  the game. Each square must be its own `Node3D` with `visible` driven by
  which square the player is in, toggled by the brooks. Do not rely on fog.
* **The painted board.** The unreachable squares beyond the hedges are flat
  quads with no collision. Give them `Kit.blocker` fences so a glide cannot
  reach them, and keep them out of the physics world entirely.
* **The verifier probes spawns for ground within 3 m.** Only two spawns exist,
  and both are on real ground.
* **Prompts go blank in Square 4.** That is a deliberate effect on the
  `Interactable` labels in that square only. Do not break the aura system
  doing it; hide the text, keep the glow.

## 11. Secrets

At least six, in the house style. Suggested:

* The word the hedge maze spells is legible from one specific altitude and is
  a different word on the second visit.
* Getting off the train between stations, which is not a square.
* One of the flowers in Square 2 is not a flower and will say so if you stay
  with it long enough.
* The Cheshire grin, done as the Usher: he is in every square, always further
  away, and in Square 8 he is the closest he has ever been.
* The empty plinth at the banquet has a name plate and the name is yours.
* Both backward brooks lead to a square you have crossed, changed by the fact
  that you have crossed it.

## 12. Returning

* **Visit 1.** As described.
* **Visit 2.** The same board, the same order, the same brooks: a player who
  learned the way keeps it. What changes is inside the squares: the maze
  spells a different word, the roses are red, the wood has its names.
* **Visit 3.** The King is not under the tree. The grass holds his shape. The
  two who explain him are still there and are still explaining.

## 13. Definition of done

The `docs/AREA_AUTHORING.md` checklist, plus:

* Reachable and solvable holding the Wings and the Hourglass, proved by the
  route solver.
* Every row of the coverage table in §5 built and recognisable.
* Eight squares, eight biomes, eight brooks, and at least two that run
  backwards.
* The third rose obtainable and genuinely hidden: no marker, no aura on the
  approach, the glide is the only hint.
* Every metric in §9 met.
* No route through the area requires a fall.
