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

Two rasterised maps (1 m cells, 3 m high, the upper one 3.2 m up), a
hundred metres by eighty. Green paint to shoulder height, white above,
fluorescent tubes that flicker once anything has been found.

Downstairs: the **lobby** (reception desk with the **visitors' book**,
waiting chairs, a lift that is always coming, the way back down, a clock),
the **stairwell** at its east end, the **main corridor** the width of the
building with WARD A, WARD B, QUIET PLEASE, NURSES and PHARMACY off it,
**wards A and B** (twelve iron beds each, curtains, drip stands; more of the
beds have a shape under the sheet the more has been found), the **chapel**
(benches, a lectern, a window that shows night, a shape worn into the back
bench), the **nurses' station** (two desks, a phone, a clock at half past
five, a chart with one name and one room), the **pharmacy**, the **spine**
running south from the main corridor to the far door, the **back
corridor** with the **morgue** (drawers, a sheet over a shape with a hat
under it), the **theatre** (a table under a lamp, nothing on it, water on
the floor), the **X-ray room** (a lightbox with one film), the
**children's ward** (small beds, wallpaper, a pawn and a king on the
floor) and the **laundry**, then the **far corridor** and **room 5½**.

Upstairs, by the stairwell: the same corridor and the same two wards
(C and D), the **records** room over the chapel with the file, and a stair
to a **roof** door that does not open. The upstairs corridor's west end is
a seam (`FloorSeam`, counted as `hospital_floor_loops`) back to the
downstairs corridor's west end, so going along it far enough puts you
downstairs without a stair; the third time through it the tall one is
there.

## The memories

Six **memory fragments** (`_memory`: a photograph turning slowly on the
spot with a light on it, item `memory`, one flag each, `memories` counted)
are hidden about the building and all six must be found:

| Key | Where |
|---|---|
| `memory_desk` | under the reception desk in the lobby |
| `memory_drawer` | the first drawer in the morgue |
| `memory_lectern` | on the lectern in the chapel |
| `memory_sink` | in the sink in the theatre |
| `memory_bed` | under a small bed in the children's ward |
| `memory_file` | in the file on the desk in records, upstairs |

Each one found says what it was (a day, in order), writes a note, and
about a second later the tall one is in front of you. At four the building
goes dark: the tubes drop to almost nothing and red emergency lights come
up (`_go_dark`, also at build once four are held). At six, `memories_all`:
the area reloads in place (`World.reload_here("far")`) with the door at the
end of the spine, which was a wall under VISITING HOURS ARE OVER, now a
door, and the far corridor and room 5½ behind it.

## The far corridor

Past the door, a corridor with water on the floor and 5½ scratched at the
end of it. It goes round twice (`hospital_loops`, a seam at x 86 back to
x 54) before the room's door is where the scratch was.

## The jumpscares

`_scare(pos, size)` is a one-shot trigger (five in the corridors, one of
them upstairs) and `LookAway` catches in the chapel's back row and the
laundry fire the same thing: `_scare_now` puts the `usher` prop 1.5 m in
front of the player, facing them, lit, with a static burst at full volume
and a heartbeat and a grey flash of the fade layer, for 0.7 s, then removes
it. Every memory picked up fires it too, after 1.2 s, and so does the
third pass through the floor seam. `usher_scares` is counted; the first
writes a journal note.

## The ending: waking up

Room 5½: the bed, the one in it half under the sheet with the King's face
and half in the coat with yours (`usher_king`), the chair with M's shape in
it, three roses in the vase, a set showing static. "The one in the bed"
(`BedLook`) says what is there: the body as the ward sees it and the one
who has been walking, one person, and that lying down is the two halves
agreeing, which from the outside is called waking up. Then it asks "Lie
down. (the ending: waking up)", "No" first, asks again, and plays the
`whole` ending (`ending_whole`) through the stub in `src/core/ending.gd`:
the set finds a channel, the tone from the machine changes, somebody sits
down in the chair and says your name, and you open your eyes. Declared as
`hospital_whole`, needs `memories_all`. This is the fourth road: regaining
consciousness. `docs/ENDINGS.md`.

## Debug

`tools/shot.sh hospital out.png from_mirror "180,0"` for the lobby;
`--pos=40,0.2,-23.5 --look=90,0 --fly` for the main corridor and
`--pos=40,3.4,-23.5` for the one upstairs; `--pos=22,0.2,-19.5 --look=0,20
--fly` for the nurses' clock; `--pos=8,3.4,-11 --look=0,0 --fly` for
records; `--flag=memories_all --visits=hospital:2 --pos=42,0.2,27
--look=180,5 --fly` for room 5½ (the far spawn is `far`). The coplanar
audit (`tools/coplanar.tscn -- --area=hospital`) is clean. The verifier
builds the area three times, the second and third with `memories_all`.

Note `_c(x, z, y)`: the height is the third argument.
