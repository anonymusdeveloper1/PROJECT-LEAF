# Phase A (core rework): working notes and progress

The plan is GAME_PLAN.md section 0. This file is how it is being built, step by step.

## Design decisions for the code

- **Missions** (balance.json `missions`): `lanes`, `strength`, `power` (recommended), 3 `phases` each with `time`
  (s), `every` [start, end] spawn interval (gets faster through the phase), `pool` [[kind, weight]], optional `boss`
  [[kind, count]] spawned at the phase start; `reward` {leaves, timber}; `first` flags to set; `gift` a building
  given on the first win (mission 2 gives the Market Stall = Thistle, mission 3 the Mushroom Cottage = Sprig).
  Enemies get 6% stronger every 30 s of a mission. 10 s breather between phases (sign card: "Go now").
  The last phase ends when its time is up and no enemies are left. Replays give half the reward.
  `Save.missions_done` (ids). `Data.progress()` = missions won. `Save.claimed` stays = lanes whose Gloom lifted
  (the first win on a lane lifts it). Gloom Night and the old stages 5–7 are gone (patches 0–3 stay as the 4 lanes).
- **The camp is not a safe zone during a mission**: enemies walk into it; `world.inside_camp()` is false while a
  mission runs; enemies are no longer pushed out of the firelight.
- **Structures with health**: buildings (home, target, bench, well, cottage, stall) in stations.gd (`hp`), towers and
  barricades in defences.gd, the campfire is `fight.gate_hp`. Enemy priority when not busy with the cat:
  barricade blocking the trail (they bump into it) → tower within 7 m → nearest standing building within 9 m →
  the campfire. A building at 0 is a **ruin** (`Save.ruined`, replaces the old `crusted`): it does nothing until
  repaired. Win → ruins and defences are mended for free. Camp falls → they stay; repair costs 30% of what the
  building cost.
- **Campfire destroyed** → Last Stand (exists). The cat can **rebuild it once per mission**: stand on the ashes 4 s,
  10 timber, a hit cancels; it comes back at 30%. **The camp falls** if the cat dies in the Last Stand or the fire
  falls a second time: -30% unspent leaves, ruins stay, broken defences stay, the campfire is a ruin
  (`Save.fire_ruined`: rebuild it at its ring before the next mission), the mission ends.
- **Defences**: fences removed (refunded as leaves on load). **Barricades** only at 3 fixed road spots per lane
  (trail fractions 0.45 / 0.62 / 0.78), levels log/stone/thorn gate. **Towers** capped by home level
  (2/3/4/5/6), with health. Spikes stay.

## Steps

- [x] 1 balance.json: missions, barricade, tower hp and caps, gating by missions
- [x] 2 save.gd / data.gd
- [x] 3 fight.gd rewrite (missions, phases, rebuild, camp falls)
- [x] 4 world.gd (camp not safe in missions, barricade slots)
- [x] 5 stations.gd (building hp, ruins, repair, sign card, shop, campfire card, gifts)
- [x] 6 defences.gd (fence refund, barricades, tower hp and cap, targets)
- [x] 7 enemy.gd (target structures)
- [x] 8 main.gd / hud.gd (rebuild channel, mission HUD)
- [x] 9 autotest (mission flows) and test
- [x] 10 new enemies' behaviours (stump, pitcher, mole, puffball, crow, stag) with placeholders

## After Phase A (17 Nov 2026)

- [x] looks: Save.mount_look / pet_look, the Stable (Market Stall) and Nest (Mushroom Cottage) rows, mount.gd /
      pet.gd set_look(), Lumi runs on the ground (looks.pet[].flies = false); same numbers for every look
- [x] npc.gd: Bramble the trader stands by the Market Stall (Idle, Wave when the cat comes, Talk at the card)
- [ ] import the 10 agent models as they finish (stump, pitcher, mole, puffball, crow, stag, bramblewool, lumi,
      trader, CatRanger2) and check them in the game
- [ ] switch player.gd to CatRanger2.glb once it is checked (see the cat agent's report for code changes)
- [ ] barricade models in Blender (barricade_log / _stone / _thorn), then Phase B
- [ ] build the APK and install it

## Paused (17 Nov 2026, the user said "stop everything, you will continue later")

The 10 Blender agents were stopped part-way. Their partial work is kept in art/scripts/<group>/<id>/ and
D:\DevCache\tmp\<id>\ (enemies: stump, pitcher, mole, puffball, crow, stag; companions: bramblewool, lumi;
npcs: trader; cat2). Where they were: stag had rig and weights done and was starting the clips; pitcher was starting
the clips; bramblewool was writing its run scripts; mole and trader were on colours; stump was editing; puffball,
crow, lumi and cat2 were early. To continue: restart each from docs/AGENT_BRIEF_MESHY.md with the same model brief,
telling it to reuse what is already in its folders. The game code for all of them is done and tested with stand-ins.
No new APK was built after Phase A.

Resumed later on 17 Nov 2026: all 10 model agents restarted from their folders, plus one agent for the three
barricade props (barricade_log, barricade_stone, barricade_thorn).
Done and tested in the game: bramblewool, lumi (village test, both looks picked), stump, pitcher, puffball, crow,
mole, stag (newfoes2 close-ups and siege), the three barricades (grow test), the trader (village close-up; npc.gd
now runs its spring chains).
CatRanger2 (the Meshy cat) is done and works in the game (vertex colours, bow tint, cloth from CatRanger2_clips.json),
but the game still uses the first cat: balance.json "hero_model" picks "CatRanger" or "CatRanger2" (test flags
--cat1 / --cat2, side by side in art/previews/cat2/ingame_old_vs_new.png). The user picks which one ships.
APK built 17 Nov 17:58 (game/build/ProjectLEAF.apk, 38.6 MB) with every new model; installed on the phone (RFCX2035YHT) later that evening. The user tried CatRanger2 on the phone and picked the
original CatRanger to ship ("hero_model": "CatRanger"). Phone progress was reset (old save backed up in
game/build/phone_save_backup/). Game changes that came with them: the
mount and pet names follow the picked look (Data.mount_name / pet_name, balance looks "short" and "shout"), the
pitcher's thorns leave from mouth_height_m, and the stag's Charge clip is sped to its charge_speed.

Optimized for weaker phones (17 Nov 2026, evening). The changes:
- the woods are drawn in culled 10 m cells;
- the sun casts one orthogonal shadow map;
- graphics levels Low / Medium / High (`Quality` autoload: auto-picked, steps down by itself, "Graphics" row on the
  Shop card);
- a faster cloth fit;
- the OpenGL fallback is on;
- a `--perf` benchmark that runs on the PC and on the phone (via `user://test_args.txt`).

The camp went from 1.77 M to 247 k triangles per frame (High) and 86 k (Low). On the S24 the camp runs at 81 fps
uncapped on High. Details and how to run the benchmark: docs/PERFORMANCE.md.

## A2: missions wave by wave (17 Nov 2026, night)

GAME_PLAN.md section 0 (Draft 7). What changed:
- `fight.gd` runs a mission as 15 waves (missions 1–5) or 20 (6–15) in chapters of 5. The last wave of a chapter is
  an elite wave; the mission's last wave brings its boss. There is a 15 s breather between waves (the signpost's "Go"
  skips it). A chapter break waits for the player, feeds the campfire back to full, pays a chest and saves the run
  (`Save.mission_run`). The campfire can be rebuilt once per chapter. If the camp falls, that chapter starts over.
- balance.json: "mission" holds the rules and the pay (kill_pay, wave bonus, chests, pay_per_mission); each mission
  now has `waves`, `count`, `chapters`, `elite` and `boss`, made from its old 3 phases (backup of the old file:
  D:\DevCache\tmp\balance_before_a2.json).
- The signpost: "Go" between waves and at a chapter break; "Go on" or "Give up this mission" when a run is saved;
  mission rows show the wave count. The other cards only work between waves. Ruins can be repaired between waves.
  The camp is safe (the cat heals there) between waves.
- Tests: the default run plays all of mission 1 and shops at each chapter break. `--resume=1` (with `--fresh`) plays
  to the first chapter break and quits; then `--resume=2` reopens the save, goes on at wave 6, lets the camp fall
  (the run stays at chapter 2), and gives up.

## A3: health bars, and the mount takes hits (17 Nov 2026, night)

- `lifebar.gd` (in the HUD) draws a flat red bar over the cat's head, a little see-through. A hit drains it, and the
  part lost shows grey for 0.35 s before it drains away. While the cat rides, a thinner bar of the same width under it
  shows the mount's health. The row of circles (pips.gd) is gone.
- `mount.gd`: the mount has health (balance.json mount.hp_by_level 6 / 9 / 13 by Market Stall level). While the cat
  rides, hits land on the mount. Knocked out, it throws the cat off and rests 20 s (`rest_s`) before it can be ridden
  again. Not ridden, it gets 1 health back every 2 s, and it is full again after every wave.
- Waves never hang: if a wave's last 3 enemies (no boss) go 45 s without anything happening (no spawn, no kill, no hit
  on a building, a defence, the campfire or the cat), they flee (`flee_after`, `flee_left`).
