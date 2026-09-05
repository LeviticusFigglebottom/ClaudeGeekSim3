# The Last Rank

Area id `promotion`. Display name **The Last Rank**, subtitle *"a pawn that
gets there is whatever it is told"*. Built in
`src/areas/promotion/promotion.gd`. Realm preset `promotion` (a bruised
violet sky, the King's Mind sky texture, thin fog).

This is where accepting the promotion goes. It is one of the three ends of
the game, and its ending scene is not made yet: `Ending.play("limbo", ...)`
sets `ending_limbo`, fades, and for now wakes the player in the flat.

## Getting there

At the board in the rotunda of the eighth square of the King's Dream, once
the banquet has begun (`dream_banquet_begun`, set by standing at the
centre), "The board" asks for your move. "Do nothing" is first and selected.
"Checkmate. The pawn to the eighth, and stay on the board. (an ending)"
asks again, "No" first, then sets `promotion_taken` and travels to
`promotion:from_banquet`.

The route is declared on the cloth's square (`kings_dream_promotion`, done
flag `ending_limbo`, requires `flag:dream_banquet_begun`).

## The place

The board from the dream with the corruption showing through. One rank of
eight squares fourteen metres across, walked north in order, with three
files of board either side that are being forgotten from the edges in: some
squares are missing, some are static. Pawns the size of houses stand along
both sides and invisible walls above them keep the player to the file.
Knocked-off pieces lie on the edge squares; every fifth fence pawn and some
of the fallen are covered in static (`_corrupt`). Behind the first square
the rank you came from is painted out with a wall of static. Falling off the
edge squares lands in the Static as everywhere; no route needs a fall.

The rank is the progression of a life, and each square has its word on the
ground in front of it:

| Square | Word | What stands there |
|---|---|---|
| 1 | BORN | a cot the size of a room, a mobile of pieces turning over it |
| 2 | SMALL | chalked hopscotch, a pawn your height beside one of theirs, a chair, the picture of the house |
| 3 | TAUGHT | six desks facing the board of rules from the croquet ground, chairs turned round, the clock |
| 4 | KEPT | filing cabinets, a desk, a phone that never rings, the ticket dispenser, the floor going to static |
| 5 | LOVED | a table for two, two warm mugs, two queens of opposite colours together, paper roses |
| 6 | HOME | the white door from the field, ajar, the mailbox with 5½ on it, a window that shows night |
| 7 | KEPT AGAIN | an iron bed with hospital corners, a drip, a chair somebody sat in a long time, a set showing static, the clock at half past five |
| 8 | (no word) | a toppled red queen, the stone from the Ossuary with your name, and a raised white square with nothing on it |

The Usher stands near the last square and vanishes when looked at, as
everywhere.

## The ending: coming to terms

"Stand on the last square" (`LastSquare`) says what it is before it asks:
the king you mated is in the corner of this board too, in a bed, with
nowhere to go, and the pawn that mated him is promoted into him; standing
on the square is agreeing to the bed, the ward, the visitor, the years, and
no more walking. "No. Not yet." first, then "Stand on it, and come to
terms.", then the second ask. Yes plays the `limbo` ending: nothing is put
on your head, you are the king in the corner and you know it now, the
pieces turn the way a ward turns when somebody's eyes move under the lids,
and the board keeps you and the bed keeps you and somebody comes in the
afternoons. The stone on the eighth square says the dates stay blank if
you stay: nobody buries a king who is still in the corner.

## Debug

`tools/shot.sh promotion out.png from_banquet "0,-6"` for the cot;
`--pos=0,0.1,-34` for KEPT, `--pos=0,0.1,-62` for HOME, `--pos=0,0.1,-90`
for the last square. The coplanar audit (`tools/coplanar.tscn --
--area=promotion`) is clean.
