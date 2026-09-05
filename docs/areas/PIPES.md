# The Waterworks

Area id `pipes`. Display name **The Waterworks**, subtitle *"where the water
went"*. Built in `src/areas/pipes/pipes.gd`. Realm preset `pipes` (dark
cyan, heavy fog, the Cistern's sky), ambience `cistern`.

The fourth road's second stretch: under the drain at the bottom of the
Cistern's emptied bath.

## Getting there

Hold all nine keepsakes over the well in the Anteroom (`cistern_drained`).
The Cistern builds dry; at the bottom of the great bath is a drain the size
of a door (`GreatDrainDown`, "Go down the drain") to `pipes:from_cistern`.
The way back is the hatch at the top of the tower, to `cistern:from_pipes`,
a spawn on the bath's bottom beside the drain. Holding R wakes you.

## The place

One rasterised map (1 m cells, 4 m high), the poolrooms aesthetic of the
Cistern carried on:

* **The shaft room.** You arrive under the pipe you came down, which goes up
  through a hole in the ceiling further than the light. Water still comes
  down it.
* **Pipes.** Three corridors drawn as tubes (`_pipe`: a `Kit.round_wall`
  laid on its side inside the corridor, ribbed, with a run of water down the
  bottom; the map's walls keep the collision).
* **Hall one.** White and cyan tile, pillars, a knee-deep channel cut across
  it with planks over it. OUTFLOW and INFLOW on the walls.
* **Hall two, the junction.** Four channels crossing, all flowing the same
  way, tiled on the bottom with water over them, and eight footbridges
  (`_bridge`: warm planks on brass posts with rails and a light) where the
  walks cross the channels, so there is no gap on the way through. A valve
  wheel the size of a cartwheel turned as far as it goes, the Usher at the
  far end. Nothing to read in here or in the turning room: the one label is
  OUTFLOW over the way out, and the looks at the pipe, the channel and the
  pedestal are kept.
* **The turning room.** A square room with a blank tiled block in the
  middle, taller than the room, rising through the ceiling. Nothing on any
  face. See below.
* **The tower.** Inside the block: two loops of stair, each 5 m of rise,
  a flight along the north wall going east, a landing, a flight along the
  south wall going west, a landing, 1.7 m wide at 0.25 m a step (the Kit's
  ramp collider, so they are walked). Each landing reaches the wall on the
  side its flight arrives from and has a sliver behind the next flight's
  foot, so the flights meet with no slot to see down through; the top
  platform stops short of the last flight, which climbs under where it
  would otherwise be. A seam at the foot of the second loop
  back to the foot of the first (`pipes_stair_loops`); after three rounds it
  ends. At the top, a platform, a black pedestal with the **Dark Glass**
  (item `dark_glass`, key `picked_dark_glass`), and the hatch.

## The turning

`_process` keeps the angle of the player round the block's centre and adds
up only the clockwise part of it (`_progress`, degrees; walking back the
other way is not counted and does not undo anything, and after half a turn
the wrong way a toast says so once). After the first full lap the way you
came in is a wall: `entrance_seal`, a tiled box in the doorway from the
junction hall, becomes visible and solid, a grind, and the toast says so.
Toasts again at the second and third laps. At four laps (`LAPS_NEEDED`)
the block gives up: a doorway opens in whichever of its east or west faces
the player is nearer (`door_face`), `pipes_opened` is set, and the tower is
open from then on (also at build if the flag is set: the east face). The
entrance stays sealed; the only way on is up. `tools/verify.sh` does not
walk it; the probe in the session notes did, and it seals at 360° and opens
at 1440°.

Seals are tiled boxes whose mesh and collision are toggled (`_set_solid`):
one in each of the block's east and west faces, one in the room's entrance.
The north and south faces are blank.

## Declared for the solver

`pipes_turns` (done `pipes_opened`, needs `cistern_drained`), `pipes_stair`
and `pipes_stair_loops` (need `pipes_opened`), `pipes_glass` (done
`picked_dark_glass`, gives `dark_glass`). The verifier builds the area
twice, the second time with `pipes_opened` set.

## Debug

`tools/shot.sh pipes out.png from_cistern "0,-6"` for the shaft room;
`--pos=11,0.2,24 --look=0,-10 --fly` for the junction hall and its
footbridges; `--pos=-14,0.2,14 --look=90,0 --fly` for the turning room from
the entry; `--flag=pipes_opened --visits=pipes:2 --pos=-23,0.3,15.5
--look=0,10 --fly` for the foot of the tower stair and `--pos=-23,10.3,15.5
--look=0,-20` for the top.
