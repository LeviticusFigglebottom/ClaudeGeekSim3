# The King's Mind

Area id `kings_mind`. Display name **The King's Mind**, subtitle *"everything
he has been told"*. Built in `src/areas/kings_mind/kings_mind.gd`.

## Getting there

1. In the Ossuary, light the candles for the four names (`ossuary_names`)
   so the crypt's gate opens. On the plinth in the crypt is one black Candle
   Stub; there are three more (the iron maiden in the Furnace, the chest in
   the Castle, the wall room in the Nowhere House). All four back on the
   plinth and the three niches give up their **Bones** (flag
   `crypt_candle_placed`, item `bones`).
2. Strike the anvil in the Furnace carrying the bones: they break into
   **Bonemeal** (flag `bonemeal_made`, item `bonemeal`).
3. On top of the pink tower in the Garden of Live Flowers (the King's Dream,
   square 2) there is a sprout where the arch used to be. Fed the bonemeal it
   grows into a beanstalk with a stair of leaves round it (flag
   `beanstalk_grown`; the dream rebuilds at spawn `hilltop`). The leaf at the
   top is a door.
4. The door comes out on the top of the same stalk, above the dream:
   spawn `from_beanstalk`. The way back is the same stalk (`kings_dream:hilltop`).

The route is declared on the sprout (`dream_beanstalk`, route
`kings_mind:from_beanstalk`, requires `item:bonemeal`).

## The place

* **A forest of beanstalks** standing in a sea of cloud with nothing under it.
  Five have tops you can walk on, joined by leaves you walk along; the rest
  are scenery. Every top and every leaf has an invisible wall along its
  edges, so the only way off is the way on. Falling anyway lands in the
  Static (`FALL_LIMIT`).
* **The keep.** Walls of grey matter (`organic/brain`), a plate at the gate:
  HIS MAJESTY IS NOT RECEIVING. Inside, two floors of labyrinth whose walls
  are bookshelves (`wood/book_wall`): everything he has been told, shelved by
  who told him. The mazes are perfect mazes carved from the area's seeded
  rng, so they differ per run and always solve. A stair in the north hall
  joins the floors; the upper hall has a well cut in it for the stair.
* **The bedroom**, the width of the keep at the south end of the upper floor.
  The Red King as he is: no crown, no colour, under a sheet (`king_coma`).
  A vase on a stool by the bed.

## The vase

Interacting with the vase holding a Paper Rose puts it in (item `rose`
taken, `roses_placed` counted, a planted rose appears in the vase). The three
roses are in the castle library, under the tavern floor (the Tin Mouse), and
the hedge maze of the Garden (the Wings). After the third, flag
`roses_all_placed`: he has stopped dreaming about you and is waiting.

## The King, and M

"The King" (`KingLook`) is a look before the third rose. After it, it asks
"Sit with him. (an ending)", "No" first, then asks again, and plays the `m`
ending (`ending_m`): the chair by the bed has a shape worn into it and the
shape is yours. You were M all along, the visitor who read to him and
brought the roses one at a time; you sign the book on the way out with one
letter. Finished as a choice; its scene is not made yet (`docs/ENDINGS.md`).
Declared as `kings_mind_m`, requires `flag:roses_all_placed`.

## Hints

The Barkeep's new "A rumour" option in the Last Lamp gives the next step of
this thread, sideways, keyed to what the player holds and has done.

## Debug

`tools/shot.sh kings_mind out.png from_beanstalk` for the stalks;
`--pos=0,10.05,-80 --look=0,0` for the gate; the bedroom is at about
`(0, 14.6, -84)`. `--flag=bonemeal_made,beanstalk_grown` for the dream side.
