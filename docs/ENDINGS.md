# Endings, and the ledger they read

**Status: designed, not built.** This is the spec for the ending system and
for the three collectible threads that feed it. None of it exists in code yet
beyond the pieces noted as *already in* below.

The principle: **the ending is not chosen from a menu and is not a score
threshold.** Each thread of optional content unlocks its own ending, so what
you explored decides how the game ends. Finishing every thread unlocks one
more that none of them can reach alone.

---

## 1. The three threads

### Thread A: the candles

**Where the candles are today.** Two different things share the word:

*Interactive, and part of a puzzle.* Four in the Ossuary chapel, one at each
gravestone along the north wall, in `catacombs.gd`. The names and their
column order are `[[5, "morrow"], [7, "elspeth"], [11, "halden"], [13,
"annis"]]`, and the puzzle wants them lit in the order `halden, annis,
morrow, elspeth`. The hint reads, verbatim, *"light the candles for the four
names in the order they went down the well."* Solving it sets flag
`ossuary_names`.

*The Candle Stub, an item.* Black wax, lit from both ends and the middle.
Four separate sources, and **nothing in the game asks for it** —
`tools/verify.sh` warns about it by name:

| Source | File | Gate |
|---|---|---|
| the chest in the castle bedchamber | `castle.gd:888` | none |
| the crypt in the Ossuary | `catacombs.gd:356` | flag `ossuary_names` |
| the room between the walls, Nowhere House | `house.gd:467` | Tin Mouse |
| the iron maiden in the Furnace | `furnace.gd:408` | opening it |

*Decorative only.* Thirty-four `candle`, `candle_tall` and `candle_cluster`
props across the city, castle, tavern, catacombs, furnace, forest, clocktower,
house and Anteroom. These are scenery and should stay scenery.

**The design.** Halden is the building the player lives in. M., the second
handwriting in the Nowhere House journal, is Morrow. Four people went down the
well; the altar has a candle for each; there is no fifth candle because nobody
wrote the fifth name.

Add a **fifth holder** to the Ossuary altar, empty, unremarked. Placing the
Candle Stub in it and lighting it is the whole thread. It requires the four
names already lit, so the thread is: solve the order, find a stub, come back.

* New flag `fifth_candle`.
* The `gravestone_blank` at the chapel's end becomes `gravestone_you`, a prop
  that already exists in the catalogue and has been waiting for this.
* The well in the Anteroom gains a fourth state. It currently ends on *"It is
  not open yet. Something is still missing, and it is not a thing."* The
  missing thing is a name.

### Thread B: the paper roses

**Two exist today**, and like the stub, nothing consumes them:

| # | Where | File | Gate |
|---|---|---|---|
| 1 | deep in the castle library loop, on a lectern | `castle.gd:675` | walking the loop |
| 2 | on a table under the tavern floor | `tavern.gd:548` | Tin Mouse |
| 3 | **the garden under the bed** | `kings_dream.gd`, unbuilt | Wings |

The third is specified in `docs/areas/KINGS_DREAM.md` §7. Each rose is folded
from a page; the castle's torn book says the page was about a king dreaming of
a garden. Three roses put into the sleeping King's open hand is the Gardener
ending.

Track them with a count rather than a boolean, since `rose` is one item id
with three sources. Use `Game.item_count("rose")`, and give each pickup a
distinct `key` so a save cannot double-count one.

### Thread C: the Nowhere House introspections

The house has six optional branches. Each already ends in a piece of writing
about the player rather than about the house, and each currently gives
nothing. **Give each branch one small item**, and call the set the
introspections. They are not keepsakes, have no verb, and cannot be equipped;
they exist to be counted.

| Branch | How you get there | Proposed item | The line it turns on |
|---|---|---|---|
| the backwards room | walk into the `?` door backwards | **a pencil stub** | THIS ROOM IS NOT ON THE PLAN. NEITHER ARE YOU. |
| between the walls | Tin Mouse through the skirting | **the candle stub** *(already in)* | PLEASE DO NOT TAKE MORE THAN ONE. |
| the endless bathroom | third visit | **a counted tile** | You stop at four hundred. The wall does not. |
| the child's corridor | second visit, four loops | **a milk tooth** | the child's bed |
| the attic | return the photograph | **a photograph of the porch with nobody on it** | Not yet. |
| the basement | walk down three times | **a pipe label** | DOWN IS THE SAME AS DOWN. |

Six items, flag `introspections_all` when the count reaches six. This is the
thread that rewards the player who treated the Nowhere House as the puzzle box
it is, and it is deliberately the hardest of the three to complete because it
spans three visits and two keepsakes.

## 2. The endings

