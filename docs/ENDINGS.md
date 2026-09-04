# Endings

**Status: three ends exist as choices; their scenes are not made.** The
fourth, the M ending, is designed in outline only and is not to be built
yet. Everything below that is marked open is open.

## The three that exist

Each is reached by a confirmation that defaults to "No", says *(an ending)*
in the option text, and asks a second time ("There is no coming back from
this one. Are you sure?", "No" first). Nothing is chosen by accident.

| Ending | Where | Flag | Goes to |
|---|---|---|---|
| **The promotion** (limbo) | the cloth at the banquet, eighth square of the King's Dream, once the banquet has begun | `promotion_taken`, then `ending_limbo` on the last square | The Last Rank, `docs/areas/PROMOTION.md`: eight squares from BORN to a square with nothing on it. Staying is the ending. |
| **The plug** (unplugged) | the same cloth, third option | `plug_pulled`, then `ending_unplugged` at the socket | Off Air, `docs/areas/STATIC_END.md`: the same eight things, grey and sinking, each watched by a set showing snow; at the end the Usher on a bed with your face, and the plug. Pulling it is the ending. |
| **The memorial** | the King in his bed in the King's Mind, after the third rose (`roses_all_placed`) | `ending_memorial` | Nowhere yet. Staying with him is the ending: a memorial to yourself. |

The Last Rank and Off Air are the same life told twice, and that is the
point: on the board it is kept and lit, and the board keeps you; off air it
is grey and going under, and it ends. Keep the distinction legible if either
is touched.

## What plays now

`src/core/ending.gd`, `Ending.play(kind, title, lines, color)`: sets
`ending_<kind>`, bumps `endings`, says the lines, fades to the colour, writes
a journal note saying the scene is not made yet, and wakes the player in the
flat with a toast saying so. **The ending scenes are the next thing to make**
and should replace the tail of that function. `Game.stats` (doors, wakes,
falls, distance, playtime) survives a save and is there for them.

## The M ending

Designed in outline, not built, not to be built until the details are
settled: the cistern ties into the mirror world, opens something there (the
roof, the ascending platforms), and leads to a hospital with the context of
the Usher's circumstances and the M ending. The Usher is the player's own
projection; the King is the body in the bed; M. is the visitor. Nothing in
the cistern, the Other Anteroom or the Static reads any of this yet.

## Open

* **The nine keepsakes rule.** An earlier decision said every ending requires
  all nine keepsakes and that holding only the nine gives the worst ending.
  None of the three choices checks the keepsakes. Whether the rule still
  stands, and which of the three is the "bad" one, is undecided.
* **The well** at the bottom of the Anteroom (`nexus.gd`, three text states,
  no fourth, no descent). It may be scrapped as an ending and become an area
  in a later pass.
* **The Paper Crown** has no use in the dream since the crowning was removed.
* **Which ending counts as finishing the game**, and whether the others stay
  reachable afterwards (all three currently return the player to the flat
  with their flag set).
