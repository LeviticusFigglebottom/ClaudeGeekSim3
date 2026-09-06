# The endings

Area id `ending`, hidden: no door leads to it. `src/areas/ending/ending.gd`
builds one of four scenes, chosen by `Game.ending_kind` (set by
`Ending.play`) and, when the game arrives, by the spawn name: `whole`,
`limbo`, `unplugged`, `m`. `src/core/ending.gd` sets `ending_<kind>`,
counts `endings`, says the last words at the place of choosing, writes the
journal note and travels here with a slow fade.

Every scene holds the player in a **scripted scene**: `Player.set_scene_lock`
stops walking and actions, keeps the look within an arc about a direction,
between two pitches, and puts the eyes where the scene wants them (0.42 m
lying, 1.12 m sitting). Lines are `hud.say` and are clicked through; the
beats between them are timers and tweens on lights and props. Every scene
ends in `_finish`: a four-second fade to the scene's colour, the area hidden
and the world painted that colour, the card (`hud.show_area_name`) with the
ending's name and its last line, a fade to black, the save left in the flat
(area `apartment`, spawn `bed`, `has_woken`), and the title screen. Continuing
goes on from the bed there with the flag set.

## Room 5½ as it is

`_build_room(daylight)` is the room the whole game was drawn from, used by
`whole` (at night) and `m` (in the afternoon): seven by nine metres, green
paint, chequered floor, ceiling tiles, a tube. The bed with its head to the
north; the drip; the chair with the shape in it to the east; the cabinet
with the vase and the three paper roses, the photograph, the book with the
ribbon in it; the set on the crate showing the last channel; a radiator; the
door to the north with the chart and 5½ beside it and the clock at half
past five over it; the visitors' book on its stand by the door; the window
to the south, night or a bright pane with a warm light behind it.

## whole: waking up (from the bed in St. Nowhere)

Lying in the bed, the eyes at the ceiling, the tube unsteady, the red
light on a little. The ceiling you know; the paper crown on the pillow
(`item_crown`). The tall one at the foot of the bed with his hat off, lit;
"he was never outside": he comes to the bed and is not there, the crown is
not there, five heartbeats, the tube steadies and the red light goes out.
The set finds a channel (the test card). The door; somebody sits down in
the chair (`patron_seated`), the pen on its chain, the book closing; "M"
says your name. The light comes up through the window; card **ANTEROOM /
you open your eyes.** Sets `game_finished`.

## limbo: the last square (from The Last Rank)

Standing on the raised white square at the end of a rank of eight, the
giant pawns either side, the toppled queen and the stone, eight pieces in a
ring facing away. The pieces turn to face you. The ward comes up around the
board: six iron beds in two rows with chairs, a wall with WARD, the clock
and the tubes, the light going from the square's white to the tube's green.
"The square is a bed": the bed appears under you and the view lowers to
lying. The one who walked ahead sits down by the bed, black, and stays. The
paper crown is put on the blanket. Three afternoons: the light goes warm
across the wall and cold back, somebody appears in the other chair and
reads and is gone, the clock chimes. Card **THE LAST RANK / you stay.**

## unplugged: the plug (from Off Air)

Standing on a tiled landing by the wall with the plug in your hand, the
cable's end at your feet, the round stage ahead with the bed, the one on it
in shadow, the chair, the set on the crate, the last light on its cable,
and twenty-two sets still lit out in the dark. The plug is warm and then
not. Every screen goes to a dot, one after another, their lights with them;
the set by the bed to a dot. The hiss stops (the ambience goes). The one on
the bed is not black any more: the shadow prop is swapped for the King
(`king_coma`), the light goes white. Seven heartbeats with the gaps
lengthening, the dot swelling with each, the light dimming with each; the
dot draws out into a line. The sheet comes up over him (a slab tweened
along the bed). Somebody sits down in the chair and does not say your
name. The light goes out. Card **OFF AIR / and that is all.**

## m: the chair (from the King's Mind)

Sitting in the chair, the eyes at 1.12 m, facing the bed with the one in it
half under the sheet and half in the coat (`usher_king`). The afternoon
light in the window. The room looked at from the chair: him, the roses, the
photograph, the line on the set. The reading, in M's voice, from the book:
a door at the end of a hall that was not there the day before, measured at
six feet and one half. The light goes across the wall, a phone rings
somewhere, a door closes; "you come anyway". Then the lock comes off: the
player stands, and the only thing to do is the visitors' book by the door
(`VisitorsBook`, "Sign the book, and go"). One letter, the door opens onto
a bright light, and out. Card **THE VISITOR / tomorrow you come back.**

## Debug

`tools/shot.sh ending out.png whole` (or `limbo`, `unplugged`, `m`) renders
the first moment of each; the spawn names the scene. A probe that clicks
through the lines (and, for `m`, walks to the book) plays each scene to the
title in under a minute headless; keep one in the scratchpad when the
scenes are touched. The verifier builds the area once with the default
scene and skips it in the reachability check, as it is hidden.
