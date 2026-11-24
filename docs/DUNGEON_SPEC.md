# Dungeons as paths: the Gloomwood (spec)

**23 Nov 2026 · future direction:** [`DUNGEON_EXPEDITIONS_PLAN.md`](DUNGEON_EXPEDITIONS_PLAN.md) records the owner's
agreed expedition, permanent-discovery and recruitment proposal. It is planning, not implemented gameplay. For
that future design, alternate routes and evolving discoveries supersede this file's original restriction against
route choices. This file remains the baseline specification for the currently playable Gloomwood.

Updated 19 Nov 2026: night road, stone-circle arena, much harder; see PHASE_A_PROGRESS ("Night road and harder"). Where this
file gives older numbers (marked "before 19 Nov"), the current ones are: 9 fights (6 with HUD pips plus 3 ambushes), Mossback
about 9,900 health at level 1 (`hp_mult` 2.2), enrage below 35%, up to 6 adds (`boss_minions_max`), the Moonwell heals 40%,
elites from level 1 (30%), `max_alive` 8 / 12 / 12 (Low / Medium / High), pay up 25%.

18 November 2026, evening. This replaces Phase E's room runs (`docs/PHASE_E_SPEC.md` sections 4.3, 5, the forks,
the room templates and the doors). Everything else in Phase E stays unless this file says otherwise: the Old Hollow
entrance in the camp, free entry, the satchel, the dash, boons, keys as a bonus, traps, chests, the spring, the Amber
Grub, Gloomtouched monsters, the mount and pet going in, Feed and Snack, lunches, the Moss Warden's seal, materials and
what they buy, home levels 7-8, saving while a run is on, and nothing moving while the game is closed.

## The user's words (18 November 2026)

> The dungeons or the burrows shall not be like this, a small room that the user fights. It shall be like a path the
> user walks and gets to the boss. But not every dungeon has a boss. So create the first dungeon not like underground:
> create like a whole small map that's outside, but set it in the dark, and add one boss to it, but also enemies that
> spawn. So as the user goes to the end of the dungeon he fights smaller enemies, then fights the boss in a big place,
> not a small one. Kind of like World of Warcraft has.

So:
1. A dungeon is **one continuous map**: a path the cat walks from the way in to the end. No rooms, no doors, no
   loading between parts, no forks to pick.
2. **Smaller enemies along the way**: packs that wake as the cat comes near (a WoW "pull"), and enemies that **spawn**
   as the cat passes (burst out of holes, fly in from the dark).
3. **The boss fights in a big place**: a wide arena at the end, much bigger than the old 7 x 15 m boss room.
4. **Not every dungeon has a boss.** The data allows a dungeon to end in a treasure clearing instead. The first one has
   a boss.
5. **The first dungeon is outdoors, at night**, not underground.

## The first dungeon: the Gloomwood

Working name "the Gloomwood" (the user can rename it). The cat walks into the Old Hollow in the camp (where it stands
now) and comes out in a wood at night. The map's sketch, bottom (the way in) to top (the arena):

| # | Stop | What happens |
|---|---|---|
| 1 | **The way in** | A small glade with the hollow's far side behind the cat (the way home: "Go home" while nothing has woken). Lantern posts. Checkpoint |
| 2 | **Sleeping camp** | A dead campfire in a clearing; 4 Thornlings and a Glowcap asleep round it. They wake together when the cat comes within the wake radius, or one is hit |
| 3 | **Burrow holes** | Three holes beside the path. As the cat passes each one, 2 Grublings burst out. A short side path west leads to a nook with the Gloom-bound chest (Open it, or Break the seal for double loot and a Gloomtouched guard) |
| 4 | **Glowcap clearing** | A bigger pack (6) from the level's pool, glow mushrooms all round |
| 5 | **Rolling logs** | A stretch of path where logs roll across on a rhythm (the log trap). A chest at its end opens only if the cat was not hit in the stretch |
| 6 | **The Moonwell** (safe) | The spring (wade in to heal 40% of the cat's health, once), two boon shrines (take one), and a root lift home (keep the whole satchel, no boss loot). Checkpoint. Amber Grub chance |
| 7 | **The bridge** | A wooden bridge over a dark stream. An elite (Gloomtouched) and 2 guards hold the far end; 2-3 Gloom Moths fly in from the dark as the cat steps onto the bridge |
| 8 | **The arena gate** | Standing roots across the path, open. Checkpoint |
| 9 | **The boss arena** | A big round stone-circle arena (radius 11 m): pale flagstones, a ring disc with a carved sigil, a few ember cracks, rune stones (low ones in the south half) and giant swords on the north and side rim (glow mushrooms and standing stones in the first version, before 19 Nov). **Mossback** sleeps at the north side. When the cat steps in, roots close the way behind it (a WoW boss door) and the boss wakes with the boss bar. When it falls: the roots open, the boss chest, the root lift home, and on the very first clear the **Moss Warden's Gloom seal** at the north edge (stand on it to break it; `stations.free_guardian()`) |

- **Length:** about 130-150 m of path from the way in to the arena's south edge. A first run takes about 5-7 minutes:
  short walks between the fights (before 19 Nov: six; now nine, six with pips and three ambushes), then a boss (before 19 Nov 40-75 s; since the rework about 64-110 s depending on the cat).
- **Shape:** the path winds but runs mostly north (up the screen), because the camera looks north and the phone is
  portrait: the cat always sees what is ahead. Path 3.5-4.5 m wide, clearings radius 5-6 m, the arena radius about 11 m.
- **The boss:** Mossback (`bear`: Slam, Gloom Dash, roars up Thornlings). The big arena gives the dash room; a dash
  into a standing stone dazes it (the weak spot, as in Phase E 6.3). Up to 6 adds at once (4 before 19 Nov; it enrages below 35%). Health from
  the level's strength: about 9,900 at level 1 (`hp_mult` 2.2; about 3,000 before 19 Nov).

## Levels (replays get harder)

- The Gloomwood is the only dungeon for now, so replays are **levels** of the same map: Level 1 is open when the
  Hollow opens; beating the boss at level N opens N+1 (`Save.burrow_depth` keeps the highest level beaten).
- Each level uses Phase E's per-depth tables for strength, damage added, trap damage, pay (amber; glowstone from level
  2; heartwood from level 3), and the old tier pools for **which** monsters fill the packs (level 1 the Rootways pool,
  2 the Grotto's, 3 the Deeps', 4 the Warrens', 5 the Gloomheart's), so higher levels look and play differently on the
  same map. Pack sizes grow with the level; Root Snappers show up inside packs from level 2; Gloomtouched elites from level 1 (30%, more at higher levels; from level 2 before 19 Nov).