- Tests: `--bars`.

## B: home levels 4–6 and skins (17 Nov 2026, night)

- Home levels 4–6 (Big Treehouse, Great Tree Home, Tree Hall): balance.json stations.camp.levels, home_names,
  fire_hp_by_camp_level, light_radius_by_camp_level, building_hp.home, defences.tower.max_by_camp_level (5 / 6 / 7).
  `stations.gd` HOME_MODELS / FIRE_MODELS / HOME_FOOT / FIRE_FOOT pick the model and footprint by level (a model not
  made yet falls back to the level before). The home steps further north-west each level (`world.station_pos`).
- New Blender models, made by two agents headless: campfire_hearth / campfire_bonfire / campfire_brazier (camp_hi.json,
  art/scripts/props/camp_hi/) and home_tree_4 / _5 / _6 (home_hi.json, art/scripts/props/home_hi/). Contact sheets in
  art/previews/props/camp_hi/ and home_hi/. The fire's light, embers and smoke now sit on each flame's own height, and
  the flame shader sways by the flame's size. The big homes get a second lamp up high.
- Skins: balance.json looks[].skins and looks[].fur; `vc.gdshader` recolours the look's fur colour family (instance
  `skin`, `skin_from`), keeping creams; Save.mount_skin / pet_skin; a "Colours" row (Next) on the Stable and Nest cards.
- Tests: `--levels`, `--skins`.
- Not done: brazier crystals do not glow (only violet glows in vc.gdshader); ruined looks are still the crystal crust;
  accessories (saddles, crowns) are later; stations stay at level 3.

## Deferred to the end (the user, 17 Nov 2026)

The bug review of today's changes (workflow review-today, stopped by the user part-way; resumable) and the next phone
build/install wait until the plan's phases are built: "you will do that after finishing with everything". Mission 1
and mission 15 both pass with the test cat (15 and 20 waves). Next: Phase C (docs/PHASE_C_SPEC.md), then D and E
(docs/PHASE_D_SPEC.md, docs/PHASE_E_SPEC.md), designed by workflows.

## Phase C: the Moss Warden, the garden, cooking and fishing (18 November 2026)

Built from docs/PHASE_C_SPEC.md, steps C0a to C4b in order (C1a, C5 and C6 were other agents' work; their props and
the Warden's model are in use). Every step was backed up first in D:\DevCache\tmp\phase_c_steps\<step>\ (the whole
project before Phase C: D:\DevCache\backup\pre_phase_c_20261118_0246).

**Changes from the user while it was built** (they override the spec):
- **Food from the start.** The garden and its cooking pot are the gift of mission 1's first win (First Embers), with
  4 Sunberries in the pantry, so the player is never stuck. Old saves that won mission 1 get them on load
  (`stations.catch_up_gifts()`).
- **Feeding the mount.** A mount knocked out in a mission no longer gets up after 20 s: it stays out until the cat
  feeds it or the next chapter break (it is whole again at chapter breaks and when a mission ends, no longer after
  every wave). While it is out the HUD's Ride button is "Feed <name>" with its food (balance.json
  `mount.revive_food`, 2 Sunberries); it works at any time, in a wave too, brings it back whole (hearts and a
  sparkle) and the cat hops on; with too little food it is greyed "No food". Outside missions it still rests 20 s and
  gets up by itself. `main.feed_mount()`, `main.can_feed()`, `mount.out()`; first-time tip `told_feed`.
- **Guardians are found, never bought.** No mission gives the Guardian Stone (bandits.gift is "" again) and no row
  sells or wakes one. Phase E calls `stations.free_guardian()` when the cat frees the Moss Warden in its first Burrow:
  stone level 1, the `warden_awake` flag, it spawns and wakes at its stone, banner "The Moss Warden is free! It will
  guard the camp while you are away." The stone and its ring show only from then. Everything for the Warden itself
  (guardian.gd, its fighting, the enemy hooks, the stone card with its post choice and upgrades, the lifebar, its
  looks and skins, the model) is built and tested.

