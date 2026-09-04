# Off Air

Area id `static_end`. Display name **Off Air**, subtitle *"the set turned
off"*. Built in `src/areas/static_end/static_end.gd`. Realm preset `static`
with heavier fog.

This is where pulling the plug goes. It is one of the three ends of the
game, and its ending scene is not made yet: `Ending.play("unplugged", ...)`
sets `ending_unplugged`, fades to white, and for now wakes the player in the
flat.

## Getting there

At the banquet on the eighth square of the King's Dream, once the banquet
has begun, taking hold of the cloth offers "Pull the plug. (an ending)" as
the third option; it asks again before going. Pulling sets `plug_pulled`
and travels to `static_end:from_banquet`. The cable it means runs from
under the cloth at the player's place to a socket in the rotunda wall,
built once the banquet has begun.

The route is declared on the cloth (`kings_dream_plug`, done flag
`ending_unplugged`, requires `flag:dream_banquet_begun`).

## The place

The Static with the set turned off. The ground is snow the way the Static's
is, going down for ever; the one firm thing is a strip of plate running
north. Along it stand the same eight things as the last rank, in the same
order, each with its word on the plate and each watched by a television the
size of a wardrobe showing snow. The things themselves are grey and half
sunk, the way things get under snow that is not cold:

BORN a cot with three small pawns · SMALL a pawn and a chair · TAUGHT a desk
and the clock · KEPT a filing cabinet and the ticket dispenser · LOVED a
table, a chair and a paper rose · HOME the white door and the mailbox · KEPT
AGAIN the iron bed and the chair · OFF a blank gravestone.

The distinction from the Last Rank is deliberate and should stay legible:
there, the things are whole and lit and the board keeps them; here they are
grey, sinking, and every one has a set watching it, because this is what is
left when the picture is taken away.

## The bed

Past OFF, a floor of white ward tile. On an iron bed lies the one who
ushered you, black, face up, head on the pillow (the `usher` prop laid down,
`TheOneOnTheBed`). A chair beside him. On a crate, the set that watches him,
showing snow, and a cable from it across the floor to a socket in a wall of
snow. Looking at him: *he has your face*, a wristband with nothing on it and
a tick in your handwriting under nothing.

"The plug" (`Plug`, at the socket) asks, "No" first, then asks again. Yes
plays the `unplugged` ending: the set goes to a dot, the snow stops going
down, he was never going to move, it was always going to be you.

## Debug

`tools/shot.sh static_end out.png from_banquet "0,-8"` for BORN;
`--pos=0,0.1,-30` for the strip; `--pos=0,0.1,-107.5 --look=0,-22` for the
bed; `--pos=-2.5,0.1,-109 --look=60,-14` for the socket. The coplanar audit
is clean.
