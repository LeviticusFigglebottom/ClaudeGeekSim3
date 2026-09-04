# Endings

**Status: undesigned.** An earlier draft of this document proposed a six
ending system keyed to separate collectible threads. **It is scrapped.**
Nothing from it survives except the one rule below, which is decided.

## The rule

**Every ending requires all nine keepsakes.** They are the price of admission
to an ending at all, not a way to choose between them.

**Holding the nine and nothing else gives the bad ending.** Optional content is
what separates one ending from another. A player who beelined the keepsakes
and skipped everything else gets the worst outcome available, and gets it
without being told they missed anything.

## Open

Everything else. What the other endings are, what optional content they read,
where they are triggered, and what the well at the bottom of the Anteroom has
to do with any of it are all unsettled and are not to be filled in here
speculatively.

## What exists in code today

* Nine keepsakes, all obtainable, proved on every run by the route solver in
  `tools/verify.sh`.
* The well in the Anteroom, `nexus.gd`, with three text states keyed on how
  many keepsakes the player holds. The third ends on *"Nine places, nine
  things. The bottom of the well is a door now. It is not open yet. Something
  is still missing, and it is not a thing."* There is no fourth state and no
  descent.
* The Candle Stub from the forge goes on the Ossuary altar in the Drowned
  City and becomes Bonemeal. Bonemeal fed to the sprout on the hill in the
  King's Dream grows the beanstalk into the King's Mind
  (`docs/areas/KINGS_MIND.md`). The three Paper Roses go in the vase by the
  King's bed there. After the third, he has stopped dreaming about you and is
  waiting. What he is waiting for, and what happens next, is open: the flag is
  `roses_all_placed` and nothing reads it yet.
* `Game.stats` counts doors, wakes, falls, distance and playtime, and survives
  a save. Any ending that wants to read the run can.
