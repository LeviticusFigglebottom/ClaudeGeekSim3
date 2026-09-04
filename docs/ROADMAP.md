# Roadmap

This first pass is deliberately not complete. Hooks for the next iterations,
roughly in order of value:

## Content
* **Mirrored realms.** The Other Anteroom has twelve painted-shut doors. Each
  can become a mirror-world version of a realm (the Hollow Wood in winter, the
  city un-drowned) using `MapBuilder.mirrored` and `Kit.mirror_only`.
* **The well at the bottom of the Anteroom.** With all nine keepsakes it becomes
  a door. Where it goes is undecided; the King's waking is the other thread.
* **More keepsakes**: a candle (light that burns down), a key that opens one
  door of your choosing, a photograph that swaps you with the person in it.
* **NPC schedules.** The barkeep, the fishwife and the hermit could move
  between realms at different real-world hours (`Game.is_night()` exists).
* **The dog's own dream.** Feed it in three realms; it leads you somewhere.
* **The King's Dream**, a tenth realm reached by answering the stone telephone
  in the Keep's dream bedroom, gated on the Moth Wings and the Hourglass.
  Fully specified in `docs/areas/KINGS_DREAM.md`; not built.
* **Six endings and the descent down the well**, chosen by which threads of
  optional content the player finished rather than by a menu. Fully specified
  in `docs/ENDINGS.md`; not built. That document also supersedes the note
  below about the two pocket items: the Candle Stub becomes the fifth candle
  on the Ossuary altar and the Paper Rose becomes a set of three for the
  sleeping King.
* **A lock for the two pocket items.** The Paper Rose and the Candle Stub can
  both be picked up (the rose in the castle library and, at mouse size, under
  the tavern floor; the stub in the castle chest, the ossuary crypt, the
  house's between-walls room and the Furnace's iron maiden) and neither is
  asked for by anything. Two hooks are already written in the fiction and want
  only a consumer: the torn page the rose is folded from "was about a king
  dreaming of a garden", so the rose belongs in the sleeping King's hand; and
  the ossuary altar already lights candles for four names, so the black stub
  is the fifth, for the name nobody wrote. `tools/verify.sh` warns by name
  about any gainable item with no lock, so this cannot go quiet again.
* **The Waiting Halls' numbers** could call other players' numbers (a shared
  leaderboard of people who were called and never came back).
* **Endings**: crown the King; put the knife back in the drawer; sit down in the
  Static and stay.

## Systems
* Rendered portals (SubViewport cameras) for true see-through non-euclidean
  doors; the seam system is the fallback.
* A photo mode; the F12 screenshot is a start.
* Accessibility: hold-to-interact toggle, larger UI scale. (Dither, vertex
  wobble, affine warp, pixel size, colour depth and interactable glow are all
  sliders now; flicker follows those.)
* Gamepad support (input actions exist; add joypad events).
* A "dream log" export. (Three save slots and a settings panel are in.)

## Pipeline
* Palette-shift generators so one texture family yields all realms.
* More props: birds, fish, a cart horse that is not a horse.
* Sound: procedural drone synth at runtime (AudioStreamGenerator) layered on
  the baked loops; positional reverb zones.
* A `tools/gen_assets/README` with a gallery contact sheet regenerated in CI.

## Done since the first pass
* The Furnace's small iron door behind the cut gallows rope now climbs into the
  Last Lamp's cellar, and the freed prisoner turns up in the taproom.
* The Clocktower landing no longer roofs over its own stair.
* Both mouse-holes are real openings a small player fits through, and the
  verifier crawls them at that size.
* Web export and a Vercel deployment, verified in a real headless browser.

## Known rough edges
* The sleeping faces of the Slow Sea are flat cards with a square backing;
  from above they read as slabs. A lathed head would sell them.
* `Clockwork.add_shape` only makes boxes; round riding platforms (the Sea's
  drifting discs, the Clocktower's gears) use a box approximation.
* Riding moving platforms and climbing the Clocktower spiral are validated
  numerically (gap/rise) but not by the headless playtest, which only walks
  the flat, the Anteroom and the bed.
* The Waiting Halls' number display is a Label3D over a small prop; a proper
  seven-segment texture would read better at pixel scale 3.
* The Keep of Hours: the King has two states (on the throne, then in bed); a
  third (gone) is not written. The library's secret shelf door re-enters the
  keep and so bumps `visit_count`, which is what makes the King get up: dream
  logic, but change it if visits should only count from the Anteroom gate.
  Hooks left in comments: chapel bells starting the great clock, the Steward,
  the "king woken" ending.
* The Drowned City's wrapping street uses 40 m phantom copies past each seam
  that end in a dark cap wall, faintly visible through fog; a third-visit
  flood of the main street and the umbrella reversing the fountain are TODOs.
* `Kit.particles(..., "fog")` renders as crisp translucent rectangles under
  software GL; the fog kind wants a softer sprite.
* Areas rebuild on every visit; large realms take ~100 ms under software GL.
  Fine on hardware; could cache.
* Under llvmpipe the frame rate is low (it is a verification path, not a play
  path).
* Unstable doors are listed for the solver but the solver assumes any listed
  target is reachable.
