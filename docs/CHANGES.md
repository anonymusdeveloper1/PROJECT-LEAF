# Project LEAF change log

Each merged branch adds an entry here, newest first.

## 25 Nov 2026 · H1 (in progress), on `feature/h1-quick-fixes`

Parts 1, 2 and 4 of step H1 are built. Part 3 (amber as the one sell-only material, no Hollow keys, the old-save
conversion) is not done yet.

- **Random Raids (part 1):** toppling the leader no longer routs the rest. The raid is held, and pays, only when
  every raider is defeated. If the last 1 to 3 raiders do nothing for `flee_after` (45 s), they walk once to the
  campfire so the raid can end. The leader banner and the signpost card say "defeat every raider to hold the camp".
  Raid Missions are unchanged: their stragglers still flee after 45 quiet seconds.
- **Leaves (part 2):** `kill_leaf_bonus` 1.3 in `balance.json` gives +30% on the leaves defeated enemies drop in
  Raid Missions, Random Raids and the Gloomwood. It applies after `mission.enemy_leaf_mult` 1.5 and never to stolen
  leaves, chests, wave pay or raid pay.
- **The Wishing Well:**
  - built at Hearthtree 3 (`needs_home` 3; it used to need 4 missions); a save that already has it keeps it;
  - its card has only its Upgrade row, and the card's subtitle shows its rates;
  - it mends 1% / 1.5% / 2.5% of max health a second in waves (it was 0.5 / 1 / 2) and 3 / 6 / 10% between waves
    (unchanged);
  - it also mends the standing Moss Warden; a downed golem gets up by its own rules;
  - a worn Well is still repaired from the signpost's Mend list;
  - Hearthtree 3's goal list no longer asks for the Well; Hearthtree 4 still asks for Well level 2;
  - the new `--homegoals` check makes sure no Hearthtree goal asks for a station that is not open yet.
- **Text (part 4):** "Burrow" became "expedition" in player-facing text. The Gloomwood and the Old Hollow keep their
  names, and the Gloomwood's grub holes are "The Grubling holes".
- **The architecture's first pieces** (`docs/ARCHITECTURE.md` part 13, H1):
  - `game/core/events.gd` (autoload, now the first): the signals and who sends them.
  - `game/core/pools.gd` (autoload): pooled arrows, damage numbers and text pop-ups, hit bursts and sprays, and leaf
    and timber pickups. Sizes are in `balance.json` `pools`, per graphics level. Shockwave, swipe, flower_ring and
    bellow share one mesh and one material per colour.
  - The save: `save_upgrades.gd` (versioned, no step yet); `Save.mark_dirty()` and `Save.flush()` (every 10 s while
    dirty, and on pause, background or close); `Save.hold_flush` (no flush during a Raid Mission wave, one at its
    end, which stops leaf farming by force-closing); atomic writes through a `.tmp` file; the `.bak` copy is loaded
    if the main save cannot be read; a backup before an upgrade; `Save.loaded_v`; `Events.currency_changed` and
    `Events.save_loaded`.
  - `Data` reads `game/content/index.json` (empty for now) through `catalog()` and `item()`.
  - New test modes `--pools` and `--saves`. `game/tests/` holds sample saves and is left out of the phone build.
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
