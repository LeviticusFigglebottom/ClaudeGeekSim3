# Endings

**Status: four roads, each with its choice in the game. No ending scene is
made yet.**

## Who is who

The Usher is the player's own projection, the consciousness walking these
places. The King is the body in the bed. M. is the visitor who sits by it.
The dream's board is the game between the body and the consciousness, and
the eighth square is where it is decided. The king in the corner of that
board is you as the ward and the visitor see you: still, in a bed, with
nowhere to go. Every choice's text says which of these it is, in plain
words, before it is taken.

## The four roads

Every choice defaults to "No" or "Do nothing", says *(an ending)* in the
option text, and asks a second time ("There is no coming back from this
one. Are you sure?", "No" first). Nothing is chosen by accident.

| Road | Where | Choice | Flag | Goes to |
|---|---|---|---|---|
| **Concede** (unplugged): killing yourself | the board in the rotunda at the eighth square, once the banquet has begun | "Concede. Lay the king down, and pull the plug on yourself." | `plug_pulled`, then `ending_unplugged` at the socket | Off Air, `docs/areas/STATIC_END.md`: the station shutting down, the same life on eight stages being struck, the lights going out behind you; the one on the bed at the end under the last light is you, on the machine, and the plug is warm. The text says it plainly: pulling it is not a picture of anything, it is you killing yourself, and it was always going to be your hand. |
| **Checkmate** (limbo): coming to terms | the same board | "Checkmate. Trap the king where he lies, and come to terms with it." | `promotion_taken`, then `ending_limbo` on the last square | The Last Rank, `docs/areas/PROMOTION.md`: eight squares from BORN to a square with nothing on it. Mating the king leaves him exactly where he is, for good: the king is you, as the ward and M see you, and the pawn that mated him is promoted into him. Standing on the last square is agreeing to the bed, the ward, the visitor, the years, and no more walking. The board keeps you and the bed keeps you and somebody comes in the afternoons. |
| **M**: the visitor's point of view | the King in his bed in the King's Mind, after the third rose (`roses_all_placed`) | "Sit in M's chair. (an ending: the visitor's)" | `ending_m` | Nowhere yet. The chair's shape is M's; sitting in it, you are not him any more but the one who visits every afternoon, reads, folds roses, signs the book with one letter and goes home, and comes back tomorrow. His breathing does not change; the ending is the coming anyway. It is the same room seen from the chair instead of the bed. Its scene is next. |
| **Whole**: regaining consciousness | the well in the Anteroom with all nine keepsakes, then down: the drained Cistern's drain, the Waterworks and its turning room, the Dark Glass, the Keep's mirror, the Other Anteroom with its roof off, the hospital and its six memory fragments, room 5½ | "Lie down. (the ending: waking up)" | `cistern_drained` → `pipes_opened` → `picked_dark_glass` → `mirror_open` → `memories_all` → `ending_whole` | The bed with the one in it half under the sheet with the King's face and half in the coat with yours: the body as the ward sees it and the one who has been walking, one person. Lying down is the two halves agreeing, and from the outside that is called waking up: the set finds a channel, the tone from the machine changes, somebody says your name, and you open your eyes. `docs/areas/PIPES.md`, `docs/areas/HOSPITAL.md`. |

The board's third option, "Do nothing. Leave the board as it is.", is the
default and is always allowed. The cloth on the banquet table is only the
way back to the Anteroom.

The Last Rank and Off Air are the same life told twice, and that is the
point: on the board it is kept and lit, and the board keeps you, and you
have agreed to it; off air it is being struck, the lights go out behind
you, and you end it yourself. Keep the distinction legible if either is
touched: one is coming to terms, the other is killing yourself, and neither
text pretends otherwise.

## The rotunda at the eighth square

Still the mirrored Anteroom with twelve doors of static. In it: an empty
hospital bed with a dent in the pillow, the most familiar thing in the
room; a monitor beside it showing static, its cable running to a socket on
the pillar behind; a chair with a letter from M on the seat; and the
chessboard on its table, a game nearly over (your pawn on the seventh, the
red king in the corner), your chair pulled out on the south side. Once the
banquet has begun the Usher comes and stands across the board.

## What plays now

`src/core/ending.gd`, `Ending.play(kind, title, lines, color)`: sets
`ending_<kind>`, bumps `endings`, says the lines, fades to the colour,
writes a journal note saying the scene is not made yet, and wakes the player
in the flat with a toast saying so. **The ending scenes are the next thing to
make** and should replace the tail of that function. `Game.stats` (doors,
wakes, falls, distance and playtime) survives a save and is there for them.

## Hints

The Barkeep's "A rumour" in the Last Lamp tells the candle-to-roses thread
in order until the ways part. Once the banquet has begun, or the roses are
in, or the player holds all nine, it asks which rumour: the board, the bed
in his head, or the well, each keyed to how far that road has been walked,
and offers another afterwards.

## Open

* **The fourth road's scene**: the choice is in the bed in room 5½ and its
  lines say what it is (waking); what the scene shows is open, like the
  other three.
* **The well's other text states** still say "something is still missing";
  the nine-keepsake state now leads somewhere.
* **The Paper Crown** has no use in the dream since the crowning was removed.
* **Which ending counts as finishing the game**, and whether the others stay
  reachable afterwards (all currently return the player to the flat with
  their flag set).