- The boss stays Mossback; Gloomtouched from level 4.
- Level 1's packs on the **first run ever** are fixed (as above) so the first run is gentle and the same for everyone.

## Rules that carry over

- **Knock-out:** back to camp, half the satchel kept (as now).
- **Leaving:** "Go home" at the way in (before anything wakes), the Moonwell's root lift (whole satchel, no boss loot),
  or the root lift after the boss.
- **Closing the game:** the run is saved at every checkpoint and when hurt (as now). "Go back in" puts the cat at the
  last checkpoint with its saved health, boons and satchel; fights before that checkpoint stay cleared, fights after it
  are full again. An old saved room run (Phase E format) is closed kindly: the whole satchel banked, the key given back.
- **No respawns** within a run. A stuck fight (nothing changes for 40 s) crumbles as now.

## How it looks: dark but readable

- Night: a deep night-blue sky and fog, a cool blue moonlight (the sun, dimmed and blue), soft blue ambient light.
- Light comes from glow mushrooms (teal), lantern posts (warm), Gloom crystals (purple), fireflies, and Sprig's lantern
  glow (already built). These are bright vertex-colour or emissive faces, so it **looks right on Low with no lights**.
  On Medium and High, a few OmniLights at the lanterns nearest the cat (keep under the Mobile renderer's 8 lights per
  mesh).
- The cat and every monster must stay easy to see: check screenshots on Low at 540x1170.
- **Woods:** dark trees, bushes, ferns, rocks and fallen logs line both sides of the path (MultiMesh in 10 m cells, as
  the camp's woods). Nothing tall stands between the camera and any walkable spot: the camera looks north from the
  south, and a thing h m tall hides about 0.84 x h m of ground north of it, so on the camera side of the path use only
  low plants, or leave a gap.
- The walkable area is the path and its clearings; the trees are the walls (no invisible walls inside clearings).

## Camera

- On the path: a little further out than the camp (distance about 24), the focus leading the cat along the path's
  direction so more of what is ahead shows.
- In the arena: further out (about 29) so the big place reads as big; the boss's telegraphs stay on screen.
- Keep the pitch, the field of view and the HUD's card-lift from the camp layout work.

## HUD

- The top bar's status: "The Gloomwood · Level 1", and a row of pips, one per fight and one for the boss, filling as
  they are cleared (this replaces the room pips).
- Banners as now ("The Gloomwood", "Level 1 · 6 fights and Mossback" (the pips still count 6 fights plus the boss; 3 ambushes have none); "The Moonwell"; "Mossback wakes!").

## Data (so new dungeons are data plus models)

- The dungeon list stays `balance.json` `burrows.list`; the Gloomwood is its first entry (id may stay `old_hollow` so
  saves keep working; its display name becomes "The Gloomwood").
- Each dungeon's map is a data file, `game/data/dungeons/<id>.json`: the path spine (points with half-widths), the
  clearings, the encounters (pack spots, kinds, wake radius; spawners with their trigger line and count), the traps,
  chests, checkpoints, standing stones, the props and lights, the end (`"boss"` with its kind and arena, or
  `"treasure"`), and the theme (sky, fog, ambient, moonlight, glow colours).
- A dungeon without a boss ends in a treasure clearing with the boss chest; the code must handle both.

## Tests (light, the user tests on the phone)

`--dungeon` (a scripted walk from the way in to the boss and the seal, screenshots at every stop), `--dungeonshots`
(each stop at 540x1170, Low and High), `--dungeonfall`, `--dungeonresume=1/2`, `--boss` (the arena only),
`--dungeonperf --quality=low`. Keep `--hollow`, `--dash`, `--burrowsave`, `--topup` and `--burrowhooks` working; drop
or rewrite the modes that only made sense for rooms.
