# The world of ANTEROOM

A dreamer in a small flat. A closet that grows a hallway. An anteroom of
twelve doors. Beyond them: places that were lost, and the things you were
holding when you woke up.

## Areas and connections

Every connection is `area:spawn`. Spawn ids are the contract between areas;
the verifier (`tools/verify.sh`) checks all of them.

| id | name | reached from | leads to | holds |
|---|---|---|---|---|
| `apartment` | Flat 5½ (waking) | wake (`bed`), hallway (`closet`), corridor (`front`), mirror_nexus (`mirror`) | bed → `nexus:default`; closet → `hallway:entrance` (needs `has_woken`); front door → `corridor:flat_door` (needs `door_code`); bathroom mirror → `mirror_nexus:default` (needs shard sight) | tape measure (kitchen drawer, after first waking); TV face easter egg; flat 7 mirrored variant (`in_flat_seven`) |
| `corridor` | The Halden Arms | apartment (`flat_door`), offices (`from_stairs`) | 5½ → `apartment:front`; 7 → `apartment:front` (mirrored); stairs → `offices:from_stairs`; lift (3 calls) → `static:lift` | looping corridor, knock-backs |
| `hallway` | The Hallway | apartment (`entrance`), house (`side`), nexus/catacombs (`end`, `stairs`) | closet → `apartment:closet`; side door (after measuring) → `house:field`; big door → `nexus:from_hallway`; stair (3 loops) → `catacombs:from_stairs` | measurement puzzle → `door_code`; lantern inscriptions; growth; loop |
| `nexus` | The Anteroom | every realm (`from_<id>`), hallway (`from_hallway`), mirror_nexus (`from_mirror`), workshop (`from_workshop`) | twelve doors → `<realm>:from_nexus`; workshop (13 bells) | bell unlocks castle door; the well counts keepsakes |
| `forest` | The Hollow Wood | nexus (`from_nexus`), city (`road`), catacombs (`well_top`), tavern back door (`clearing`) | gate → `nexus:from_forest`; road → `city:west_gate`; well (rain) → `catacombs:from_well` | **Lantern** (hermit hut; light 3 braziers in stone order); **moonlight** (canopy, needs wings); standing stones; giant trees |
| `city` | The Drowned City | nexus, forest (`west_gate`), catacombs (`sewer_top`), clocktower (`from_tower`), tavern back door (`alley`) | gate → `nexus:from_city`; west gate → `forest:road`; sewer (lantern) → `catacombs:from_sewer`; tower door (tower key) → `clocktower:from_city` | **Bell** (cathedral crypt, bell-order puzzle); **tower key** (palace, stone knights admit the crowned); wrapping streets |
| `tavern` | The Last Lamp | nexus, sea (`from_sea`), furnace (`from_furnace`, the cellar) | door → `nexus:from_tavern`; back door → random of `forest:clearing`, `city:alley`, `house:field`, `sea:shore`; inn bed → `sea:from_tavern`; mouse gap → undertavern; cellar iron door (rope cut) → `furnace:from_tavern` | riddle → **coin**; moonlight trade → **Umbrella**; bard, patrons, barkeep |
| `house` | The Nowhere House | hallway (`field`), nexus (`from_nexus`), tavern back door (`field`), cistern (`basement`), offices (`from_offices`) | lone door in the field → `nexus:from_house`; basement stair (loops) → `cistern:from_basement`; kitchen wing (visit ≥ 3) → `offices:from_house` | **Tin Mouse** (visit ≥ 2); dog + biscuit; photos that change; mirrored on visit 2; bigger bathroom; backwards door; attic (photo) |
| `castle` | The Keep of Hours | nexus | gate → `nexus:from_castle`; bedchamber mirror (shard) → `mirror_nexus:default`; library shelf → `castle:wardrobe` | **Paper Crown** (rotating rooms; hourglass steadies them); tapestry (knife) → the King's dream; infinite library; throne |
| `sea` | The Slow Sea | tavern (`from_tavern`), nexus, tavern back door (`shore`) | pier door → `nexus:from_sea`; sleeping shore → `tavern:from_sea` | **Moth Wings** (highest platform; clockwork platforms); giant faces; colour-shifting sky |
| `catacombs` | The Ossuary | forest (`from_well`), city (`from_sewer`), hallway (`from_stairs`), nexus | ladder → `forest:well_top`; grate → `city:sewer_top`; door → `nexus:from_catacombs` | **Mirror Shard** (reflecting pool; needs lantern to find the way); gravestone name puzzle; lantern-only paths |
| `furnace` | The Furnace | mirror_nexus (`from_mirror`), nexus, tavern cellar (`from_tavern`) | iron door → `nexus:from_furnace`; mirror gate (shard) → `mirror_nexus:from_furnace`; small iron door (after the rope) → `tavern:from_furnace` | **Kitchen Knife** (the chained giant holds it out); the pit of slow fire (fall in: the Static); the forge and the Stoker; **candle stub** (iron maiden); the choir that sings one note (the bell stops it); the gallows rope (knife) opens every cage |
| `cistern` | The Cistern | house (`from_basement`), nexus | drain ladder → `house:basement`; tiled door → `nexus:from_cistern` | **torn page** (follow the reading voice to the showers); the great sunken bath and its writing on the bottom; the lifeguard who climbed down; the corridor that only goes on (three passes → the glass float); the umbrella makes it rain indoors; higher water on the second visit |
| `offices` | The Waiting Halls | corridor (`from_stairs`), house (`from_house`), nexus | fire door → `corridor:from_stairs`; door 5½ (once your number is called) → `nexus:from_offices`; STAFF ONLY → `house:from_offices`; door 0604 (door code) → `hallway:end`; door 0001 → the same waiting room | **missing photo** (archive drawer marked 5½); take a number, wait three times; **dog biscuit** (vending machine, B4); the corridor of cubicles that goes round; the photocopier that prints a face; the shadow at the desk |
| `clocktower` | The Clocktower | city (`from_city`), nexus (`from_nexus`, both at the bottom) | ground doors → `city:from_tower` and `nexus:from_clocktower`; top door → `nexus:from_clocktower` | **Hourglass** (top of the spiral; two great gears to ride, the wings make it easy); the clock whose hands move only when unseen; the great bell stops the works; the keeper; a chest with a clock hand with your name on it |
| `static` | The Static | falling out of any world (`default`), corridor lift (`lift`), nexus | a screen → `nexus:from_static` | the Usher's home; nothing stays |
| `mirror_nexus` | The Other Anteroom | apartment mirror (`default`), furnace (`from_furnace`) | mirror → `apartment:mirror`; furnace door → `furnace:from_mirror`; a crack → `nexus:from_mirror` | reversed plaque; mirror-only geometry |
| `workshop` | The Workshop (hidden) | nexus (13 bells) | door → `nexus:from_workshop` | every prop on a plinth |

