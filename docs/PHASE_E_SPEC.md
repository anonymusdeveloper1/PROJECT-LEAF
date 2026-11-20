# Phase E: the Burrows (spec)

> **18 November 2026, evening: the room runs below were replaced by dungeons as paths: see `docs/DUNGEON_SPEC.md`**
> (built the same evening; notes in `docs/PHASE_A_PROGRESS.md`, "The Gloomwood (dungeon rework, 18 Nov 2026)"). A
> Burrow is now one continuous map at night (`game/data/dungeons/<id>.json`), a path past fights to a boss in a big
> arena; replays are levels, not depths. Sections 4.3 (the run map and forks), 5 (rooms, doors, templates), 11.1's
> "one room at a time" and the room pips of 12.1 no longer apply; `burrow_room.gd` and `data/burrow_rooms.json` are
> gone. Everything else here (the Hollow, keys, the dash, traps, monsters, the satchel, boons, rewards, the area
> contract far away at the origin, saving) still stands unless DUNGEON_SPEC.md says otherwise.

## The user's decisions of 18 November 2026 (these override anything below that disagrees)

1. **The Burrows are most of the game after the missions.** The loop: go into a Burrow, bring back what the camp needs,
   upgrade the camp, get stronger, go deeper. Entry is **free and unlimited**: no hollow keys gate a run (keep any
   key the spec gives as a small bonus reward, never as a ticket; section 8 does not apply as a gate).
2. **Several Burrows, more over time.** Build the first one (the Old Hollow) on a data structure that holds a list of
   Burrows (each: name, entrance, theme colours, monster pool, boss, rewards), so new ones are data plus models.