Five, plus the true one. All of them are reached from the bottom of the well
in the Anteroom, except the Gardener, which is reached in the King's Dream and
is the only one that does not require the nine keepsakes.

| # | Ending | Requires | What happens |
|---|---|---|---|
| 1 | **Let him have his hour** | nothing | The default. Leave, or wake for the last time. The King sleeps on, the flat is the flat, the clock says half past five. |
| 2 | **The Gardener** | three roses, in the King's hand | He stops dreaming the Keep and dreams the garden instead. Every realm keeps its shape but the light goes gold. Not an exit; a change of world. |
| 3 | **The Fifth Name** | nine keepsakes, `fifth_candle` | The well opens because it now knows who is asking. You go down. |
| 4 | **The Same House** | nine keepsakes, six introspections, the torn page, the photograph returned | You understand the house was always the flat. You wake in the Nowhere House and the Nowhere House is Flat 5½. |
| 5 | **Nobody Drowned** | nine keepsakes, and never having fallen out of a dream, `Game.stats.falls == 0` | The Lifeguard's four hundred days. A quiet, hard, hidden ending for a careful player. Do not hint at it anywhere except the log. |
| 6 | **Half Past Five** | everything above in one run | The clock moves. One minute. Nothing else in the game has ever moved. |

Ending 6 is the point of all of it. Every clock in ANTEROOM reads half past
five: the grandfather clock in the Nowhere House hall, the great clock in the
Keep, the clock in the Waiting Halls, the keeper's ledger and the clock face
in the Clocktower, the sign in the flat. The Keep already teases it once, in
`castle.gd`: *"It has moved. One minute. Nobody wound it."* The true ending is
that the tease was true, and you are the one who wound it.

## 3. The descent

Shared by endings 3 to 6. Specified here rather than in a separate area doc
because it should be built as an extension of `nexus.gd`, not a new area.

Once the well opens, its rim grows a ladder. The shaft has **nine landings,
one per keepsake**, and at each landing something in the dark is glad to have
one and takes it. By the bottom the player is carrying nothing, which is how
they started, and it is the only place in the game that empties the inventory.

* Take them in acquisition order, not a fixed order, so the descent reads as
  the player's own route played backwards.
* No puzzle on the way down. Just the ladder, the nine hands, and the sound.
* At the bottom, the room is **the bathroom of Flat 5½, from underneath**.
  You come up through the floor into the tub, whose tide marks match the
  Cistern's. The deepest room in the world is the smallest room in the flat.
* The endings differ only in what is in that bathroom, and only ending 6
  changes the clock.

Getting a keepsake back to finish an ending means climbing for it, which makes
choosing an ending an act instead of a menu.

## 4. Implementation plan

Each step is independently shippable and independently verifiable.

1. **The ledger.** A small module, `src/core/ledger.gd`, that answers
   `roses()`, `candles()`, `introspections()`, `keepsakes()` and
   `ending_available(id)` by reading `Game` flags and item counts. Nothing
   else should compute an ending's availability. Add it as an autoload only if
   it needs signals; otherwise keep it static.
2. **The verifier learns about endings.** Extend the orphan-item check in
   `tools/verify.gd` into an endings check: every ending must be reachable on
   some route, reported the way keepsakes already are. This is what stops an
   ending from silently becoming impossible when an area changes.
3. **Thread A**, the fifth candle. Smallest and most self-contained: an empty
   holder on the Ossuary altar, an interaction gated on `ossuary_names` and
   the Candle Stub, the flag, the gravestone swap, and the well's fourth
   state. Ship this first; it clears one of the two orphan-item warnings and
   it makes the well's existing text pay off.
4. **Thread C**, the six introspections. Six pickups in places that already
   exist, plus the count flag. No new geometry.
5. **The King's Dream**, per `docs/areas/KINGS_DREAM.md`. This is the large
   one and it delivers the third rose.
6. **Thread B**, the roses in the King's hand, and ending 2.
7. **The descent**, and endings 1, 3, 4, 5.
8. **Ending 6**, and the clock change. Every clock in the game reads from one
   place after this, so add `Game.the_hour` and have all of them ask it.

### Notes for whoever builds this

* Endings must be replayable. Set a flag per ending seen, show them in the
  journal, and let the player climb back up.
* Do not gate an ending on a random door. The tavern back door is the only
  random thing in the game and nothing important should sit behind it.
* Ending 5 depends on `Game.stats.falls`, which resets with the save. Confirm
  it survives a load before building the ending on it.
* Keep every requirement readable from the journal. A player should be able to
  work out what they missed without a wiki, and the journal is the only place
  the game is allowed to be explicit.
