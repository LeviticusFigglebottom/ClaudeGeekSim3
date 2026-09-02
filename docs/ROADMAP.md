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
* **The Waiting Halls' numbers** could call other players' numbers (a shared
  leaderboard of people who were called and never came back).
* **Endings**: crown the King; put the knife back in the drawer; sit down in the
  Static and stay.

## Systems
* Rendered portals (SubViewport cameras) for true see-through non-euclidean
  doors; the seam system is the fallback.
* A photo mode; the F12 screenshot is a start.
* Accessibility: hold-to-interact toggle, larger UI scale, reduced flicker.
* Gamepad support (input actions exist; add joypad events).
* Save slots and a "dream log" export.

## Pipeline
* Palette-shift generators so one texture family yields all realms.
* More props: birds, fish, a cart horse that is not a horse.
* Sound: procedural drone synth at runtime (AudioStreamGenerator) layered on
  the baked loops; positional reverb zones.
* A `tools/gen_assets/README` with a gallery contact sheet regenerated in CI.

## Known rough edges
* The sleeping faces of the Slow Sea are flat cards with a square backing;
  from above they read as slabs. A lathed head would sell them.
* `Clockwork.add_shape` only makes boxes; round riding platforms (the Sea's
  drifting discs, the Clocktower's gears) use a box approximation.
* Riding moving platforms and climbing the Clocktower spiral are validated
  numerically (gap/rise) but not by the headless playtest, which only walks
  the flat, the Anteroom and the bed.
* The Furnace's small iron door (behind the cut gallows rope) opens onto
  stairs that are "not finished being dreamt": a hook for a way up into the
  Last Lamp's cellar.
* The Waiting Halls' number display is a Label3D over a small prop; a proper
  seven-segment texture would read better at pixel scale 3.
* Areas rebuild on every visit; large realms take ~100 ms under software GL.
  Fine on hardware; could cache.
* Under llvmpipe the frame rate is low (it is a verification path, not a play
  path).
* Unstable doors are listed for the solver but the solver assumes any listed
  target is reachable.
