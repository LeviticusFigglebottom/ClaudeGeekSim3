# St. Nowhere

Area id `hospital`. Display name **St. Nowhere**, subtitle *"visiting hours
are over"*. Built in `src/areas/hospital/hospital.gd`. Realm preset
`hospital` (pale green, fog that thickens with each visit), ambience
`offices`.

The end of the fourth road. Above the Other Anteroom with its roof off, up
the platforms, through a door.

## Getting there

1. The Dark Glass from the top of the Waterworks (`docs/areas/PIPES.md`).
2. Hold it up to the mirror in the Keep's bedchamber. The mirror opens
   somewhere else (`Mirror` opts `alt_item`/`alt_area`; flag
   `mirror_open`) onto `mirror_nexus:open`.
3. The Other Anteroom builds without its roof when `mirror_open` is set: a
   stair of fifty slabs round the wall and up (`_spiral`, 0.4 m a step, so
   it is walked, not jumped) to a landing above the wall and a door, "Up,
   into the next one", to `hospital:from_mirror`. The way back is the door
   in the lobby's north wall to `mirror_nexus:top`.

## The place

One rasterised map (1 m cells, 3 m high). Green paint to shoulder height,
white above, fluorescent tubes.

* **The lobby.** Reception desk with the **visitors' book**; waiting chairs;
  a ticket dispenser; a lift that is always coming; the way back down.
* **The main corridor**, with WARD A, WARD B, QUIET PLEASE and NURSES off it.
* **Wards A and B.** Ten iron beds each with curtains and drip stands. More
  of the beds have a shape under the sheet each visit.
* **The chapel.** Benches, a lectern, a window that shows night, and a shape
  worn into the back bench that is the shape from the chair by the King's
  bed.
* **The nurses' station.** A chart: one name, one room, 5½, one visitor,
  over and over.
* **The back corridor**, the **theatre** (a table under a lamp, nothing on
  it), and, from the second visit, the **morgue** (a sheet over a shape with
  a hat under it, drawers all labelled with the same letter).
* **The far corridor** past VISITING HOURS ARE OVER, and **room 5½**.

## Visits

The area is meant to be visited more than once (`visit_count`), and is
worse each time.

| Visit | What is different |
|---|---|
| 1 | Clean and lit. The far door is a wall with the sign over it. Sign the visitors' book (`hospital_book_read`): every line is room 5½ and one letter, M, in your hand. |
| 2 (book signed) | Some tubes flicker. Water on the back corridor's floor and in the theatre. The morgue door is open. The far door is a door: the corridor beyond goes round twice (`hospital_loops`, seam at x 62 back to x 46) and ends at a wall with 5½ scratched in it and breathing behind it. Two jumpscares. |
| 3 | The door in that wall. Room 5½: the bed, the one in it half under the sheet and half in the coat (`usher_king`), the chair with your shape, three roses in the vase, the set showing static. Four jumpscares. |

## The jumpscares

`_scare(pos, size)` is a one-shot trigger; `_scare_now` puts the `usher`
prop 1.6 m in front of the player, facing them, with a static burst and a
heartbeat and a grey flash of the fade layer, for just over half a second,
then removes it. `usher_scares` is counted; the first writes a journal note.
The end of the far corridor's second loop also fires one.

## The ending

"The one in the bed" (`BedLook`) in room 5½ says what is there, then asks
"Lie down. (an ending)", "No" first, then asks again, and plays the `whole`
ending (`ending_whole`) through the stub in `src/core/ending.gd`. Its
scene, like the others', is not made. Declared as `hospital_whole`, needs
`hospital_book_read`.

## Debug

`tools/shot.sh hospital out.png from_mirror "180,-6"` for the lobby;
`--pos=-3,1.6,-10.5 --look=90,-4` for the main corridor;
`--visits=hospital:2 --flag=hospital_book_read --pos=8,1.6,9.5 --look=-90,-4`
for the far corridor; `--visits=hospital:3 --flag=hospital_book_read
--pos=28,1.6,20 --look=0,-12` for room 5½ (check `--visits` in
`src/main/main.gd`).