## Keepsakes and the routes to them

| keepsake | where | needs |
|---|---|---|
| Lantern | Hollow Wood, hermit's hut | light the three braziers in the order carved on the standing stones |
| Small Bell | Drowned City, cathedral crypt | ring the four bells in clock order |
| Paper Crown | Keep of Hours, rotating rooms | Bell (rung in the Anteroom opens the keep); Hourglass helps |
| Tower Key (item) | Drowned City, palace throne | Paper Crown (the knights kneel) |
| Hourglass | Clocktower top | Tower Key; Moth Wings help |
| Moth Wings | Slow Sea, highest platform | reach the Sea (tavern inn bed) |
| Bottle of Moonlight (item) | Hollow Wood canopy | Moth Wings |
| Umbrella | Last Lamp, the barkeep | Bottle of Moonlight |
| Mirror Shard | Ossuary, reflecting pool | Lantern (to see the way); reach the Ossuary (city sewer with Lantern, forest well with Umbrella, or the hallway stair) |
| Kitchen Knife | Furnace, the giant's hand | Mirror Shard (the flat's bathroom mirror) |
| Tin Mouse | Nowhere House, second visit | reach the house (hallway side door after measuring with the tape measure, or the tavern back door) |

## Waking-world chain (the House of Leaves thread)
sleep → wake with a keepsake (`has_woken`) → tape measure in the drawer →
closet is the Hallway → measure it → door code 0604 and a side door to the
field → the Nowhere House → the Halden Arms via the front door → the
Waiting Halls → and back into the house from the wrong side.

## Latent routes the solver is told about
Count-gated exits are declared with `Puzzle.declare(..., {"route": "area:spawn"})`:
the Nowhere House basement stair (three descents) → `cistern:from_basement`,
the Hallway stair (three descents) → `catacombs:from_stairs`.

## Secrets (first pass)
* TV face on channel zero (1 in 24, or half the time at 3 am).
* Knock on every flat; something knocks back from too low down.
* Thirteen bells in the Anteroom: the very small door.
* The Usher: appears where you are not looking; five sightings change the journal.
* Flat 7 is your flat, mirrored.
* Five and a half minutes in the Hallway.
* Feed the dog; it follows you between worlds and comes to the bell.
* Extra person in the hall photograph after three wakings.
* Door 0604 in the Waiting Halls opens onto the far end of the Hallway.
* Press B4. The vending machine has been waiting.
* Strike the anvil in the Furnace seven times; something upstairs barks.
* Ring the great bell at the top of the Clocktower with the Small Bell in hand.
* The corridor in the Cistern that only goes on gives up after three passes.

## Planned, not built
* `kings_dream` — The King's Dream. In from the stone telephone in the Keep's
  dream bedroom (`castle:DreamPhone`, needs Moth Wings and Hourglass), out to
  `castle:from_dream` and `nexus:from_kings_dream`. Holds the third Paper Rose.
  Spec: `docs/areas/KINGS_DREAM.md`.
* The descent below the Anteroom's well, built as an extension of `nexus`, and
  the six endings that read from it. Spec: `docs/ENDINGS.md`.
