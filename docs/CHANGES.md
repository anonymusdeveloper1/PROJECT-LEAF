# Project LEAF change log

Each merged branch adds an entry here, newest first.

## 26 Nov 2026 · H4: building windows, part 1 (on `feature/h4-building-windows`, waiting for the owner's phone test)

Built in three stages: `e3fd019` (stage 1: the window kit, bows and buildings as content folders, one window file per
building; nothing visible changed), `63059eb` (stage 2: the new windows and the build menu) and stage 3 (the old tests
moved to the new windows, the stations forwarders deleted, `card.gd` moved to `ui/kit/`, these docs). The branch starts
from `feature/h3-food-bag`, so it merges after H3. Not pushed yet. Backup: `D:\DevCache\backup\pre_h4_2026-11-26`.

- **The Hearthtree window:** tabs at the top (Hearthtree, Cat, Defences); a tab shows once it has something, there is
  no tab bar with one tab, and the window opens on the Hearthtree tab. A tab gets a "!" when something on it can be
  bought (the owner's yes). Mend all, Patch it up and "Nothing for sale yet" stay at the top and Graphics at the
  bottom. Goals have Go or Show buttons.
- **The pinned Upgrade (the owner's Q1 (c) and Q2 (a)):** the Hearthtree, the Training Target, the Bow Shop, the Well,
  the Guardian Stone (awake), the garden, the Market, the Mushroom Cottage and the Saddlery end in an Upgrade that never
  scrolls away. It always opens a confirm window listing what the next level gives; the price is red and Confirm grey
  when you can't pay. Cancel and Confirm go back to the building's window. Buy, Equip and Build stay one tap.
- **The Bow Shop (Q10 (a), Q11):** one row per bow. The bow in the paw shows Upgrade with its price, then a grey
  Equipped when it can't level now; other owned bows show Equip; the rest Buy, or Locked with what they need. A tap on
  a bow's picture opens its inspect view: the bow turning in 3D with its arrow, its numbers and "Each arrow hits for
  N", the real damage with the cat's Damage upgrades and any running potion.
- **The build menu (Q12-Q16):** the build icon next to the Bag opens a grid of building pictures with a Build button
  on each open one, a detail view, and pictures that fade in one after another. Locked ones are greyed with their
  needs. A built building leaves the menu. Nothing can be built while the Hearthtree is in ruins. A dot on the build
  icon replaces the Hearthtree marker's "!" for buildings.
- **Building:** the camera glides to the new building for about 2 s while it rises out of the ground with dust and the
  flower ring. The joystick, a wave or going below ground ends the shot at once.
- **Tips (Q17 (a)):** both building tips say "tap the build icon next to the Bag", with no arrow.
- **Code:** `ui/windows/` (one file per building, the base `building_window.gd`), `ui/kit/` (`card.gd`, `list_row.gd`,
  `confirm_window.gd`, `card_parts.gd`, `icon_grid.gd`, `model_view.gd`), `content/bows/` (6) and
  `content/buildings/` (11). `stations.gd` went from 2,672 to 1,723 lines. List rows show up to 4 lines.
- **Tests:** new `--buildmenu`; `--homegoals`, `--bowshop` (now also `autotest_g3_bow_windows.gd`) and `--cards` (now
  also `autotest_g2_cards_kit.gd`) rewritten; every older mode that read the old cards moved to the new windows. All
  pass on the PC (numbers in `docs/STATUS.md`). `--hudcheck`'s lost-tap flake came from the PC's own mouse moving
  between a test tap's down and up; the test now ignores the PC's mouse, and it passed 6 runs of 6. `--guardian` had
  failed since before H4 because the mission gate refused its mission; the test now opens the gate the way
  `--laststand` does.

## 26 Nov 2026 · H3: food, potions and the Bag (on `feature/h3-food-bag`, waiting for the owner's phone test)

Built in three stages: `f0f181a` (stage 1: timers, the Bag model, crops and recipes, save v4), `09dc171` (stage 2:
potions, the Bag window, the garden and the cooking pot) and stage 3 (the clean-up, two small fixes, these docs). The
branch starts from `feature/h2-hud`, so it merges after H2. Not pushed yet. Backup: `D:\DevCache\backup\pre_h3_2026-11-26`.

- **Real time (the owner's rule change of 25 Nov):** crops grow and the pot cooks by the phone's clock, also while the
  game is closed. Nothing else runs then. If the phone's clock is set back, the jobs wait until it catches up. This is
  one general timer system (`core/timers.gd`, the `Timers` autoload): a later long job is one entry in `balance.json`
  `timers.jobs` and a small handler.
- **The garden:** a window that looks like the bed (plots 3 2 1 over 6 5 4). Drag a seed onto an empty plot and pay on
  the drop. Two new crops, Emberpeppers (20 leaves, 8 min) and Swiftroots (18 leaves, 7 min), beside Sunberries,
  Fernmint and Honeybells (4, 5 and 6 min). Water is free: watered plants grow twice as fast for 5, 6 or 7 min at
  garden level 1, 2 or 3. Tap a ripe plot to pick it into the Bag. The Gloom meter gets +2 once per visit that picks.
- **The cooking pot:** drag or tap ingredients into 3 slots; Cook lights up on an exact recipe; it cooks for 30–60 s in
  real time; Collect puts the result in the Bag. A read-only recipe list sits in the window (the owner's yes). The
  Gloom meter gets +3 on the Cook tap.
- **5 recipes replace the 7 old dishes:** Health Potion (2 Fernmint, 1 honey: heals the cat 40% over 5 s), Mount
  Health Potion (2 Sunberries, 1 honey: brings a knocked-out mount back with full health), Cooked Fish (1 fish: mends
  the mount to full over 10 s), Damage Potion (2 Emberpeppers, 1 honey: arrows +25% for 30 s), Speed Potion (2
  Swiftroots, 1 honey: the cat +25% faster for 20 s). Crops and recipes are content folders (`game/content/crops/`,
  `game/content/recipes/`). Raw fish mends a standing mount by 10%, the Golden Carp by 50%, and Bramble buys the Golden
  Carp for 300 leaves.
- **The Bag:** 24 slots; food, fish, amber, towers and spikes stack to 20; each potion is one stack up to its limit
  (Health Potion 3, Mount Health Potion 3, Cooked Fish 10, Damage Potion 1, Speed Potion 2). Tap a slot for **Use**
  (potions and fish) or **Place** (towers and spikes). A full Bag refuses a
  purchase before you pay; a catch swims away; a ripe crop stays ripe; a potion waits in the pot. Things already paid
  for always go in. Eat, Quick heal, Use auto and the "x/20" pantry are gone.
- **HUD:** the Health Potion button (row 1 right) shows while the cat is hurt and the Bag holds one. The Mount Health
  Potion button takes Ride's place while the mount is knocked out. A line under the currencies shows a running Damage
  or Speed Potion ("Damage +25% · 24 s"; the owner's yes).
- **Gone (the owner's answers):** Feed and its 2 Sunberries (the Mount Health Potion replaces it); eating food below
  ground and the Snack button (only Health Potions heal the cat there); the dishes and their boosts; growing by waves.
- **Placing from the Bag:** towers and spikes go into the Bag when bought. Place closes the Bag and shows the ghost; the
  piece drops in with a bounce and a puff of dust. The ghost is now red by the lake and the home, the same rule as the
  start-up check (the owner's yes).
- **Icons:** stand-ins drawn in code for the five potions (a bottle in each recipe's colour), Emberpeppers and
  Swiftroots (the owner's pick).
- **Save version 4:** the pantry goes into the Bag; an old dish waiting or eaten becomes a Health Potion (up to 3);
  half-grown crops keep their share as timer jobs; old watering is dropped. New fields `bag` and `timers`.
- **Code:** new `core/timers.gd`, `core/bag.gd`, `core/effects.gd`, `parts/effects_holder.gd`,
  `commands/use_potion.gd`, `ui/windows/garden_window.gd`, `ui/windows/cooking_window.gd`, `ui/kit/drag_source.gd`
  and `ui/kit/drop_slot.gd` (the game's first drag-and-drop). `garden.gd`, `cooking.gd` and `inventory.gd` are
  rewritten. Stage 3 removed the legacy names (`Save.pantry`, `snack_choice`, `meal_ready`, `meal_on`, `Data.snack`,
  `set_meal`, `meal_boost`) and the old balance keys (`garden.crops`, `cooking.recipes`, `burrows.lunch`,
  `mount.revive_food` and others), and fixed two review points: a refused Use's reason in the Bag clears once it is no
  longer true, and when a crop ripens and the pot finishes in the same check, one toast says both.
- **Tests (stage 2, PC, 26 Nov):** new `--timers` 29, `--content` 33, `--bag` 109 (also `--inventory`; it runs the
  potions checks too), `--garden` 62, `--cook` 53; `--feed` now runs the potions checks; `--saves` 69, plus
  `--saves --startup=1` then `--startup=2` (a real first launch with a v3 save); `--hudcheck` 128, `--cards` 55,
  `--fightf` 90, `--campg` 58, `--fishing` 9, `--burrowhooks` 9, `--layoutsave=2` 5, `--smoke` OK; no failures except
  the known one below. Stage 3 (new checks for its two fixes): `--bag` 110, `--garden` 63, `--cook` 55, `--smoke`
  OK; `--content`, `--timers`, `--saves` (and `--startup=1/2`), `--fishing`, `--campg`, `--burrowhooks` and
  `--hudcheck` 128 pass after the clean-up.
- **Known:** `--dungeoncareful` loses at the boss in about 2 runs of 3 (it passed 1 of 3). The cat has 14 health: in
  the run it won the boss took 25 health from it, in a run it lost 32, with all 3 Health Potions used both times. Only
  Health Potions heal below ground now, and the careful cat has 3 Health and 3 Mount Health Potions. The owner's call:
  noted, not retuned; expeditions are rebuilt in H8 and balanced in H11. The garden's card scrolls about 150 px at
  540x960 to reach its Upgrade row (the window itself fits); at the phone's shape (480x1040 with safe insets) nothing
  scrolls. Cooked Fish's light orange bottle is close to the Damage Potion's orange.

## 26 Nov 2026 · H2: the new HUD and Settings (on `feature/h2-hud`, waiting for the owner's phone review)

Built in three commits: `c030041` (part 1), `1d0377c` (parts 2, 4 and 5) and `042d78c` (part 3). Not merged yet.

- **The screen** (from the owner's sketch): top-left only the three currencies, always all three, no dark strip (the
  satchel follows them below ground); top-right the Settings gear; top-centre the raid bar with no words and no numbers,
  a thin campfire bar under it in fights, and the words line under that. The boss bar, banners, toasts and status line
  sit under that group and never reach the middle third.
- **Raid bar:** a Raid Mission wave fills with the share beaten (empty between waves); a Random Raid shows the Gloom
  meter, the warning countdown, then the share of the whole attack; the Gloomwood shows its fight pips. It never counts
  enemies left.
- **Bottom:** the Bag, a build icon (it opens the Hearthtree's card at its Buildings shelf) and the snack or potion slot;
  the defence buttons (smaller) above the Bag; Ride/Walk (or Feed) at the right. Place and Done sit centred while
  placing. Start wave is on the signpost's card only. The Bag shows health as bars and packs the currencies under them.
- **Buttons** slide and fade over 0.2 s, and stop taking touches the moment they start to leave.
- **Settings window** (the gear): Graphics Auto, Low, Medium or High, and Sound on or off. Saved in `user://settings.json`
  (`core/settings_file.gd`), apart from the game save, and never written during autotests.
- **Code:** `hud.gd` is split into `game/ui/hud/` (facade plus `top_bar`, `fight_bar`, `messages`, `action_buttons`,
  `card`, `card_signpost`, `shop_tiles`, `hud_icons`, `lifebar`, `threat_arrows`, `health_bars`, `settings_window`,
  `slide`, `hud_layout`, `hud_style`). The HUD listens to Events (`currency_changed`, `fight_progress`, `riding_changed`,
  `mount_down_changed`, `placing_changed`, `area_changed`, `boss_changed`, `campfire_hit`, `wave_ended`, `raid_ended`).
  Ride/Walk sends the Ride command (`commands/ride.gd`). `fight.wave_total()` counts boss summons.
- **Tests:** new `--settings` (40 checks); `--hudcheck` 121 checks (real taps on Ride, the gear, a graphics row, the Bag
  and the build icon; a mission wave, the Last Stand and a raid's attack; the raid bar fills); `--inventory` 56. The old
  `--raidshots` fail ("the Watch card") predates H2.

## 25-26 Nov 2026 · H1 (merged into `development` on 26 Nov)

All four parts of step H1 are committed and merged into `development` (26 Nov 2026, after the owner's phone review).

- **Random Raids (part 1, `8e796fc`):** toppling the leader no longer routs the rest. The raid is held, and pays, only when
  every raider is defeated. If the last 1 to 3 raiders do nothing for `flee_after` (45 s), they walk once to the
  campfire so the raid can end. The leader banner and the signpost card say "defeat every raider to hold the camp".
  Raid Missions are unchanged: their stragglers still flee after 45 quiet seconds.
- **Leaves (part 1):** `kill_leaf_bonus` 1.3 in `balance.json` gives +30% on the leaves defeated enemies drop in
  Raid Missions, Random Raids and the Gloomwood. It applies after `mission.enemy_leaf_mult` 1.5 and never to stolen
  leaves, chests, wave pay or raid pay.
- **The Wishing Well (part 1):**
  - built at Hearthtree 3 (`needs_home` 3; it used to need 4 missions); a save that already has it keeps it;
  - its card has only its Upgrade row, and the card's subtitle shows its rates;
  - it mends 1% / 1.5% / 2.5% of max health a second in waves (it was 0.5 / 1 / 2) and 3 / 6 / 10% between waves
    (unchanged);
  - it also mends the standing Moss Warden; a downed golem gets up by its own rules;
  - a worn Well is still repaired from the signpost's Mend list;
  - Hearthtree 3's goal list no longer asks for the Well; Hearthtree 4 still asks for Well level 2;
  - the new `--homegoals` check makes sure no Hearthtree goal asks for a station that is not open yet.
- **One expedition material, no keys (part 3):**
  - Amber is the only material left. Glowstone and heartwood are gone, and amber pays for nothing: Bramble buys 1 amber
    for 1,000 leaves and 1 Gloom shard (Market, after the missions) and sells no materials.
  - Amber drops (`balance.json` `burrows.amber`; a value is its whole part plus a chance for one more): the boss or end
    chest 1, the Gloom-bound chest 0.5 (breaking the seal doubles it), a Gloomtouched elite's kill 0.1, the Amber Grub
    caught 0.5, a level's first clear 1 (straight into the satchel). Ordinary kills and other chests drop none. A
    knock-out still keeps half the satchel, rounded down.
  - Lucky Paw (the owner, 25 Nov 2026): chests give 50% more leaves and timber (`boons.lucky.chest_mult` 1.5) and never
    more amber. It used to give one more of each material.
  - The Hollow keys are removed everywhere: no key boon at the start of a run, no key row on the way-in card, no key
    from raids, replays or first clears.
  - Every price that asked for materials now asks for leaves (timber is unchanged): the old leaves plus amber x 60,
    glowstone x 120 and heartwood x 400. Hearthtree 6, 7 and 8 are 17,160, 33,480 and 54,400 leaves (110, 150 and 200
    timber); the Foxfire Bow is 5,120; tower level 5 is 5,760.
  - Save version 3 (`core/save_upgrades.gd`): an older save's amber (25 leaves each), glowstone (50), heartwood (150)
    and Hollow keys (150 each, at most 3) turn into leaves, a half-done run's satchel included. The rates are in
    `balance.json` `save_upgrades.to_v3`.
  - Texts: the Bag says amber is "Rare. Bramble buys it at the Market."; the Saddlery tile says "Level 4 opens after
    the Raid Missions" (or "Level 5 ..."); the sealed chest note says "Leaves and timber, maybe amber".
- **Text (part 4, `e296fd1`):** "Burrow" became "expedition" in player-facing text. The Gloomwood and the Old Hollow keep their
  names, and the Gloomwood's grub holes are "The Grubling holes".
- **The architecture's first pieces (part 2, `f96fd95`)** (`docs/ARCHITECTURE.md` part 13, H1):
  - `game/core/events.gd` (autoload, now the first): the signals and who sends them.
  - `game/core/pools.gd` (autoload): pooled arrows, damage numbers and text pop-ups, hit bursts and sprays, and leaf
    and timber pickups. Sizes are in `balance.json` `pools`, per graphics level. Shockwave, swipe, flower_ring and
    bellow share one mesh and one material per colour.
  - The save: `save_upgrades.gd` (versioned; its first step, 2→3, is in part 3 above); `Save.mark_dirty()` and `Save.flush()` (every 10 s while
    dirty, and on pause, background or close); `Save.hold_flush` (no flush during a Raid Mission wave, one at its
    end, which stops leaf farming by force-closing); atomic writes through a `.tmp` file; the `.bak` copy is loaded
    if the main save cannot be read; a backup before an upgrade; `Save.loaded_v`; `Events.currency_changed` and
    `Events.save_loaded`.
  - `Data` reads `game/content/index.json` (empty for now) through `catalog()` and `item()`.
  - New test modes `--pools` and `--saves`. `game/tests/` holds sample saves and is left out of the phone build.
- **Tests brought up to date (no game change):** `--topup` (the Training Target and the Bow Shop at level 5 for the
  4/6/8/9/10 caps, the saddle worn) 23 pass, 0 fail; `--burrowsave` (the first Damage price and the map's fight count
  read from the data) 16 pass; `--raidloss` 14 pass. Several amber and key checks in `--dungeon`, `--burrowfoes`,
  `--burrowhooks`, `--raid` and `--saves` were made exact (a value forced, a saved file read), and `--saves` also loads
  a v3 sample (`game/tests/saves/v3_sample.json`).
- **Speed:** on the PC the camp frame went from 2.2 ms to 1.88 ms and a 17-foe fight from 4.02 ms to 2.94 ms
  (`docs/PERFORMANCE.md`). Phone numbers are still to come.

## Cosmetic skin identity and Meshy references (24 Nov 2026; design only)

- Saved the selected effect-free spectral A-pose, visible tail and matching quiver, then revised it using direct
  renders of the shipping cat to restore the real face, green eyes, markings, ears, hands and paws.
- Archived the three Wispbound/Dawnfire/Starforged concepts, earlier reference views, original inspiration and exact
  generation prompts in `docs/skin_concepts/`. `SKIN_DESIGN_WORKFLOW.md` records full-skin cosmetic direction,
  single-image Meshy 6 input and reuse of the original character meshes for exact identity.
- Recorded that browser automation stopped before Meshy submission. Model generation, final skin integration,
  shaders/effects and quiver implementation remain follow-up work; no new skin is represented as shipped.

## Continuous Random Raids (development working tree, 23 Nov 2026)

- Changed **Random Raids only** into one continuous attack. **Raid Missions keep their existing wave rules.**
  Defend Camp starts the attack once; groups of 1–3 vary their trails across all four approaches without round
  breaks. A seeded roster and existing level increment provide at most 50 enemies, including leader/summons.
- Preserved raid types, leader rout, camp/renown strength scaling, live-enemy limits and final reward formulas.
  The leader arrives last so its death cannot cancel unspawned ordinary arrivals. Loss consolation follows the
  defended proportion. Labels show raiders remaining instead of wave numbers; the start action closes the dialog.
- Individual member IDs and capped boss summons preserve cleared enemies on resume. Old multi-wave saves get
  credit for the cleared portion once. Damage and the used campfire rebuild persist. Completion pays once.
- Added `--assault` (also `--raidsave`) tests for composition, pacing, backpressure, pause/resume, legacy migration,
  summons, loss credit and duplicate rewards. Updated existing Random Raid expectations in campaign/HUD/type tests.
  Smoke, 29 assault, 90 campaign, 16 live-raid and 39 menu checks passed. Ready/combat screenshots checked.
  Backup: `D:\DevCache\backup\pre_random_assault_20261123`.

## Raid Mission swipe fix (development working tree, 23 Nov 2026)

- Fixed the new rounded card panels swallowing touch drags before they reached the scroll container. Backgrounds
  and buttons pass input upward; decorative number badges ignore it. The signpost scrollbar is hidden as requested,
  using the mode that preserves scrolling.
- Added real finger-input regressions for dragging over titles, number badges, locked buttons and card padding,
  scrolling both ways, and dragging from an enabled Start button without launching a fight. A stationary Start tap
  still launches the mission. Previous checks only set the scroll position directly and missed this regression.
- Verification: reproduced the gesture failures before fixing them; smoke and all 39 `--missions` checks passed
  afterward. Phone-proportion screenshots checked with the scrollbar hidden. Balance unchanged.
  Backup: `D:\DevCache\backup\pre_mission_scroll_20261123`.

## Descending Raid Missions and signpost polish (development working tree, 23 Nov 2026)

- Reordered Raid Missions from 15 down to 1 within To finish / Completed. Removed empty groups and shortened
  repeated labels. Each mission has a numbered badge, name, status and one action in a rounded card.
- Added more padding around tabs and rows, staggered fade/settle animations on opening and view changes, and
  tactile button feedback. Unchanged live refreshes keep existing cards and scrolling; content changes still update.
- Applied the roomier card spacing to Random Raids without changing its combat, costs or unlock rules.
- Verification: smoke and `--missions` (30 checks) passed, covering descending order across progression states,
  stable refreshes and existing replay/save protections. Phone-proportion screenshots checked for clipping/spacing.
  Backup: `D:\DevCache\backup\pre_signpost_polish_20261123`.

## Raid Missions catalogue and replays (development working tree, 23 Nov 2026)

- Applied the owner's terminology correction: **Raid Missions** are the existing 15 structured missions;
  **Random Raids** are recurring endgame assaults. The signpost has separate navigation for each.
- Lists all Raid Missions, unfinished and completed. Finished entries show Replay; unfinished entries retain
  sequential unlocking. The Random Raids view unlocks after every unique mission is finished, while the catalogue
  remains available. Home goals, building unlocks and the Hollow entrance use the Raid Mission terminology.
- Enabled replays through the actual progression gate. Existing 50% completion rewards and normal wave/chest pay
  apply; unique completion records and first-clear gifts remain one-time. A saved mission cannot be overwritten
  by starting another entry. Existing campfire, pending-raid and active-fight protections remain.
- Added card navigation to the existing HUD frame, with fixed tab buttons and a scrolling catalogue. Current
  Random Raids retain the Watch controls. Documented the owner's simultaneous four-direction assault and adaptive
  difficulty direction plus proposed Incoming Attack / Camp Readiness / Rewards / Recent Results menu content.
  The combat redesign is future work, not part of this implemented menu/replay update.
- Verification: smoke completed; `--missions` 26 checks and `--homegoals` 48 checks passed. Screenshots cover fresh,
  partly finished, replay and endgame navigation. Backup: `D:\DevCache\backup\pre_mission_menu_20261123`.

## Dungeon and recruitment discussion documented (23 Nov 2026; documentation only)

- Added `DUNGEON_EXPEDITIONS_PLAN.md` covering the agreed direction: ten distinct dungeons as a release target,
  random expeditions, separate difficulty, changing encounters/routes, permanent discoveries and quest-recruited
  companions who join the campfire and can accompany later adventures.
- Recorded victory/death returning to camp with replayable locations, persistent discoveries and completed quest
  steps, existing save/loot foundations, first-prototype suggestions, open decisions and compatibility requirements.
- Distinguished the one currently playable Gloomwood from the developer-only Test Glade and these future features.
  Clarified the older route/resident restrictions for the future design while keeping camp guardians' role separate.
- Linked the plan from `STATUS.md`, `GAME_GUIDE.md`, `DUNGEON_SPEC.md` and `GAME_PLAN.md`. The next discussion is the
  owner's proposed raid changes; no new raid requirements were inferred. No gameplay changes or APK build in this step.

## Acorn Tower crossbows and arrows (development working tree, 23 Nov 2026)

- Added `tower.gd`: independently swivel the crossbow through 360°, pitch toward close or distant foes, hold a target
  until it leaves range, and wait for alignment before release. The foundation stays fixed. Loading, string draw,
  release, recoil and reload follow the existing tier's firing interval. Broken towers hide the arrow and stop;
  repairs restart loading; upgrades replace the whole model and arrow tier.
- Replaced the old homing/spinning acorn in `acorn.gd` with enlarged classic Twig Bow arrows. Straight flight,
  full-length swept collision, a visible trail, one hit and pause/area cleanup. Arrow scale grows 1.6/1.8/2/2.2/2.4×;
  tip/fletching palettes change at every tier, with a soft violet/amber glow at tiers 4/5.
- Increased tier ranges to 5/6/7/8/9 m. Damage remains 8/14/24/36/44; cadence, health, upgrade prices and placement
  limits remain. The shop shows full-circle coverage, damage and range first. Save IDs and ownership are unchanged.
- Finished the existing five tower GLBs: removed the fixed loaded acorn and separated their original bowstrings.
  Original vertex buffers, base meshes, materials, pivots and all other visible parts are preserved. The local
  reproducible pipeline is `art/scripts/defences/split_turrets.py`; geometry audit is in the task's temp directory.
- Verification passed smoke plus 168 checks in `--rows`: repairs and 40 full-circle/range-edge shots, all five arrow tiers,
  loading/recoil, close targets, outside-range refusal, upgrading during reload, breaking/repairing, pause and swept
  collision. Backup: `D:\DevCache\backup\pre_acorn_arrows_20261123`.

## Fire-spitter flame visuals (development working tree, 23 Nov 2026)

- Redesigned the projectile as a round, bright fireball with a wavy orange rim, directional flame tail and sparks.
  `fire_tongue.gdshader` draws animated flame silhouettes on lightweight camera-facing effect quads. Burning enemies
  and impact bursts use these flames too; existing low-poly ember sparks remain.
- Each impact leaves animated ground fire: an irregular glowing scorch, low rising flames and embers. The patch
  extinguishes after 3 seconds, with a 0.8-second fade. A nearby new hit refreshes the patch instead of stacking it.
  `fire_patch.gd` manages its clock, fade, pause and area cleanup; `fire_ground.gdshader` animates ground embers.
- Counts cap at 4 / 6 / 8 patches for Low / Medium / High. Particle counts follow graphics quality. No per-effect
  light, shadow, bitmap asset or new prop/character model is required. Damage, burn duration, upgrades, cadence,
  range and targeting remain unchanged; the ground mark is a visual effect, without an additional damage tick.
- Verification: `--smoke` completed; `--saddlery` covers 110 checks, including real impacts, visible flame components,
  ground placement, 3-second expiry, final fade, pause/resume, nearby refresh, quality caps, Low visuals and area cleanup.
  Screenshots: `D:\DevCache\tmp\leaf_fire_visuals\final`. Backup: `D:\DevCache\backup\pre_fire_visuals_20261123`.

## Manual raid waves and increased supplies (development working tree, 23 Nov 2026)

- Renamed player-facing missions to raids across the signpost, goals, unlock messages and Hollow entrance. Existing
  campaign IDs, `missions_done`, `mission_run` and internal mode names stay intact for save compatibility.
- Every wave requires **Start wave** at the signpost. Removed the campaign's 15-second automatic advance and the
  Gloom Raid's automatic wave starts. Gloom scouting can still reveal trails, but its timer cannot begin combat.
- Doubled the base wave-clear leaf formula (3 + 0.5 × wave → 6 + wave) and timber (1 → 2), before existing campaign
  scaling. Fresh enemy kill drops are 1.5×, rounded; carried stolen leaves are returned once at their original value.
  Gloom Raid waves also pay the base leaf/timber amount. Removed the obsolete early-start timer payment.
- Saved `wave_done` after every cleared campaign wave. App restart resumes the next uncleared wave; a defeat retries
  only the failed wave. A five-wave supply chest keeps its reward and recovery, while numbering continues to 6, 11,
  16 and the final wave. Legacy chapter-only checkpoints load as before. Active dishes survive new wave checkpoints.
- PC checks: `--smoke` completed; `--fightf` passed 90 checks, including real enemy drops, reward accounting, repeated
  callbacks/taps, indefinite waits, save/load, failed-wave retries, 5→6, 19→20, final wins and Gloom Raid resume.
  Backup: `D:\DevCache\backup\pre_manual_raids_20261123`.

## Late bow damage and leaf affordability (development working tree, 23 Nov 2026)

- Bow upgrades reaching levels 6–10 now add 20% of base damage each, replacing 10%. Earlier levels retain the original
  curve; mastery levels 11–12 retain their 10% increment on top of the stronger late levels. All existing purchased
  levels benefit automatically. Level 9 gains 22.2% arrow damage; level 10 gains 26.3%.
- Reduced leaf prices for upgrades reaching levels 6–10 by about 25%, rounded to five leaves. Ember 5→9 now costs
  1,480 leaves instead of 1,976. Early upgrades, crafting, mastery materials and building prices keep their costs.
  The Bow Shop shows the actual damage percentage gained by the next late upgrade alongside its price.
- Affordability audit: first clears of missions 13–14 provide at least 5,773 guaranteed leaves, excluding kills and
  performance/early-wave rewards. A level-4 Bow Shop upgrade plus Ember 5→9 costs 3,480, leaving 2,293 from that income.
  Buying Ember, taking it 1→9 and buying Shop 4 totals 4,964. These are budget examples; prior spending and repairs vary.
- Boss health, attacks and summons are preserved. The suggested post-charge vulnerability window is not included in
  this first test. Validation covers damage boundaries, actual arrow/burn damage, old levels with an empty wallet,
  insufficient leaves, exact-price purchases, bulk upgrades and the pre-final-mission leaf budget.
- PC verification: `--smoke` completed and `--bowshop` passed 77 checks. The Android test APK includes these changes.

## Ember Ranger and slower mounts (development working tree, 23 Nov 2026)

- Renamed Nightfall Ranger to Ember Ranger and recoloured its clothing crimson with warm gold trim and cream lining.
  The shop portrait reflects the new palette. Dusk keeps its teal palette. The price remains 6,000 leaves and the
  legacy `nightfall_ranger` ID keeps ownership and equipped saves intact.
- The atlas edit changes clothing cells only. All 964 non-image GLB buffer views, including geometry, skin weights
  and animation data, are preserved byte for byte. The local palette/recolour scripts live in `art/scripts/cat_skins/`.
- Reduced actual mounted movement speed by 15% at every Market level: 1.5 / 1.65 / 1.8 multipliers become
  1.275 / 1.4025 / 1.53. Walking speed is unchanged. The Market card displays the updated riding bonus.
- PC verification passed smoke and 63 Tailor checks, with standing, running and shooting outfit views. Speed table
  ratios are exactly 85% of the previous values.

## Fire-spitter flame balls (development working tree, 23 Nov 2026)

- Replaced the three-second fire cone with visible flame balls from the attachment's nozzle. Automatic shots follow
  the cat's current shooting interval, including draw upgrades, bow draw speed and food boosts. The attachment has
  its own timer, so skills and their shared gap do not throttle it. After phone feedback, range now matches the cat's
  current arrow range, including bow and range upgrades. It assists the cat's focus or acquires a foe in any direction.
- The existing attachment meshes now have a rotating firing unit on both mounts, with the collar and hangers fixed.
  Geometry, colours and neutral bounds are preserved. The unit tracks targets while the mount follows the joystick,
  retargets when a foe dies or leaves range, and waits for nozzle alignment before firing. Flight lifetime covers the
  full current range. The local export script is `art/scripts/attachments/22_fire_tracking.py`.
- A ball hits the first enemy along its flight and bursts around that enemy. Every foe in the 1.25 m splash receives
  impact damage once; survivors also burn. Level 1 deals 8 impact damage and 8 burn damage per second for 2 s.
  Each upgrade adds 40% of the base to both; level 5 deals 20.8 impact damage and 20.8 burn damage per second.
- Flight uses swept collision, freezes with gameplay, expires on a miss and ends if the active area changes.
  Effects share their meshes/materials, scale particles with quality, and fade their trails after impact.
- Saddlery item descriptions show splash damage, radius, burn and the cat-linked firing pace. Existing owned
  attachments and upgrade levels continue to work. PC verification passed smoke and 94 Saddlery checks, including
  normal/upgraded range limits, target switching, the fixed harness and rear shots while steering left/right on both mounts.

## Mounted torso-only rear-quarter shooting (development working tree, 23 Nov 2026)

- After phone play, the owner requested the original joystick steering and a wider firing angle. The mount faces
  travel and runs forward. The owner's latest adjustment sets a strict 280-degree shooting arc (140 degrees each
  side, an 80-degree rear gap); held targets are released outside it. The Fire-spitter tracks independently.
- The owner requested torso-only animation after testing the full-body pivot. The five mounted shooting loops
  (Front, QuarterLeft/Right and RearLeft/Right) now animate only the spine and its upper-body descendants. The character
  root faces the mount and the procedural seat keeps the hips and bent legs aligned with it throughout aiming.
- Chest rotation is bounded in the authored rear poses. The shoulders, arms and head handle an over-shoulder shot,
  with both wrists repositioned together to keep the bow draw aligned. All poses share the original draw/release clock.
- The mounted animation library is `assets/cat/mounted/shooting.res`; its animation blend filters out the lower body.
  Saddle movement, mount clearance and cloth run afterward. Dismounting resets the fading upper-body layer to its front
  pose as the character root turns toward the target, avoiding a doubled aim turn.
- PC verification passed `--smoke` and 61 `--mountedaim` checks. The focused mode tests real arrows and hits at broad bearings on
  both mounts, torso rotation above a forward-facing root, hips and feet, both outfits with different bows, the rear
  blind spot, left/right steering and forward gait, target reacquisition, Ram direction and dismounting mid-shot.
- Screenshots cover both ends of the wide arc and left/right movement, from the mount and rider viewpoints.
- Built the revised debug APK at `game/build/ProjectLEAF.apk` (42.7 MB) for remote phone testing.

## Supplies inventory (development working tree, 23 Nov 2026)

- Added Bag with a shared grid of square supplies slots, currency icons and counts, and selected-item details.
  A live preview shows the actual cat and her current mount while riding. Food, keys, materials, unplaced defences
  and dishes share the grid. Selecting a material shows At camp and This run counts. Gameplay continues.
- Garden and pot cards show food counts. Recipes show Have and Need, their effects and activation, and replacement
  of an existing waiting dish. All unlocked recipes are actionable in the scrolling card.
- Harvests, fishing catches, cooking and Market trades show actual stock changes and resulting totals.
- The player can choose a dungeon quick-heal food or Auto. The bottom button shows food, quantity and availability.
  Bag Eat and quick heal share validation and cooldown, report actual healing, and save food with healed run health.
- Older saves default to Auto. An unknown saved food choice also defaults to Auto. Live counts update existing
  controls so health changes during combat preserve an in-progress tap.
- PC verification passed `--smoke` and `--inventory` with 53 passes at 480x1040 and simulated S24 safe areas.
  Checks cover real touch input, active enemies with Bag open, stock limits, recipe access, healing, resuming a saved
  run, material settlement, and older saves. Phone verification awaits a connected device.
- The revised debug APK built successfully at `game/build/ProjectLEAF.apk` (42.6 MB).

## feature/g3-g4-bows-saddlery-outfits (merged into development, 23 Nov 2026)

Work from 21–23 Nov 2026 was committed on this branch. The full APK was
installed on the owner's phone at 01:52 on 23 Nov. The save matched its backup.

### Windows tools

- The local `tools/build_apk.ps1` builds the debug APK. It fills blank Java
  and Android SDK paths in Godot's editor settings and signs with the owner's
  debug keystore through environment variables. With `-Install`, it backs up
  the phone save using ADB `run-as` before replacing the APK and compares the
  save hashes afterward. Routine ADB stderr messages no longer stop it.
- The local `.mcp.json` connects the Godot MCP server in `tools/mcp/` to
  Godot 4.7.2. `tools/start_blender_mcp.ps1` opens a separate Blender window
  with a bridge on localhost port 9876. The client `tools/blender_mcp.py`
  sends Blender work to that window.
- Codex CLI made concept images through `tools/gen_concepts.ps1` and helped
  with code review, fixes and docs. In the read-only review and editing
  workflow it returns patches for someone with write access to apply.
- Install check: `D:\DevCache\backup\phone_save_20261123_0152` contains the
  before and after copies of the save with matching hashes.
- `game/project.godot` still selects the mobile renderer. The explicit
  OpenGL fallback setting was removed from the project file.

### Working rules

- The owner makes models in Meshy. Claude may design bows, arrows and mount
  attachments in Blender. For other models Claude finishes the owner's
  meshes and may rebuild broken parts to match the owner's design, as with
  the outfit cloaks and the Tailor's Nook.
- Run Blender headless or use the window the bridge launcher opens. Leave
  the owner's open Blender alone. Agents working side by side stay
  headless. Use Haiku for simple jobs, Sonnet for well-specified work and
  Opus for harder systems and balance. Use Opus or Codex for a final review.
- C: can hold normal caches and temporary files again. The project, builds,
  backups and work files stay on D:. Test runners still put TEMP and TMP
  under `D:\DevCache\tmp` and run one at a time because they share a test save.
- References include `CLAUDE.md`, `docs/ASSET_RULES.md` and
  `docs/AGENT_BRIEF_MESHY.md`.

### Missions without Hearthtree gates

- Win a mission and the next one opens at any Hearthtree level. This fixes
  the mission 11 soft-lock, where the player could be short of the leaves
  for Hearthtree 4 with no mission left to play for more.
- Main files `data.gd` and `fight.gd`. All 15 `missions[].needs_home`
  entries in `balance.json` are 1. Tests `--homegoals` and `--fightf`.

### Five loop fixes

1. A camp fall takes 30% of the leaves gained in the lost chapter, up to the
   leaves on hand. Savings, chests for completed chapters and gains during
   chapter breaks are safe. The chapter's gain survives a restart.
2. Hearthtree levels 2–5 now ask for missions 1, 5, 9 and 12, respectively.
3. A ruined Hearthtree costs 10% of its build and upgrades to repair, with
   a 20-leaf minimum and caps of 900 leaves and 30 timber.
4. A downed tower's Repair badge charges the same leaf price as **Mend the
   defences** for that tower.
5. The Saddlery opens at Hearthtree 2 once mission 8 is won.

- Main files `fight.gd`, `save.gd`, `data.gd`, `stations.gd` and
  `defences.gd`. Balance keys `raid.leaves_share`, `raid.repair_share`,
  `gloom_raids.repair`, `stations.camp.levels[].goals` and
  `stations.saddlery.needs_home`.
- Tests `--fightf`, `--laststand`, `--homegoals`, `--rows`, `--campg`,
  `--saddlery` and `--raidloss`.

### G3 · Bow Shop

The Bow Bench became the Bow Shop. Buy a bow once, upgrade it separately
and equip an owned bow free between waves. The Twig Bow is the original
bow and starts equipped. Thorn Volley and Foxfire are hidden in the shop.

| Bow | Opens at | Leaves / timber | Base damage | What changes |
|---|---|---|---|---|
| Twig | Start | Free | 1.0× | Normal draw and range, plain shots |
| Sunwood Longbow | Bow Shop 2 | 400 / 15 | 1.15× | Pierces one enemy and reaches 1.5 m farther. Draw takes 10% longer. |
| Ember | Bow Shop 3 | 900 / 30 | 1.3× | Burns for 3 s at 25% of the hit's damage each second. Range is 0.8 m shorter. |
| Frost | Bow Shop 5 | 1,600 / 50 | 1.45× | Slows enemies and freezes on the third hit. Draw takes 25% longer. |

- Claude made bow and arrow models in Blender with the owner's approval.
  The shop shows pictures of the bows. Each bow has its own release, trail
  and hit effects, including Sunwood's golden flash, Ember's flames and
  Frost's ice. Owning Frost is a goal for Hearthtree 6.
- Main files `stations.gd`, `player.gd`, `arrow.gd`, `enemy.gd`, `fx.gd`
  and the bow, arrow and shop art under `game/assets/`.
- Balance keys `stations.bench`, `bows` (`craft`, `cost`, `damage`,
  `draw_mult`, `range_bonus`, `fx`, `burn`, `frost`), `cat.min_range_m`
  (2 m) and the Frost goal in `stations.camp.levels`. Tests `--bowshop`
  and `--homegoals`.

### Hearthtree prices

Each upgrade costs more leaves and timber than the last. From level 2
through 8, leaves cost 500, 3,500, 9,000, 10,500, 15,000, 25,000 and 40,000.
Timber costs 20, 40, 60, 80, 110, 150 and 200.

- Main files `balance.json` (`stations.camp.levels`) and `stations.gd`.
  Test `--homegoals`.

### G4 · Saddlery and riding

- Stomp, Ram, Pounce and Bellow are learned at the Saddlery and trigger on
  their own while riding. The old built-in mount moves are now skills.
  Pre-G4 saves with mission 8 won get Stomp 1. The old saddle and bags
  carry over at levels 3 and 5.
- Fire-spitter burns enemies ahead, Mossweave Saddle adds mount health and
  Saddlebags add leaves from kills. Claude made each attachment for both
  mounts. Only the one worn shows and works. Swap it free between waves.
  Thunder Shoes remain a separate Gloomwood item on the Stable card.
- Thistle gains Ram, Pounce and Bellow clips. Bramblewool gains Stomp,
  Pounce and Bellow. The cat sways, bobs and leans with the mount, and
  jolts when it uses a skill. She carries the bow upright, tilted toward
  her, and shoots only ahead. Turn the mount to face enemies behind you.
- The cat leans away and can slide back slightly to reduce overlap with
  the mount's head. The clearance sweep still measured overlap in some
  moves, greatest in Thistle's Bellow (7.1 cm). A thin amber bar under the
  cat's red bar shows the mount's health.
- Main files `mount.gd`, `player.gd`, `ride_motion.gd`, `main.gd`,
  `lifebar.gd`, `stations.gd`, `save.gd` and the models and clip lists
  under `game/assets/companions/`.
- Balance keys `stations.saddlery`, `saddlery`, `mount_skills`,
  `mount_attachments`, `building_hp.saddlery`, and the `mount.aim_cone_*`
  and `mount.ride_*` settings. Tests `--saddlery` (52 passes), the
  `--saddlery --rideclear` sweep and the updated Gloomwood tests.

### The cat's bow carry

- `CatRanger.glb` has updated Idle, Walk, Run and Shoot clips. She carries
  the bow higher, with less bounce while running, and it no longer spins
  after release. `bow_face.gd` rolls her paw in place so the string faces
  her chest on foot and in the saddle. Drawing already faces the string
  toward her. The correction eases off for the fishing rod.
- Main files `game/assets/cat/CatRanger.glb`, `bow_face.gd` and
  `player.gd`. Balance key `cat.bow_face_max_deg`. Checks include
  `--bowshop` and Blender clip and export checks.

### Barricades, defences and the Well

- After mission 1, road pads open as the Hearthtree grows. The four gates
  open at level 1, the four middle pads at 3, the two right far pads at 4,
  and the two left far pads at 5. Fernwood and Bandit Thicket each have
  three evenly spaced pads along the road. The left middle pads sit near
  the bends. Built rows keep their pads and move with the rebuilt roads
  when camp grows. The card explains when Build is unavailable.
- Repair a row at any time. Each broken piece costs 30% of the row's build
  price. For a damaged piece apply its missing share of health to that
  price, with a 50% floor for a cracked piece. Build rows and repair
  towers between waves.
- The Wishing Well mends standing buildings, the fire, barricade pieces
  and towers to full. At Well levels 1–3, it restores 3%, 6% or 10% of
  max health per second between waves and 0.5%, 1% or 2% during a wave.
  Things at zero still need a repair or a mission win. A tower mended to
  full clears its wrecked look.
- Main files `defences.gd`, `world.gd`, `main.gd`, `stations.gd` and
  `hud.gd`. Balance keys `defences.barricade.rings_by_home`, `pad_rule`,
  `repair_share`, `patches[].far_pad`, `patches[].even_barricade_spacing`
  and `well.passive`. Tests `--rows` (94 passes), `--campg` and `--layout`.

### Tailor's Nook and cat outfits · 23 Nov

- Build the Nook at Hearthtree 3 for 1,500 leaves and 40 timber. Original
  Ranger is free, Dusk Ranger costs 3,000 leaves and Nightfall Ranger
  costs 6,000. Outfits change looks only. Wear owned outfits free between
  waves. Each new cloak swings on four cloth bones.
- After the Codex review, the Nook's collision radius is 1.35 m and its
  interaction ring is 1.95 m from its centre. Buildings built during a
  fight get their health immediately. The shop blocks a sale when its
  outfit model is missing, and `hero_clips()` uses the model that loaded
  so a fallback uses the original cat's clips.
- Main files `stations.gd`, `world.gd`, `data.gd`, `save.gd`,
  `player.gd`, `cloth.gd`, `cloth_fit.gd`, `tailors_nook.glb`, and the
  outfit models, clip files and pictures. Balance keys `stations.tailor`,
  `building_hp.tailor` and `cat_skins`. Tests `--tailor` and `--layout`.

### Tests added and updated

- `autotest_g3_bow.gd` (`--bowshop`, 61 passes), `autotest_g4_saddle.gd`
  (`--saddlery`, 52) and `autotest_cat_skins.gd` (`--tailor`, 63) cover
  the shops, gear, effects and outfit swaps.
- `autotest_layout.gd` (`--layout`, 132) checks space and access for the
  new camp buildings. `autotest_g2_def.gd` (`--rows`, 94) checks pads,
  repair costs, repairs in waves and the Well. `autotest_g2_camp.gd`
  and `autotest_g2_cards.gd` cover camp and card changes.
- `autotest_f_home.gd` and `autotest_f_fight.gd` cover mission access,
  goals and chapter loss. `autotest.gd` runs the new modes and updates the
  siege, Last Stand and loss checks. `autotest_e.gd` updates Foxfire and
  the Stable and Saddlery checks. `--smoke` completed.

### Not built yet / open questions

- Earning mount skills in dungeons is an idea for later.
- Add two or three more mission bosses later.
- Paid outfits using premium currency are for a later update.
- Buildings never fade. The cat can disappear from view behind the Nook
  and other buildings. How to handle that is still open.

### Known test failures

- `--topup`: 8 existing failures (15 pass) from older stat, bow, mastery
  and Hearthtree expectations.
- `--raidloss`: 2 existing failures (12 pass) from trying to replay a
  won mission after replays were removed.
