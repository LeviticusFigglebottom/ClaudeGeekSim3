# Endings

**Status: four roads, each with its choice in the game. No ending scene is
made yet.**

## Who is who

The Usher is the player's own projection, the consciousness walking these
places. The King is the body in the bed. M. is the visitor who sits by it.
The dream's board is the game between the body and the consciousness, and
the eighth square is where it is decided.

## The four roads

Every choice defaults to "No" or "Do nothing", says *(an ending)* in the
option text, and asks a second time ("There is no coming back from this
one. Are you sure?", "No" first). Nothing is chosen by accident.

| Road | Where | Choice | Flag | Goes to |
|---|---|---|---|---|
| **Concede** (unplugged) | the board in the rotunda at the eighth square, once the banquet has begun | "Concede. Lay the king down, and pull the plug." | `plug_pulled`, then `ending_unplugged` at the socket | Off Air, `docs/areas/STATIC_END.md`: the same life told grey and sinking, each thing watched by a set showing snow; the Usher on a bed at the end, and the plug. Accepting death. |
| **Checkmate** (limbo) | the same board | "Checkmate. The pawn to the eighth, and stay on the board." | `promotion_taken`, then `ending_limbo` on the last square | The Last Rank, `docs/areas/PROMOTION.md`: eight squares from BORN to a square with nothing on it. The King and the Usher stay separated; the consciousness stays a piece. |
| **M** | the King in his bed in the King's Mind, after the third rose (`roses_all_placed`) | "Sit with him." | `ending_m` | Nowhere yet. You were M all along: the one who came every day, read to him and brought the roses. Finished as a choice; its scene is next. |
| **Whole** | the well in the Anteroom with all nine keepsakes, then down: the drained Cistern's drain, the Waterworks, the Dark Glass, the Keep's mirror, the Other Anteroom with its roof off, the hospital, three visits, room 5½ | "Lie down." | `cistern_drained` → `pipes_opened` → `picked_dark_glass` → `mirror_open` → `hospital_book_read` → `ending_whole` | The bed with the one in it half under the sheet and half in the coat: the King and the Usher, the body and the consciousness, one of you. Lying down beside him is the ending. `docs/areas/PIPES.md`, `docs/areas/HOSPITAL.md`. |

The board's third option, "Do nothing. Leave the board as it is.", is the
default and is always allowed. The cloth on the banquet table is only the
way back to the Anteroom.

The Last Rank and Off Air are the same life told twice, and that is the
point: on the board it is kept and lit, and the board keeps you; off air it
is grey and going under, and it ends. Keep the distinction legible if either
is touched.

## The rotunda at the eighth square

Still the mirrored Anteroom with twelve doors of static. In it: an empty
hospital bed with a dent in the pillow, the most familiar thing in the
room; a monitor beside it showing snow, its cable running to a socket on
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

* **The fourth road's scene**: the choice is in the bed in room 5½; what
  the ending shows is open, like the other three.
* **The well's other text states** still say "something is still missing";
  the nine-keepsake state now leads somewhere.
* **The Paper Crown** has no use in the dream since the crowning was removed.
* **Which ending counts as finishing the game**, and whether the others stay
  reachable afterwards (all currently return the player to the flat with
  their flag set).