3. **Who goes in: the cat, its pet and its mount.** No guardian ever goes in: they stay home and look after the camp.
8. **Guardians are found here and collected** (see GAME_PLAN.md section 0, "The camp guardian"). The first, the Moss
   Warden, is freed for sure at the end of the first Burrow (sealed in Gloom crystals behind the boss; stand on the
   seal to break it; call `stations.free_guardian()` from Phase C). More guardians are found sealed in later or
   deeper rooms. They fight in different ways, some help with other things (no resource production), none come into
   a Burrow. Guardian spots = home level - 3, at least 2, at most 5 (the user: 2 when the missions end, +1 per home
   level, up to 5). Add home levels 7 and 8 (after the missions, paid mostly with Burrow materials; new home and
   campfire models, falling back to level 6's until they exist). Phase C built one guardian
   (`main.guardian`, `guardian.gd`): generalise it to a list of guardians, each with its own kind and post, with the
   enemy hooks looping over them. New kinds need the user's Meshy models (concept images first; stand-ins until then).
4. **Food matters from the start** (Phase C makes the garden the gift of mission 1): a knocked-out mount is brought
   back with food in the Burrows too (the same Feed button as in missions), and a packed lunch (food) can be eaten in a
   run to heal the cat.
5. **What is earned and sold.** New pets and mounts are looks only (same strength). **Attachments for the pet and the
   mount** (saddles, armour, charms, lanterns) **help in the Burrows**: they are the late game's real goods. For now
   they are bought with what the Burrows pay (in-game); real-money sales come later. Give the first set: 3 for the
   mount and 3 for the pet, each with a clear Burrow-only effect (more health in a run, a stronger signature move, more
   loot, a lantern that shows traps...), bought and equipped on the Stable and Nest cards.
6. **Nothing happens while the game is closed**, as the rest of this spec already says.
7. The user tests on the phone: build it complete and playable, with light testing (no long test runs).
9. Guardian upgrades at the stone cost leaves (the user, 18 November 2026), as Phase C built them; do not switch them
   to Burrow materials.
10. **Only one guardian for now** (the user, 18 November 2026, while Phase E was being built; it replaces decision 8's
    collection): the Moss Warden, found in the Burrows and never on the way in. It lies sealed in Gloom crystals behind
    the boss at the end of the first clear of the Old Hollow; the cat fights through the run, beats the boss and stands
    on the seal to break it (`stations.free_guardian()`). No other guardian kinds, no guardian spots and no choosing at
    the stone: those are for later (`GAME_PLAN.md` keeps them as "later"). Home levels 7 and 8 stay, for the camp
    growing with Burrow materials.
11. The answers to section 23 (the user, 18 November 2026): a knock-out keeps half the materials; entry is free and
    unlimited and a key is only a bonus (it gives the run a boon from the start), `Save.burrow_keys` shared with Phase D;
    entry is blocked only while a raid is pending or a fight is on (ruins and wear only show a warning on the card);
    the Leaf Dash is for the Burrows only; the sealed hollow shows from the first mission won; the new creatures use
    stand-ins until the user's Meshy models come; the top upgrades as proposed; a dish in the pot goes down with the cat.

**Built 18 November 2026** (notes, choices and tests: `docs/PHASE_A_PROGRESS.md`, "Phase E"). Where the build differs
from the text below, the decisions above and those notes win.

18 November 2026. **Status: a proposal for the user to approve.** It follows `GAME_PLAN.md` section 0 (Draft 7, "After
the missions", the Burrows bullet) and the code as it is today (`game/scripts`, `game/data/balance.json`). Godot was not
run for this spec and no game file was changed. Every number is a first guess, to be tuned by play.

**Where it comes from.** Three designs were judged: "gameplay first", "lean and safe first" and "player delight first".
All three judges picked **gameplay first** (forks, the Leaf Dash, the satchel, a run that waits while the game is
closed). This spec starts from it, takes out every rule problem the judges found, and adds the best ideas of the other
two:
- From "lean and safe": a dedicated patch number (99) for monsters below ground, `fight.spawn` handing over to the
  Burrows, narrow rooms with a wider camera so the whole room is always on screen, no entry while the camp is damaged,
  a stuck-room safety net, a fairness rule for warnings, and new bosses used only once their model exists.
- From "player delight": the sealed hollow you can see long before it opens, the reveal on the 15th win, Sprig glowing
  like a lantern underground (without needing a light), the Amber Grub, chests and the spring that work by walking up
  to them, and the fix for the HUD status line.
- Taken out: the optional daily key bonus and anything else that reads the clock, and the run ending when the app is
  closed. Smoothed: the jump in boss health from depth 1 to depth 2. Trimmed for the first build: station level 4,
  Watch Root, Ember Heart and two of the eight boons.

**Checked against `docs/PHASE_C_SPEC.md` and `docs/PHASE_D_SPEC.md`** (both exist now). To fit them, this version:
- runs the hollow's path **west round Phase C's garden** (C puts the garden bed at (0.5, 8.4), on the straight line
  south);
- makes the Burrows' top defences **level 5**, because Phase D already adds level 4 (for Gloom shards), and gives the
  **Moss Warden a level 4** paid with Burrows materials, as Phase D asks;
- renames the second material from "gloomglass" to **glowstone** (teal), so it is never confused with Phase D's violet
  Gloom shards;
- shares `Save.burrow_keys` with Phase D (its raids give the keys), uses Phase D's `add_gloom("burrow_run")`, its quiet
  saves (`Save.save_game(true)`), its pause hook (`main._notification`) and its pickup kinds (`"leaf"`, `"shard"`);
- lets a dish waiting in Phase C's pot go down with the cat;
- drops the seed drops (Phase C's garden has no seed inventory: seed packets are bought by the Plant row);
- adds no row to the top-left of the HUD (Phase C's meal chip and Phase D's shard row already fill it): materials show
  on the cards.

Section 21 lists every touch point with Phase C and Phase D, both ways. Phase E works whichever of them is built first.

---

## 0. In one paragraph

After the last mission, the old root hollow at the south edge of the woods breaks its Gloom seal: **the Old Hollow**.
It has sat there, sealed, since the first mission was won, with two violet eyes blinking under the crystals. The cat
walks onto its ring, and the card spends one **Hollow key** to go down to a depth. A **run** is 4 or 5 small rooms,
seen one at a time, and takes about 3-5 minutes. It starts with a den, then **forks**: the cat picks one of two
tunnels by the sign over each door (Den, Gauntlet, Treasure, Elite). Just before the boss comes a last fork, **Spring**
(heal and take a boon) or **Elite** (a hard fight for sure glowstone), and then the **boss den**. There are no towers,
no healing in the camp and no trails. Monsters sleep in groups, wake together and hunt the cat. Grublings burst out of
the floor, Glowcaps lob spore bombs at the cat's spot, Root Snappers bite along a line, and charges smash into pillars.
The cat survives by moving and by the **Leaf Dash**, a flick of the thumb. Rare materials (amber, glowstone,
heartwood) go into a **satchel**: climbing out brings all of them home, and a knock-out brings home half. **Keys come
only from things done in play** (raids held, replays won, first clears). Nothing refills by time, and the key ring
holds 3. Nothing about a run moves, ends or is lost while the game is closed: a run in progress waits at the Hollow.

---

## 1. The user's rules, and how this spec keeps them

| Rule | How |
|---|---|
| One cat protecting its campfire camp, not a village | Only the cat and Sprig go down. Thistle is too big for the tunnels and stays at the stall. The Moss Warden (Phase C) stays guarding the camp. No workers, no expeditions, nothing produced. |
| **Nothing happens while the game is closed** | Phase E reads no clock and saves no time or date anywhere. Keys never refill. A run in progress is saved as it was at the start of its current room (with the cat's health, updated when it is hurt) and waits at the Hollow card: it is never played, finished or lost while the game is closed. Every timer in the Burrows clamps its frame time (`minf(delta, 0.1)`) and stops while `main.frozen`, so one long frame after Android resumes the app cannot skip a warning. |
| The camp must be kept in good condition at all times | The Hollow refuses entry while a building is a ruin, the campfire is ashes, a raid is pending or under way, or a mission is on. The materials buy the camp's strongest defences and the Warden's top level. |
| The Burrows open after the last mission, to earn resources for the camp and its defences | Sealed until the 15th mission is first won. They pay the rare materials for mastery, level-5 defences and the Warden's level 4. |
| "A few keys a day so they never replace the camp" | Each key needs camp play (a Gloom Raid held, or a mission replay won), or a first clear. The ring holds 3. Raids and runs take turns. There is no clock-based limit. |
| Short runs of 3-5 minutes, a few rooms, traps, a boss | Depths 1-2: 4 rooms (about 3-3.5 min). Depth 3 and deeper: 5 rooms (about 4-5 min). |
| The cat (with the pet) moves and dodges more than in the waves | Telegraphed attacks every few seconds, the Leaf Dash with "close call" rewards, pillars that daze charging monsters, traps, and no towers to hide behind. |
| No menus | The Hollow, the doors, the shrines, the treasure chest and the lifts are rings with cards. The spring and the other chests work by walking up to them. |
| Looks-only monetisation | Keys, materials, boons and the upgrades they buy are never sold. |
| Low-end phones | One room exists at a time, at most 10 live monsters (8 on Low), no lights needed (glow comes from bright vertex-colour faces), and every room costs less than the camp (section 19). |
| Characters from the user's Meshy, props from Claude in Blender | 5 new characters as concept prompts (section 18), with stand-ins until they arrive. Props and the new defence models are Blender work (section 17). |

---

## 2. How a run plays, and why it is not a wave

| | Waves (missions, raids) | A Burrows run |
|---|---|---|
| Where danger comes from | Down 4 trails toward a fixed camp | From every side of a small room, and out of the floor |
| What the cat does | Holds ground near the camp and protects buildings | Travels north room by room and protects only itself |
| Help | Towers, barricades, spikes, the Warden, Sprig, Thistle | Sprig only |
| Healing | In the camp between waves | A spring, dew drops and a dew bud after some rooms. Damage carries from room to room |
| Threats | Health races and siege pressure | Telegraphed area attacks every few seconds: lobs, falling crystals, bites along a line, charges, rolling logs, monsters bursting out of the floor |
| Skill | Positioning, hiding, upgrades | Dodging with the Leaf Dash, baiting charges into pillars, reading the warnings on the ground |
| Choices | What to buy between waves | Which tunnel; open the chest or break its seal; drink and climb out or face the boss; climb out or go deeper |

**A run at depth 2 (the Glowcap Grotto), minute by minute (targets):**
- **0:00** The Hollow card: "Depth 2 · Enter" spends a key. Fade to the first room. Banner "The Glowcap Grotto", sub
  "Depth 2 · 4 rooms and Mossback". Sprig glows warm teal at the cat's shoulder. A Berry Tart was waiting in the pot,
  so the cat eats it on the way down (Phase C).
- **0:05 Den.** Six monsters stand asleep. When the cat comes within 5 m, crosses the wake line, or hits one, they all
  wake ("!"). Five seconds later two Grublings burst out of the floor near the cat (a violet ring warns 0.8 s ahead).
  The Glowcaps back off and lob spore bombs at the cat's spot: dash out of the ring. Room clear: a dew bud blooms
  (+2 health), the root gates in the north wall rise, and the two doors show their signs, "Gauntlet" and "Treasure".
- **0:55 Gauntlet** (picked). Rolling logs cross the room in three lanes, and a chest waits at the far end. "Reach it
  unhurt and it opens." Dashing through a log at the last moment is a **close call**: the next arrow does double
  damage.
- **1:30 Fork: Spring or Elite.** The cat has 7 of 15 health and takes the Spring: it wades in to drink (full
  health), then picks one of two boon shrines ("Sharp Thorns: arrows hit 25% harder"). A root lift also stands there:
  "Climb out now with your satchel", the safe exit.
- **2:00 Boss den.** Mossback sleeps at the far end. Awake, it slams and roars up Thornlings; its Gloom Dash ends in a
  pillar: "Bonk!", dazed for 2.5 s, and it takes 50% more damage.
- **3:00** Mossback falls. Its helpers vanish into petals, and the boss chest bursts open with amber and glowstone that
  fly to the cat. Two rings: **Climb out** (bank everything) or **Go deeper** (one more key: depth 3 at once, keeping
  health, boons and satchel, +15% on the satchel when banked, but a knock-out still keeps only half).

---

## 3. The entrance: the Old Hollow

### 3.1 Where it stands
- **Hollow centre `H = (0, 0, 19.0)`**, due south at the woods' edge (the woods start at r 21, the first trees at
  r 21.6). Collision circle radius 1.4, tag `"hollow"`. Its far edge is at r 20.4.
- **Ring at `(0, 0, 16.9)`**, radius 0.8, on the camp (north) side.
  - The usual rule is a ring on the camera (+Z) side of its building. That is not possible here: the cat is held
    inside r 20.3 (`MOVE_R`), and the hollow must sit at the woods' edge. So the hollow shows just below the cat on
    screen, which suits a hole in the ground the cat looks down into.
- **Return spot `(0, 0, 15.5)`**, facing north (toward the camp). It is off the ring, so the card does not pop up
  again when the cat comes back.
- **Why here.** The south half has no trail, Gloom, patch or sunrays at any home level. Phase D adds nothing south of
  the campfire ("that is the Burrows hollow's place"). The lake is south-west (about -113°, r 3.5-10.2), more than 9 m
  away. Phase C's garden bed (0.5, 8.4) is 10.6 m away, its fishing spot (-7.2, 5.3) 15.9 m, and its guardian stone
  (8.0, 0.75) 20.4 m. The ±62° trails are more than 17 m away.
- **Camera check** (distance 18, because the cat is outside the camp). With the cat on the ring, the focus clamps to
  `(0, 0, 16.5)`. The camera sits at about `(0, 13.8, 28.1)`. The cat is just below the screen centre and the hollow is
  in the lower middle, centred left to right on every phone shape. The camera's line to the cat is only 0.9 m high over
  the hollow's north rim (z 17.6), 2.6 m over its centre, and 4.3 m over its south rim (z 20.4). That gives the model's
  height rules (section 17): **north rim ≤ 0.6 m, south rim ≤ 1.8 m, root arches on the east and west sides up to
  3.0 m**.

### 3.2 The clearing (so the woods do not hide the hollow)
The camera's line to the cat is only about 5.8 m high where the trees start (z 21.6), and those trees are 6-8.7 m tall.
Trees past z 26.5 are below the bottom edge of the view and do not matter. Add to `world.gd`:

```gdscript
## The wedge of woods and meadow kept clear round the Old Hollow, and a strip along its path (Phase E).
func in_hollow_clear(p: Vector3) -> bool:
	var h: Dictionary = Data.b["burrows"]["hollow"]
	var c: Dictionary = h["clear"]
	if p.z > float(c["z_from"]) and p.z < float(c["z_to"]):
		if absf(p.x) < float(c["half_x"]) + float(c["widen"]) * (p.z - float(c["z_from"])):
			return true
	var q := Vector2(p.x, p.z)
	var pts: Array = h["path"]
	for i in pts.size() - 1:
		var a := Vector2(float(pts[i][0]), float(pts[i][2]))
		var e := Vector2(float(pts[i + 1][0]), float(pts[i + 1][2]))
		if Geometry2D.get_closest_point_to_segment(q, a, e).distance_to(q) < float(c["path_clear"]):
			return true
	return false
```
With the numbers in section 13: |x| < 4.0 at z 15.5, 6.4 at z 21.6 and 8.4 at z 26.5, plus a strip 1.8 m either side
of the hollow path (section 3.3). The scatter is built before the path mask is stamped, so the strip has to be worked
out from the path's points, not from `path_strength`.

- `_woods` (world.gd 670-771) skips trees, undergrowth, coral trees and meadow flowers, rocks and mushrooms where
  `in_hollow_clear(p)` is true. **Draw every random number for the instance first, then skip it**, so the rest of the
  seed-2611 woods stays exactly where it is.
- `_hideouts` (524-569, seed 909): a post-filter at the end, the same way Phase C's `in_reserved` filter works (C 1.3):
  drop every hide spot within 3.0 m of `H` or inside `in_hollow_clear`, and free its node. The generation loop stays as
  it is.
- `grass.gd` `keep_out` (35-56): add `[H, 2.4]` and `[ring, 1.1]` (a separate list, never the `VILLAGE` dict).
- `defences._valid` (347-360): `if main.world.in_hollow_clear(pos) or pos.distance_to(H) < 2.6: return false`. In
  `defences.build()`, next to Phase C's reserved-ground refund: any saved tower or spikes entry (with `x`/`z`) inside
  that area goes back to `Save.items[type]`, with the same `main.hud_note` ("%d defence piece%s stood where the camp
  needs room: place it again").
- Dressing in the notch: `hollow_roots_a` and `hollow_roots_b` (section 17), two giant roots snaking flat from the
  treeline toward the hollow, so the gap reads as "where the old roots go down", not as missing trees.
- If the `--hollow` screenshots (section 20) still show a crown over the cat, raise `widen`.

### 3.3 The path (round the west side of Phase C's garden)
- Always stamped in `world.rebuild_paths` (350-382), from the first launch, as part of the teaser, at the village lane's
  width (`CAMP_PATH_HALF`), smoothed with `_smooth(..., 7)`:
  - the lane trunk `(0, 0, 1.0) → (0.3, 0, 5.4)`, stamped again even if the village lane already stamps it (before any
    village building exists it is the only way south);
  - then `(0.3, 0, 5.4) → (-1.0, 0, 6.2) → (-2.3, 0, 8.3) → (-2.2, 0, 11.0) → (-1.0, 0, 13.6) → (0.0, 0, 15.9)`.
- Because it is always there, `_path_key` needs no change.
- Clearances (positions from `world.gd` and `PHASE_C_SPEC.md`; `--hollow` checks them in the game):

| Thing | Distance from the path's centre line | Clear of the path's edge |
|---|---|---|
| Garden ring (0.5, 7.2) | 1.64 m | 1.1 m (the cat on the path never stands in it) |
| Garden bed (0.5, 8.4), r 1.1 | 2.43 m | 0.78 m |
| Phase C reserved ground (0.5, 7.9), r 2.0 | 2.17 m | outside it |
| Mushroom Cottage ring (about (-2.1, 5.1)) | 1.56 m | 1.0 m |
| Lake shore (centre (-6.3, 2.7), r ≤ 3.3) | 6.9 m from the centre | 3.0 m |
| Fishing ring (-6.48, 5.28) | 5.1 m | far |

### 3.4 Sealed, then open
- **The model is always there** (`burrow_hollow` with its `seal` part: a plug of violet Gloom crystals and brambles
  over the hole). Its `eyes` part (two violet glints) blinks: shown for 0.25 s every 4-7 s (random), only while sealed.
- **The ring shows from the first mission won** (`Data.progress() >= 1`): dim violet `Color(0.78, 0.55, 1.0)`, no
  pulse, with the sealed card (section 12.2).
- **The reveal.** `main.on_stage_end(won)` ends with `burrows.check_open()`. If the hollow is not open and
  `Data.next_mission() >= Data.mission_count()`, it waits `reveal_after_win_s` (8 s: after the win banner, a gift
  banner and Phase D's raids intro). If a banner is still on screen (`hud.banner_busy()`, new: true while the banner
  label is visible), it waits 1 s more, at most 4 times. Then `open_hollow(true)`:
  1. `Save.set_flag("hollow_open")`, `Save.burrow_keys = maxi(Save.burrow_keys, keys.open_fill)` (fills the ring to
     3; a player who already earned keys from raids loses nothing), save.
  2. `main.shake(0.35)`. The `seal` part sinks (tween its position y down 1.2 m and scale y to 0.1 over 0.9 s, then
     hide), and the `eyes` part hides. `Fx.shockwave(main, H, 2.4)`, `Fx.kill(main, H + (0, 0.8, 0), violet)` 3
     times, `Fx.flower_ring(main, H, 2.0)`, `Sfx.play("win")`.
  3. `hud.banner("The Old Hollow opens!", gold, "Something stirs under the roots")`, then
     `hud.tip("The Old Hollow is open at the woods' edge. You have 3 Hollow keys.", stations.rings["hollow"])` (flag
     `told_hollow`).
  4. The ring turns gold `Color(1.0, 0.82, 0.3)` and pulses while a key is held and nothing blocks entry.
- **Old saves** that already won all 15 missions get the same reveal `reveal_old_save_s` (6 s) after loading
  (`check_open()` from `main._ready`, deferred, after the HUD exists, so it comes after Phase D's "raids are open"
  intro and Phase C's catch-up tip). The flag is set in the same step, so the ring is filled only once.

### 3.5 Every registry the `hollow` id joins
Phase C found that a new station id must join several lists or the game crashes (C 1.2). For `hollow`:

| Where | What to add |
|---|---|
| `stations.gd` `FOOT` (27) | `"hollow": 1.4` (`foot()` crashes on a missing key) |
| `stations.build()` ring list (33) | `"hollow"`, with `_card_hollow()` |
| `stations.model_name()` | `hollow` → `burrow_hollow` |
| `stations.shown()` | `hollow`: always true (the sealed model is the teaser) |
| `stations.ring_shown()` | `hollow`: `Data.progress() >= int(cfg.hollow.ring_from_missions)` |
| `stations.refresh()` model list (101) and ring match (132-142) | the model at `station_pos("hollow")`; the ring at `cfg.hollow.ring`; the `seal` and `eyes` parts shown while sealed |
| `world.station_pos()` (250-264) | `"hollow"` returns `cfg.hollow.pos` (a missing id returns ZERO, the campfire) |
| `world.build` | `add_circle(H, 1.4, "hollow")` |
| **Not** touched | `BUILDINGS` (no hp, no ruins, never a siege target), `VILLAGE`, `_ruin_card`, `_card_shop`, `gift()` |

---

## 4. Depths, tiers and the run map

### 4.1 Depths
- **Depth 1 is open** when the Hollow opens. **Depth d+1 opens** when depth d's boss is beaten
  (`Save.burrow_depth`, the deepest depth beaten).
- Five named tiers. Depth 6 and deeper reuse tier 5 with the boss cycle: +0.5 strength and +10% pay per depth. That
  depth number is the record (`burrow_stats.best`).

| Depth | Tier | Rooms (with the boss) | Monster strength | Pool | Boss | Pays |
|---|---|---|---|---|---|---|
| 1 | The Rootways | 4 | 2.0 | thornling, grub, glowcap, boar, mole | Thornling Chief, Gloomtouched | amber |
| 2 | The Glowcap Grotto | 4 | 2.5 | grub, glowcap, brute, puffball, frog (+ snappers) | Mossback | amber, glowstone |
| 3 | The Amber Deeps | 5 | 3.0 | beetle, mole, crow, boar, thornling, grub (+ snappers) | **Old Grubber** (new; Gloomtouched Mossback stands in until its model exists) | + heartwood |
| 4 | The Crystal Warrens | 5 | 3.6 | moth, pitcher, glowcap, snail, beetle (+ snappers) | The Owl Witch | more of all |
| 5 | The Gloomheart | 5 | 4.2 | stump, beetle, glowcap, moth, puffball, crow, grub (+ snappers) | The Elder Thornstag | the most |
| 6+ | The Gloomheart, deeper | 5 | +0.5 a depth | as depth 5 | cycle: Old Grubber, Mossback, the Owl Witch, the Elder Thornstag, all Gloomtouched | +10% a depth |

- For comparison, mission 15 runs at strength 2.12 to 4.13, and Phase D's raids at 2.2 + 0.07 a raid level. Within a
  run, monster strength rises 4% a room (`room_ramp`). Bosses ignore the room ramp.
- **Monster damage below ground is not scaled by strength.** It is the kind's base `damage` plus
  `damage_add_by_depth` (0, 0, 1, 1, 2 for depths 1-5; then +1 every 2 depths, at most +4). Hits stay readable (1-2 at
  depth 1, 3-4 at depth 5), and dodging is what matters. Health scales with strength as usual.

### 4.2 Bosses and their health

| Depth | Boss | Health | Notes |
|---|---|---|---|
| 1 | Thornling Chief, Gloomtouched | 160 x 2.0 x `hp_mult` 9.4 ≈ 3,000 | 3 Grublings erupt near the cat every 12 s. A gentle first boss |
| 2 | Mossback | 1,500 x 2.5 x 1.05 ≈ 3,940 | Slam, Gloom Dash (into a pillar: dazed), roars up Thornlings |
| 3 | Old Grubber, the Gloom Badger | 2,000 x 3.0 x 0.85 = 5,100 | New (section 7.3). **Until `res://assets/enemies/grubber/grubber.glb` exists, Gloomtouched Mossback stands in** (1,500 x 3.0 x 1.15 ≈ 5,180), so the game never shows a placeholder boss |
| 4 | The Owl Witch | 2,200 x 3.6 x 0.82 ≈ 6,490 | Blink, orbs, hex, moths |
| 5 | The Elder Thornstag | 3,200 x 4.2 x 0.6 ≈ 8,060 | Charges into pillars, roars up Stump Golems |
| 6+ | Cycle | the cycle's `hp_mult` x strength | Gloomtouched |

- Target: boss fights of 40-75 s for a cat at the depth's suggested power. A cat just past mission 15 does about 110
  arrow damage a second plus Sprig's 18. With dodging it is shooting about 60% of the time, so depth 1 takes about
  40 s and depth 2 about 50 s. Depths 4-5 assume some mastery levels (section 9.3).
- A boss room never has more than 4 minions alive at once (`boss_minions_max`). Summons over the cap are skipped.

### 4.3 The run map (forks), seeded
```
plan(depth, seed):                                # returns the list of steps
  n = rooms_by_depth[min(depth, 5)]               # rooms before the boss: 3 at depths 1-2, 4 from depth 3
  steps = [ {room: "den"} ]                       # always a den first ("den_first" on the very first run)
  for i in 1 .. n-2:  steps += { fork: two_distinct(fork_weights, rng(seed, i), avoid = the previous pair) }
  steps += { fork: ["spring", "elite" if depth >= elite_from_depth else "treasure"] }
  steps += { room: "boss" }
```
- `fork_weights`: den 3, gauntlet 3, treasure 2, elite 2 (elite only from depth 2). A fork never offers two of the same
  type.
- The template for each step is picked with `rng(hash([seed, step, type]))`, so a resumed run rebuilds the same room.
  The seed is `hash([burrow_stats.runs, depth])`: no clock.
- **The very first run** uses a fixed plan: `den_first`, then the fork `[gauntlet, treasure]`, then
  `[spring, treasure]`, then the boss.
- Lengths: depths 1-2 are den, one fork room, spring (or treasure/elite), boss: about 3-3.5 min. From depth 3 there is
  one more fork room: about 4-5 min.

---

## 5. Rooms

### 5.1 Size and layout
Every room is **7 m wide inside** (x from -3.5 to 3.5) and runs **north** (-Z, up the screen), because the camera looks
north. At camera distance 21.5 the screen shows about 7.6 m across at the cat, so both walls are always on screen and
nothing attacks from off screen. Local room space: the entry (south edge, camera side) is at z = 0, the cat appears at
`(0, -1.2)`, and the north wall is at z = -l.

| Type | Length l | What happens | Done when |
|---|---|---|---|
| **Den** | 13 | 4-9 monsters asleep at spawn spots (more by depth). They all wake when the cat crosses z < -3, comes within 5 m of one, or hurts one. `late_after_s` (5 s) later the tier's swarm comes: Grublings burst out near the cat, or (in the Warrens) moths fly in at the north doors. From depth 2 a Root Snapper may hold a template's snapper spots. Some dens have fern patches to hide in | Every monster is dead. A dew bud blooms (+2 health), the gates rise, the doors open, pickups fly to the cat (`pickup.call_home`). 12% chance an **Amber Grub** then pops out (section 7.4) |
| **Gauntlet** | 16 | Traps on a rhythm (logs, thorn plates, falling crystals; from depth 3 a Gloom tide creeps up behind). Optional snappers beside the path. A chest at the far end | The cat reaches z < -l + 2.5. The chest opens **only if the cat was not hurt in this room**; otherwise "The chest stays shut: you were hit" and it crumbles. The doors are open from the start |
| **Treasure** | 11 | A Gloom-bound chest. Its card: **Open it** (normal loot) or **Break the Gloom seal** (double loot, but a Gloomtouched guard and 2 adds burst out and the gates shut until they fall) | The chest is opened (and the guard beaten, if the seal was broken) |
| **Spring** | 12 | A moonwell spring: wade in and stand 1.5 s to drink (full health, once). Two **boon shrines**: take one, and the other fades. A **root lift**: climb out now with the satchel (no boss loot). 30% chance of an Amber Grub | The cat takes the single door (to the boss) or the lift |
| **Elite** | 13, 2 pillars | One Gloomtouched elite and 2 adds, awake at once. Sure loot: the elite table (amber 1-2 and glowstone 1, heartwood sometimes from depth 4) | All dead (dew bud as in a den) |
| **Boss** | 15, 3 pillars | The boss sleeps at the north end and wakes like a den, with the boss bar. When it falls: every other monster vanishes into petals, the boss chest opens when the cat walks up, the root lift rises in the north-west and a "Deeper tunnel" opens in the north-east | Climb out or go deeper |

- **Doors** sit in the north wall: two at x = ±1.9 for a fork, one at x = 0 for a single exit, or at x = +1.9 when the
  room has a lift at x = -1.9 (the spring). Each door has a ring at `(door_x, -l + 1.0)` and a sign with the next
  room's type. The two fork rings are 3.8 m apart (rings must be 1.5 m or more apart, because `_update_rings` takes the
  first ring that contains the cat).
- **Entry lift.** The first room of every run also has a root lift at `(-2.5, -1.0)`. Until the den wakes, its card
  offers "Climb back up" and gives the key back. After that it is gone.
- **Walls** are the room's rectangle (`constrain`) plus pillar circles. There is no other collision inside a room, so
  nothing can get stuck on scenery. The south wall is a low lip (≤ 0.5 m), so the camera sees in.
- Templates are data (`game/data/burrow_rooms.json`, section 14): 12 to start with, and more can be added without
  code.

### 5.2 Camera in a room
- Distance `burrows.cam_dist` = **21.5** (the camp distance).
- Focus x is locked to the room's centre line. Focus z follows the cat: `clamp(cat_z + CAM_LEAD, -(l - 9.0), -1.5)` in
  room space (the lower bound is never above -1.5). At focus -1.5 the top of the screen shows about 13 m ahead, so
  rooms of 13 m or less fit whole.
- Pitch, field of view and no turning stay as they are. After every teleport: `main.snap_camera()` (sets `_cam_dist`
  to its target and runs `_update_camera(1.0, true)`).

### 5.3 Safety net (like fight.gd's flee rule)
Every 0.5 s, `burrow.gd` adds up the cat's health and every room monster's health. If the sum has not changed for
`stuck_after_s` (40 s), no boss is alive and nothing is left to spawn, the remaining monsters crumble into the roots
(petals, freed, no drops) and the room counts as cleared.

---

## 6. Moving and dodging

### 6.1 The Leaf Dash (one thumb)
- **Gesture: a flick on release.** `joystick.gd` keeps the touch's positions for the last `flick_window_s` (0.08 s).
  When the finger lifts, if it moved at least `flick_min_px` (70 canvas px, about 875 px/s) in that window, the
  joystick emits `flicked(dir)` in that direction. This covers both a quick separate flick and a "swipe and let go" at
  the end of steering. A thumb that steers and then lifts slows down first, so ordinary steering, taps and slow lifts
  never dash. Touches that start on a card (`ui_block`) never count. On desktop, Space dashes in the stick direction (or
  the facing). The autotest uses `joystick.force_flick(dir)`.
- **The dash:** 3.0 m in 0.22 s. **Can't be hurt for 0.32 s.** Cooldown 1.4 s. The cat keeps aiming and shooting
  through it. It still goes through the room's `constrain`, so it cannot pass through walls, pillars or shut gates. It
  clears `slow_t` (dash out of slime and spores). Not while riding (never below ground) or knocked out.
- **Close call:** if anything would have hurt the cat during the dash's protection (a hit, a trap, a burst), the hit is
  ignored, "Close call!" pops up, and `main.empowered_t = 2.0`. The next arrow within 2 s does double damage, through
  the existing Ambush path in `player._fire` (380). This rewards dashing through an attack at the last moment.
- **Look:** there is no dash clip yet. The cat plays Run at 2x and leans 15° forward, with a quick squash
  (`Fx.boing`), a few petals (`Fx.petals`) and dust (`Fx.dust`). The hood and cape cloth follow by themselves. Later,
  optional: a 0.25 s `Dash` clip made in the Cat Ranger project (`D:\3D Modeling Test`).
- **Cooldown display:** a small arc under the cat's health bar (`lifebar.gd`) that fills while recharging. Hidden when
  the dash is ready or not available.
- **Where:** **the Burrows only** (`burrows.dash.everywhere = false`), so mission and raid balance does not change, and
  Phase C's tap-anywhere fishing never meets a flick. Turning it on everywhere is one flag (question 4).

### 6.2 Telegraphs (everything that hurts much is announced)
All big attacks use the existing `Fx.telegraph_ring(parent, pos, radius, duration, color)` and
`Fx.telegraph_line(parent, from, dir, length, width, duration, color)` with a fixed warning time. **Fairness rule**
(checked by `--traps` and `--boss`): traps warn at least 0.8 s ahead and monster specials at least 0.6 s, and safe
ground is never more than 1.6 m from the edge of a trap's danger area.
- Glowcap spore bomb: ring r 1.1 at the cat's spot plus 0.5 s of its movement, 1.1 s.
- Falling crystal: ring r 0.9 near the cat, 0.9 s.
- Rolling log: band across its lane, 1.0 s.
- Thorn plate: ring r 0.85, 0.8 s; plates fire in rows that sweep from north to south.
- Spore vent: ring r 1.4, 0.8 s.
- Root Snapper bite: line 3.2 m x 0.9 m, 0.7 s.
- Grubling bursting out: ring r 0.8, 0.8 s.
- Old Grubber: eruption ring r 1.6, 0.9 s; roll line 9 m, 0.9 s.
- Boar, stag and bear charges and dashes already have their lines.

### 6.3 Pillars, walls, daze and the weak spot
A charging monster (boar, stag, the bear's Gloom Dash, Old Grubber's roll) that the room stops against a **pillar or
wall** is **dazed for 2.5 s** ("Bonk!" and stars) and takes **x1.5 damage** for the daze plus 0.3 s (`_vuln_t`,
`vuln_mult`). Boss dens have 3 pillars and elite arenas 2. Tip on the first boss den (`told_pillar`): "Lure its charge
into a pillar: it gets dazed and takes extra damage."

### 6.4 Traps (`trap.gd`)
Traps hurt monsters too (`foe_damage` x the room's strength, once per firing per monster), so luring monsters through a
log lane or a crystal fall is a tactic. Damage to the cat is `trap_damage_by_depth` (1, 1, 2, 2, 2), through
`player.hurt`, so the dash's protection applies.

| Trap | Made from | Rhythm | Hurts |
|---|---|---|---|
| `log` | `log_fallen` (existing, 2.09 m), long axis along z, rolling along x | Lanes at z -4.5, -8.5, -12.5. Every 3.2 / 2.8 / 2.4 s, phase-shifted. Rolls wall to wall at 6 m/s, spinning, changing direction each time | The cat and monsters in its band (\|dx\| < 0.45, \|dz\| < 1.05). Knockback |
| `thorns` | `trap_thorns` (new) | A 3 x 5 grid of plates. One row fires every 0.5 s, sweeping north to south, cycle 2.6 s. Spikes up for 0.5 s | Anything on a plate |
| `crystal` | `gloom_crystal` (existing), falling | Every 1.4 s at a random spot within 2.5 m of the cat, inside the trap zone | Anything within 0.9 m |
| `spores` | `spore_vent` (new) | On 1.5 s, off 2.0 s, warning 0.8 s, r 1.4 | Slows the cat 2 s (`player.slow_t`). No damage |
| `tide` | code (a violet wall) | Gauntlets from depth 3. Starts 3 s after entry at the south wall, creeps north at 0.55 m/s, stops when the cat reaches the end | 1 damage a second inside it |

### 6.5 Health in a run
- The cat starts a run with its current health (plus a dish's health boost, if one goes down with it). **It does not
  heal over time below ground** (`inside_camp` is false there).
- The **spring** heals fully, once.
- A **dew bud** after a cleared den or elite room heals 2.
- **Dew drops:** 8% of kills (25% of elites; x3 with the Dewdrop Charm boon) drop a dew pickup that heals 1.
- A **knock-out** ends the run (section 9.1). There is no respawn below ground.

### 6.6 Hiding (optional, cheap)
A den template may list fern patches (`ferns: [x, z, r]`). While in the Burrows, `main._update_hiding` asks
`area.hide_at(p)` instead of `world.hide_at(p)`, so the existing Hidden and Ambush mechanic works there: wait in the
ferns, and the first shot that wakes the room is an Ambush.

---

## 7. Monsters

### 7.1 Every existing kind, in burrow mode
In `enemy.gd`, `func _in_area() -> bool: return main.area != null and main.area.owns(global_position)`.
- **Patch number 99.** Burrows monsters are spawned with `AREA_PATCH = 99`, never -1 (with -1, `trails.size() > patch`
  passes and `trails[-1]` silently uses the last trail). Harden the existing guards in `setup` (line 123) and `_think`
  (464) to `patch >= 0 and main.world.trails.size() > patch`.
- **The behaviour key.** Phase D changes `match id:` in `_think` (468) to `match String(info.get("ai", id)):`. The new
  branches below go into that same `match` (if Phase D is not built yet, make that one-line change in step E3).
- **Sleep and wake:** new vars `awake := true` and `guard_at`. While asleep, `_think` keeps the monster in place playing
  Idle, with an occasional "z" text. It wakes on damage (`hit`), on the cat within `wake_r` (5 m), or on
  `area.wake_room()` (the cat crossing the wake line, or any monster in the room waking). On waking: a "!" text and a
  hop (`Fx.boing`).
- **Hunt, never siege:**
  - The shared tail of `_think` (664-671), after `state = "walk"`: `if _in_area(): _hunt(p, reach); return`.
  - The moth's fall-through (529-538): `if main.fight.last_stand or _in_area(): _hunt(p, reach); return`.
  - The per-kind specials keep working because they target the cat (`_cat_reachable` works far from the camp).
    Pitchers find no tower or building and spit at the cat. A puffball's burst hits only the cat.
  - Phase C's guardian targeting (enemies fighting the Warden when it is in their way) finds nothing 400 m away.
- **Summons** (owl summon, bear and stag roars) need no change in enemy.gd: `fight.spawn` hands them to
  `main.area.spawn` when the area owns the spot (section 16.2), so they get the room's strength and the minion cap.
- **Flee:** `_do_flee` (1265) first line `if _in_area(): state = "walk"; return`. Only the Amber Grub runs away below
  ground, with its own branch.
- **Charges** end at the room's walls: in `_do_charge` (1112) use `main.area.outside(global_position)` when
  `_in_area()`, instead of `global_position.length() > WOODS_R + 2.0` (which would be true at once at x 400). In the
  "rammed something solid" branch (the building and tower loop just above), when `_in_area()`: `_daze_long(daze_on_block_s)`
  instead of looking for buildings. The bear's `_do_dash` (1177) gets the same branch when it is blocked by a pillar or
  wall rather than stopped by reaching the cat.
- **`_daze_long(s)`:** `state = "daze"`, `_act_t = 0.8 - s` (the daze state ends at `_act_t > 0.8`, as `_end_charge`
  sets it up), `_vuln_t = s + 0.3`, `Fx.text("Bonk!")`, a ring of stars (`Fx.sparkle` x3).
- **Hidden-cat fallback** in `_hunt` (822-825): `if _in_area(): _goal = global_position; return` (stay put) instead of
  heading for the world origin.
- **Gloomtouched elites:** `make_gloomtouched(boss := false)`: health x2.4 (not for bosses, whose health comes from
  `hp_mult`), damage +1, scale x1.15, speed x1.1, `Props.set_param(_body, "gloom", 0.7)`,
  `Fx.wind_aura(self, 1.2, 1.0)` on spawn, and `title = "Gloomtouched " + info.name` (the boss bar reads `title` when
  set).
- **Damage:** after `setup`, `area.spawn` sets `e.damage = int(info.damage) + area.damage_add()` (+1 if Gloomtouched)
  and `e.gate_damage = 0`.
- **Weak spot:** `hit()` multiplies the damage by `vuln_mult` (1.5) while `_vuln_t > 0`.
- **Pay:** in `_die`, when `_in_area()`, call `main.area.on_enemy_died(self)` **instead of** `main.drop_leaves(...)`.
  The area drops `round(info.leaves x leaf_mult)` leaf pickups (bosses drop none: their pay is the boss chest), rolls
  amber and dew, and counts the room clear.
- **Raccoons are left out below ground** (nothing to steal there).
- **Enemies stay children of `main`** (an identity transform), as `fight.spawn` does today, because `enemy.gd` mixes
  `position` and `global_position`.

### 7.2 New monsters (from the user's Meshy; stand-ins until then)
Until a model arrives, each small new kind points at an existing model with `model`, `scale` and a new `tint` key.
`setup` applies `Props.set_param(_body, "tint", Color(info.tint))` when `info.tint` is set (the `vc` shader already has
a `tint` instance parameter). When the Meshy model lands in `res://assets/enemies/<id>/`, delete those three keys.

| id | Name | Stand-in | Role | Behaviour (a new branch in the `_think` match) |
|---|---|---|---|---|
| `grub` | Grubling | `mole` x0.6, tint #C9B8F0 | A swarm from below | Spawned through `start_emerge(at)`: hidden, a warning ring (0.8 s), then it pops up (Emerge clip if present, dust); 1 damage if the cat stands within 0.6 m. Then the default chase and pounce |
| `glowcap` | Glowcap | `brute` x0.55, tint #7FE3E0 | Artillery that makes the cat move | Keeps 4-7 m away: walks off when the cat is within `keep_away` (4 m). Every 2.6 s it lobs a spore bomb at the cat's spot plus 0.5 s of the cat's movement: ring r 1.1 for 1.1 s, then `Fx.spores`, 1 damage and a 2 s slow inside it |
| `snapper` | Root Snapper | `pitcher` x1.15, tint #6E8F3A | A living trap | Never moves (`anchored`, speed 0, no knockback). Turns toward the cat at 2 rad/s. When the cat is within 3.2 m and inside ±35° of its facing: warning line 0.7 s, then a bite along the line (2 + depth add). Cooldown 2.2 s |
| `amber_grub` | Amber Grub | `mole` x0.5, tint #F2B44C | A treasure critter to chase | Section 7.4 |
| `grubber` | Old Grubber, the Gloom Badger (boss) | **none in play**: Gloomtouched Mossback stands in until `grubber.glb` exists (section 4.2). The autotest can run its AI on the `bear` model with a tint | A boss that tests dodging | Section 7.3 |

`setup` also reads `anchored = bool(info.get("anchored", false))` (the var exists at enemy.gd 46, but nothing sets it
today).

### 7.3 Old Grubber (boss AI, branch `"grubber"`)
- **Burrow** every 9 s: it digs down (the mole's `_start_dig`/`_do_dig` flow, body hidden), a dust trail follows the
  cat at 3 m/s for 2 s and stops, a warning ring (r 1.6) fills for 0.9 s, then it erupts: damage x2 inside the ring,
  `Fx.shockwave`, `main.shake(0.3)`.
- **Roll** every 7 s when the cat is 3-9 m away: windup 0.9 s with a 9 m warning line, then the boar's charge code at
  8.5 m/s for 1.4 s. Hitting the cat does double damage. Hitting a pillar or wall dazes it (section 6.3).
- **Swipe** in melee (the ordinary attack).
- **Calls 3 Grublings** at 60% and 30% health (through `area.spawn` with `emerge`).

### 7.4 The Amber Grub (branch `"amber_grub"`)
- 12% chance after a den is cleared, 30% on entering a spring room. It pops out of a hole with the toast "Ooh, an Amber
  Grub!" and a sparkle.
- It runs from the cat toward the hole furthest from it (`area.flee_point`). After `life_s` (10 s) it digs away: "It
  got away!".
- It never attacks (damage 0). Caught: it bursts into 30 x leaf_mult leaves plus 1 amber for the satchel.

---

## 8. Hollow keys (nothing while the game is closed)

- `Save.burrow_keys`, **at most 3** (`keys.cap`). The field is shared with Phase D: whichever phase is built first adds
  it (section 15).
- **Earned only by doing things in play:**

| Source | Keys | Where in the code |
|---|---|---|
| The Hollow opens (once) | the ring is filled to 3 | `burrows.open_hollow()` |
| A Gloom Raid held (Phase D) | 1, or 2 for an elite raid | Phase D's `raids.finish`, step 3 (D 17.1). Once Phase E exists it calls `main.burrows.grant_key("raid", n)` instead of writing the field, so the overflow below also applies |
| A mission replay won, once the Hollow is open | 1 | `fight._win` when it is not the first win |
| The first clear of a depth | 1 | `burrow.gd`, when a boss falls on a depth deeper than `Save.burrow_depth` |

- **Over the cap**, a key becomes 150 leaves (`overflow_leaves`) with the toast "Key ring full: +150 leaves".
- **No timers, no dates.** Nothing refills, and nothing is given or taken when the app opens or a day changes.
- **Spending:** 1 key when the player taps Enter, saved at once. It comes back only if the cat climbs back up the entry
  lift before the first den wakes ("The key slips back into your pocket"). "Go deeper" after a boss costs 1 more. A
  resumed run costs nothing.
- Every grant goes through `burrows.grant_key(reason: String, n := 1) -> int` (returns how many fitted), which shows
  the toast "+1 Hollow key (2 of 3)" with the key icon, or the overflow toast, and saves.
- Why this keeps the Burrows a side trip: Phase D's meter brings a raid about every 10 minutes of camp play, and each
  key needs a raid (or a full replay of 15-20 waves), so runs and raids take turns, and the cap stops hoarding.

---

## 9. Rewards

### 9.1 The satchel
- **Leaves and timber** go straight into the save as today (leaf pickups through `collect_leaves`, chest timber
  directly). So do **Gloom shards** from a boss chest (once Phase D exists). They are never at risk.
- **Materials** picked up go into the **satchel** (`run.satchel`), shown at the top right.
- **Climb out** (the root lift after the boss, or the spring's lift): bank the whole satchel x (1 + 0.15 x chain),
  rounded down per material, never less than the satchel itself.
- **Go deeper** (after a boss, 1 key): the next depth's first room at once. Health, boons and satchel carry over, and
  `chain` goes up by 1.
- **Knocked out:** banner "Knocked out!" with sub "Sprig drags you back up the hollow". After 1.2 s, fade, bank
  `floor(n x knockout_keep)` of each material (0.5; question 1), and the key is spent. No leaves are taken. No ruins.
- Pickups still lying in a room are collected when the cat leaves it.

### 9.2 Materials and drop tables

| Material | id | Looks | From |
|---|---|---|---|
| Root Amber | `amber` | A honey-orange resin crystal | Every depth: kills (6-10%), chests, elites, bosses |
| Glowstone | `glowstone` | A pebble of cold teal foxfire light (never violet, so it is not mistaken for a Gloom shard) | Depth 2+: chests, elites, bosses |
| Heartwood | `heartwood` | A glowing knot of old root with an amber heart | Depth 3+: bosses and first clears; now and then chests and elites at depths 4-5 |

- A drop value v means `floor(v)`, plus one more with chance `frac(v)`.
- Deeper than depth 5: depth 5's values x (1 + 0.1 x (depth - 5)).
- **Expected per full run** (first guesses): depth 1 about 5 amber; depth 3 about 8 amber, 3-4 glowstone and 1
  heartwood; depth 5 about 11 amber, 6 glowstone and 1.5 heartwood. Plus 300-600 leaves, 6-12 timber and (with Phase D)
  3-8 Gloom shards.
- **Leaves per minute** stay at or below a mission-15 replay (about 125 a minute): about 70-100 a minute at depths 1-3
  and about 110 at depth 5, so the Burrows pay materials and never become the leaf farm.
- **No seeds.** GAME_PLAN says seeds come "from the trader and the Burrows", but Phase C's garden has no seed
  inventory (the Plant row buys a seed packet with leaves). If Phase C ever adds rare seeds, the boss chest is the
  place (`drops.boss` gets a `seeds` key).

### 9.3 What materials buy (the top upgrades)
All of these sit on existing cards and stay hidden until the Hollow opens. They cost leaves plus materials.

| Upgrade | Where | Effect | Cost |
|---|---|---|---|
| **Mastery 11 and 12** for Damage, Draw speed, Health and Move speed | Training Target (Damage, Draw speed), Shop (Health, Move speed) | The stat's `per_level` simply continues. Range and Leaf magnet stay at 10 (range is already 8.5-10 m). Needs the stat at 10 | L11: 400 leaves + 6 amber. L12: 550 leaves + 9 amber + 3 glowstone |
| **Bow mastery 11 and 12**, every bow | Bow Bench (level 3) | Per level as today | L11: 600 leaves + 6 amber + 2 glowstone. L12: 800 leaves + 9 amber + 3 glowstone + 1 heartwood |
| **Foxfire Bow** (a 4th bow) | Bow Bench (level 3) | x1.45 damage, pierces 2, +1.0 m range, a teal glow tint | Craft: 2,000 leaves + 16 glowstone + 3 heartwood |
| **Heartwood Gate** (barricades level 5) | Shop | 2,000 health (level 4 Shardstone: 1,400) | 1,800 leaves + 16 amber + 6 glowstone |
| **Amber Tower** (acorn towers level 5) | Shop | 44 damage every 0.65 s, 7.0 m range, 1,000 health (level 4: 36 / 0.7 s / 6.5 m / 800) | 2,800 leaves + 20 amber + 8 glowstone + 2 heartwood |
| **Amber Thorns** (spikes level 5) | Shop | 42 damage a second, 55% slow (level 4: 34, 50%) | 1,500 leaves + 14 amber + 6 glowstone |
| **Moss Warden level 4** (Guardian Stone level 4, Phase C) | Guardian Stone card | 1,800 health, fists 75, slam 125, a little bigger (level 3: 1,300 / 55 / 90) | 2,000 leaves + 20 timber + 10 glowstone + 4 heartwood |

- **Levels need the home:** defence level 5 needs home level 5 (Phase D's rule `dl + 1 <= Save.camp_level`), and stone
  level 4 needs home level 4 (`Data.station_max_level` is `min(home level, levels.size())`). Level-5 defences also need
  level 4 first, so Phase D's shard goods stay part of the climb. If the user answers Phase D's question 5 with "all top
  defences wait for the Burrows", these simply become level 4.
- **Totals:** about 170 amber, 78 glowstone, 13 heartwood, 20 timber and 19,500 leaves for everything (all 4 stats,
  all 4 bows, the Foxfire Bow, all 3 defences and the Warden). First clears give 4 heartwood. That is about **20 runs**
  at depths 2-4, alongside raids; a player who levels only the bow in the paw needs about 12. Deeper depths are for the
  record after that, and still pay leaves and timber for Phase D's repairs.
- **Later sinks (not in Phase E):** Phase F fletching (special arrows from materials), and later candidates: station
  level 4, Watch Root (+1 tower spot), Ember Heart (+25% campfire health).
- **The cap on home stats must not change.** Do not lengthen `stat_cap_by_station_level`: `Data.stat_cap` (data.gd
  160) reads it by the stat's station, and Health, Move speed and Leaf magnet use the home, so a longer array would lift
  them to 12 at home level 4+. Mastery has its own list per stat (section 13.3).
- **Raids grow with it:** Phase D's camp score counts defence levels and the guardian's level, so level-5 defences and
  Warden level 4 make raids a little bigger, as "bigger camps draw bigger raids" asks.

---

## 10. Boons (for one run, picked at a spring)

A spring offers 2 different boons out of 6 (seeded). A boon lasts until the cat leaves the Burrows. Boons are applied
through `Data.run_mods`, which `burrow.gd` sets on entry and on a pick, and clears on leaving.

| id | Name | Effect |
|---|---|---|
| `sharp` | Sharp Thorns | Arrows hit 25% harder (`Data.arrow_damage` x (1 + `run_mods.damage`)) |
| `quick` | Quick Paws | The dash recharges 40% faster and goes 1 m further |
| `moss` | Mossheart | +3 most health and +3 health now (`Data.cat_max_hp` + `run_mods.hp`) |
| `fury` | Sprig's Fury | Sprig spits 50% faster (pet.gd divides its interval by `run_mods.pet_rate`) |
| `dewcharm` | Dewdrop Charm | Healing dew drops three times as often |
| `lucky` | Lucky Paw | Every chest gives one more of each material in it |

Boons stack with a Phase C dish (both multiply: `Data.arrow_damage()` x (1 + meal damage) x (1 + run damage)). Later
candidates: Echo Arrow (every 4th shot splits in three) and Thornmail (whatever hits the cat takes a thorn hit).

---

## 11. How it is shown: the same scene, far away

### 11.1 Why this shape
- **Not `change_scene`.** That would free `main` and rebuild the whole camp on the way back (path stamping, about
  6,500 grass tufts, 480 scatter items, GLB loads), a hitch on low-end phones. It would also lose the state that lives
  only in memory (`stations.hp`, defence piece health, mount health and rest).
- **Not hiding `world`.** The sun and the WorldEnvironment are its children.
- **Same scene, far away.** The Burrows are built in code around **`ORIGIN = (400, 0, 0)`**, at y = 0 (the camera
  focus, bolts, rings, slime and pickups all assume ground at 0). The camp is beyond `cam.far` (120) and outside the
  sun's 36 m shadow box, so it is not drawn. Coming back is instant.
- **One room at a time.** Room slot n is built at `ORIGIN + (0, 0, -40 x (n % 8))`. A new room is built 40 m on, and
  the old one is freed behind the fade, so stray bolts and slime from the last room are far away and run out by
  themselves. Only one room's monsters exist, so arrows, Sprig and bolts never need to see through walls.
- A big dark **void plane** (90 x 90 m, unshaded, the tier's `void` colour) lies under each room at y -0.03, so no sky
  colour shows past the walls.

### 11.2 The area contract
`burrow.gd` is one Node3D child of `main` (`main.burrows`), made in `main._ready`, idle until a run starts. While the
cat is inside, `main.area` points to it; otherwise `main.area` is `null`. Phase D already tests `main.get("area")`.

```gdscript
func owns(p: Vector3) -> bool                      # a run is on and p.x > burrows.own_x (200)
func constrain(p: Vector3, radius: float, is_enemy: bool, flyer := false) -> Vector3
func outside(p: Vector3) -> bool                   # touching a wall (ends a charge)
func cam_focus(cat: Vector3) -> Vector3            # section 5.2
func cam_dist() -> float                           # burrows.cam_dist (21.5)
func spawn(kind: String, at: Vector3, opts := {}) -> Node3D
func on_enemy_died(e) -> void
func flee_point(p: Vector3) -> Vector3             # the hole furthest from the cat
func hide_at(p: Vector3)                           # the fern patch at p, or null
func cat_down() -> void
func status_text() -> String
func room_pips() -> Array
func satchel() -> Dictionary
```

`constrain`: clamp x into `[cx - 3.5 + r, cx + 3.5 - r]` and z into `[cz - l + r, cz - r]` (fliers too: cave walls
are high), then, if not a flier, push out of the pillar circles in 2 passes (the circle code from `world.constrain`
874-893).

### 11.3 Hooks into the code that exists

| Camp code that assumes the camp | Hand-over |
|---|---|
| `world.constrain` (869) | First line: `if main != null and main.area != null and main.area.owns(p): return main.area.constrain(p, radius, is_enemy, flyer)`. Use `owns(p)`, not just "area is set": Thistle walking home, the trader and the Warden keep the camp rules while the cat is below ground. This covers player.gd 267 and every enemy call (enemy.gd 846, 1097, 1150, 1192, 1226, 1277) |
| Camera (main.gd 163-183) | When `area != null`: distance `area.cam_dist()`, focus `area.cam_focus(player.global_position)` instead of the 16.5 m origin clamp. Add `snap_camera()` |
| Environment | `cam.environment = area.env` (a Camera3D override) on entry and `null` on exit. `world.sun.light_energy` x the tier's `sun`, restored on exit. Never a second WorldEnvironment |
| `fight.spawn` (221-231) | First line: `if main.area != null and main.area.owns(at): return main.area.spawn(kind, at, {"summon": true})`. Summons get the room's strength and the minion cap. It may return `null` when capped, and the summon callers ignore the result |
| `fight.start_mission` (83) | Also refuse while `main.area != null` (Phase D's `start_raid` already waits: its `blocked_reason()` is "away") |
| `main.on_player_down` (520-526) | First lines: `if area != null: area.cat_down(); return` (no respawn timer) |
| `main.set_riding` (474-496) | Refuse while `area != null` |
| `main._update_hiding` (188-205) | `area.hide_at(p)` while in the Burrows |
| `main._update_grass` (252) | `if area != null: return` (no grass there) |
| `main._notification` (Phase D adds it) | On pause, focus out and close: also `burrows.persist()` (section 11.7). If Phase D is not built yet, add `_notification` with Phase D's shape (D 17.3) |
| `pickup.gd` line 51 (the ±20.5 clamp) | Only when `main.area == null`; otherwise `main.area.constrain(...)` |
| `enemy.gd` | Section 7.1 |
| `fight` while below ground | Untouched. `fight.active` stays false, so `busy()`, `on_enemy_died()` and `damage_fire` do nothing |

Things that already work far away (checked): `inside_camp` is false (the cat can be hurt and does not heal; enemy bolts
do not pop), `fence_hit`, `slow_at` and `blocked_between` find nothing, `_ranged_target` finds no towers, buildings or
campfire, the owl's blink goes through `world.constrain` (so it lands inside the room), and the pet teleports to the
cat by itself when more than 6 m away (pet.gd 164-165). The camp's towers find no foe in range, and Phase C's Warden
only thinks during a wave.

### 11.4 Light: cosy-spooky, and right on Low
- `area.env` is one `Environment` per run: background a solid colour (the tier's `void`), ambient light from a colour
  (the tier's `ambient` at `ambient_energy`), the camp's filmic tonemap, a light fog (`fog`, `fog_density`), and
  `glow_enabled = Quality.glow()` (updated on `Quality.changed` while a run is on).
- **No lights are needed below ground.** Glowing mushrooms, crystals, the spring and the lanterns are bright
  vertex-colour faces, so the Burrows look right on Low with lamps off, and never hit the Mobile renderer's limit of 8
  lights per mesh.
- **Sprig's lantern glow:** an unshaded, additive billboard halo (a code-drawn soft disc, 0.9 m, the tier's `glow`
  colour) that follows the pet, and a soft unshaded ground pool (a transparent disc, r 2.0) under it. Both work on Low.
  On Medium and High (`Quality.lamps()`), one OmniLight3D (range 4.5, energy 0.9, group `"lamp"`) is added on top. If
  the pet is hidden (a ruined Mushroom Cottage cannot happen here, because ruins block entry, but guard anyway), the
  halo rides on the cat's shoulder.

### 11.5 Going in
`burrows.start_run(depth)` (from the Hollow card, after `Data.pay({"keys": 1})`):
1. Write `Save.burrow_run` (section 15), `burrow_stats.runs += 1`, save.
2. `main.set_riding(false, false)` (Thistle walks home), `hud.hide_card()`, `defences.stop_placing()` if placing,
   `main.frozen = true`, `player.frozen = true`, `await hud.fade(1.0, 0.3)`.
3. `main.area = self`, `Data.run_mods = _mods()`. Start loading the tier's enemy GLBs and props with
   `ResourceLoader.load_threaded_request`.
4. **Phase C's dish:** if `burrows.meals_in_runs` and `main.get("cooking") != null` and `Save.meal_ready != ""`:
   `main.cooking.eat("run")`. The dish's boosts apply below ground as they do in a chapter (`Data.meal_boost`: draw,
   hp, damage, friends for Sprig); the fire and guardian boosts simply do nothing there.
5. `_build_step()`: build the room, spawn its content, put the cat at room `(0, -1.2)` facing north (`facing = PI`),
   put the pet at the cat + `(0.5, 1.1, 0.3)`, `main.snap_camera()`, `hud.refresh()`, `hud.refresh_build()`.
6. Environment and sun on, `await hud.fade(0.0, 0.3)`, unfreeze. Tier banner ("The Glowcap Grotto", sub "Depth 2 · 4
   rooms and Mossback"). The first run ever also shows the dash tip (`told_dash`).

**Next room** (`choose(type)` from a door ring): fade; while frozen, free the room's leftover foes and the room node
(unregister its rings first), save the run, build the next room in the next slot, place the cat and pet, snap the
camera; fade in.

### 11.6 Coming back
`climb_out()`, `cat_down()` and `abandon_run()` all end in `_leave(result)`:
1. Freeze and fade out. Collect the room's pickups. Bank as in section 9.1. Update `burrow_stats` (`won`, `falls`,
   `best`). On a first clear: `Save.burrow_depth = depth`, the first-clear heartwood (into the satchel before banking)
   and key.
2. Free the room and any leftover foes. `main.area = null`, `Data.run_mods = {}`, restore the environment and sun,
   `hud.boss = null`. Phase C's dish: `main.cooking.finish(true)` (used up) if one went down with the cat.
3. `Save.burrow_run = {}`, save.
4. Put the cat at the return spot `(0, 0, 15.5)` facing north. After a knock-out use `player.revive(...)` (full
   health); otherwise keep its health, clamped to its normal most health (it heals in the camp). Place the pet, snap the
   camera, fade in, unfreeze.
5. Banner "Back at camp", with what was banked in the sub ("+9 amber · +4 glowstone · +1 heartwood"). Then
   `main.on_area_left(result)`: `hud.refresh()`, `hud.refresh_build()`, `stations.refresh()`, and
   `main.raids.add_gloom("burrow_run")` when `main.get("raids") != null` (Phase D: 15 points, never past 95, so a raid
   is never already pending when the cat comes up).

### 11.7 Saving and resuming (nothing moves while the game is closed)
- `Save.burrow_run` is written at run start, **at every room entry** (step, picked types, health, boons, satchel,
  chain), when a room is cleared (`cleared: true`, so a resume does not refight it), on a boon pick and on a drink.
- **When the cat is hurt** it is written again, at most once every 1.5 s and always when health drops to 2 or less, so
  closing the app cannot dodge a knock-out. These saves are quiet (`Save.save_game(true)`: the file is written without
  emitting `changed`, so the open card is not rebuilt mid-fight; Phase D's signature).
- **`burrows.persist()`**, called from `main._notification` on pause, focus out and close: if a run is on, write the
  cat's health into `burrow_run` and save quietly. That covers an Android pause in the middle of a room.
- On load, the cat always starts in the camp. The Hollow card shows **"Go back in"** (no key): it rebuilds the saved
  step (the same template from the seed) with the saved health, boons, satchel and chain. A cleared room comes back
  cleared with its doors open and no monsters. A room that was not cleared starts over with the saved health. A dish
  that was eaten for the run is back in the pot (Phase C's load rule turns `meal_on` back into `meal_ready`), so "Go
  back in" eats it again. **"Leave it"** ends the run like a knock-out: half the satchel is banked and the key stays
  spent.
- If `burrow_rooms.json`'s `version` changed under a saved run, or its step no longer resolves, the run is ended kindly:
  the whole satchel is banked and the key is given back. Toast: "An update closed your run: everything was brought
  home."
- Every timer in `burrow.gd`, `burrow_room.gd` and `trap.gd` uses `minf(delta, 0.1)` and stops while `main.frozen`
  (Phase D sets `frozen` while Android has the app paused).

---

## 12. HUD and cards

### 12.1 HUD (hud.gd)
- **Top left:** nothing new. In the camp the `_res` box already holds leaves, timber, Phase C's meal chip and Phase D's
  shard row, so keys and materials show on the cards instead (the Hollow card, and a "have" note on every row that
  costs a material). **Below ground** the box shows only the leaves row and the meal chip (timber and shards hide while
  `main.area != null`), so it stays clear of the boss bar at y 190.
- **Top right while below ground:**
  - `_stage_l` shows `area.status_text()`: "The Glowcap Grotto · room 2 of 4", "… · Mossback" in the boss den, "… ·
    room 2 cleared".
  - In the `_gate_bar` spot (w-300, 96, 276 x 34), a **room pip strip** (`_draw_rooms()`): one 22 px circle per step,
    12 px apart (filled = done, ring = here, hollow = ahead, a small crown for the boss).
  - Under it (y 136), the **satchel line**: material icons with counts (only those above 0), 26 pt.
  - **Priority** in `hud.refresh()`, `_process` and `_draw_gate()`: `main.area != null` first (the Burrows), then
    `fight.active` (missions and raids), then `main.raids.meter_shown()` (Phase D's meter). So the meter bar hides
    below ground without any change to Phase D.
- **Hidden below ground:** the campfire bar, the build bar (`refresh_build` returns early with
  `_build_bar.visible = false`), the place bar, the Ride/Walk button and the drag hint.
- **Kept:** the boss bar (it reads `boss.title` when set, else `info.name`), banners, toasts, tips with arrows, and the
  health bar over the cat with the dash arc under it.
- **Fade overlay:** a full-screen ColorRect (#0B0F0A) on its own CanvasLayer (layer 20). `hud.fade(alpha, secs)`
  returns the tween. While its alpha is above 0 it is in group `"ui_block"` with MOUSE_FILTER_STOP, so the joystick
  ignores touches.
- **`hud.banner_busy() -> bool`** (new): true while the banner is on screen (used by the reveal).
- **Icons:** code-drawn next to `_make_leaf`, `_make_log` and Phase D's `_make_shard`: `_make_key` (a golden key with an
  acorn head), `_make_amber` (honey-orange), `_make_glow` (teal), `_make_heart` (a brown knot with an amber core).
- **Cost buttons:** `_cost_button` loops over `Data.CURRENCIES` and adds an icon and a count for each non-zero cost
  (red when `Data.have(k) < n`). This replaces Phase D's extra shard branch with the same result. Minimum width
  `max(150, 24 + 78 x number of currencies)`, with 22 pt counts for 3 or more currencies.
- **The status line fix:** `main._update_rebuild` (347-351) clears `hud.status` every frame today. Give it
  `var _status_mine := false`, and clear the status only when it was the one that set it. The spring can then show
  "Drinking… 60%".

### 12.2 Cards (all at most 6 rows, so none scroll)
**The Old Hollow, sealed** (from the first mission won): title "The Old Hollow", sub "Sealed by the Gloom". One
disabled row: "Win every mission to open it", note "%d of 15 won · something sleeps under the roots".

**The Old Hollow, open, no run saved:** title "The Old Hollow", sub "Hollow keys %d of 3", plus " · your %s goes down
with you" when a Phase C dish waits in the pot.
1. **If entry is blocked**, one disabled row and nothing else (`burrows.blocker()`, in this order):
   - a mission or a raid is on (`fight.active`): "Finish the fight first"
   - a Gloom Raid is pending (`Save.raids.pending`, Phase D): "A Gloom Raid is coming: defend the camp first"
   - `Save.fire_ruined`: "Rebuild the campfire first"
   - a building is a ruin: "Repair the %s first: the camp must stand while you are away"
   - a Phase C mini-game is on (`main.get("busy_minigame") == true`): "Finish fishing first"
2. Otherwise up to 3 depth rows, the deepest first: the newest open depth, the deepest cleared (if different) and
   depth 1 (if different). Text "Depth %d · %s", note "%d rooms and %s · pays %s" plus " · tough for you now" when
   `Data.power() < power_by_depth`. Cost `{"keys": 1}`, label "Enter". Disabled when `Save.burrow_keys == 0`.
3. An info row (disabled) "Your materials", note "amber %d · glowstone %d · heartwood %d".
4. If `Save.burrow_keys == 0`: an info row "No key", note "Hold a Gloom Raid or win a mission replay to earn one".
5. If anything in the camp needs mending (Phase D's `raids.camp_check().items` not empty, else
   `defences.wrecked_count() > 0`): an info row "The camp needs mending", note "%d to fix · Mend all at the signpost
   before the next raid" (a reminder only; it does not block).

**The Old Hollow, run saved:** title "The Old Hollow", sub "Your run is waiting".
- "Go back in", note "Depth %d, room %d of %d · %d health · satchel: %s", label "Go back in". Blocked by the same
  blockers as above (shown instead of this row).
- "Leave it", note "Bring home half the satchel · the key is spent", label "Leave".
- The "Your materials" info row.

**Entry lift** (the first room, until the den wakes): title "The Way Up", row "Climb back up", note "Your key comes
back", label "Up".

**Fork door** (a ring at each door): title = the type ("Den", "Gauntlet", "Treasure", "Spring", "Elite", "The boss").
Sub: "Monsters wake together" / "Traps · a chest if you're not hit" / "A Gloom-bound chest" / "Heal, and pick a boon" /
"A Gloomtouched %s · sure glowstone" / "%s waits below". Row "Go this way", note what is inside (for example
"Glowcaps, Brutes" or "Rolling logs"), label "Go".

**Boon shrine:** title = the boon's name, sub = its note. Row "Take this boon", note "Until you leave the Burrows ·
only one", label "Take".

**Gloom-bound chest** (treasure room): sub "Crusted with Gloom crystals". Rows "Open it", note "Amber, maybe
glowstone", label "Open"; and "Break the Gloom seal", note "Twice the loot · a Gloomtouched guard bursts out", label
"Break".

**Root lift** (spring and boss den): sub "Back up to the camp". Row "Climb out", note "Bring home: %s%s" (plus
" (+15% for going deeper)" when chain > 0), label "Climb".

**Deeper tunnel** (boss den, north-east): sub "Depth %d · %s". Row "Go deeper", note "Keep health, boons and satchel ·
+15% when you climb out · a knock-out keeps half", cost `{"keys": 1}`, label "Go".

**No card:** the spring (wade in and stand 1.5 s; `hud.status` shows the progress), the gauntlet chest and the boss
chest (they open when the cat comes within 1.1 m), dew buds and the Amber Grub.

**Top-upgrade rows on existing cards** (only once the Hollow is open; every note ends with " · have %s" for the
materials it costs, for example " · have 12 amber, 4 glowstone"):
- Training Target and Shop stat rows: after level 10, "Damage · mastery 1 of 2" with the leaves-and-materials cost.
  Before the Hollow opens, a stat at 10 shows "max".
- Bow Bench: "Thorn Volley · mastery 1 of 2" for the bow in the cat's paw; "Foxfire Bow", note "Pierces 2 · +1 m
  range · x1.45 damage", label "Craft".
- Shop defences (after Phase D's level-4 rows): "Every barricade to Heartwood", note "2,000 health" (or "Needs a bigger
  home (level 5)"); "Every tower to Amber", note "44 damage every 0.65 s, 7 m range, 1,000 health"; "Every spike patch
  to Amber Thorns", note "42 damage a second, slows 55%".
- Guardian Stone (Phase C's `_station_upgrade_row("stone")`): "Upgrade to level 4", note "Moss Warden: 1,800 health,
  fists 75, slam 125" or "Needs home level 4".
- Signpost endgame note (Phase D's Watch card): add "Replays also earn a Hollow key".

### 12.3 Tips (once each, saved in `Save.flags`, named like Phase C's and D's)
- `told_hollow`: the opening (section 3.4).
- `told_dash` (first run): "Flick your thumb to dash! Nothing can hurt you mid-dash, and dodging through an attack
  makes your next arrow hit double."
- `told_fork` (first fork): "Pick a tunnel: the sign says what's inside."
- `told_satchel` (first material): "Materials go in your satchel. Climb out to bring them all home; knocked out, you
  keep half."
- `told_traps` (first trap room): "A glow on the ground warns where a trap will strike: step or dash away."
- `told_pillar` (first boss den): "Lure its charge into a pillar: it gets dazed and takes extra damage."

---

## 13. balance.json

### 13.1 New block `"burrows"`
Do not reuse the key `"raid"` (the mission camp-falls numbers) or `"gloom_raids"` (Phase D).

```json
"burrows": {
  "_note": "Phase E, the Burrows (docs/PHASE_E_SPEC.md), open once every mission is won. A run costs 1 Hollow key: a den, forks, spring or elite, then a boss den, rooms_by_depth rooms before the boss, built one at a time far from the camp. Monster health x strength_by_depth (x (1 + room_ramp x step); bosses x hp_mult, no ramp); damage = the kind's damage + damage_add_by_depth. Keys only from play (keys; Phase D's raids give theirs through burrows.grant_key); nothing is ever given, refilled or taken by time. Satchel: all of it banked on climbing out (x (1 + chain_bonus x chain)), knockout_keep of it on a knock-out; leaves, timber and shards are banked at once. A drop value v = floor(v) + a chance frac(v) of one more. Past depth 5: strength +strength_per_depth_after a depth, pay x (1 + pay_per_depth_after x (depth - 5)).",
  "origin": [400.0, 0.0, 0.0],
  "room_step": 40.0,
  "room_slots": 8,
  "own_x": 200.0,
  "room_w": 7.0,
  "cam_dist": 21.5,
  "fade_s": 0.3,
  "hollow": {
    "pos": [0.0, 0.0, 19.0], "radius": 1.4, "ring": [0.0, 0.0, 16.9], "ring_r": 0.8, "return": [0.0, 0.0, 15.5],
    "ring_from_missions": 1,
    "clear": {"z_from": 15.5, "z_to": 26.5, "half_x": 4.0, "widen": 0.4, "path_clear": 1.8},
    "trunk": [[0.0, 0.0, 1.0], [0.3, 0.0, 5.4]],
    "path": [[0.3, 0.0, 5.4], [-1.0, 0.0, 6.2], [-2.3, 0.0, 8.3], [-2.2, 0.0, 11.0], [-1.0, 0.0, 13.6], [0.0, 0.0, 15.9]],
    "grass_keep_out": 2.4, "ring_keep_out": 1.1, "hideout_keep_out": 3.0, "defence_keep_out": 2.6,
    "reveal_after_win_s": 8.0, "reveal_old_save_s": 6.0, "reveal_wait_s": 1.0, "reveal_wait_max": 4
  },
  "keys": {"cap": 3, "open_fill": 3, "replay": 1, "first_clear": 1, "overflow_leaves": 150},
  "meals_in_runs": true,
  "knockout_keep": 0.5,
  "chain_bonus": 0.15,
  "rooms_by_depth": [0, 3, 3, 4, 4, 4],
  "strength_by_depth": [0, 2.0, 2.5, 3.0, 3.6, 4.2],
  "strength_per_depth_after": 0.5,
  "room_ramp": 0.04,
  "damage_add_by_depth": [0, 0, 0, 1, 1, 2],
  "damage_add_after": {"every": 2, "max": 4},
  "trap_damage_by_depth": [0, 1, 1, 2, 2, 2],
  "leaf_mult_by_depth": [0, 1.0, 1.2, 1.4, 1.6, 1.8],
  "pay_per_depth_after": 0.1,
  "leaf_mult_max": 2.5,
  "power_by_depth": [0, 40, 48, 56, 64, 72],
  "power_per_depth_after": 8,
  "max_alive_by_quality": [8, 10, 10],
  "boss_minions_max": 4,
  "den_count_by_depth": [[0, 0], [4, 5], [5, 6], [5, 7], [6, 8], [7, 9]],
  "late_spawns_by_depth": [0, 2, 2, 3, 3, 3],
  "late_after_s": 5.0,
  "wake_r": 5.0,
  "wake_line": 3.0,
  "snapper_chance_by_depth": [0, 0, 0.5, 0.6, 0.7, 0.8],
  "fork_weights": {"den": 3, "gauntlet": 3, "treasure": 2, "elite": 2},
  "elite_from_depth": 2,
  "tide_from_depth": 3,
  "gloomtouched": {"hp": 2.4, "damage_add": 1, "scale": 1.15, "speed": 1.1, "gloom": 0.7},
  "vuln_mult": 1.5,
  "daze_on_block_s": 2.5,
  "stuck_after_s": 40.0,
  "dew": {"chance": 0.08, "elite_chance": 0.25, "heal": 1, "bud_heal": 2},
  "spring": {"drink_s": 1.5, "heal": 1.0},
  "amber_grub": {"den_chance": 0.12, "spring_chance": 0.3, "life_s": 10.0, "leaves": 30, "amber": 1},
  "save_hurt_every_s": 1.5,
  "save_hurt_low_hp": 2,
  "drops": {
    "kill_amber_chance": [0, 0.06, 0.07, 0.08, 0.09, 0.10],
    "chest": {"amber": [0, 2, 2, 3, 3, 4], "glowstone": [0, 0, 1, 1, 1, 2], "heartwood": [0, 0, 0, 0, 0.25, 0.25], "leaves": [0, 40, 55, 70, 85, 100], "timber": [0, 2, 3, 3, 4, 5]},
    "gauntlet_share": 0.5,
    "sealed_mult": 2.0,
    "elite": {"amber": [0, 1, 1, 1, 2, 2], "glowstone": [0, 0, 1, 1, 1, 1], "heartwood": [0, 0, 0, 0, 0.25, 0.25]},
    "boss": {"amber": [0, 2, 3, 3, 4, 4], "glowstone": [0, 0, 1, 2, 2, 3], "heartwood": [0, 0, 0, 1, 1, 1], "leaves": [0, 150, 200, 250, 300, 350], "timber": [0, 4, 5, 6, 7, 8], "shards": [0, 3, 4, 5, 6, 8]},
    "first_clear": {"heartwood": [0, 0, 0, 1, 1, 2]}
  },
  "bosses": [
    {"depth": 1, "kind": "chief", "hp_mult": 9.4, "gloomtouched": true, "adds": "grub", "adds_n": 3, "adds_every": 12.0},
    {"depth": 2, "kind": "bear", "hp_mult": 1.05},
    {"depth": 3, "kind": "grubber", "hp_mult": 0.85, "needs_model": true, "stand_in": {"kind": "bear", "hp_mult": 1.15, "gloomtouched": true}},
    {"depth": 4, "kind": "owl", "hp_mult": 0.82},
    {"depth": 5, "kind": "stag", "hp_mult": 0.6}
  ],
  "boss_cycle": [
    {"kind": "grubber", "hp_mult": 0.85, "needs_model": true, "stand_in": {"kind": "bear", "hp_mult": 1.15}},
    {"kind": "bear", "hp_mult": 1.15},
    {"kind": "owl", "hp_mult": 0.82},
    {"kind": "stag", "hp_mult": 0.6}
  ],
  "boss_gloomtouched_from_depth": 6,
  "tiers": [
    {"id": "rootways", "name": "The Rootways", "first": 1,
     "pool": [["thornling", 4], ["grub", 3], ["glowcap", 1], ["boar", 1], ["mole", 1]], "swarm": "grub", "elites": ["chief", "boar"],
     "env": {"floor": ["#6B5638", "#5C4A2E"], "void": "#1E1A12", "fog": "#34452A", "fog_density": 0.010, "ambient": "#A9C483", "ambient_energy": 0.75, "sun": 0.85, "glow": "#FFB84D"},
     "dress": [["fern", 6], ["mushroom_cluster", 4], ["root_tangle", 6], ["rock_1", 2]]},
    {"id": "grotto", "name": "The Glowcap Grotto", "first": 2,
     "pool": [["grub", 2], ["glowcap", 3], ["brute", 2], ["puffball", 1], ["frog", 1]], "swarm": "grub", "elites": ["brute", "frog"],
     "env": {"floor": ["#3E5A55", "#34504A"], "void": "#10201E", "fog": "#1F4A4A", "fog_density": 0.012, "ambient": "#7FE3D0", "ambient_energy": 0.75, "sun": 0.7, "glow": "#5FE0C8"},
     "dress": [["glow_mushroom_big", 3], ["mushroom_cluster", 5], ["root_tangle", 4]]},
    {"id": "deeps", "name": "The Amber Deeps", "first": 3,
     "pool": [["beetle", 2], ["mole", 2], ["crow", 1], ["boar", 2], ["thornling", 2], ["grub", 1]], "swarm": "grub", "elites": ["beetle", "boar"],
     "env": {"floor": ["#6A4A2A", "#5E4024"], "void": "#22160A", "fog": "#5A3A12", "fog_density": 0.012, "ambient": "#FFC870", "ambient_energy": 0.7, "sun": 0.75, "glow": "#FFC870"},
     "dress": [["amber_cluster", 4], ["root_tangle", 5], ["rock_2", 3]]},
    {"id": "warrens", "name": "The Crystal Warrens", "first": 4,
     "pool": [["moth", 3], ["pitcher", 2], ["glowcap", 2], ["snail", 1], ["beetle", 1]], "swarm": "moth", "elites": ["snail", "pitcher"],
     "env": {"floor": ["#4A4660", "#423E58"], "void": "#14122A", "fog": "#2A2650", "fog_density": 0.014, "ambient": "#B9A6FF", "ambient_energy": 0.75, "sun": 0.65, "glow": "#C9B8FF"},
     "dress": [["gloom_crystal", 5], ["rock_1", 3], ["root_tangle", 3]]},
    {"id": "gloomheart", "name": "The Gloomheart", "first": 5,
     "pool": [["stump", 1], ["beetle", 2], ["glowcap", 2], ["moth", 2], ["puffball", 1], ["crow", 1], ["grub", 2]], "swarm": "grub", "elites": ["stump", "snail", "beetle"],
     "env": {"floor": ["#3A2E48", "#33283F"], "void": "#120C1A", "fog": "#2A1A3A", "fog_density": 0.016, "ambient": "#C08AFF", "ambient_energy": 0.7, "sun": 0.6, "glow": "#FFD45A"},
     "dress": [["gloom_crystal", 6], ["root_tangle", 5], ["amber_cluster", 1]]}
  ],
  "dash": {"distance": 3.0, "time": 0.22, "iframes": 0.32, "cooldown": 1.4, "flick_window_s": 0.08, "flick_min_px": 70, "close_call_s": 2.0, "everywhere": false},
  "traps": {
    "log": {"lanes_z": [-4.5, -8.5, -12.5], "every": [3.2, 2.8, 2.4], "phase": [0.0, 1.1, 0.5], "warn": 1.0, "speed": 6.0, "half_w": 0.45, "half_len": 1.05, "knock": 4.0, "foe_damage": 60},
    "thorns": {"cols_x": [-2.3, 0.0, 2.3], "rows_z": [-4.0, -6.3, -8.6, -10.9, -13.2], "radius": 0.85, "warn": 0.8, "up_s": 0.5, "cycle": 2.6, "row_gap_s": 0.5, "foe_damage": 40},
    "crystal": {"z_from": -3.0, "z_to": -13.0, "every": 1.4, "near_cat": 2.5, "warn": 0.9, "radius": 0.9, "foe_damage": 80},
    "spores": {"radius": 1.4, "warn": 0.8, "on_s": 1.5, "off_s": 2.0, "slow_s": 2.0},
    "tide": {"speed": 0.55, "start_after_s": 3.0, "tick_s": 1.0, "damage": 1}
  },
  "boons": {
    "sharp": {"name": "Sharp Thorns", "note": "Arrows hit 25% harder", "damage": 0.25},
    "quick": {"name": "Quick Paws", "note": "The dash recharges 40% faster and goes 1 m further", "dash_cd": 0.4, "dash_dist": 1.0},
    "moss": {"name": "Mossheart", "note": "+3 health until you leave", "hp": 3},
    "fury": {"name": "Sprig's Fury", "note": "Sprig spits 50% faster", "pet_rate": 1.5},
    "dewcharm": {"name": "Dewdrop Charm", "note": "Healing dew drops three times as often", "dew_mult": 3.0},
    "lucky": {"name": "Lucky Paw", "note": "Every chest gives one more of each material in it", "chest_plus": 1}
  },
  "materials": {
    "amber": {"name": "Root Amber", "short": "amber", "color": "#F2A23A"},
    "glowstone": {"name": "Glowstone", "short": "glowstone", "color": "#5FE0C8"},
    "heartwood": {"name": "Heartwood", "short": "heartwood", "color": "#A8743A"}
  }
}
```
`drops.boss.shards` is paid only when `Data.b.has("gloom_raids")` (Phase D built); otherwise it is skipped.

### 13.2 New `"enemies"` entries
```json
"grub": {"name": "Grubling", "model": "mole", "scale": 0.6, "tint": "#C9B8F0", "hp": 14, "speed": 1.7, "damage": 1, "gate_damage": 0, "leaves": 1, "aggro": 6.0, "reach": 0.4, "attack_every": 0.9, "height": 0.6, "radius": 0.28, "color": "#C9B8F0", "emerge_warn": 0.8, "emerge_damage": 1, "emerge_r": 0.6},
"glowcap": {"name": "Glowcap", "model": "brute", "scale": 0.55, "tint": "#7FE3E0", "hp": 40, "speed": 0.6, "damage": 1, "gate_damage": 0, "leaves": 4, "aggro": 8.0, "reach": 0.5, "attack_every": 1.4, "height": 0.9, "radius": 0.35, "color": "#7FE3E0", "lob_every": 2.6, "lob_range": 7.0, "lob_warn": 1.1, "lob_radius": 1.1, "lob_lead": 0.5, "keep_away": 4.0, "slow_s": 2.0},
"snapper": {"name": "Root Snapper", "model": "pitcher", "scale": 1.15, "tint": "#6E8F3A", "hp": 90, "speed": 0.0, "damage": 2, "gate_damage": 0, "leaves": 6, "aggro": 3.2, "reach": 3.2, "attack_every": 2.2, "height": 1.2, "radius": 0.5, "color": "#6E8F3A", "anchored": true, "bite_cone_deg": 35, "bite_warn": 0.7, "bite_width": 0.9, "turn_rate": 2.0},
"amber_grub": {"name": "Amber Grub", "model": "mole", "scale": 0.5, "tint": "#F2B44C", "hp": 45, "speed": 2.3, "damage": 0, "gate_damage": 0, "leaves": 0, "aggro": 0.0, "reach": 0.3, "attack_every": 9.0, "height": 0.45, "radius": 0.28, "color": "#F2B44C"},
"grubber": {"name": "Old Grubber", "hp": 2000, "speed": 0.9, "damage": 2, "gate_damage": 0, "leaves": 0, "aggro": 10.0, "reach": 1.3, "attack_every": 1.7, "height": 2.2, "radius": 0.9, "color": "#8A8496", "boss": true, "dig_every": 9.0, "dig_track_s": 2.0, "dig_speed": 3.0, "dig_warn": 0.9, "dig_radius": 1.6, "roll_every": 7.0, "roll_min": 3.0, "roll_max": 9.0, "windup": 0.9, "charge_speed": 8.5, "charge_time": 1.4, "fence_damage": 0, "summon_at": [0.6, 0.3], "summon": 3, "minion": "grub"}
```
`grubber` has no `model` key: it loads `res://assets/enemies/grubber/grubber.glb` when that exists. `Data.depth_boss(d)`
uses the stand-in while `ResourceLoader.exists(...)` is false. The `--boss=grubber` autotest sets
`model = "bear"` and `tint = "#B8B0C8"` on the entry before spawning, to test the AI before the model exists. None of
these kinds may join Phase D's raid pools (they are built for rooms, not trails).

### 13.3 Additions to existing blocks (the top upgrades)
Dotted paths show where each value goes; in the file they are ordinary nested entries. `cost` arrays and
`stat_cap_by_station_level` / `bow_cap_by_bench_level` stay as they are. Level index 3 of each defence is Phase D's
level 4; Phase E appends index 4 (level 5).
```json
"stats.damage.mastery": [{"leaves": 400, "amber": 6}, {"leaves": 550, "amber": 9, "glowstone": 3}],
"stats.draw.mastery":   [{"leaves": 400, "amber": 6}, {"leaves": 550, "amber": 9, "glowstone": 3}],
"stats.health.mastery": [{"leaves": 400, "amber": 6}, {"leaves": 550, "amber": 9, "glowstone": 3}],
"stats.speed.mastery":  [{"leaves": 400, "amber": 6}, {"leaves": 550, "amber": 9, "glowstone": 3}],
"bows.twig.mastery":    [{"leaves": 600, "amber": 6, "glowstone": 2}, {"leaves": 800, "amber": 9, "glowstone": 3, "heartwood": 1}],
"bows.sunwood.mastery": [{"leaves": 600, "amber": 6, "glowstone": 2}, {"leaves": 800, "amber": 9, "glowstone": 3, "heartwood": 1}],
"bows.volley.mastery":  [{"leaves": 600, "amber": 6, "glowstone": 2}, {"leaves": 800, "amber": 9, "glowstone": 3, "heartwood": 1}],
"bows.foxfire": {"name": "Foxfire Bow", "damage": 1.45, "arrows": 1, "spread_deg": 0, "pierce": 2, "range_bonus": 1.0, "bench_level": 3, "craft": {"leaves": 2000, "glowstone": 16, "heartwood": 3}, "needs_burrows": true, "tint": "#7FF0D8", "per_level": 0.1, "cost": [45, 65, 90, 125, 170, 230, 310, 420, 560, 750], "mastery": [{"leaves": 600, "amber": 6, "glowstone": 2}, {"leaves": 800, "amber": 9, "glowstone": 3, "heartwood": 1}]},
"defences.barricade.levels[4]": {"hp": 2000, "upgrade": 1800, "mats": {"amber": 16, "glowstone": 6}, "model": "barricade_heartwood", "name": "Heartwood", "needs_burrows": true},
"defences.tower.levels[4]":     {"damage": 44, "every": 0.65, "range": 7.0, "hp": 1000, "upgrade": 2800, "mats": {"amber": 20, "glowstone": 8, "heartwood": 2}, "name": "Amber", "needs_burrows": true},
"defences.spikes.levels[4]":    {"dps": 42, "slow": 0.55, "upgrade": 1500, "mats": {"amber": 14, "glowstone": 6}, "name": "Amber Thorns", "needs_burrows": true},
"stations.stone.levels[3]":     {"leaves": 2000, "timber": 20, "glowstone": 10, "heartwood": 4, "needs_burrows": true},
"guardian.hp_by_level[4]": 1800,
"guardian.fist_damage_by_level[4]": 75,
"guardian.slam_damage_by_level[4]": 125,
"guardian.scale_by_level[4]": 1.18
```
- `bows.*.craft` may now be a number (leaves) or a cost dictionary (`Data.craft_cost(bid)` turns a number into
  `{"leaves": n}`).
- The tower and spike level-5 models are `acorn_tower_5` and `thorn_spikes_5` (the existing naming in
  `defences.model`), and the barricade's comes from `levels[4].model`. Until a model exists, the level-4 choice is used
  (Phase D's model or its own fallback) with a small `amber_cluster` child on top (section 16.2).
- If Phase D is not built when E8 lands, there is no level 4 to append after: then E8 waits for Phase D's level 4, or
  the user's answer to D's question 5 moves these entries to index 3.
- The stone and guardian entries are skipped if Phase C is not built.

---

## 14. `game/data/burrow_rooms.json`

Room space: x across (-3.5..3.5), z from 0 (entry, south) to -l (north wall). Pillars are `[x, z, r]`, snappers
`[x, z, facing_deg]` (0 = facing south toward the entry, 90 = east), ferns `[x, z, r]`, vents `[x, z]`. Doors and their
rings come from the plan (section 5.1).
```json
{
  "_note": "Phase E room templates, 7 m wide inside. Loaded by Data into Data.rooms. Bump version when a template id or layout changes: a saved run on an older version is closed kindly (whole satchel banked, key returned).",
  "version": 1,
  "rooms": [
    {"id": "den_first", "type": "den", "min_depth": 1, "max_depth": 1, "first_only": true, "l": 13, "pillars": [],
     "spawns": [[-1.5, -7.5], [1.5, -7.5], [0.0, -9.5], [-2.4, -10.5], [2.4, -10.5]],
     "fixed": ["thornling", "thornling", "glowcap", "thornling", "thornling"], "ferns": [[-2.6, -4.0, 0.8]]},
    {"id": "den_open", "type": "den", "min_depth": 1, "l": 13, "pillars": [],
     "spawns": [[-2.4, -6.0], [2.4, -6.0], [0.0, -8.0], [-2.0, -10.5], [2.0, -10.5], [0.0, -11.6], [-2.8, -8.6], [2.8, -8.6]],
     "snappers": [[-3.0, -4.0, 90], [3.0, -9.0, -90]], "ferns": [[2.6, -3.4, 0.8]]},
    {"id": "den_pillars", "type": "den", "min_depth": 1, "l": 13, "pillars": [[-1.8, -5.0, 0.55], [1.8, -8.5, 0.55]],
     "spawns": [[-2.8, -6.6], [2.8, -5.0], [0.0, -7.4], [-1.4, -10.5], [1.4, -11.0], [-2.8, -11.6], [2.8, -10.0], [0.0, -12.0]],
     "snappers": [[0.0, -11.9, 0]]},
    {"id": "den_vents", "type": "den", "min_depth": 2, "l": 13, "pillars": [[0.0, -7.0, 0.6]], "vents": [[-2.3, -5.0], [2.3, -9.5]],
     "spawns": [[-1.2, -5.5], [2.8, -6.5], [-2.8, -8.0], [0.0, -10.0], [-1.8, -11.5], [1.8, -11.5], [2.8, -12.0], [-2.8, -12.0]]},
    {"id": "den_ring", "type": "den", "min_depth": 3, "l": 13,
     "pillars": [[-2.0, -4.5, 0.5], [2.0, -4.5, 0.5], [-2.0, -9.5, 0.5], [2.0, -9.5, 0.5]],
     "spawns": [[0.0, -7.0], [-3.0, -7.0], [3.0, -7.0], [0.0, -4.2], [0.0, -11.0], [-3.0, -11.8], [3.0, -11.8], [0.0, -12.2]],
     "snappers": [[-3.1, -2.8, 90], [3.1, -2.8, -90]]},
    {"id": "gauntlet_logs", "type": "gauntlet", "min_depth": 1, "l": 16,
     "traps": [{"type": "log", "lane": 0}, {"type": "log", "lane": 1}, {"type": "log", "lane": 2}], "chest": [0.0, -14.4]},
    {"id": "gauntlet_thorns", "type": "gauntlet", "min_depth": 1, "l": 16,
     "traps": [{"type": "thorns"}], "chest": [0.0, -14.6]},
    {"id": "gauntlet_crystals", "type": "gauntlet", "min_depth": 2, "l": 16,
     "traps": [{"type": "crystal"}], "snappers": [[-3.0, -6.5, 90], [3.0, -10.5, -90]], "chest": [0.0, -14.4]},
    {"id": "treasure_nook", "type": "treasure", "min_depth": 1, "l": 11, "chest": [0.0, -5.5],
     "guard": [0.0, -8.8], "spawns": [[-2.0, -8.4], [2.0, -8.4]]},
    {"id": "spring_pool", "type": "spring", "min_depth": 1, "l": 12, "spring": [0.0, -5.0],
     "shrines": [[-2.3, -8.2], [2.3, -8.2]], "lift": [-1.9, -11.0]},
    {"id": "elite_arena", "type": "elite", "min_depth": 2, "l": 13, "pillars": [[-1.9, -5.5, 0.55], [1.9, -5.5, 0.55]],
     "elite": [0.0, -8.5], "spawns": [[-2.4, -9.6], [2.4, -9.6]]},
    {"id": "boss_den", "type": "boss", "min_depth": 1, "l": 15,
     "pillars": [[-1.9, -5.5, 0.6], [1.9, -5.5, 0.6], [0.0, -8.8, 0.6]],
     "boss": [0.0, -12.0], "chest": [0.0, -10.6], "lift": [-1.9, -14.0], "deeper": [1.9, -14.0]}
  ]
}
```
- When a den needs more monsters than it has spawn spots, the extra ones stand at a random spot within ±0.8 m of a used
  one.
- Ring positions: shrine rings at shrine + (0, 1.1), the treasure chest ring at chest + (0, 1.3), lift and deeper
  rings at (x, -l + 1.0). The spring's drink zone is its pool (r 1.0 around `spring`). The shrine rings are 4.6 m apart.
- The tide (gauntlets from depth 3) is added by code, not by the template.

---

## 15. Save fields and old saves

### 15.1 New fields (save.gd: the var, `load_game` with `d.get`, and the `save_game` dict)
```gdscript
var mats := {"amber": 0, "glowstone": 0, "heartwood": 0}   # Burrows materials
var burrow_keys := 0        # SHARED with Phase D: add it only if Phase D has not added it yet. Load: int, 0..3
var burrow_depth := 0       # the deepest depth whose boss was beaten; depth + 1 is open
var burrow_run := {}        # a run under way (below); {} = none
var burrow_stats := {"runs": 0, "won": 0, "falls": 0, "best": 0}
```
`burrow_run` shape:
```json
{"v": 1, "depth": 2, "seed": 918273, "step": 2, "picked": ["den", "gauntlet"], "cleared": false, "hp": 11,
 "boons": ["sharp"], "satchel": {"amber": 3, "glowstone": 1}, "chain": 0, "spring_used": false,
 "woke": true, "first_run": false, "meal": "berry_tart"}
```
- `meal` is the Phase C dish that went down with the cat (or ""), so `_leave` knows to call `cooking.finish(true)`.
- New flags in `Save.flags`: `hollow_open`, `told_hollow`, `told_dash`, `told_fork`, `told_satchel`, `told_traps`,
  `told_pillar`.
- `save_game(quiet := false)`: Phase D's signature (when `quiet` is true it writes the file without emitting
  `changed`). If Phase D is not built yet, Phase E adds exactly that signature; existing callers are unchanged.
- `Save.add_mat(id, n)`. It does not save; the caller saves at room clears and at the end of a run.

### 15.2 Old saves
- `load_game` uses `d.get(key, default)` as today. `mats` and `burrow_stats` are merged key by key
  (`for k in d.get("mats", {}): mats[k] = int(d["mats"][k])`), so ids added later keep their defaults.
- **No timestamps or dates** anywhere. Nothing is worked out from elapsed time on load.
- A save that has already won all 15 missions: the reveal and the key ring filled to 3, once (section 3.4).
- A save from a build with Phase D but no Phase E may already hold `burrow_keys` (from raids). They are kept; the
  reveal only tops the ring up to 3.
- Old saves keep stats and bows at ≤ 10, `def_levels` at ≤ 4 and the stone at ≤ 3. Mastery, level 5 and stone level 4
  come only from the new rows. `defences.level()` already clamps to the kind's `levels.size()` (Phase D).
- A saved `burrow_run` with a different `v` or a step that no longer resolves is closed kindly (section 11.7).
- Legacy fields (`best_night`, `spots`) are untouched, and no new field reuses their names.

---

## 16. Files and functions

### 16.1 New files
**`game/scripts/burrow.gd`** (about 600 lines): the run and the area. `main.burrows`; `main.area` points to it while
inside.
- Constants: `AREA_PATCH := 99`. State: `main`, `run` (the live copy of `Save.burrow_run`), `room` (the current
  `burrow_room.gd`), `slot`, `env`, `active`, `_late_t`, `_hurt_in_room`, `_save_cd`, `_sun_was`, `_sum_t`,
  `_last_sum`, `_halo`.
- Camp side: `check_open(old_save := false)`, `open_hollow(celebrate: bool)`, `grant_key(reason: String, n := 1) ->
  int`, `blocker() -> String` (the first reason entry is refused, or ""), `card() -> Dictionary` (the Hollow card,
  called from `stations._card_hollow`), `persist()`.
- Run: `start_run(depth)`, `resume_run()`, `abandon_run()`, `plan(depth, seed) -> Array`, `step_type() -> String`,
  `_build_step()`, `choose(type)` (a door ring's action), `climb_out()`, `go_deeper()`, `cat_down()`,
  `_leave(result: String)`, `_swap_room()`, `_bank(share: float) -> Dictionary`, `_save_run(quiet := false)`,
  `_eat_meal()`, `_finish_meal()`.
- Spawning: `spawn(kind, at, opts := {}) -> Node3D` (like `fight.spawn`: a Node3D with enemy.gd, `main.add_child`,
  `setup(kind, AREA_PATCH, s)`; then the damage override, and `opts` `asleep`, `emerge`, `gloomtouched`, `boss`,
  `summon`; a boss sets `main.hud.boss` and the banner "%s wakes up!"; returns `null` over the cap),
  `strength() -> float`, `damage_add() -> int`, `leaf_mult() -> float`, `wake_room()`, `foes() -> Array` (the "foes"
  group members the area owns), `on_enemy_died(e)` (leaves, amber, dew, clear check), `_room_cleared()`,
  `_crumble_rest()`.
- Loot: `drop_mats(at, table: Dictionary)`, `collect_mat(kind, n, at)`, `open_chest(kind: String, sealed: bool)`.
- Boons: `take_boon(id)`, `_mods() -> Dictionary`.
- The area contract (section 11.2).
- `_process(delta)`: `d = minf(delta, 0.1)`; nothing while `main.frozen` or not `active`. Wake line, late spawns,
  the gauntlet end check, the boss adds timer, the spring drink, chest touches, the Amber Grub timer, the safety net,
  the halo following the pet, the throttled save.

**`game/scripts/burrow_room.gd`** (about 350 lines): builds one room from a template.
- `build(burrows, tpl: Dictionary, type: String, tier: Dictionary, doors: Array, origin: Vector3)`:
  - the floor (one code-built mesh: a 1 m grid of quads, each face one of the tier's two floor colours with a little
    jitter, `Props.vc()`, about 240 triangles) and the void plane;
  - walls as MultiMeshes of `burrow_wall_1` / `_2` (east, west, and north between doors) and `burrow_wall_low`
    (south), plus `burrow_corner` x4; fillers next to doors scaled along x;
  - `burrow_door` instances with their `gate` part, `burrow_sign` with a Label3D for the next room's type, and
    `burrow_pillar` (circle colliders);
  - seeded dressing from `tier.dress` along the walls (|x| 2.6-3.2, so the middle stays clear), count by Quality; ferns,
    vents, traps, chests, the spring, shrines, lifts, holes;
  - rings through `main.register_ring`.
- `constrain(p, r, is_enemy, flyer)`, `outside(p)`, `contains(p)`, `cam_focus(cat)`, `open_gates()`,
  `close_gates()`, `hide_at(p)`, `flee_point(p)`, `holes() -> Array`, `free_all()` (unregister rings first, then
  `queue_free`).

**`game/scripts/trap.gd`** (about 220 lines): one trap node, `setup(main, room, spec: Dictionary, depth: int,
strength: float)`.
- Types `log`, `thorns`, `crystal`, `spores`, `tide` (section 6.4).
- Warnings from `Fx.telegraph_line` / `telegraph_ring`. The cat is hurt through `main.player.hurt(from, n)` (dash
  protection and close calls apply). Monsters are hurt through `e.hit(dir, foe_damage x strength)`, once per firing
  (a set of instance ids cleared each cycle). Spores set `player.slow_t`. Each trap checks the cat and foes only on its
  burst frames. Timers use `minf(delta, 0.1)` and stop while `main.frozen`.

**`game/data/burrow_rooms.json`**: section 14.

### 16.2 Changed files

| File | Where | Change |
|---|---|---|
| `main.gd` | vars near 35 | `var area = null`, `var burrows: Node3D`, `var empowered_t := 0.0`, `var _status_mine := false`, `const BurrowScript := preload("res://scripts/burrow.gd")` |
| | `_ready` 56-114 | After `stations.build`: make `burrows` (`burrows.main = self`, `add_child`). Connect `joystick.flicked` to `_on_flick`. At the end, after Phase D's `raids.restore_on_load` and Phase C's `catch_up_gifts`: `burrows.check_open(true)` (deferred by `reveal_old_save_s`) |
| | `_process` 118-140 | `empowered_t` countdown |
| | `_update_camera` 163-183 | Area distance and focus (section 11.3); new `snap_camera()` |
| | `_update_hiding` 188-205 | `area.hide_at(p)` while in the Burrows |
| | `_update_grass` 252 | Return while `area != null` |
| | `_update_rebuild` 346-368 | The status line fix (section 12.1) |
| | `on_stage_end` 423-435 | `burrows.check_open()` at the end (after Phase D's raid branch returns, so only for missions) |
| | `set_riding` 474-496 | Refuse while `area != null` |
| | `on_player_down` 520-526 | Area branch first |
| | `_notification` (Phase D) | `burrows.persist()` beside `raids.persist()` |
| | new | `dash_enabled() -> bool` (`area != null or burrows cfg dash.everywhere`), `_on_flick(dir)` (calls `player.dash(dir)` when enabled), `drop_item(at, kind, n)` (material and dew pickups), `on_area_left(result)` |
| `world.gd` | `constrain` 869 | The `owns(p)` delegate |
| | `station_pos` 250-264 | `"hollow"` returns `burrows.hollow.pos` |
| | `build` | `add_circle(H, 1.4, "hollow")` |
| | `_woods` 670-771 | `in_hollow_clear(p)`: **draw, then skip** |
| | `_hideouts` 524-569 | The hollow post-filter at the end (next to Phase C's) |
| | `rebuild_paths` 350-382 | Stamp the trunk and the hollow path |
| | new | `in_hollow_clear(p)` |
| `grass.gd` | `build` 35-56 | Keep-outs at the hollow (2.4) and its ring (1.1), in their own list |
| `stations.gd` | `FOOT`, `build` ring list, `model_name`, `shown`, `ring_shown`, `refresh` | The `hollow` registry entries (section 3.5); ring radius 0.8, violet while sealed, gold once open; the `seal` and `eyes` parts and the eyes' blink timer |
| | `_update_pulses` 347-359 | The hollow ring pulses when open, a key is held and `burrows.blocker() == ""`, or a run is saved (Phase C's `pulse` row key works too) |
| | new | `_card_hollow()` → `main.burrows.card()` |
| | stat rows (about 680-710) | Use `Data.stat_cap(id)` and `Data.stat_cost(id, lv)` (dictionaries, materials included) |
| | `_card_bench` / `_upgrade_bow` (753-810) | Use `Data.bow_cap()`, `Data.bow_cost(bid, lv)` and `Data.craft_cost(bid)`; the Foxfire Bow craft row (hidden until the Hollow opens) |
| | `_card_shop` 518-571 | Phase D's `_def_cost(type, lv)` also merges `levels[lv-1].mats`. Phase D's `_upgrade_defence` guard gains `or (dl + 1 >= 5 and not Data.burrows_open())`. The level-5 row text and note (section 12.2) |
| | `_station_upgrade_row` (726-738) | A next level marked `needs_burrows` shows as "max" until the Hollow opens (the Guardian Stone's level 4) |
| `defences.gd` | `_valid` 347-360, `build` 28-50 | The hollow keep-out and the old-save refund (section 3.2) |
| | `model` 80-86 | Level 5: `levels[4].model` for the barricade, `acorn_tower_5`, `thorn_spikes_5`; if `not Props.has(name)`, the level-4 choice (Phase D's, with its own fallback) plus an `amber_cluster` child at Phase D's `CAP_AT[type]` + (0, 0.15, 0), scale 0.5 |
| | `level` 76-77 | Phase D already clamps to `levels.size()`; nothing more |
| `enemy.gd` | vars 30-93 | `awake := true`, `guard_at`, `gloomtouched := false`, `title := ""`, `_vuln_t := 0.0`, `_lob_at`, `_bite_dir`, `_life_t` |
| | `setup` 94-124 | Read `anchored` and `tint`; harden the patch guard (123) |
| | `_physics_process` 345-435 | `_vuln_t` countdown; states `"emerge"`, `"lob"`, `"bite"` |
| | `_think` 463-671 | Sleep check at the top; harden the guard (464); Phase D's `match String(info.get("ai", id))` (468); branches `glowcap`, `snapper`, `grubber`, `amber_grub` (`grub` uses the default); the area tail and the moth guard (section 7.1) |
| | `_hunt` 818-830 | The area fallback |
| | `_do_charge` 1072-1113, `_do_dash` 1177-1197 | Area wall end; blocked by a pillar or wall → `_daze_long` |
| | `_do_flee` 1265-1277 | Area branch |
| | `hit` 1281-1314 | x `vuln_mult` while `_vuln_t > 0` |
| | `_die` 1317-1340 | `main.area.on_enemy_died(self)` instead of `drop_leaves` when `_in_area()` |
| | new | `_in_area()`, `wake()`, `start_emerge(at)`, `make_gloomtouched(boss := false)`, `_daze_long(s)` |
| `fight.gd` | `spawn` 221-231 | The area delegate (first line) |
| | `start_mission` 83 | Refuse while `main.area != null` |
| | `_win` 454-490 | `if not first_win and Data.burrows_open(): main.burrows.grant_key("replay")` |
| `player.gd` | vars 57-81 | `_dash_t`, `_dash_iframe`, `_dash_cd`, `_dash_dir`, `_dash_dist` |
| | `_process` 247-371 | While dashing: move along `_dash_dir` (through `constrain`) instead of the stick, Run at 2x, lean, petals; timers count down |
| | `_fire` 373-395 | `main.ambush_ready or main.empowered_t > 0` doubles the damage and uses it up |
| | `hurt` 398-413 | `_dash_iframe > 0` → `_close_call()` and return; in the area, `burrows._hurt_in_room = true` and the throttled quiet save |
| | new | `dash(dir: Vector2) -> bool`, `_close_call()`, `dash_ready_frac() -> float` |
| `joystick.gd` | `_input` 24-41 | Keep the active touch's recent positions; on release, the flick test → `flicked.emit(dir)`. Space key. `force_flick(dir)` for the autotest. `signal flicked(dir: Vector2)` |
| `lifebar.gd` | `_draw` 51 | The dash arc under the health bar while recharging |
| `pickup.gd` | `setup` 15, line 51, `_collect` 54 | Phase D's `kind := "leaf"` and `setup(m, v, at, k := "leaf")`; Phase E adds the kinds `amber`, `glowstone`, `heartwood` (models `mat_*`) and `dew` (`dew_drop`); the area-aware clamp; `_collect` routes materials to `main.burrows.collect_mat` and dew to +1 health; `steal()` takes leaves only |
| `pet.gd` | `_spit` 210 | The interval divided by `Data.run_mods.get("pet_rate", 1.0)` |
| `hud.gd` | `_layout` 151-172, `refresh` 175-183, `_process` 198-232, `_draw_gate` 275, `refresh_build` 327, `_cost_button` 526-566, icons 604-646, `_draw_boss` 293-301 | Section 12.1 |
| `data.gd` | `can_afford` / `pay` 224-233 | `const CURRENCIES := ["leaves", "timber", "shards", "keys", "amber", "glowstone", "heartwood"]`. `have(k)`, `take(k, n)`, `give(k, n)` (`keys` maps to `Save.burrow_keys`, `shards` to `Save.shards` when it exists, materials to `Save.mats`). `can_afford` and `pay` loop **only over `CURRENCIES`**: cost dictionaries also hold `needs_missions`, `needs_burrows` and `mats`, which are not money. This replaces Phase D's explicit shard lines with the same behaviour |
| | `stat_cap` 160 | If the Hollow is open, the stat has `mastery` and its normal cap is 10: `10 + mastery.size()` |
| | `bow_cap` 169 | If the Hollow is open and the bench cap is 10: 12 |
| | `arrow_damage` 216, `cat_max_hp` 195 | x (1 + `run_mods.damage`), + `run_mods.hp` (beside Phase C's meal boosts) |
| | new | `var run_mods := {}`, `var rooms := {}` (loaded in `_ready`), `burrows_open()` (`Save.flag("hollow_open")`), `burrow_cfg()`, `mat_name(id)`, `mats_line(cost) -> String` (the " · have …" note), `depth_tier(d)`, `depth_strength(d)`, `depth_damage_add(d)`, `depth_leaf_mult(d)`, `depth_power(d)`, `depth_boss(d) -> Dictionary` (the stand-in while the model is missing), `depth_drop(table, key, d) -> float`, `stat_cost(id, lv)`, `bow_cost(bid, lv)`, `craft_cost(bid)` |
| `save.gd` | 7-118 | Section 15 |
| Phase D `raids.gd` | `finish` step 3 | `if main.get("burrows") != null: main.burrows.grant_key("raid", n) else: Save.burrow_keys = mini(max, keys + n)` |
| Phase C `cooking.gd` | `eat()` | Optional `scope := "chapter"`: with `"run"` the banner sub says "%s this run" |
| `autotest.gd` | mode list 100-215 | Section 20 |

---

## 17. Blender props (Claude in Blender, `docs/ASSET_RULES.md`)

Faceted, one colour per face (`M_VertexColor`), front Blender -Y (Godot +Z), origin on the ground at the footprint
centre, metres. Glowing parts are bright faces. Named parts are moved by code (`Props.find_part`). Every prop falls back
to `Props._placeholder` until it exists, so the code can be built first; add faceted placeholder cases for each name to
`props.gd` `_placeholder_mesh`, as Phase C does (no magenta boxes). Group files: `art/blender/props/burrows.blend`,
`game/assets/props/<name>.glb` plus `game/assets/props/burrows.json`, previews in `art/previews/props/burrows/`. Run
`blender-asset-qa` on each before calling it done.

| Prop | Size (m) | Max tris | Notes |
|---|---|---|---|
| `burrow_hollow` | 4.4 x 3.6 x 3.0 | 3,000 (building) | A dark round hole (1.6 m across) going down between giant mossy roots. **North (camp-side, Blender +Y) rim ≤ 0.6 m**, with wooden steps going down; **south (camera-side, -Y) rim ≤ 1.8 m**; root arches on the east and west sides up to 3.0 m. Two small amber lanterns on the roots (glow faces). Parts: `seal` (violet Gloom crystals and brambles plugging the hole), `eyes` (two violet glints under the seal), `glow` (the hole's inner rim, bright once open). Collision circle 1.4 |
| `hollow_roots_a`, `hollow_roots_b` | 6.0 x 1.2 x 0.8 | 800 each | Giant roots snaking flat from the treeline toward the hollow (dressing in the cleared notch; no collision) |
| `burrow_wall_1`, `burrow_wall_2` | 2.0 x 0.7 x 2.2 | 500 each | Packed earth with roots and stones, tiling end to end; the room side is the front |
| `burrow_wall_low` | 2.0 x 0.5 x 0.5 | 200 | The south lip, so the camera sees in |
| `burrow_corner` | 1.0 x 1.0 x 2.4 | 400 | A root knot |
| `burrow_door` | 2.0 x 0.8 x 2.4 | 1,200 | A root arch with a 1.6 m opening. Part `gate`: root bars, lowered 2.0 m by code |
| `burrow_sign` | 0.6 x 0.2 x 1.2 | 300 | A root-post board beside a door; the code adds a Label3D in the type's colour |
| `burrow_pillar` | 1.2 x 1.2 x 2.6 | 500 | A root column |
| `burrow_hole` | 1.2 x 1.2 x 0.3 | 300 | A dirt hole with a mound rim and claw marks (spawns, the Amber Grub) |
| `burrow_spring` | 2.4 x 2.4 x 0.4 | 1,500 | A moonwell pool, r 1.1, mossy stone rim, glowing water faces, walkable |
| `boon_shrine` | 0.8 x 0.6 x 1.4 | 400 | A mossy standing stone with a glowing leaf rune |
| `root_lift` | 1.6 x 1.6 x 2.6 | 1,200 | A vine-basket lift in a root niche. Part `basket` rises |
| `burrow_chest` | 1.0 x 0.7 x 0.8 | 600 | A root chest. Part `lid` (origin at the hinge). `leaf_chest` has a fixed open lid, so it cannot be reused |
| `gloom_seal` | 1.2 x 0.9 x 0.9 | 300 | A crystal cage over the treasure chest |
| `burrow_chest_boss` | 1.6 x 1.1 x 1.2 | 900 | A big root chest wrapped in glowing vines; part `lid` |
| `trap_thorns` | 1.7 x 1.7 x 0.6 | 500 | A floor plate, r 0.85. Part `spikes` rises |
| `spore_vent` | 1.0 x 1.0 x 0.4 | 300 | A ring of tiny mushrooms round a vent; part `cap` squashes before a puff |
| `dew_bud` | 0.4 x 0.4 x 0.5 | 100 | A closed green bud; part `petals` opens |
| `glow_mushroom_big` | 0.9 x 0.9 x 1.4 | 400 | A tall glowing teal mushroom (Grotto dressing) |
| `amber_cluster` | 0.5 x 0.5 x 0.5 | 300 | Amber crystals (Deeps dressing, and the level-5 fallback cap) |
| `root_tangle` | 1.0 x 0.6 x 0.4 | 150 | Floor and wall dressing |
| `mat_amber` | about 0.25 | 100 | Pickup: a honey-orange resin crystal |
| `mat_glowstone` | about 0.22 | 100 | Pickup: a rounded teal pebble with bright faces (teal, never violet: Phase D's shard is a violet crystal) |
| `mat_heartwood` | about 0.25 | 100 | Pickup: a knot of brown root with an amber core |
| `dew_drop` | 0.2 | 100 | Pickup: a green water drop |
| `barricade_heartwood` | 3.0 x 0.8 x 1.1 | 1,500 | Barricade level 5: carved heartwood logs bound with glowing root bands; the same footprint as the other barricades |
| `acorn_tower_5` | 1.9 x 1.9 x 3.2 | 1,500 | The Amber Tower: parts `turret` and `marker_shoot` like the other towers; an amber cap |
| `thorn_spikes_5` | 1.3 x 1.0 x 0.45 | 1,500 | Amber Thorns: spikes with amber tips |
| `guardian_stone` (Phase C's prop) | as Phase C | +300 | Add a part `heart`: a heartwood knot with an amber core set into the stone's top, shown at stone level 4 (until then, code adds an `amber_cluster` child at (0, 1.7, 0), scale 0.6) |

Reused as they are: `log_fallen` (the rolling log), `gloom_crystal` (falling crystals and dressing), `rock_1`,
`rock_2`, `mushroom_cluster`, `fern`, `golden_leaf`.

The Foxfire Bow needs no model: the cat's bow is tinted, as the other bows are. Floors, the void and the tide are built
in code.

---

## 18. New characters for the user's Meshy (concept prompts)

Made with Codex CLI (`codex exec`, built-in image generation), one image per asset, **one batch of 5**, with
`-i "D:\3D Modeling Test\CatRanger\reference\concept_sheet.png"` as the style reference. Prompts go in
`concepts/burrows/prompts/`, images in `concepts/burrows/`. Each image goes to the user's Meshy, then Claude colours,
rigs and animates the mesh per `docs/AGENT_BRIEF_MESHY.md`. Output: `game/assets/enemies/<id>/<id>.glb` + `.json`. Add
each to the budget and clip tables in `docs/ASSET_RULES.md` when it is made.

Every prompt uses the same closing blocks as `concepts/enemies3/prompts/` (written out in full in each file):
> STYLE: Stylized LOW-POLY 3D game model render in the same art style as the attached reference image: few, large
> faceted flat-shaded polygons with visible facets, simple chunky cute shapes, no fine detail, clean matte saturated
> colours with simple painted patches, soft even studio lighting. A bright, friendly fantasy mobile-game look.
>
> FOR A 3D MODEL GENERATOR: Exactly one subject, alone. The whole body visible from top to bottom with empty margin on
> every side, centred, nothing cropped. No ground, no base, no props lying around. Plain flat light-grey background with
> no gradient, no floor and no cast shadow. No particles, smoke, sparkles or floating effects. Limbs held a little away
> from the body so they read clearly.
> ONE SINGLE IMAGE: not a character sheet, no multiple views, no turnaround, no close-up insets, no colour swatches, no
> text, no labels, no watermark, no border.
> REFERENCE: use the attached image only as an art-style reference (the low-poly faceted 3D look, shading and colour
> saturation). Do not draw the cat and do not copy its sheet layout.

**`01_grubling.txt`** (`grub`, 2,000 tris, about 0.6 m long). Clips: Idle, Walk, Attack (event `hit`), Hit, Die,
**Emerge** (pops up out of the ground, about 0.6 s).
> SUBJECT: A Grubling, a small burrowing grub creature about knee-high to a cat: a plump pale lavender segmented body,
> six stubby legs, a round head with big dark shiny eyes and tiny pincers, a little brown dirt on its belly. Its marks
> of the Gloom are glowing violet eyes and three small solid violet crystals growing from its back. Cheeky and
> squishy, never scary or gory.
> CAMERA AND POSE: side view turned about 30 degrees toward the camera, camera at its height. Crawling pose, head
> raised.

**`02_glowcap.txt`** (`glowcap`, 3,000 tris, about 0.9 m tall). Clips: Idle, Walk, Attack (a bonk), Hit, Die,
**Cast** (throws the spore ball overhand; event `cast`).
> SUBJECT: A Glowcap, a small walking mushroom creature: a wide glowing teal mushroom cap with pale glowing spots, a
> stubby cream stem body with short root feet, two little arms hugging a puffy spore ball, a grumpy little face under
> the rim of the cap. Its marks of the Gloom are glowing violet eyes and a few small solid violet crystals on the cap.
> Grumpy and comic, never scary or gory.
> CAMERA AND POSE: front view turned about 20 degrees to the side, camera at chest height. Neutral standing pose,
> arms a little away from the body.

**`03_root_snapper.txt`** (`snapper`, 3,500 tris, about 1.2 m tall). Clips: Idle (a slow sway), **Windup** (the jaws
gape, 0.7 s), Attack (a lunging bite; event `hit`), Hit, Die. Walk is a copy of Idle (code safety); `ground_speed`
0.
> SUBJECT: A Root Snapper, a living trap plant rooted in the ground: a big jaw made of two curved bark-covered root
> halves lined with wooden thorn teeth, mossy green outside, a glowing amber sap pocket inside the open mouth, thick
> roots spreading round its base, one leafy tuft on top. It cannot walk. Its marks of the Gloom are two glowing violet
> eye-knots above the jaw and a few solid violet crystal growths on the bark. Mischievous, never scary or gory.
> CAMERA AND POSE: front view turned about 20 degrees to the side, camera at its mid height. Jaws half open.

**`04_old_grubber.txt`** (`grubber`, boss, 12,000 tris, about 2.2 m tall). Clips: Idle, Walk, Attack (claw swipe;
event `hit`), Hit, Die, **Dig** (about 0.8 s), **Emerge** (about 0.7 s; event `impact`), **Windup** (curls into a
ball, about 0.9 s), **Charge** (rolling-ball loop), **Roar** (event `roar`). Spring bones: `jig.lantern.*`,
`jig.roots.*`.
> SUBJECT: Old Grubber, the Gloom Badger, a big chunky badger boss about twice the height of a cat, stocky and round,
> grey and cream fur with a bold black-and-white face stripe, huge digging claws, a crown of tangled roots on its head,
> an amber lantern hanging from a root on its back, a grumpy determined face, slightly hunched, ready to dig. Its marks
> of the Gloom are glowing violet eyes and solid violet crystals growing in its root crown. Grumpy and grand, a little
> comic, never scary or gory.
> CAMERA AND POSE: front view turned about 20 degrees to the side, camera at chest height. Neutral standing pose on
> all fours with the head up, claws a little away from the body.

**`05_amber_grub.txt`** (`amber_grub`, 2,000 tris, about 0.5 m long). Clips: Idle, Walk, Run, Hit, Die, **Dig**
(burrows away, about 0.8 s).
> SUBJECT: An Amber Grub, a plump, adorable treasure grub about half as tall as a cat: its round segmented back is
> translucent golden amber that glows warmly, with a cream underside, six stubby legs, a tiny happy face with rosy
> cheeks and two little feelers. Shy and sweet, never scary.
> CAMERA AND POSE: side view turned about 30 degrees toward the camera, camera at its height. Mid-scurry, head raised.

Optional, not Meshy: a 0.25 s `Dash` clip for the Cat Ranger in its own project (a low forward leap, ears back).

---

## 19. Quality and performance

- **Live monsters:** `max_alive_by_quality` (Low 8, Medium and High 10; missions allow 28, Phase D's raids 18-28), plus
  a boss (≤ 12k tris) and at most 4 boss minions. The O(n²) separation in `main._physics_process` stays tiny.
- **Room budget** (it must cost less than the camp: S24 camp High 297k tris / 192 draw calls, Low 100k / 122): room
  geometry ≤ 15k tris (walls about 8k, doors 2.4k, pillars 1.5k, dressing about 3k). Walls and dressing are MultiMeshes
  per prop type (`Props.mesh(name)`, as `_scatter_cells` does): about 25-40 draw calls. Dressing count by Quality: 8 /
  14 / 18.
- **Targets:** the busiest den (10 monsters, traps, the cat, Sprig): Low ≤ 70k tris and ≤ 80 draw calls, a steady 30
  fps on a weak phone; High ≤ 120k tris, 60 fps or more on the S24.
- **Lights:** none needed. One optional OmniLight (Sprig) on Medium and High, in group `"lamp"`, so
  `world.apply_quality` turns it off on Low.
- **Shadows:** walls and pillars cast on Medium and High; the floor, dressing and void plane never cast; `Fx.blob` on
  Low as everywhere.
- **Fog and glow:** fog in the camera environment is cheap on Mobile; glow follows `Quality.glow()`.
- **Particles:** every Fx call goes through `Quality.particles(n)` as today. Telegraphs are small unshaded transparent
  planes.
- **Hitches:** rooms are built behind the fade, and the tier's enemy GLBs and props load with
  `ResourceLoader.load_threaded_request` at run start. The Quality frame watch already ignores frames over 0.25 s.
- **The camp keeps running** while the cat is below ground, but it is not drawn (400 m away). Grass pushers are skipped
  (`_update_grass` returns). The towers' scans find nothing in range. Phase D's meter does not tick (`can_fill` checks
  the area) and Phase C's Warden only thinks in a wave.
- **Saves:** run saves while hurt are throttled (1.5 s) and quiet (no `changed`).
- **Frame time:** every Burrows timer clamps `delta` to 0.1.

---

## 20. Autotest modes (autotest.gd; the lead runs them, Claude does not run Godot)

Each mode sets up its own save (with `--fresh`): all 15 missions won, stats 10, sunwood 10, the stations at 3, home 4.
With Phase D built it also sets `Save.raids.meter = 0` and `pending = false`, so no raid comes mid-test.

| Mode | What it checks |
|---|---|
| `--hollow` | A save with 1 mission won: the sealed hollow and ring, the card text; screenshots on the ring at 9:16 and 9:20. Then all 15 won: the reveal runs after the other banners (flag set, keys filled to 3, `seal` hidden), the ring turns gold. Screenshots of the reveal, the path and the notch. No tree, undergrowth, coral tree, hideout, grass tuft or placed defence stands inside `in_hollow_clear`; the hollow and the cat are both on screen with the cat on the ring, and no crown covers them. With Phase C: the path's centre line stays 1.5 m or more from the garden ring and 2.0 m or more from the garden bed's centre plus its radius, and outside Phase C's `RESERVED` circles |
| `--burrow` | `player.invincible = true`, 3 keys, depth 1, seed 1234. For each step: the room is built, the foe count matches the plan, monsters sleep until the wake line. Kill all (`e.hit(dir, 9999)`) → gates open and door rings show. Pick option 0 → the spring heals, take a boon → the boss spawns, `hud.boss` is set → kill it → climb out. Asserts: `Save.mats` grew by the satchel, keys 2 + 1 first-clear key = 3, `burrow_run == {}`, `fight.active == false`, `Save.mission_run` unchanged, `burrow_depth == 1`, `main.area == null`, the cat near (0, 15.5), `cam.environment == null`, the sun's energy restored. A screenshot per room |
| `--burrowfall` | Not invincible. In room 2, set health to 1 and let a thornling hit → the run ends, the cat at the return spot with full health, `floor(satchel x 0.5)` banked, the key spent, leaves never reduced, `burrow_stats.falls == 1` |
| `--burrowresume` / `--burrowresume=2` | Phase 1 starts a run, reaches step 2, takes a hit, quits. Phase 2 (same save, no `--fresh`): the cat is in the camp, the card offers "Go back in", resume → the same template id, the saved health (the hit counted), boons kept, no key spent. Then "Leave it" on a second saved run → half banked |
| `--dash` | In `gauntlet_logs`: `force_flick` → moved about 3 m (±0.2); blocked by a wall when flicked into it; a log crossing during the protection does not hurt and sets `empowered_t`; a second flick within 1.4 s does nothing; the next arrow does double damage. A slow release (under `flick_min_px` in the window) does not dash. Outside the Burrows a flick does nothing |
| `--traps` | Every trap type: its warning comes before the damage by at least 0.8 s (±0.05), safe ground within 1.6 m, it hurts the cat once per cycle and also hurts a test monster. Spores slow without damage. The tide's pace. Screenshots |
| `--boss=<chief/bear/grubber/owl/stag>` | Straight into a boss den. Summons go through `area.spawn` (positions inside the room, the run's strength, never more than 4 minions). A charge into a pillar → state `"daze"` for about 2.5 s and `_vuln_t > 0`, the next hit x1.5. Every special warns at least 0.6 s ahead. A screenshot of each warning. `grubber` runs on the bear model with a tint |
| `--topup` | Gives materials and buys tower level 5 (after level 4), stat 11 and 12, bow 11 and 12, the Foxfire Bow and (with Phase C) stone level 4 → materials paid, caps raised, Health capped at 12 only through mastery (never by home level), the level-5 model falls back when missing, level 5 refused at home level 4 and before the Hollow opens, stone level 4 hidden before the Hollow opens |
| `--burrowsave` | Loads an old-format save (no new fields, all missions won): defaults, the reveal, keys filled to 3, once over two loads. A save with `burrow_keys` 2 and no `hollow_open`: kept, topped up to 3. A save with a `burrow_run` of another `v`: closed kindly, satchel banked, key returned. Reload twice and wait 5 s: keys unchanged (nothing by time) |
| `--burrowhooks` | Only with Phase C and/or D built. D: the Hollow refuses entry while `Save.raids.pending`; a finished run adds 15 meter points (and never past 95); the meter does not move during a run; a raid held with 3 keys gives +150 leaves instead of a 4th key. C: a dish in the pot is eaten at run start (`meal_on` set, its boost applies), used up at run end, and back in the pot after a quit mid-run |
| `--burrowperf` | The busiest den with `max_alive` monsters on Low, Medium and High: fps, tris and draw calls into `report.json`, then `docs/PERFORMANCE.md` ("Burrows") |

`--smoke` gains a short Burrows step (enter, clear one room, climb out). The existing `--smoke`, `--laststand` and
`--perf` (and Phase C's and D's modes) must still pass: the camp is unchanged apart from the hollow, its path and the
notch. **Review check:** Phase D's no-clock grep (`get_unix_time|get_datetime|get_date_|get_time_dict|get_time_string`)
still finds matches only in `autotest.gd`.

---

## 21. Fitting with Phase C and Phase D

**Phase D (Gloom Raids, `docs/PHASE_D_SPEC.md`):**
- **Meter:** it does not fill while `main.get("area") != null` (D's `can_fill`), and a pending warning never starts
  below ground (D's `blocked_reason` "away"). A finished run calls `main.raids.add_gloom("burrow_run")` (D's action:
  15 points, never past 95), so a raid never becomes pending because of a run.
- **Entry:** the Hollow refuses entry while a raid is pending (`Save.raids.pending`) or fought (`fight.active`), the same
  way a pending raid blocks a mission replay in D.
- **Keys:** `Save.burrow_keys` is D's field too. D's raids give 1 key (2 for an elite raid), at most 3. Once E exists,
  D's `finish` gives them through `main.burrows.grant_key("raid", n)`, so a full ring turns the extra key into 150
  leaves instead of losing it.
- **Defences:** D's level 4 (Shardstone, shards) stays. E adds level 5 with materials (D: "Level 5 of each defence is
  left to Phase E"). D's `_def_cost` merges `mats`, D's `_upgrade_defence` guard adds the Hollow check, D's
  `repair_cost` formula already scales with the level, and D's camp score counts the new levels.
- **Currencies:** E's `Data.CURRENCIES` loop includes `"shards"` and replaces D's explicit lines with the same result;
  `_cost_button` draws D's shard icon from the same loop. Boss chests pay a few shards (banked at once) when D is built.
- **Saves:** E uses D's `save_game(quiet := false)` and adds `burrows.persist()` to D's `main._notification`.
- **Pickups:** E uses D's `kind` (`"leaf"` default, `"shard"`) and adds its own kinds.
- **HUD:** the top-right spot belongs to the Burrows below ground, then to fights, then to D's meter (section 12.1).
  The top-left gets nothing new from E.
- **Enemies:** E's branches go into D's `match String(info.get("ai", id))`. None of E's kinds join raid pools.
- **The south:** D adds nothing south of the campfire and keeps sneak raids on the 4 north trails, so no raid crosses
  the hollow, its path or the notch. If a southern raid trail is ever added (D's question 6), it must keep out of
  `in_hollow_clear`.
- **Banners at the last win:** D's raids intro plays first; E's reveal waits 8 s and for the banner to clear.

**Phase C (Moss Warden, garden, cooking, fishing, `docs/PHASE_C_SPEC.md`):**
- **Ground:** C's stone (8.0, 0.75), garden (0.5, 8.4) and fishing spot (-7.2, 5.3) are all clear of the hollow. The
  hollow path goes west round the garden (section 3.3), and E's keep-outs and C's `RESERVED` circles do not overlap.
  Both filter hide spots after the generation loop, so the seed-909 sequence is unchanged by either.
- **The Warden** stays in the camp and never goes down. It thinks only in a wave, so nothing changes while the cat is
  below ground. Its level 4 costs Burrows materials (section 9.3): E appends to C's `stations.stone.levels` and the
  `guardian.*_by_level` arrays, and C's `_station_upgrade_row` hides the level until the Hollow opens.
- **Meals:** a dish waiting in the pot is eaten when a run starts (`cooking.eat("run")`) and used up when the run ends
  (`cooking.finish(true)`). C's load rule puts it back in the pot after a quit, so "Go back in" eats it again. A dish
  is therefore for whatever comes first: the next chapter, the next raid or the next run. `burrows.meals_in_runs`
  turns this off.
- **Seeds:** none from the Burrows (C has no seed inventory).
- **Fishing:** the Hollow refuses entry while `main.busy_minigame` is set; the flick dash never works in the camp, so it
  cannot clash with C's tap-anywhere fishing.
- **HUD:** C's meal chip stays visible below ground (it says what the cat is eating).

**Phase F:** fletching special arrows from materials (the ongoing material sink), and daily or weekly tasks with
Burrows goals ("Clear a depth without a hit", "Catch an Amber Grub"), earned in play.

---

## 22. Build order (small steps; each ends with its autotest)

1. **[Built]** **E0, plumbing** (nothing visible): Save fields and migration, `save_game(quiet)` (if Phase D has not added it),
   `Data.CURRENCIES` / `have` / `take` / `give` / `can_afford` / `pay`, `stat_cost`, `bow_cost`, `craft_cost`, the
   `burrows` block, `Data.rooms`. *Test: `--burrowsave` (load parts), `--smoke`.*
2. **[Built]** **E1, the Hollow in the camp:** `in_hollow_clear` (draw, then skip), the notch, the path round the garden, collision,
   the grass, hideout and defence keep-outs (with the refund), the `hollow` registry entries, the ring and its three
   card states, `check_open` and the reveal with the keys, `grant_key` from replays, placeholder props. *Test:
   `--hollow`.*
3. **[Built]** **E2, the area skeleton:** `burrow.gd` and `burrow_room.gd` with `den_open` only and no monsters; the `main.area`
   hooks (camera, `snap_camera`, the `owns(p)` delegate, riding refused, `_update_grass`); `hud.fade`; environment and
   sun; the HUD priority; enter and climb out. *Test: walk the room, come back, the camp intact.*
4. **[Built]** **E3, monsters in rooms:** enemy burrow mode (sleep and wake, the hunt tail, the moth guard, patch 99 and the
   hardened guards, the `ai` match if Phase D has not added it, flee, charge end, hidden-cat fallback), the
   `fight.spawn` delegate, `area.spawn` with strength and the damage override, room clear and gates, the safety net,
   leaf pickups and the clamp fix, `cat_down`. A **fixed plan** first: den, den, boss (existing bosses). *Test:
   `--burrow` (dens and boss only), `--burrowfall`.*
5. **[Built]** **E4, the run map:** plan and seed, forks with signs and door rings, treasure, spring, elite and boss rooms,
   material pickups and the satchel, boons, `Save.burrow_run` and resume, `persist()` in `_notification`, the entry
   lift and key return, HUD status, pips and satchel line. *Test: `--burrow` in full, `--burrowresume`.*
6. **[Built]** **E5, the Leaf Dash:** the joystick flick, `player.dash`, protection, close call and `empowered_t`, the lifebar arc,
   the tip. *Test: `--dash`.*
7. **[Built]** **E6, traps, pillars and ferns:** `trap.gd` (log, thorns, crystal, spores, tide), the gauntlet templates, the chest
   only if unhurt, charges into pillars and walls → daze and weak spot, fern hiding. *Test: `--traps`, `--boss=bear`.*
8. **[Built]** **E7, new monsters on stand-ins:** `grub` (`start_emerge`), `glowcap` (lob), `snapper` (bite line), `amber_grub`,
   Gloomtouched elites and the chief boss, the `tint` key, the `grubber` AI (on the bear model in the autotest only).
   *Test: `--boss=chief`, `--boss=grubber`.*
9. **[Built]** **E8, rewards and top upgrades:** drop tables, the sealed chest, first clears, dew, mastery rows for stats and bows,
   the Foxfire Bow, level-5 defences with the model fallback (after Phase D's level 4), the Warden's level 4 (with
   Phase C), materials on cost buttons and the " · have" notes. *Test: `--topup`, then the existing `--levels` again.*
10. **[Built]** **E9, tiers and look:** the 5 environments, dressing, colours, Sprig's halo. Perf pass. *Test: `--burrowperf`.*
11. **[Built]** **E10, Phase C and D hooks** (when they land, in either order): `add_gloom("burrow_run")`, the raid blocker, D's
    keys through `grant_key`, boss-chest shards, meals in runs, the mini-game blocker. *Test: `--burrowhooks`.*
12. **[Done before]** **E11, Blender props** (in parallel from E1): `burrow_hollow` first, then the walls, door, sign, pillar, spring,
    shrine, lift, chests, traps, pickups, then the level-5 defences and the stone's `heart` part. `blender-asset-qa` on
    each.
13. **[Stand-ins; models wait on the user]** **E12, Meshy characters** (in parallel from E2): the 5 concept images (section 18) → the user's Meshy → rig and
    clips per the brief → drop in by deleting `model`, `scale` and `tint` from each entry. Old Grubber becomes depth 3's
    boss by itself once `grubber.glb` exists.
14. **[Docs done; tuning by play on the phone]** **E13, tuning and docs:** play for run length (3-5 min), boss times (40-75 s), materials per run (about 20 runs
    to buy everything) and leaves per minute (at or below replays). Then update `GAME_PLAN.md` (section 24) and
    `docs/ASSET_RULES.md` (the new budgets and clips).

---

## 23. Questions for the user, and risks

**Questions**
1. **A knock-out keeps half the materials gathered in the run** (leaves, timber and shards are always kept). Keep it,
   or keep everything (less tension)?
2. **Keys:** the ring filled to 3 when the Hollow opens, then +1 for each raid held (2 for an elite raid), each replay
   won and each new depth cleared; at most 3 held; no clock at all. Is that the right pace?
3. **Entering only while the camp stands** (no ruin, no ashes, no raid coming)? Or should a ruin only show a warning?
4. **The Leaf Dash:** Burrows only (proposed), or in missions and raids too later?
5. **The sealed Old Hollow** shows from the first mission won (a teaser). Keep it, show it from the first launch, or
   only when it opens?
6. **Meshy batch:** Grubling, Glowcap, Root Snapper, Old Grubber and the Amber Grub. Make all five? Until then the
   small ones use tinted existing models, and Mossback stands in for Old Grubber.
7. **Top upgrades:** mastery levels 11-12, a 4th bow (Foxfire), level-5 defences and the Moss Warden's level 4. The
   right "top tier", or should materials buy something else (for example station level 4, more tower spots or a
   tougher campfire)?
8. **A cooked dish goes down with the cat** if one waits in the pot (it is for the next chapter, raid or run, whichever
   comes first). OK, or should runs never use the pot?

**Risks**
- `world.constrain` must hand over only for points the Burrows own (`owns(p)`); otherwise Thistle walking home and the
  trader break while the cat is below ground.
- `Data.can_afford` and `pay` must loop over currencies only: cost dictionaries carry `needs_*` and `mats` keys.
- Monsters below ground use patch 99, never -1; every trail lookup sits behind the hardened guards.
- Summons must reach `area.spawn` (through the `fight.spawn` delegate), never the mission path.
- Clearing the woods for the hollow must draw the random numbers first and skip afterwards, or the whole seed-2611
  woods reshuffles.
- The path round the garden is worked out from positions in code and in Phase C's spec, not seen in the game yet:
  `--hollow` must confirm it before the props are made.
- The flick may still fire by accident on some thumbs: `flick_window_s` and `flick_min_px` are the levers, and the
  first play test should watch for it.
- The top-left HUD box in the camp (leaves, timber, Phase C's meal chip, Phase D's shards) may already reach the boss
  bar at y 190 during a mission replay with a boss. Not caused by E, but check it in the screenshots; the fix is to put
  the boss bar under the box (`max(190, box bottom + 12)`).
- Level 5 depends on Phase D's level 4 being in the file first; if D is late, E8 waits or the user's answer to D's
  question 5 moves E's entries to level 4.
- The camp-falls key `"raid"` and Phase D's `"gloom_raids"` are untouched; the Burrows use `"burrows"`.
- Yields, costs, boss health and powers are first guesses. Tune by play (E13).

---

## 24. Text for GAME_PLAN.md (after the user approves)

Section 0, "After the missions", replace the Burrows bullet with:

> - **The Burrows (dungeons)** *(Phase E design, 18 November 2026: docs/PHASE_E_SPEC.md)*. The Old Hollow at the
>   south edge of the woods stands sealed from the first mission won and opens when the last mission is won, with the
>   key ring filled to 3. A run costs a key and lasts 3-5 minutes: a den, forks where the cat picks a tunnel (den,
>   gauntlet of traps, treasure, elite), a spring or an elite fight, then a boss (the Thornling Chief, Mossback, Old
>   Grubber, the Owl Witch and the Elder Thornstag by depth). Every trap and big attack glows on the ground before it
>   lands, and the cat (with Sprig) moves, dashes with a flick of the thumb and baits charges into pillars. Materials
>   (amber, glowstone, heartwood) go into a satchel: climbing out keeps all of them, a knock-out keeps half; leaves,
>   timber and shards are always kept. **Keys come only from playing**: a Gloom Raid held (2 for an elite raid), a
>   mission replay won, a new depth cleared; at most 3 are held, and nothing refills while the game is closed. A run in
>   progress waits at the Hollow when the game is closed. A dish waiting in the pot goes down with the cat. Materials
>   pay for mastery (levels 11-12 of damage, draw speed, health, speed and every bow), the Foxfire Bow, the level-5
>   Heartwood Gate, Amber Tower and Amber Thorns, and the Moss Warden's level 4. Keys and materials are never sold.

In the Gloom Raids bullet, lines 123-124 ("the meter can fill offline, and then at most one raid is waiting at the
gate") become what Phase D's section 26 says: the meter fills only while the game is played; nothing fills, fights or
refills while the game is closed.

---

## Props as built (18 November 2026, notes for the code)

All 30 section-17 props are in `game/assets/props/` with `burrows.json` (`size_m` as [x, y, z] in Blender axes, plus
an `origin` field; `extra_colours` holds the hex values of the colours not in `art/palette.json`, for placeholders).
Contact sheets: `art/previews/props/burrows/burrows_contact_sheet_rooms.png`, `..._camp.png`, `tiling_game.png`,
`tiling_34.png`. Positions are Blender coordinates; in Godot, Blender (x, y, z) is (x, z, -y).
- Parts are modelled in their SHOWN state; the code moves them away:
  - `burrow_door` `gate`: modelled closed (z 0 to 2.0); position.y = -2.0 opens it (fully under the floor).
  - `trap_thorns` `spikes`: modelled raised (tips 0.58 m); rest at position.y = -0.5; fire: tween to 0, hold 0.5 s, back.
  - `burrow_hollow` `seal`, `eyes`, `glow`: origins on the ground at the hole centre, except `eyes` (midpoint of the two
    eyes, Blender (0, -0.5, 0.43)). `glow` is the bright amber inner rim: hidden while sealed, shown once open. The
    dark eye sockets stay on the seal. North rim about 0.4 m high; south rim under 0.9 m in the middle.
  - Chest lids (`burrow_chest`, `burrow_chest_boss` `lid`): origin on the hinge at the back top edge; open with
    rotation.x = deg_to_rad(-100).
  - `gloom_seal` shares its origin with `burrow_chest` and fits around it.
  - `root_lift` `basket`: origin on the ground; raise position.y to lift (the vine ropes stay).
  - `spore_vent` `cap`: origin at its base (z 0.04); squash with scale.y.
  - `dew_bud` `petals`: origin at z 0.2; open by scaling to about (1.7, 0.45, 1.7).
  - `acorn_tower_5`: `turret` with `marker_shoot` under it, like the other towers.
- Pickups `mat_amber`, `mat_glowstone`, `mat_heartwood`, `dew_drop`: origin at the CENTRE (like `golden_leaf`).
- `burrow_sign` has an extra `marker_label` at the board's front centre, Blender (0, -0.046, 0.84), for the Label3D.
- Walls: `burrow_wall_1`, `burrow_wall_2` and `burrow_door` share the same 12-point end section at x = +-1.0, so they
  tile in any order; `burrow_wall_low` has its own matching ends. Each wall is one mesh (fine for a MultiMesh). The
  room-side face is at about y = -0.29 at the floor (roots to -0.42); the back at +0.35.
- Sizes slightly off the table: `gloom_seal` 1.25 x 0.96, `burrow_chest` 0.96 wide, the hollow 4.46 x 3.63 x 2.88.
