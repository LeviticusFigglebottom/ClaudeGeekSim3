# Off Air

Area id `static_end`. Display name **Off Air**, subtitle *"the set turned
off"*. Built in `src/areas/static_end/static_end.gd`. Realm preset `static`
overridden to a near-black void with almost no fog and no sky; ambience
`static`.

This is where conceding at the board goes. It is one of the four ends of
the game: `Ending.play("unplugged", ...)` sets `ending_unplugged`, fades to
white, and plays the scene in `docs/areas/ENDING.md`, the plug in your hand
and every screen going to a dot.

## Getting there

At the board in the rotunda of the eighth square of the King's Dream, once
the banquet has begun, "The board" asks for your move. "Concede. Lay the
king down, and pull the plug. (an ending)" asks again, "No" first, then sets
`plug_pulled` and travels to `static_end:from_banquet`.

The route is declared on the eighth square (`kings_dream_plug`, done flag
`ending_unplugged`, requires `flag:dream_banquet_begun`).

## The place

The station shutting down. Out in a dark with nothing under it but a floor
of static far below (decoration: falling lands in the Static), eight
**stages** hang on cables, each a steel plate fourteen metres across with a
lip and unseen walls, numbered 8 to 1 in tape, and between them the road: a
plate deck slung on cables with rails either side and one thick cable
underneath carrying the signal. The stages rise a little as they go.

Each stage is the same life as the Last Rank's, being **struck**: tape on
the floor where the thing stood, a crate stencilled with its name, and what
is left of it.

| Stage | Word | What is left |
|---|---|---|
| 8 | BORN | the cot under a dust sheet, the mobile's pieces in a box |
| 7 | SMALL | hopscotch in tape, a chair too small, a pawn your height |
| 6 | TAUGHT | the desk with its chair upside down on it, the rules board face down, the clock face down |
| 5 | KEPT | the filing cabinet on its side, the ticket dispenser, the number being served |
| 4 | LOVED | two chairs stacked, two mugs on the floor, a paper rose in a crate |
| 3 | HOME | the white door laid flat like a struck flat, the mailbox knocked over |
| 2 | KEPT AGAIN | the iron bed stripped to its frame, the drip, the chair |
| 1 | OFF | a circle of light with nobody in it, the tape outline of where they were, the blank stone face down |

Every stage has a set the size of a room beside it, still on, and a
spotlight over its middle. **Coming onto a stage puts the one before it
out**: the spotlight fades, the set goes to black with a `tv_off`, and the
count on the card in the sky comes down (`_arrive`). Forty-four more
screens drift slowly out in the dark on either side (`_drift`), and over
the end hangs a broadcast test card forty-eight metres wide, TRANSMISSION
ENDS under it, and the count of channels still on.

## The end

Past stage 1, on the cable's end, a round tiled floor under the one light
still on. The bed, the one who ushered you on it, black, face up (the
`usher` prop laid down, `TheOneOnTheBed`), a chair, the monitor on a crate
showing the last channel, and a cable running to a socket in a wall the
size of a building, which is the picture between channels up close.

"The plug" (`Plug`, at the socket) says what it is before it asks: the
picture on the last channel is him, and he is you, in the bed, on the
machine, and pulling it is not a picture of anything, it is you killing
yourself. "No. Leave it in." first, then "Pull the plug on yourself.", then
the second ask. Yes plays the `unplugged` ending: every screen still lit
goes to a dot, the hiss stops, he was never going to move, it was always
going to be you and your hand on the plug.

The distinction from the Last Rank is deliberate and should stay legible:
there, the things are whole and lit and the board keeps them; here they
are being packed away and the lights are going out behind you, and it
ends.

## Debug

`tools/shot.sh static_end out.png from_banquet "0,-6"` for stage 8;
`--pos=0,0.1,-6 --look=-21,-4 --fly` for the first cable;
`--pos=11.9,11.9,-217 --look=0,-8 --fly` for the bed; `--pos=11.9,11.9,-200
--look=0,4 --fly` for the card.