**What was built**
- C0: the hud wave-lock fix (`_on_save_changed` goes through `_spec`), `stations._locked()`, rows with `"pulse"`,
  `hud.banner_later()` (gift banners), `hud.tip_after()` (a tip that waits for the one on screen), `main.reopen_ring()`,
  `Fx.puff()`, `Fx.hearts()`; the save fields (no timestamps; an eaten dish goes back into the pot on load) and Data
  helpers; balance.json `guardian`, `garden`, `ingredients`, `cooking`, `fishing`, `looks.guardian`, the three
  stations; reserved ground for the stone, garden and fishing spot (hide spots, placed towers and spikes, which are
  refunded once, the lake's rocks and reeds); three-slot skins with `needs_flag`; `catch_up_gifts()`.
- C1: the Guardian Stone east of the camp (runes by level), `guardian.gd` (post, think 4 times a second, punch, slam
  with a daze for small foes, wrecking foes first, the bodyguard reflex, crumble and pull itself together with the
  cat's help, Last Stand by the ashes, home and Sit between missions), the enemy hooks (taunt, structure hits on it,
  slams and bursts, charges blocked), its moss-green bar and regrow arc, the post choice ("Change": guard the camp or
  hold a trail of the coming mission). It walks a grid path (AStarGrid2D over the camp's footprints) to its post and
  home, so it never wedges between the campfire, the pot and the Bow Bench.
- C2: the garden (one step per wave held, two while watered; one merged plant mesh and a glint while ripe), its card
  and actions, the garden path and grass keep-out.
- C3: the cooking pot (one dish waits, eaten when the next chapter starts, used up when the chapter is held, back in
  the pot if the camp falls), 7 recipes (fish ones only once fishing exists, the Feast once a Golden Carp was caught),
  the boosts (cat health, draw, damage, pet/mount/Warden hits, campfire health, the Warden's health and revive), the
  HUD chip, the boss tip.
- C4: fishing at the lake (cast, nibbles, tap on the bite with a white, blue or gold "!", reel in the green, stop by
  dragging or when a wave starts), the rod in the cat's bow paw (worked out on the bone so it points forward and up;
  the bow is hidden meanwhile), catches into the pantry (timber and leaves too), the fish log, the 20-catch pity, the
  three lake treasures in order (Lucky Lure, Silk Line, Lake-moss Charm for the Lakeweed skin), the Fishing Spot as
  mission 6's gift.
- C7 (part): the tips, banners and first-catch moments the spec describes. No sounds were made (`Sfx.play` of a sound
  that does not exist does nothing), no cosmetic pats, no APK.

**Test modes** (autotest.gd; each logs `EXPECT PASS` / `EXPECT FAIL`): `--guardian`, `--guardianab`, `--garden`,
`--cook`, `--fishing`, `--feed`, `--camplife`; `--skins` has a Warden pass (every skin, Lakeweed only with the charm).
Test notes: the Warden needs about 11 m from its stone to the Mossback post, so `--guardian` gives it 14 s (the spec
said 10); `--camplife` allows the pot's footprint to touch the campfire's (the spec puts it on the rim on purpose).

**Final test run** (18 Nov 2026, all with no script errors): `--smoke` (fresh, and three old saves: after mission 1,
a veteran with towers on the new ground, one that missed its gifts), `--village`, `--siege`, `--laststand`, `--bars`,
`--skins`, `--levels`, `--grasswalk`, `--lake`, `--resume=1` then `--resume=2`, and the default run that plays all
15 waves of mission 1 (341 leaves and 15 timber at the end, as before Phase C, plus the garden); the Phase C modes:
`--camplife` 36/36, `--guardian` 31/31, `--garden` 10/10, `--cook` 12/12, `--fishing` 10/10, `--feed` 7/7,
`--guardianab` 2/2 (Mossback Wakes, the cat far away: with the Warden 0 building and campfire damage, 21 kills, 2
waves held; without it 1,850 building damage, the campfire out and 6 ruins). `--perf`: docs/PERFORMANCE.md (the
Warden costs about 0.1 ms in a fight). Logs and shots: D:\DevCache\tmp\phase_c_runs\final\.

**Left for later**
- Sounds (`thud`, `rumble`, `plop`, `splash`, `pluck`, `water`, `sizzle`) in tools/make_sfx.py.
- A balance pass by play (the Warden's share, garden pace, dish strength, fishing feel), and `--perf` on the S24.
- The Warden's cosmetic moments (pats, a flower at chapter breaks).
- The stone card still has its upgrade row (500 / 1,200 leaves + 15 timber): it raises the Warden's stone level, it
  does not buy a guardian. The user may want it gone or moved to Phase E.

## Phase D: the Gloom Raids and keeping the camp up (18 November 2026)

Built from docs/PHASE_D_SPEC.md, steps D1 to D9 in order, then D11 on the PC. Before each step its files were backed up
to D:\DevCache\tmp\phase_d_steps\<step>\. The whole project from before Phase D is in
D:\DevCache\backup\pre_phase_d_20261118_0420. Test runner: D:\DevCache\tmp\phase_d_runs\run.sh `<folder> <args...>`
(it stops early on a parse error).

**What was built**
- D1:
  - the save fields `shards`, `raids`, `wear`, `unlocks`, `fire_look`, `burrow_keys` and `save_v`, with
    `RAIDS_DEFAULT` (plus `last_lost`). There are no times anywhere. A plan of an unknown kind is dropped.
  - `Save.save_game(quiet)`
  - `Data.can_afford` / `pay` with shards, `Data.gr()`, `Data.raids_open()`. `Data.guardian_level()` from Phase C is
    kept.
  - the HUD's shard row (a crystal drawn in code; it counts up as the shard shower lands) and the shard cost icon
  - balance.json `gloom_raids`
- D2:
  - wrecks are saved by reference (`piece.src`, its own `Save.placed` entry)
  - `defences.level()` clamps to the number of levels; a model not made yet falls back a level
  - the endgame mend price, `piece_mend_cost`, `mend_piece`, `lane_guard`
  - the endgame ruin price with its cap; `full_hp`, `reset_hp` with wear, `save_wear`
  - `_repair` clears the wear and gives the building its health back mid-fight
  - `repair_all_free(before)`: a replay after the endgame (`fight._endgame_run`) mends only its own ruins
- D3 and D4: a raid is a mode of fight.gd (`mode`, `raid`, `warning`, `start_raid`, `_raid_wave_cleared`,
  `_raid_over`, `_rout`, seeded `_rand`), and the new `scripts/raids.gd` (`main.raids`) runs the rest:
  - the meter: clamped delta, idle after 45 s, the game opens idle, action points capped at 95, quiet saves every 10
    points
  - the plan at 75% (kind, trails, level, leader, seed), `spec_for`, warnings always 30-60 s, the idle hold, the sneak
    reveal, "10 seconds!"
  - pay: perfect, ready, streak, renown, Burrow keys. A loss pays 2 shards per wave held.
  - `persist()` from `main._notification` (pause, focus out, close), and `restore_on_load()` with the migration of
    old saves
  - the replay bumps, and the intro on the last mission's first win
  - meter hooks for a harvest, a dish and a fish
- D5:
  - the HUD's top right (the meter, idle, Tracker, blocked, the warning countdown) and `hud.point_at`
  - the Watch card (`card_watch`) and the raid card (`card_raid`); `_run_rows` and `_replay_rows` were split out of
    the sign card
  - the signpost becomes `signpost_watch`: its crystal fills, and the flag, the bell and the ribbons show as they are
    earned
- D6: the `ai` key in enemy.gd and the `herald` enemy (the Crow Drummer at 1.25x as its placeholder, drumming), the
  leader banner and boss bar, the rout, and the elite leaders in turn.
- D7:
  - wear: a gloom tint and 1-3 `rubble_pile`s at the building's foot, with a "Patch it up" row on every building card
  - `camp_check`, the camp's condition, "Mend all" / "Mend some" (in priority order, effects staggered across the
    camp)
  - the camp check row at the top of the shop; "Mend the defences"
- D8:
  - defence level 4 (Shardstone), hidden before the endgame and needing home level 4
  - Lookout and Tracker
  - Gloomlit colours on the Stable and Nest cards
  - Shardfire (`flame.gdshader` gets a `tint`; the fire's light turns violet)
  - selling shards to Bramble
- D9: the six props from `raids.json` are used: `signpost_watch` (its earned parts are hidden at load), `gloom_shard`,
  `rubble_pile`, `barricade_shard`, `acorn_tower_4`, `thorn_spikes_4`.
- D11: `--raidperf` on the PC (docs/PERFORMANCE.md), GAME_PLAN.md section 0 and the build order, game/README.md, and
  the `raid` note.
- The six things found while reading were applied:
  - `_veteran` clamps its mission index and sets `src` on its barricades
  - `Data.guardian_level()` is kept
  - the warning also waits while `main.fishing.busy()`
  - the guardian's post and `stations._post_lanes()` use the raid's known trails, and the raid calls the guardian's
    `on_mission_start()` (or `on_raid_start()`, if Phase E adds it)
  - `main.on_stage_end` keeps the guardian, fishing and mount lines for raids and skips only the free mending

**Choices made while building** (small, within the spec):
- The garden grows a step for each raid wave held, as it does for mission waves.
- `since_elite` counts lost raids too, so a lost elite raid can come back.
- The boss bar moved down to y 246, under the new shard row.
- `test_awake` and `manual` in raids.gd are for the tests only.

**Not built**
- D10, the Herald's model: the concept image exists (`concepts/enemies4/01_gloom_herald.png`), and the game waits on
  the user's Meshy model. Then set `"model": "herald"` in balance.json and drop `scale`.
- The balance pass by play on the phone, and `--raidperf` on the S24.
- D12 (the Moth Lantern and Bramble Snare, optional).
- The sounds `raid_horn`, `shard` and `rout`. Stand-ins play until they exist: the horn twice, the pickup sound, the
  win sound.

**What Phase E (the Burrows) needs from the raid code**
- While the cat is in a Burrow, set a property `area` on main (non-null). The meter does not fill, and a pending raid's
  warning waits ("Raid waiting · back to camp"). Clear it on return.
- Call `main.raids.add_gloom("burrow_run")` when a run finishes (15 points; action points never pass 95%).
- `Save.burrow_keys` (0-3): +1 per raid held, +1 more for an elite raid. The Burrows are free, so keys are only a
  bonus.
- Block entering a Burrow while `Save.raids.pending` is true, as missions are blocked, so a raid cannot be dodged.
- The raid's guardian hooks:
  - `main.guardian` is null until it is freed
  - at the warning, raids call `on_raid_start()` if it exists, else `on_mission_start()`
  - at the end, raids call `on_raid_end(won)` if it exists, and `main.on_stage_end` calls `on_mission_end()`
  - the post follows `main.raids.known_lanes()`
  - `Data.guardian_level()` counts in the camp score, so guardians found in the Burrows make raids bigger
- Signals `raids.raid_started(spec)` and `raids.raid_ended(won, perfect)`.
- Defence level 5:
  - append a fifth level to `defences.<type>.levels` (`acorn_tower_5` and `thorn_spikes_5` exist)
  - the shop's defence rows and `_upgrade_defence` already go up to `levels.size()`, priced by `stations._def_cost`
    (leaves + shards)
  - a materials key needs adding to `_def_cost`, `Data.can_afford` / `pay` and `hud._cost_button`
- A Burrows run must leave `fight.mode` at "mission". `fight.start_raid` refuses while any fight is active.

**Final test run** (18 Nov 2026; logs and shots in D:\DevCache\tmp\phase_d_runs\final\). No run had a script error.
- Earlier phases:
  - the default run: all 15 waves of mission 1, ending with 341 leaves and 15 timber, as before
  - `--resume=1` then `--resume=2`, `--laststand`, `--siege`, `--smoke`
  - `--garden` 10/10, `--cook` 12/12, `--feed` 7/7, `--guardian` 31/31, `--skins` 2/2, `--camplife` 36/36
- Phase D modes:
  - `--raid --raid-small` 16/16; `--raid` with full waves 16/16; `--raid --raid-small --with-warden` 18/18
  - `--raidloss` 14/14, `--meter` 14/14, `--raidsave` 15/15
  - `--raidresume=1`, then `=2` 6/6, then `=3` 1/1
  - `--raidtypes` 16/16, `--wear` 10/10, `--shards` 20/20, `--raidintro` 5/5, `--raidshots` 10/10
  - `--raidperf` at Low, Medium and High (docs/PERFORMANCE.md)
- The no-clock grep finds nothing outside autotest.gd.
- `--headless --import` was run after the new script (it made `raids.gd.uid`).
- Two quits in the middle of a raid wave each printed a Godot exit warning (a few objects still in use at exit). Neither
  came back when the runs were repeated, and there was no script error.

## Phase E: the Burrows (18 November 2026)

Built from docs/PHASE_E_SPEC.md, steps E0 to E10 in order, on the PC, following the decisions at the top of the spec
and the user's answers to its section 23 (free, unlimited entry with keys only as a bonus; a knock-out keeps half the
materials; entry blocked only by a pending raid or a fight; the Leaf Dash in the Burrows only; the sealed hollow from
the first mission won; stand-ins for the new creatures; the top upgrades as proposed; a dish goes down with the cat).
Before each step its files were backed up to D:\DevCache\tmp\phase_e_steps\E<n>\ (the whole project from before
Phase E is in D:\DevCache\backup\pre_phase_e_20261118_1526). Test runner: D:\DevCache\tmp\phase_e_runs\run.sh
`<folder> <args...>` (540x960; it stops early on a parse error); the final check is final.sh there.

**The user's change while it was built: one guardian.** Only the Moss Warden, found sealed in Gloom crystals behind
the boss at the end of the first clear of the Old Hollow (the cat fights through the run, beats the boss, stands on the
seal for 3 s: `stations.free_guardian()`). It can never be freed in the first room or by going in, and the Burrows
only open once every mission is won. The guardian code was not generalised (the single `main.guardian` from Phase C
stays, which was the safer choice: it was not started when the change came); no Bramble Boar, Lantern Owl, guardian
spots or choosing at the stone were built. The collection stays in GAME_PLAN.md as "later". Home levels 7 and 8 stay.

**What was built**
- E0: the save fields `mats`, `burrows` (per Burrow: deepest depth, runs, wins, falls, best), `burrow_run`, `attach`
  (no timestamps; old saves load with the defaults); `Data.CURRENCIES` with `have` / `give` / `take`, and `can_afford`
  / `pay` looping over currencies only; `stat_cost`, `stat_top`, `bow_cost`, `bow_top`, `craft_cost`; the `burrows`
  block in balance.json with `list` (the Old Hollow: entrance, path, clearing, five tiers with pools, looks and
  dressing, bosses and the boss cycle, the sealed guardian); `data/burrow_rooms.json` (12 templates) as `Data.rooms`;
  the HUD's cost buttons draw every currency (icons for keys, amber, glowstone and heartwood made in code).
- E1: the Old Hollow at the woods' edge (`scripts/burrow.gd`, `main.burrows`): its model with the seal and the
  blinking eyes, its ring and card (sealed from the first mission won, open, blocked, a run waiting), the reveal after
  the last mission's first win (it waits for the banners; old saves get it once at start) with the key ring filled
  to 3, keys from replays won (`grant_key`; a 4th key is 150 leaves). The clearing (`world.in_hollow_clear`: every
  random number is drawn first, then the tree is skipped, so the seed-2611 woods are unchanged), the path round the
  west of the garden (stamped last; the hide spots use the map without it, so their seeded sequence is unchanged), the
  grass, hide-spot and placed-defence keep-outs (old placed towers and spikes there go back to the bag), the roots.
  Built for any number of Burrows: everything comes from `burrows.list`.
- E2: the area: `scripts/burrow_run.gd` (`main.burrows.runner`, `main.area` while the cat is below ground) and
  `scripts/burrow_room.gd` (one room 400 m from the camp: floor, void, walls and dressing as MultiMeshes, doors with
  gates and signs, pillars, ferns, rings). The hooks: the camera (a room's own focus and distance, `snap_camera`),
  `world.constrain` hands over only for points the area owns, no grass pushers below ground, the fade (`hud.fade`), the
  tier's camera environment and a dimmer sun, the HUD's top right (status, room strip, satchel), the build bar below
  ground (Ride / Walk or Feed, and a Snack).
- E3: monsters below ground (enemy.gd): asleep in dens until the cat comes within 5 m, crosses the wake line or hurts
  one; they hunt the cat (no siege), nowhere to flee, patch 99 with hardened trail guards, a charge or the Gloom Dash
  into a pillar or wall dazes for 2.5 s with a x1.5 weak spot; `fight.spawn` hands summons to the room (its strength,
  at most 4 minions); `area.spawn` (strength by depth and room, damage = the kind's + the depth's), the room clear,
  gates and door rings, the dew bud, the safety net, leaf, material and dew pickups (`pickup.gd` kinds), the knock-out
  (half the satchel). The cat and Sprig leave sleepers further than 5 m alone.
- E4: the run map (seeded; the first run fixed), forks with signs, the treasure room (open, or break the seal: a
  Gloomtouched guard, twice the loot), the spring (drink to full, two boon shrines, a root lift), the elite room, the
  boss den (the boss asleep, the boss chest, the lift and the deeper tunnel), going deeper (+15% when banked), the
  entry lift (back up before the den wakes, nothing lost), boons, `Save.burrow_run` written at every room, when hurt
  (throttled, quiet) and on pause, "Go back in" / "Leave it" on the card, a run from an older room list closed kindly.
- E5: the Leaf Dash (a flick as the finger lifts, Space on a PC): 3 m in 0.22 s, untouchable for 0.32 s, a close call
  makes the next arrow hit double, 1.4 s cooldown with an arc under the health bar; Burrows only.
- E6: `scripts/trap.gd`: rolling logs, thorn plates sweeping north to south, falling crystals near the cat, spore
  vents (slow, no damage), the Gloom tide from depth 3; each glows at least 0.8 s before it strikes and hurts monsters
  too. The gauntlet chest opens only for a cat that was not hurt. Fern patches hide the cat.
- E7: the Grubling (bursts out of the floor), Glowcap (keeps away, lobs spore bombs where the cat is going), Root
  Snapper (never moves, bites along a line) and Amber Grub (runs to the far hole, digs away after 10 s; caught it pays
  leaves and amber), all on tinted stand-ins; Gloomtouched elites and the Thornling Chief boss (its Grublings every
  12 s); Old Grubber's AI (burrow and erupt, roll into pillars, Grublings at 60% and 30%), which runs once its model
  exists (the test runs it on the tinted bear).
- E8: the drop tables (kills, chests, elites, bosses, first clears; boss chests pay shards with Phase D), mastery 11
  and 12 (Damage, Draw speed, Health, Move speed; every bow), the Foxfire Bow, level-5 defences (Heartwood Gate, Amber
  Tower, Amber Thorns; their models exist), the Warden's level 4 (2,500 leaves and 20 timber: guardian upgrades cost
  leaves, the user's rule; amber crystals on the stone mark it), " · have …" notes; home levels 7 and 8 (every table by
  home level extended: fire health, firelight, home health, tower spots, the Warden's power, the home's and campfire's
  footprints, the pot's place; models fall back to level 6's); attachments (3 for the mount, 3 for the pet) on the
  Stable and Nest cards.
- E9: the five tiers' looks (floor, void, fog, ambient light, glow, dressing) and Sprig's lantern halo; `--burrowperf`
  (docs/PERFORMANCE.md, "Phase E").
- E10: Phase C and D hooks: a dish in the pot goes down with the cat (`cooking.eat("run")`, used up at the end, back in
  the pot after a quit), `raids.add_gloom("burrow_run")` when a run ends, Phase D's raid keys through `grant_key`, the
  raid blocker, the meter idle below ground.
- The debug endgame start (`--endgame`, a separate save; see game/README.md).

**Choices made while building**
- A Hollow key is spent (when the card's "Use a Hollow key" is on) for one boon from the start of the run, picked by
  the run's seed. The entry lift gives it back.
- The mount goes down with the cat (the user's decision 3): Ride / Walk and Feed work below ground, a knocked-out mount
  stays out until fed (2 Sunberries) and limps after the cat, its Thump works there, and the dash works while riding.
- The packed lunch is a Snack button below ground: one food from the pantry heals the cat (fish +4, honey +3, golden
  carp +6, herbs +2, Sunberries +2, tried in that order so the mount's berries last), at most every 3 s.
- Attachments: one worn per companion, bought with leaves and materials. Mossweave Saddle (mount health x1.5), Thunder
  Shoes (Thump +60%), Saddlebags (loot x1.25); Glowworm Lantern (traps and spore bombs warn 0.3 s earlier), Ember Charm
  (the pet's sparks +60%), Dew Bell (+2 cat health). Burrows only. **Card-only**: nothing is shown on the models yet.
- Home levels 7 and 8 cost 4,000 leaves, 60 timber, 40 amber, 16 glowstone, 3 heartwood (after depth 2) and 6,000
  leaves, 90 timber, 60 amber, 30 glowstone, 6 heartwood (after depth 3). Fire 2,400 / 3,000, firelight 7.6 / 7.7 m
  (kept inside the stone and the garden), home 3,300 / 4,000 health, 8 / 9 tower spots, the Warden's power 1.9 / 2.05.
  The camp's layout stays level 6's.
- The camera below ground follows the cat along the room (the spec's clamp left the cat under the cards at the north
  end of long rooms): focus between -(l - 3) and -0.5 in room space.
- The run code is two files (`burrow.gd` for the camp side, `burrow_run.gd` for the run) instead of the spec's one.
- After the boss, the lift and the deeper tunnel wait until the Warden's seal is broken, so it is always found; a
  knock-out or "Leave it" after the boss frees it too, and a save whose first depth is cleared without it frees it at
  start (a safety net).
- Old Grubber digs under pillars; the spring room counts as cleared when the cat comes in.
- Fixed in passing: `Fx.wind_aura` no longer captures a node that may be freed (a Gloomtouched monster killed at once
  printed an error).

**Stand-ins** (until the user's Meshy models): Grubling and Amber Grub (the mole, small and tinted), Glowcap (the
brute, small and teal), Root Snapper (the pitcher, tinted bark-green), Old Grubber (Gloomtouched Mossback stands in
at depth 3 and in the deeper cycle); home and campfire 7-8 (level 6's models); the Warden's level-4 heart (an amber
cluster); the dash sound (`pop`).

**Not built**
- E11 needed nothing (the 30 props were made). E12: stand-ins only. E13: the docs; tuning is left to play on the phone.
- The spec's `--burrowperf` target of 80 draw calls on Low is not met in the busiest den on the PC (127; the camp is
  106): see docs/PERFORMANCE.md.

**Test modes** (game/scripts/autotest_e.gd; each logs `EXPECT PASS` / `EXPECT FAIL`): `--burrowsave`, `--hollow`,
`--burrowroom`, `--burrow`, `--burrowfall`, `--burrowresume=1` then `=2`, `--dash`, `--traps`,
`--boss=bear|chief|grubber`, `--burrowfoes`, `--topup`, `--burrowtiers`, `--burrowhooks`, `--burrowperf`.

**Final test run** (18 Nov 2026, 540x960; logs and shots in D:\DevCache\tmp\phase_e_runs\final\). No run had a script
error.
- Earlier phases: the default run (all 15 waves of mission 1, 341 leaves and 15 timber, as before), `--resume=1` then
  `--resume=2`, `--smoke`, `--guardian` 31/31, `--guardianab` 2/2, `--camplife` 36/36, `--levels`, `--skins` 2/2,
  `--raid --raid-small` 16/16, `--raid --raid-small --with-warden` 18/18, `--raidsave` 15/15; after the last small
  change also `--feed` 7/7 and `--cook` 12/12.
- Phase E: `--burrowsave` 14/14, `--hollow` 17/17, `--burrowroom` 11/11, `--burrow` 26/26, `--burrowfall` 6/6,
  `--burrowresume=1` 1/1 then `=2` 6/6, `--dash` 7/7, `--traps` 7/7, `--boss=bear` 5/5, `--boss=chief` 5/5,
  `--boss=grubber` 6/6, `--burrowfoes` 7/7, `--topup` 22/22, `--burrowtiers` 6/6, `--burrowhooks` 11/11,
  `--burrowperf` at Low, Medium and High (docs/PERFORMANCE.md).
- The no-clock grep finds nothing outside autotest.gd. `--headless --import` was run after each new script.
- The debug endgame start was tried on the PC without `--autotest`: the endgame save was made, a second launch kept
  it, `--endgame-off` turned it off, and no real save was made or touched (the test files were removed afterwards).

## Camp layout and HUD (18 Nov 2026)

The user played on the phone (Samsung S24, 1080x2340) and asked for two things, both approved: the camp laid out round
the campfire so nothing hides the cat, and a HUD that keeps the middle of the screen clear. Every changed file was
backed up first to `D:\DevCache\tmp\layout_hud_steps\part1\` and `part2\` (the whole project from before is in
`D:\DevCache\backup\pre_layout_hud_20261118_1739`). Runs and shots: `D:\DevCache\tmp\layout_hud\runs\`.

**The user's change while it was built.** A first plan put the well, the cottage and the stall round the lake (a
lakeside corner). The user replaced it before it was finished: the campfire is the centre of everything with open
ground all round it, the home beside it, the other buildings round the fire and the home, near but a little apart and
not in a ring, each on its own path; the lake stays beside the camp, not in it, and only the Wishing Well goes by the
lake, on its nearest shore. That is what was built.

**The camp** (`world.gd` `SPOTS`, the same at every home level; rings on the camera's side, `SPOT_RING`):
| Building | Where | Its ring |
|---|---|---|
| Training Target | (2.5, -0.5), east of the fire, close | +1.25 m south |
| Bow Bench | (4.5, 0.6), east | +1.05 m south |
| Mushroom Cottage | (6.4, 3.6), south-east | +1.45 m south |
| Market Stall | (3.0, 5.6), south-east, by the Burrow lane | +1.2 m south |
| Wishing Well | (-2.7, 3.9), on the lake's near (east) shore | +1.05 m south |

The home, the campfire, the pot, the signpost, the guardian stone, the garden, the lake and the fishing spot did not
move. Why the east and south-east: the north half is the four trails (at home level 1 their mouths are only 4.45 m
from the fire, so anything tall north of the fire hides a trail's mouth from the camera), the west and north-west are
the home (it grows to a 1.9 m footprint and an 8 m wide tree) and the lake, and the ground straight south of the fire
stays open. A search over the free ground (`D:\DevCache\tmp\layout_hud\camp_search4.py`, with the models' real
heights) found no spot for a tall building anywhere else that holds at all eight home levels. The bench and the target
no longer spread outward with the home (they had: k up to 1.75); they stand still like the rest.

- Paths: a cobbled path from the fire to each building's ring, reaching the ring from the camera's side and passing
  clear of the other rings (`STATION_PATHS`); the stall's branches off the Burrow lane; the well's is a short worn path
  with flat stepping stones (`_stepping_stones`, its own seed 733).
- Nothing hides the cat: `--layout` builds each model's height map and checks every ring, the camp's paths, the trails
  within 14 m, the barricade spots and the trail mouths: no building stands south of any of them closer than its height
  hides (the camera looks down 50 degrees).
- The firelight: at home level 1 (4.0 m) only the target stands inside it; from level 6 (7.5 m) every building does,
  and every ring but the cottage's (8.15 m from the fire: the cottage has to keep clear of the stall's and the bench's
  view lines and of the stone). Nothing about the light changes danger: between waves there are no enemies anywhere,
  and in a wave the light protects nothing and the cards are closed (only the signpost works, as before), so using a
  building never puts the cat at risk. The camera now stays pulled back anywhere within 8 m of the fire when no fight is
  on (`world.camp_view`), so walking to a building outside the light no longer zooms in. Enemies still go for the nearest
  standing building within 9 m, as before.
- Old saves: towers and spikes on the new buildings' ground (built or not, and their rings) go back to the bag on load
  with the note "N defence pieces stood where the camp needs room: place them again"; placing there is refused.
- The seeds: the woods (seed 2611) and the trail edges draw every number and then skip what lands on the buildings'
  ground; the hide spots' loops still test the old village ground and their map still holds the old village lane and
  the bench's and target's old paths (only in `path_img_base`), and the new ground is filtered afterwards. Checked: the
  hide spots' sequence is byte for byte the same as before the change (old and new code side by side, `--levels`).
- Also: the lake's dock always reaches out from the big home's side (it moved with the home level at load before, and
  at level 1 it would have landed on the well); flower beds keep off the buildings.

**The HUD** (`hud.gd`; the user's rule: nothing of the HUD in the middle third of the screen where the cat stands, but
the health bars over the cat and the pointer arrow):
- **The top bar**: one slim row on a soft dark strip (`STRIP`, rounded at the bottom) under the phone's status bar and
  camera hole (`DisplayServer.get_display_safe_area()` on a phone, scaled to the HUD; `--safe-top=N` / `--safe-bottom=N`
  try it on a PC). Left: leaves, timber and shards (32 px icons, 28 px numbers; below ground the satchel's materials
  follow the leaves). Right: the fight's bar (the campfire's health, the raid meter or a raid's countdown, the Burrow's
  room strip; 236 x 30). When there is a status line, a dish or the endgame-save label, the bar grows a second slim line:
  the endgame label and the dish on the left (up to 40% of the width), the status line on the right (18 px, cut with
  "..." if it still does not fit).
- **Just under it**: the boss bar (full width), then the banner as a compact strip (30 px title, 19 px line, about
  2 s; a mission or a raid won or lost is a little bigger, 40 px, and stays about 3.5 s, still at the top), then the
  toast and the status or hiding line ("Rebuilding the campfire...", "Hidden in the grass"). They stack down only as far
  as they are shown; all of it stays in the top third.
- **The bottom**: the buttons (Ride / Feed / Snack, the defences to place, Place / Done) above the gesture bar, with the
  tip (21 px, two lines at most, arrow to its ring as before) and the "Drag anywhere to move" hint as small lines just
  above them. Fishing's "Wait for the bite...", "Tap!" and "Now!" use that line too (`hud.line_y()`).
- **Cards** dock at the bottom as a sheet: the full width less 10 px, above the gesture bar, sliding up. Their rows,
  buttons and scrolling are as before (`_fill_card`; the scroll still caps at 0.52 of the screen). While one is open the
  camera's focus moves toward the camera (`hud.card_lift()`, from the camera's own projection) so the cat stands about a
  third up the clear part between the top bar and the sheet, with its building above it. The bottom buttons sit just
  above a short sheet and hide under a tall one (their top would pass 66% of the screen); the tip and the hint wait the
  same way.
- **Rings** (`ring.gd`, `main._ring_glow`): only rings within 3.2 m of the cat, the one it is walking toward (the
  stick's direction, within 12 m) and the one a tip points at glow; the others ease down to a faint outline (no fill, no
  pulse). Burrow rings share the code.
- **Popups** (`fx.gd`): words and numbers are about 25% smaller and gone in about 0.8 s (words) and 0.5 s (numbers);
  "+N thing" popups of the same thing within 0.6 s and 2.5 m merge ("+3 amber").

**Choices made while building** (within the brief):
- The positions are fixed at every home level (the bench and the target used to spread out with the home).
- The camera stays pulled back within 8 m of the fire when no fight is on, so visiting a building outside the small
  early firelight does not zoom in; nothing else about the light changed.
- The fight's bar sits in the top bar's right side (it is the campfire's bar, the raid meter and countdown and the room
  strip in one), with the status line on the bar's second line; the boss bar sits just under the top bar.
- The toast and the status/hiding line moved to the top, under the banner; tips and the hint to the bottom.
- With a tall card open, the bottom buttons and the tip hide under it rather than float mid-screen; with a short card
  they sit just above it.
- Fishing's bite bubble over the float stays where it was (on the water, like the bars over the cat); its words moved
  to the bottom line.
- The lake's dock is fixed on the big home's side (it used to follow the home level read at start).
- Test runs on this PC use `--disable-vsync`: with the screen off, vsync held Godot at about 4 frames a second and the
  Warden's timed checks failed (the same happened to the old code); with it, 55-60.

**Test modes** (`game/scripts/autotest_layout.gd`; each logs `EXPECT PASS` / `EXPECT FAIL`): `--layout` (74 checks: at
home levels 1-8 with every building built, each building clear of the fire, the clear ground south of it, the lake, the
footprints, the reserved ground, the Burrow's clearing and path, the trails and barricade spots, and hiding nothing;
rings 1.5 m apart; no hide spot on the buildings' ground; the walk from the fire to every ring at levels 1 and 6;
top-down and game-camera shots at every level, the cat at each ring at levels 4 and 6), `--layoutsave=1` then `=2` (5),
`--hudcheck` (65: every card docked, inside the screen, its buttons and texts inside it, the cat in the clear above it,
the bottom buttons off it; the signpost with a saved run, the Watch, a raid's meter, warning and card; placing a tower; a
mission with a boss bar; a Burrow room and the card of every ring on the first run's way to the boss and the lift;
nothing of the HUD in the middle third). The PC's screen is 1080 lines tall, so Windows clamps a 540x1170 window to
540x1061 (a 720x1414 HUD); the phone's exact shape (720x1560, as on the S24) was run at 480x1040 as well.

**Final test run** (18 Nov 2026, with `--disable-vsync`; logs and shots in `D:\DevCache\tmp\layout_hud\runs\final\`,
`final1170\`, `phone\` and `fix\`). No run had a script error; every EXPECT passed.
- The default run: all 15 waves of mission 1, **341 leaves and 15 timber** at the end, as before (the target, now
  east of the fire, changes nothing in that run).
- Earlier phases: `--resume=1` then `=2`, `--smoke`, `--guardian` 31/31, `--guardianab` 2/2, `--camplife` 36/36,
  `--levels`, `--skins` 2/2, `--raid --raid-small` 16/16, `--raid --raid-small --with-warden` 18/18, `--raidsave`
  15/15, `--village`, `--feed` 7/7, `--cook` 12/12, `--garden` 10/10, `--fishing` 10/10, `--raidshots` 10/10, `--meter`
  14/14.
- Phase E: `--burrowsave` 14/14, `--hollow` 17/17, `--burrowroom` 11/11, `--burrow` 26/26, `--burrowfall` 6/6,
  `--burrowresume=1` 1/1 then `=2` 6/6, `--dash` 7/7, `--traps` 7/7, `--boss=bear` 5/5, `--boss=chief` 5/5,
  `--boss=grubber` 6/6, `--burrowfoes` 7/7, `--topup` 22/22, `--burrowtiers` 6/6, `--burrowhooks` 11/11, `--burrowperf
  --quality=low` 1/1.
- New: `--layout` 74/74 at 540x960, at 540x1170 (clamped, above) and at 480x1040; `--layoutsave=1/2` 5/5; `--hudcheck`
  65/65 at 540x960, at 540x1170 and at 480x1040 (both with `--safe-top=73 --safe-bottom=42`, the S24's bars).
- After the last small change (fishing's words take the hint's line) `--smoke`, `--fishing` 10/10 and `--hudcheck`
  65/65 were run again.
- The hide spots' sequence was compared with the old code (`--levels`, same seeds): identical.
- The no-clock grep finds nothing outside autotest.gd. `--headless --import` was run after adding autotest_layout.gd.
- Three runs printed Godot's exit note "N resources still in use at exit" (as in Phases D and E, on other modes); no
  script error.

**Before and after** (the phone's shape, 480x1040): before, old code: `runs\before_phone_camplife\camplife_l4_overview.png`
and `_l6_overview.png`, `runs\before_phone_default\05a_shop_card.png` and `03_wave01_fight.png`,
`runs\before_phone_burrowroom\burrowroom_01_in.png`. After: `runs\phone\layout\layout_l4_camp.png` and
`layout_l6_camp.png` (top-down: `layout_l4_top.png`, `layout_l6_top.png`), `runs\phone\hudcheck\hud_card_shop.png` and
`hud_card_cottage.png`, `hud_mission_boss.png`, `hud_burrow_room.png`.

**Not done**: no APK (the lead builds it); the top bar has not yet been seen under the S24's real status bar and camera
hole (the safe area is read from the phone at run time; tried on the PC with `--safe-top`).

**19 November 2026: the home's one spot, and the lake moved.** After playing this layout on the phone the user asked
for the home to stand in the same place at every level and not so close to the campfire, then for it not to be so
close to the lake. The home is now at `world.HOME_SPOT` (-4.6, 0, 0.25) at every level 1-8: west of the fire, beside
(never on) the WNW trail's mouth, with at least 1.5 m of open ground between its footprint and the fire's. The trails
all come from the north and leave no gap a growing tree fits in, so the lake made room instead: it moved 2.6 m
south-west to (-7.8, 0, 5.0), and the Wishing Well (-4.2, 0, 6.2), its path, the Fishing Spot (-8.7, 0, 7.6) and its
ring, the reserved ground and the dock moved with it. The woods and the hide spots still draw every seeded number with
the old lake and old home spots (`OLD_LAKE_C`, `OLD_HOME`) and then skip what lands on the new ground, so the forest
does not reshuffle. Defence pieces are refused on the home's ground and at the water. `--layout` gained a check per
level: the home at its spot, the fire gap and a water gap of at least 1.5 m, off the trails and barricade spots, and
hiding no ring or path (`_bins`/`_hides_bins` read the model's real surfaces). The spot was searched in a copy
(`D:\DevCache\tmp\homefix`); the lake's final place and the 1.5 m water gap were set by the lead. Backup of the live
files: `D:\DevCache\backup\pre_homefix_20261119_0023`.

## The Gloomwood (dungeon rework, 18 Nov 2026)

The user rejected Phase E's room runs the same evening: a dungeon must be a path the cat walks to a boss, like World of
Warcraft, outdoors at night for the first one, with enemies that sleep in packs and enemies that spawn as the cat
passes, and a boss in a big place (not every dungeon needs a boss). Built from `docs/DUNGEON_SPEC.md` on the PC. Backup
of everything it touched: `D:\DevCache\backup\pre_dungeon_20261118_2003` (scripts, data, docs, GAME_PLAN.md,
game/README.md). Runs and shots: `D:\DevCache\tmp\dungeon\runs\` (runner `D:\DevCache\tmp\dungeon\run.sh <folder>
<args...>`, 480x1040, `--disable-vsync`; `batch.sh <tag> <modes...>` runs a list and writes `<tag>_summary.txt`).

**What was built**
- `game/data/dungeons/old_hollow.json`: the Gloomwood as data. A spine of 26 control points with half-widths (smoothed:
  158 m from the way-in glade to the arena's centre, 144 m to its south edge), six clearings (the way in, the sleeping
  camp, the Glowcap clearing, the Moonwell, the far bank, the old oak), a side branch to the nook, the arena (radius
  11), six fights, three checkpoints, two chests, three log lanes, the stream and the bridge, the gate, five standing
  stones, holes, fern patches, lanterns, glow-cap rings, crystals, props, the woods' seed, fireflies and the theme's
  colours. Positions are `[x, z]`, `{"s": arc length, "off": metres right}` along the path, or `{"in": clearing}`, so a
  stop moves with the path when the path is edited. `test_glade.json` is a tiny map that ends in a treasure (tests).
- `scripts/dungeon_map.gd` (new): builds a map far away at the origin (400, 0, 0). The walkable ground is the union
  of the spine's capsules, the clearings, the branch and the arena (a 6 m lookup grid; far queries use the control
  points' coarse capsules); `constrain` clamps onto it, pushes out of the stones and blocking props, and while the
  arena is sealed its edge is a wall from both sides; fliers may hover 3.5 m off the edge (moths over the stream).
  `steer` sends monsters round the bends (along the path toward the cat, out of the nook by its junction). The look: a
  vertex-coloured ground in 16 m cells (path, moss in the clearings, worn arena ground, mud by the stream, darker
  away from the path), a dark floor beneath, the stream (a vertex-coloured ribbon with glints) and a wooden bridge
  built in code, the woods as MultiMeshes in 14 m cells (trees, bushes, ferns, rocks, logs), lanterns, glow caps,
  crystals, holes and fern patches as MultiMeshes, the arena's five standing stones (code-built, a teal rune) and its
  root gate (code-built arch; its bars rise when the boss fight starts), the dead campfire and other props. Light
  without lights: additive halos over the lanterns, glow caps, crystals and the dead fire's embers, pools of light
  under them, and fireflies drifting and blinking in the vertex shader (three MultiMeshes, one draw call each).
- `scripts/burrow_run.gd` (rewritten): the run on the map. Fights (packs spawn asleep when the cat comes within 28 m,
  wake together inside their wake radius or when one is hit; spawners fire when the cat crosses their line across the
  path), the way home at the way in (before anything wakes), the Gloom-bound chest (open, or break the seal: a
  Gloomtouched guard and two friends, twice the loot), the logs' chest (opens only if the cat crossed the stretch
  unhurt), the Moonwell (spring once, two boon shrines, a root lift with the whole satchel), the checkpoints, the boss
  (spawned asleep at the north side; stepping 1.4 m into the arena seals the roots and wakes it with its bar; when it
  falls the roots open, its helpers vanish, its chest, the lift, and on the first clear the Moss Warden's seal), the
  treasure end, levels, the satchel, boons, saving, the camera, the HUD's status and pips, the night environment, the
  lantern lights on Medium and High, Sprig's lantern glow.
- `scripts/burrow.gd`: the card. "The Old Hollow" (the camp's entrance keeps its name; `entrance.name` in balance.json)
  leads into "The Gloomwood" (the Burrow's `name`; the id stays `old_hollow`, so saves keep their stats). Rows: "The
  Gloomwood · Level N" (Go in; the highest open level), "Play another level" (Lower / Highest, round the open levels),
  the key, the materials, the camp's mending; a saved run: Go back in (level, checkpoint, health, satchel) / Leave it.
- `scripts/trap.gd`: each trap has its own frame on the map (origin and the path's direction), so traps work on any
  bend; a log rolls across the path from side to side (`half` metres each way). Thorns, crystals, spores (now with its
  own vent) and the tide still work, from a map's "traps" list.
- `enemy.gd`: a waking monster wakes its whole fight (`area.wake_pack`), and walking monsters steer round the path's
  bends (`area.steer`, checked 4 times a second). `hud.gd`: one pip per fight and one for the boss (`fight_pips`),
  `card_open()`, `drop_tip_ring()` (a camp tip's arrow lets go when the cat goes in). `world.gd`: `fill_light` (the
  night turns it down). `mount.gd`: the mount's spot beside the cat stays on the path. `data.gd`: `Data.dungeon(map)`,
  `burrow_map_id`, `burrow_end_name`, `burrow_fights`. Shaders: `vc` has a `glow` instance parameter and `vc_multi` a
  night tint (`INSTANCE_CUSTOM.b`) and a shine (`.a`) for bright saturated faces (lantern glass, glow caps, water
  glints); `night_glow.gdshader` (new) draws the halos, pools and fireflies.
- `balance.json` `burrows`: `cam` (path 24, arena 29, lead 2 m, arena bias 35% up to 4 m), `fight_ramp` 0.04, `spawn_r`
  28, `pack_elite_chance_by_level` (0, 0, 35, 50, 65, 80%), `unhurt_share`, the log trap per lane; the tiers keep only
  their pools and elites; `list[0]`: name "The Gloomwood", `map`, `entrance.name`.
- Removed (the rooms): `burrow_room.gd`, `data/burrow_rooms.json`, `Data.rooms`, `room_template`, `depth_rooms`,
  `depth_boss`; forks, doors and signs, the room plan, room templates and pips, the den's late swarm (the spawners
  replace it), going deeper and its +15% chain, the tiers' looks and dressing, the per-depth boss list and cycle, and
  the room-only tests.
- Kept as they were: the Hollow and its reveal, free entry and keys as a start boon, the dash, Gloomtouched elites,
  the Amber Grub, the satchel and knock-out half, boons and attachments, Feed and Snack, a dish going down with the
  cat, the stuck-fight crumble (now per awake fight), the mount and pet, `persist()` and hurt saves, Phase D's hooks.

**Choices made where the spec was silent**
- **Six fights.** The spec's stops hold four (the camp, the holes, the Glowcap clearing, the bridge) but its banner says
  six: two small path packs were added, the bramble bend (3 at level 1, after the clearing) and the old oak (4, after
  the bridge). The holes are one fight (three spawners, 2 Grublings each), the bridge one (its pack and the moths).
- **First run ever, level 1** (fixed): the camp 4 Thornlings and a Glowcap; the holes 3 x 2 Grublings; the clearing
  2 Glowcaps, 2 Thornlings, a Grubling and a Boar; the bend 2 Thornlings and a Boar; the bridge a Gloomtouched
  Thornling Chief and 2 Thornlings, and 2 moths; the oak a Boar, 2 Thornlings and a Mole. The bridge always has its
  Gloomtouched elite (its stop says so); other packs get one only from level 2.
- **Levels:** packs are `base + per_level x (level - 1)`, at most `max_alive_by_quality` (8 on Low, 10); from level 2
  an elite from the tier's list (Gloomtouched) replaces one member by chance, and each pack's snapper spots hold a
  Root Snapper by chance (50-80%); spawners send `count + per_level x (level - 1)`; monsters get 4% more health per
  fight along the path; the boss is Mossback at every level with `hp_mult` 1.0 (3,000 health at level 1, then 3,750,
  4,500, 5,400 and 6,300), Gloomtouched from level 4. No "go deeper": the next level is picked on the card.
- **Checkpoints:** fights won before the checkpoint stay won; every fight after it is full again (won or not); chests
  opened, the spring drunk and the boon taken stay so (nothing to farm). Back in at the way in with nothing won and an
  empty satchel, the way home opens again.
- **Moths** fly in from four spots 6.5 m off the bridge (over the stream), the elite's pack wakes when the cat is half
  way over. **Holes** fire when the cat comes within 0.8 m of a line across the path at the hole.
- **The arena gate** is a code-built root arch with rising bars (the `burrow_door` prop was tried first: its wall-slot
  ends and dark tunnel did not suit an open wood). Its bars close behind the cat; the arena's edge is a wall from both
  sides while sealed. A pack still awake outside stays outside.
- **The camera rule** (nothing tall on the camera's side of walkable ground): every candidate is drawn from the seeded
  sequence; a tree, bush, big rock or log is placed only if the ground up to `cr + 0.84 h` north of it (across its top
  radius) is not walkable, else something lower is tried (in the end a fern). Glow caps on the arena's south rim shrink
  until they hide nothing. The result: low ferns and bushes beside the path, trees from about 3 m out.
- **Camera:** the camp's focus while a card is docked (the HUD's card lift works from it), so a card in the arena also
  brings the distance back to 24.
- **The night on Low:** the moon is the sun at energy 0.7 in a blue (#A9C0FF) with blue ambient light (#6A7FC0, 0.85),
  a thin fog; the woods are darkened and cooled in the shader. Ground colours were brightened twice after looking at
  Low shots, so the path, the cat and the monsters read.
- **Speed:** the map is built the first time the cat goes in (about 0.45 s on the PC, behind the fade), then kept
  hidden 400 m away and reused (a new graphics level rebuilds it). Packs spawn only near the cat; bypassed sleepers stay
  asleep. The boss's adds count only awake monsters toward the cap (sleepers far back on the path no longer block
  them: found by `--boss`).

**Numbers** (PC, RTX 3070, 480x1040)
- The map: 158 m of path from the way-in glade to the arena's centre (144 m to its south edge), 134 walkable shapes,
  24 lanterns, 726 tall woods instances checked against the camera rule (none hides walkable ground). Built in about
  0.47-0.51 s the first time (behind the fade), instant after.
- The walk at level 1 (`--dungeon`, the test cat is a mission-15 veteran standing still and shooting, invincible; a
  player dodges, so a real run is longer): the camp 2.5 s, the holes 0.75 s each, the nook's guard 10 s, the Glowcap
  clearing 6 s, the bend 3 s, the bridge's moths 12 s and its pack, the oak 5 s; Mossback (3,000 health) 36 s with
  the key's boon and 44-47 s without one (`--boss`): at about 60% of the time shooting, as Phase E assumed for a
  dodging player, that is 60-75 s. The whole test run, from the camp back to the camp, 3 min 12 s.
- Graphics Low (`--dungeonperf`, see docs/PERFORMANCE.md): the way in 107 draw calls, a full pack fight 145, the arena
  118, against the camp's 120.

**Tests** (`game/scripts/autotest_e.gd`; each logs `EXPECT PASS` / `EXPECT FAIL`): `--dungeon`, `--dungeonshots`
(with `--quality=low` and `high`), `--dungeonfall`, `--dungeonresume=1` then `=2`, `--boss`, `--dungeonperf`,
`--dungeontreasure`, `--dungeonlevels`, and from Phase E `--burrowsave`, `--hollow`, `--dash`, `--traps`,
`--burrowfoes`, `--topup`, `--burrowhooks`. Dropped with the rooms: `--burrowroom`, `--burrow`, `--burrowfall`,
`--burrowresume`, `--boss=bear|chief|grubber` (now runs `--boss`), `--burrowtiers`, `--burrowperf`. `--hudcheck`
(autotest_layout.gd) now walks the Gloomwood's rings and the arena instead of a room.

**Final test run** (18 Nov 2026, 480x1040, `--disable-vsync`; logs and shots in `D:\DevCache\tmp\dungeon\runs\final\`
and `final2\` (after the last change, the scatter merged per kind in 14 m cells). No run had a script error.
- The Gloomwood: `--dungeon` 42/42, `--dungeonshots --quality=low` and `--quality=high` (no errors; shots), `--dungeonfall`
  7/7, `--dungeonresume=1` 3/3 then `=2` 10/10, `--boss` 11/11, `--dungeonperf --quality=low` 1/1 (before the scatter
  merge the pack fight was 154 draw calls, 1.28x the camp, and failed the 1.25x check), `--dungeontreasure` 5/5,
  `--dungeonlevels` 16/16.
- Kept from Phase E: `--traps` 8/8, `--burrowfoes` 7/7, `--dash` 7/7, `--hollow` 19/19, `--burrowsave` 16/16, `--topup`
  22/22, `--burrowhooks` 11/11.
- Earlier phases: the default run (all 15 waves of mission 1, 341 leaves and 15 timber, as before), `--smoke`,
  `--resume=1` then `=2`, `--guardian` 31/31, `--raid --raid-small` 16/16, `--hudcheck` 55/55 (fewer rings than the old
  room run), `--layout` 74/74.
- The no-clock grep finds nothing outside autotest.gd. `--headless --import` was run after the new scripts.

**Best shots** (480x1040, High on the PC): `runs\final2\dungeon\dungeon_01_wayin.png`, `dungeon_03_camp_fight.png`,
`dungeon_04_holes.png`, `dungeon_09_moonwell.png`, `dungeon_12_bridge.png`, `dungeon_15_boss_fight.png`,
`dungeon_16_seal.png`; on Low: `runs\final2\shots_low\dshot_low_*.png` (every stop, the map from above).

**Not done:** no APK (the lead builds it); not played on the phone yet; the root gate and standing stones are built in
code (no Blender models were needed); Old Grubber's AI is no longer used by any level (kept for a later dungeon).

### Night road and harder (19 Nov 2026)

From the user's phone play ("the floor is weird... a nightly road"; "make the dungeon quite a lot harder") and refs 1-5
(private, in `concepts/dungeon_refs/`). Backup: `D:\DevCache\backup\pre_dungeon2_20261119_0053`; runs in `D:\DevCache\tmp\dungeon2\runs\`.
- **Floor** (`scripts/night_floor.gd`, `shaders/night_ground.gdshader(inc)`, `_lite` on Low; the map's `floor` block): one plane drawn from a ground map, a light map (lantern and torch pools baked in, so Low shows them; the woods' shade) and a style map (road sections: flagstones, worn, cobbles, bricks, moss near the Moonwell; planks at the bridge). Slate stone, dark green, orange light as the one accent; puddles with a moonlit sheen; torches, stone lanterns, barrels, relics, roots, grass tufts, big leaves; props near a light tinted warm. Arena like ref 5: pale flagstones, a ring disc with a carved sigil, a few ember cracks, rune stones (low ones in the south half), giant swords on the north and side rim.
- **Perf, Low** (`--dungeonperf`, draw calls / frame ms): way in 107.4 / 1.65 before, 103.6 / 1.48 after; pack fight 149.8 / 2.38 before, 144.0 / 1.93 after; arena 115.7 / 1.75 before, 112.1 / 1.68 after (measured before the arena rim and the last light pass). Map build 0.46 s before, about 0.76 s after.
- **Harder** (balance.json `burrows`, the map's fights and `end.mods`, `enemy.gd` boss mods): strength 2.0 to 3.0 at level 1 (then 3.7, 4.4, 5.2, 6.0), +1 damage from level 1, fight ramp 4% to 6%, bigger first-run packs, Gloomtouched elites in the clearing and at the oak, three ambushes, wake radius 5 to 6.5 m, packs within 16 m pull each other, the spring heals 40%, dew drops halved, buds on half the won fights. Mossback: 9,900 health (was 3,000), slam x2, 4 adds a roar every 11 s (up to 6), an enrage below 35% (faster, shorter cooldowns, a second wider slam ring, Gloomtouched adds). Pay +25%.
- **Measured** (the endgame save's cat, arrow 48.7, 14 health; `--dungeonstand`, `=god`, `=items`, `--dungeoncareful`): standing and shooting it is knocked out just after the Glowcap clearing (it loses camp 2, holes 2, clearing and bend 11); with 1,000 extra health it loses camp 2, clearing and bend 22, bridge and oak 61, the gate's ambush 2, Mossback 109 (196 in all) and Mossback falls in 69 s standing (enraged at 48 s); riding Thistle with lunches but not dodging it falls 6 s into Mossback (Thistle lost 65 over 4 feeds); played carefully (dashes, mount, lunches) it wins, Mossback in 64 s at 7,650 health. Before (estimated from its damage, not measured): the same cat beat Mossback (3,000) in about 20 s. Tests (19 Nov, last run, 0 SCRIPT ERROR): `--smoke` done, `--dungeon` 44/44 (Mossback 80 s), `--boss` 12/12 (100 s, enraged), `--dungeonstand` 1/1. Not run this time: the full regression list, `--dungeonperf` after the arena and light changes, `--dungeonresume` (its last run clashed with another run on the same save).

## Tap to open (19 Nov 2026)

The user, after playing on the phone: the cards must not pop up when the cat steps on a ring; the player taps instead,
and the rings should look different ("get creative"). Then the cards too: "open like a whole UI, but not full screen...
a close button... click away to close it". Then the arrows: show where an attack comes from. Built in a private copy
(`D:\DevCache\tmp\interact\game`) while the Gloomwood was reworked here, delivered as
`D:\DevCache\tmp\interact\interactpatch.py` (exact pairs, new files in `patch_files\`) and applied to the live files.
Backup of the touched live files: `D:\DevCache\backup\pre_tap_20261119_0937`.

- **Markers, no ground rings** (`scripts/marker.gd`, which replaces `ring.gd` and `shaders/ring.gdshader`). A small
  leaf-topped pin badge floats over each usable thing, with an icon drawn from SVG in code: a bag (the shop, over the
  home's counter), target, bow, bucket, mushroom house, stall, flag (the signpost), stone, sprout, pot, fish, flame (the
  ashes), hollow; below ground a house (the way home), chest, leaf (the shrines), up arrow (the lifts) and crystal (the
  seal). It keeps the old ring's colour.
  - Far away it is small and dim; within 3.2 m (or where the cat is heading, or what a tip points at) it is full size.
  - In reach it grows, glows, sends out a "tap" ripple, and the thing gets a rim glow (`shaders/marker_rim.gdshader`,
    an overlay on its own meshes).
  - A "!" replaces the old pulse, and a badge fades while it would cover the cat.
- **Taps** (`scripts/interact.gd`). Walking near opens nothing. A tap (shorter than 0.35 s, moving less than 26 HUD px,
  so never the end of a drag) on a badge or on the thing opens its card within reach (the old ring's radius + 0.65 m,
  from the old ring's spot). Further away the cat walks there (`joystick.auto`) and the card opens on arrival; a finger
  on the ground stops the walk.
  - Still walk-in: the spring, traps, dew buds, the unhurt and end chests, the ashes, the dash, and the Training
    Target's practice spot.
  - The Gloom seal breaks after a tap while the cat stays close.
  - Texts now say "tap"; the hint reads "Drag anywhere to move · tap things to use them".
- **Cards are dialogs** (`hud.gd`).
  - 90% of the width, at most 80% of the height between the phone's bars (scrolling inside), in the middle, over a soft
    dim of the game. The game keeps running.
  - A wooden header with the name and its line, and a round X (68 HUD px).
  - The X, a tap on the dim, Android's back button or Escape close it; a drag on the dim moves nothing. The camera no
    longer lifts the cat (`card_lift` is gone).
- **Where an attack comes from** (`scripts/threat_arrows.gd`). Small orange arrows at the screen's edge point toward
  foes off the screen, one per direction (eight sectors round the cat). They show during a wave or a raid, and below
  ground for awake foes; they fade when there are none. An arrow pulses when the fire or a building was just hit from
  its side. The foes are read every 0.15 s.
- **Tests.** Every card test now taps through real touches (`autotest.gd` `_tap`, `_use`, `_at_ring`, `_tap_close`,
  `_tap_outside`).
  - `--layout`: no two badges overlap on the screen, none covers the cat at a marker's spot, and a tap from a few
    metres walks the cat there.
  - `--hudcheck`: every dialog fits inside the bars with its X, and each closes by its X, a tap outside, or back.
  - New: `--taps` and `--arrows`.
- **Results.**
  - Private copy (480x1040, 0 script errors, no tap fell back): `--layout` 118, `--layoutsave` 5, `--hudcheck` 76,
    `--taps` 22, `--arrows` 3, the default run 341 leaves / 15 timber, `--guardian` 31, `--camplife` 36, `--fishing`
    10, `--cook` 12, `--garden` 10, `--feed` 7, `--raid --raid-small` 16, `--raidshots` 10, `--hollow` 19,
    `--dungeon` 43, `--boss` 11, `--burrowhooks` 11, `--dash` 7.
  - Live, after the patch: `--smoke`, `--arrows` 3/3, `--hudcheck --safe-top=73 --safe-bottom=42` 76/76, `--dungeon`
    45/45 (with the dungeon agent's new checks); 0 script errors.
  - Shots: `D:\DevCache\tmp\interact\runs\live\` and `runs\dev\taps\`.
