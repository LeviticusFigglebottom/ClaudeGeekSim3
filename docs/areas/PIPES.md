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
  way, a valve wheel the size of a cartwheel turned as far as it goes (DO
  NOT CLOSE WHILE OCCUPIED), the Usher at the far end.
* **The turning room.** A square room with a tiled block in the middle,
  taller than the room, rising through the ceiling. The block has a doorway
  in its far face, and a stair visible through it. Walk round to it and it
  is not there: it is in the far face again. See below.
* **The tower.** Inside the block: two loops of stair (flights along the
  north and south walls, landings east and west) with a seam at the foot of
  the second loop back to the foot of the first (`pipes_stair_loops`); after
  three rounds it ends. At the top, a platform, a black pedestal with the
  **Dark Glass** (item `dark_glass`, key `picked_dark_glass`), and the
  hatch.

## The turning

`_process` watches which sector of the room the player is in (east, west,
or neither, by the angle round the block's centre). The doorway is on face
`door_face`. When the player comes round into the doorway's sector the
block "turns": the doorway seals on that face and opens on the opposite one
(`Game.bump("pipes_turns")`, a grind). On the sixth turn the wall gives up:
the doorway stays where the player is, `pipes_opened` is set, and the
tower is open from then on (also at build if the flag is set). Toasts mark
the first, second and fourth turns.

Seals are tiled boxes in the doorways whose mesh and collision are toggled
(`_set_solid`). The blank faces are the north and south.

## Declared for the solver

`pipes_turns` (done `pipes_opened`, needs `cistern_drained`), `pipes_stair`
and `pipes_stair_loops` (need `pipes_opened`), `pipes_glass` (done
`picked_dark_glass`, gives `dark_glass`). The verifier builds the area
twice, the second time with `pipes_opened` set.

## Debug

`tools/shot.sh pipes out.png from_cistern "0,-6"` for the shaft room;
`--pos=11,1.6,-4 --look=-90,-6` for hall one; `--pos=-14,1.6,14 --look=90,-4`
for the turning room from the entry; `--flag=pipes_opened --pos=-23,12.2,13
--look=0,-10` for the top of the tower.
