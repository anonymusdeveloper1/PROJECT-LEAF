# Project LEAF: where we are (25 November 2026)

**The full description of the game as it is now: `docs/GAME_GUIDE.md`.**

**25 Nov 2026 · Phase H started.** The owner approved `docs/PHASE_H_PLAN.md` (version 1.2) and the architecture in
`docs/ARCHITECTURE.md`. The four rule changes are now in `CLAUDE.md` and `docs/GAME_GUIDE.md`:
- only timers keep running while the game is closed (from H3);
- purple shards are the paid currency and buy looks only, and Bramble never buys shards;
- the Mushroom Cottage leaves the camp (H5);
- numbers live in `game/data/` and `game/content/`.

**H0:**
- Concepts are made and reviewed, in `concepts/h_*`.
- The owner picked the Hollow Jailer as the intro boss.
- The owner's ten Meshy models are in `art/source/meshy/phase_h/`.

**H1** is being built on `feature/h1-quick-fixes`. The work is done by agents as `docs/PHASE_H_PLAN.md` Part F sets out.
- **Done (25 Nov 2026):**
  - Random Raids are held only when every raider is defeated (part 1);
  - +30% leaves from defeated enemies, and the Wishing Well at Hearthtree 3 with faster healing in waves (part 2);
  - "Burrow" became "expedition" in the text (part 4);
  - the architecture's first pieces: Events, Pools, the safer save, `content/index.json`, and the `--pools` and
    `--saves` tests;
  - PC speed: camp 2.2 to 1.88 ms, fight 4.02 to 2.94 ms.
- **Next:** part 3 (amber as the one sell-only material, no Hollow keys, the old-save conversion). Then the docs, the
  APK on the phone and the owner's review. Phone speed numbers come with the APK.

**24 Nov 2026 · Skin concepts and identity workflow saved.** See
[`SKIN_DESIGN_WORKFLOW.md`](SKIN_DESIGN_WORKFLOW.md) for the latest spectral reference, three alternative skin
concepts, exact image-generation prompts and direct renders of the shipping cat. The latest image restores the
actual green eyes, angular muzzle, ear tufts, hands/paws and striped tail. Preserve the original character meshes
when fitting clothing for an exact final identity match. These are design references only: Meshy generation was
stopped by the computer-use URL safety check before submission. The new skin, effects and matching quiver remain
authorized follow-up work; no new model has been generated or installed. The owner requested saving the session
on GitHub's `development` branch, including the curated concept references under `docs/skin_concepts/`.

**23 Nov 2026 · Random Raids are one continuous assault.** Only **Random Raids** changed; Raid Missions retain
their 15/20 manually started waves, checkpoints and progression. Defend Camp starts one attack, with a seeded roster
of 36–46 plus the existing level increment, capped at 50 including its leader and any boss summons. Groups of 1–3
arrive across shuffled rotations of all four trails, 0.22 seconds apart within groups and 1.1–2 seconds between
groups. Existing live-enemy caps prevent crowd spikes without creating round breaks. The leader arrives last and
retains its rout. One victory pays one completion reward; partial defence still earns consolation. Defeated member
IDs, summoned reinforcements and damage survive save/resume. Old cleared waves reduce the remaining roster once.
Existing camp/renown strength scaling remains; expanded player-power scaling and recruited companions are future
work. Checks passed: smoke, 29 `--assault`, 90 `--fightf`, 16 live-raid and 39 mission-menu checks. Ready/combat
screenshots were visually checked; phone performance still needs owner testing.

**23 Nov 2026 · Raid Mission touch scrolling fixed.** The new card backgrounds were intercepting swipe input.
Card panels and action buttons now pass drags to the scroll container; number badges ignore touch input. Swiping
over text, badges, card padding and locked/enabled buttons scrolls correctly. Dragging over Start cancels its tap;
a deliberate tap still starts the mission. The signpost scrollbar is hidden at the owner's request while swipe
scrolling remains enabled. Smoke and `--missions` (39 checks, including real finger events) passed. The gesture
regressions reproduced the failure before the fix; layout/order, rewards and progression are unchanged.

**23 Nov 2026 · Signpost layout and animation polish.** Raid Missions now descend from **15 to 1**, retaining
To finish / Completed groups. Roomier rounded cards show a number badge, mission name, short status and one action.
Header, tabs and list have more padding; empty groups are hidden. Opening or switching views gently fades and
settles the cards; buttons respond to presses. Unchanged live refreshes retain the cards, scroll and animation state.
Random Raids uses the same spacing. Gameplay, unlocks and rewards are unchanged. Smoke and `--missions` (30 checks)
passed; fresh, partly completed and endgame layouts were visually checked at phone proportions.

**23 Nov 2026 · Raid Missions catalogue and Random Raids navigation.** The owner clarified the names: the 15
structured entries are **Raid Missions**; the recurring endgame attacks are **Random Raids**. The signpost now
lists all Raid Missions under To finish / Completed, marks finished entries and permits Replay. Completed ones
remain playable after the separate Random Raids view unlocks at 15 unique completions. Replays use existing
repeat rewards and do not duplicate gifts/progress. Saved runs are protected from replacement; ashes and pending
raids still block starting another fight. Smoke, `--missions` (26) and `--homegoals` (48) passed.
See [`RAID_MISSIONS_AND_RANDOM_RAIDS_PLAN.md`](RAID_MISSIONS_AND_RANDOM_RAIDS_PLAN.md) for what is built and the
agreed next combat direction: one simultaneous assault from all four directions, adapting to player/camp power,
with guardian and later recruited-friend defence. The subsequent continuous-assault change is described above;
the proposed expanded menu panels and player-power scaling remain future work.

**23 Nov 2026 · dungeon and recruitment direction documented (planning only).** See
[`DUNGEON_EXPEDITIONS_PLAN.md`](DUNGEON_EXPEDITIONS_PLAN.md) for the agreed direction: ten distinct dungeons as a
release target, random expeditions, difficulty separate from location, changing runs, permanent discoveries,
quest-recruited camp companions and replayable locations after a win or death. One playable dungeon exists today,
the Gloomwood; Test Glade is development-only. Buddy roles/counts, quest details, difficulty formulas and death
loot rules remain open. These features are not implemented. The owner's subsequent Raid Missions / Random Raids
requirements and menu discussion are recorded separately in `RAID_MISSIONS_AND_RANDOM_RAIDS_PLAN.md`.

**23 Nov 2026 · Acorn Tower arrows and full-circle aim.** The five existing tower looks now have independently
swivelling and pitching crossbows above fixed foundations. Each visibly loads an enlarged classic Twig Bow arrow,
draws its native bowstring, releases, recoils and reloads. Arrows fly straight with a visible trail and swept
collision. Levels reach 5 / 6 / 7 / 8 / 9 m; damage stays 8 / 14 / 24 / 36 / 44 with the existing cadence/prices.
Arrow size grows 1.6× to 2.4× and tips/fletching progress through leaf/silver, pale blue, gold, violet and amber.
The former baked-in acorns were removed and native strings separated; original vertex buffers, tower base meshes,
materials and pivots are preserved. Damaged, broken, repaired and upgraded towers retain their existing rules.
Legacy placed towers and owned levels gain the new behaviour automatically. PC verification passed `--smoke` and
`--rows` (168 checks: defence repair plus all five tower levels, eight bearings each, close/range-edge shots and loading cycles).

**23 Nov 2026 · Fire-spitter flame redesign.** Projectiles have a round, yellow-hot fire core, animated orange flame
tails and flying sparks. Impacts spread a flame burst and a glowing ground scorch with low, flickering flames.
Ground fire lasts 3 seconds after the last nearby impact, fading during the final 0.8 seconds; then flames and mark
are removed. Repeated hits refresh one nearby patch. Graphics levels cap separate patches at 4 / 6 / 8 and scale
particles. Ground effects pause with gameplay and clear on area changes. Burning enemies use the same animated
flame silhouettes. Existing impact/splash damage, enemy burn duration, upgrades, target tracking and range are
preserved; the ground effect is visual and adds no separate damage tick. New shaders and procedural effect quads
use no new character/prop models or textures. Verification uses `--smoke` and `--saddlery` (110 checks).

**23 Nov 2026 · player-started raids and more supplies.** Player-facing missions are now called raids; legacy IDs,
save keys and code names remain compatible. Every wave waits for **Start wave** at the signpost, including Gloom
Raid waves. Waiting never auto-starts combat or grants an early-start timer bonus. Wave-clear leaf formula and
timber are doubled (6 + wave leaves and 2 timber before campaign scaling); fresh enemy drops gain 50%, rounded,
without multiplying returned stolen leaves. Five-wave chests, enemy strength and first-clear rewards are retained.
Each campaign wave now saves `wave_done`: restart or defeat retries the next uncleared wave, with continuous 1–15
or 1–20 numbering. Older chapter-only saves still load. Active food survives a wave checkpoint. PC verification
passed `--smoke` and `--fightf` (90 checks), including real drops, exact payouts, no duplicate pay, manual waits,
save/reload, losses, 5→6, 19→20, legacy saves, final wins and Gloom Raid waiting/resume.

**23 Nov 2026 · stronger, affordable late bow upgrades.** Bow levels 6–10 now each add 20% of base damage;
early levels and mastery increments keep 10%. Existing levels receive the stronger damage without another purchase.
Late upgrade leaf prices are about 25% lower. Ember level 5→9 costs 1,480 leaves (was 1,976); its level-9 hit at
Damage 9 is 59.488 (was 48.672). The shop shows the next upgrade's actual percentage damage gain and price.
The conservative first-clear leaf income of missions 13–14 is at least 5,773, excluding kills and bonuses. Shop 4 plus
Ember 5→9 costs 3,480; even buying Ember and raising it from 1→9 plus Shop 4 costs 4,964. Mission rewards and boss
attack patterns are unchanged. The extra post-charge damage window remains a possible later test.
PC checks passed `--smoke` and `--bowshop` (77 checks), including insufficient/exact leaf balances and real arrow damage.

**23 Nov 2026 · Ember Ranger and mount speed.** Nightfall Ranger is now **Ember Ranger**, with crimson clothing,
warm gold trim and cream cloak lining, distinct from Dusk's teal. Its shop portrait is updated. The legacy
`nightfall_ranger` ID and file paths preserve existing purchases and equipped saves. Only clothing atlas pixels
changed; geometry, rig, weights, animations, fur, face and gear are preserved. Mounted travel is 15% slower at
every Market level: speed multipliers are now 1.275 / 1.4025 / 1.53. The Market card shows the revised speed bonus.
PC checks passed `--smoke` and `--tailor` (63 checks).

**23 Nov 2026 · Fire-spitter flame balls.** Updated in the `development` working tree. The worn attachment launches
visible flame balls from its nozzle at the cat's current firing pace, including draw upgrades, bow speed and meal boosts.
The range also follows the cat's current arrow range, including bow and range upgrades. The firing unit swivels toward
the cat's focused enemy or acquires another foe in any direction while the mount follows joystick travel. The collar
and hangers stay fixed. Shots wait for the nozzle to line up, and flight time covers targets at the range edge.
An impact damages the enemy and foes within 1.25 m, then burns survivors for 2 s. Level 1 deals 8 impact damage and
8 burn damage per second; each upgrade adds 40% of the base to both. The attachment fires independently of skill gaps.
Only riding in combat launches new balls. Projectiles stop when gameplay is frozen and missed shots expire.
PC checks passed `--smoke` and `--saddlery` (94 checks). The debug APK is prepared for remote phone testing.

**23 Nov 2026 · mounted torso-only aiming.** Updated in the `development` working tree after the owner's phone play.
The mount faces joystick travel and uses its original forward Run animation. The cat shoots in a strict 280-degree
arc (140 degrees either side), with an 80-degree rear gap. Held targets outside that arc are released. At the owner's request, Front,
QuarterLeft/Right and RearLeft/Right clips now affect only the upper body. The root, pelvis and bent legs face the
mount; the torso, shoulders, arms and head handle aiming. Chest rotation is bounded in the authored poses and the
wrists are repositioned together for rear shots. The clips share one draw/release clock. PC verification uses
`--smoke` and `--mountedaim` (69 passes), including strict arc boundaries and dismounting during a rear shot.
The revised debug APK is built at `game/build/ProjectLEAF.apk` for remote phone testing. Screenshots cover shots near both arc edges and
left/right steering on both mounts, plus both outfits with different bows.

**23 Nov 2026 · supplies inventory.** Built in the `development` working tree. Bag uses a shared square grid for food,
dishes, keys, materials and unplaced defences. Currency icons and counts sit above it. A live preview shows the cat,
with her current mount while riding. Gameplay continues during use. The garden, pot, fishing and Market show clear
owned totals and receipts. Select a dungeon healing food or use Auto. PC checks passed `--smoke` and `--inventory`
(53 passes) at 480x1040 with safe areas. The revised debug APK is built at `game/build/ProjectLEAF.apk`.
Phone verification awaits a connected device.
See `docs/INVENTORY_PLAN.md`.

**23 Nov 2026.** Committed on `feature/g3-g4-bows-saddlery-outfits` and merged into `development`.
The APK for the full update was installed on the owner's phone at 01:52. The before and after saves match.
See `docs/CHANGES.md` for the complete 21–23 Nov entry.

Read this first when work starts again. The full design is `GAME_PLAN.md` section 0 (Draft 7). Step-by-step build
notes are in `docs/PHASE_A_PROGRESS.md`. Each phase has its spec in `docs/PHASE_C_SPEC.md`, `PHASE_D_SPEC.md` and
`PHASE_E_SPEC.md`; read the decisions at the top of D and E first.

## Built and working (tested on the PC)

| Part | What it is |
|---|---|
| Tailor's Nook and cat outfits (23 Nov 2026) | Build the outfit shop at Hearthtree 3 for 1,500 leaves and 40 timber. Original Ranger is free, Dusk Ranger costs 3,000 leaves and Nightfall Ranger costs 6,000. Outfits are looks only. Each new cloak swings on four cloth bones. Codex review fixes and the shop are covered by `--tailor` (63 passes) and `--layout` (132). |
| Phase A | Missions, enemies that attack buildings, the campfire Last Stand and rebuild, the camp falling, barricades and tower spots |
| Low-end phones | Low / Medium / High graphics, picked by the game and changeable on the Shop card; the forest culled in cells; one shadow map; a faster cloth fit; `--perf` benchmark (`docs/PERFORMANCE.md`) |
| A2 | Missions of 15 waves (missions 1–5) or 20 waves (6–15) in chapters of 5: elite waves, a boss at the end, 15 s breathers, chapter breaks that save ("Go on" / "Give up"), wave pay and chapter chests, a flee rule so a wave can never hang |
| A3 | Health bars over the cat and the mount; the mount takes hits while ridden |
| B | Home levels 4–6 with new campfires (hearth, bonfire, crystal brazier) and bigger tree homes; colour skins for every mount and pet ("Colours" row) |
| C | The garden and cooking pot (the gift for winning mission 1, with 4 Sunberries); cooking (a dish is eaten when the next chapter starts); fishing (after mission 6); feeding a knocked-out mount (2 Sunberries via the Ride button, which becomes "Feed"); the Moss Warden guardian built with the user's Meshy model but HIDDEN until the Burrows free it (`stations.free_guardian()`) |
| E | The Burrows. **Built** 18 November 2026, steps E0-E10 on the PC; notes in `docs/PHASE_A_PROGRESS.md`, "Phase E". The Old Hollow south of the camp (sealed from the first mission won, open after the last), free and unlimited entry (a Hollow key only adds a boon), traps, the Leaf Dash (a flick, Burrows only), the new monsters on stand-ins, the satchel (a knock-out keeps half), boons, saving and resuming a run, the mount and the pet going down with the cat (Feed and a Snack button), the Moss Warden freed from its Gloom seal behind the first boss, mastery 11-12, the Foxfire Bow, level-5 defences, the Warden's level 4 (leaves), home levels 7-8 (Burrow materials), attachments for the mount and the pet, and a debug endgame start. Its room runs (den, forks, doors, room templates) were **replaced the same evening** by the row below |
| Burrows as paths | **Built** 18 November 2026, evening, from the user's word ("a path to the boss, like World of Warcraft"): `docs/DUNGEON_SPEC.md`; notes in `docs/PHASE_A_PROGRESS.md`, "The Gloomwood (dungeon rework, 18 Nov 2026)". The Old Hollow leads into **the Gloomwood**, one continuous wood at night built from `game/data/dungeons/old_hollow.json` (`dungeon_map.gd`, `burrow_run.gd`): a 144 m path from the way in past nine fights (six with HUD pips: the sleeping camp, the burrow holes, the Glowcap clearing, the bramble bend, the bridge with its moths and elite, the old oak; plus three ambushes), the nook's Gloom-bound chest, the rolling logs and their chest, the Moonwell (spring, boon, root lift home) and the arena gate, to Mossback (about 9,900 health at level 1, `hp_mult` 2.2; enrages below 35%; up to 6 adds) in a stone-circle arena whose roots close behind the cat, then the chest, the Warden's seal on the first clear and the lift home. Replays are levels 1, 2, 3... (other monster pools, bigger packs, snappers from 2, elites from level 1 at 30%, the boss Gloomtouched from 4). Checkpoints at the way in, the Moonwell and the gate ("Go back in" starts there). Night look that needs no lights (glowing faces, halos and pools, fireflies; three lantern lights on Medium and High). Reworked on 19 November as a night road (see the next row). A map can end in a treasure instead of a boss. Tests in `game/scripts/autotest_e.gd` (`--dungeon` and others, `game/README.md`) |
| Night road and harder | **Built** 19 November 2026 (notes in `docs/PHASE_A_PROGRESS.md`, "Night road and harder"). The Gloomwood's floor is one night plane (`night_floor.gd`: flagstones, cobbles, planks, puddles, torches, lanterns; a stone-circle arena with a carved sigil, rune stones and giant swords). Much harder: strength 3.0 at level 1, +1 damage, bigger packs, elites from level 1, three ambushes, `max_alive` 8 / 12 / 12 (Low / Medium / High), the Moonwell heals 40% of the cat's health, pay up 25%. Raids do not come while the cat is in the Gloomwood: the meter and warnings wait. |
| Phase F | **Built** 19 November 2026 (plan: `docs/PHASE_F_PLAN.md`; described in `docs/GAME_GUIDE.md`). Tested on the PC with `--smoke` and the three new modes. Home goals for homes 2-8 (the home grows only when every goal is met and the price is paid; the home's card has a "Grow the home" section with Go / Show buttons and the badge shows "!"), mission gates by home level (**removed 21 Nov 2026**: no mission waits for the Hearthtree any more), **no replays**, much bigger win rewards, the Training Target and Bow Bench at 5 levels (caps 4/6/8/9/10), stat and bow prices +30%, Range +0.2 m a level. Missions: roads in patterns (surround, pincer, rush; mission 1 teaches them; the top bar says where the next wave comes from), bursts, no easy waves, real last chapters for missions 6, 13 and 15, an easier mission 2 and softer boars with a daze after a missed charge. Reasons to move: Pitchers and Frogs shoot from beyond the cat's reach, the Golden Grub, the Gloom Totem, and pay bonuses for a quick clear, an intact wave and going on early. The Gloom fades a step per mission won. Tests `--homegoals`, `--fightf`, `--enemyf`. Older tests that start a won mission need `fight.skip_gate`. |
| Phase G1 | **Built** 20 Nov 2026 (the fixes, step G1 of `docs/PHASE_G_PLAN.md`; described in `docs/GAME_GUIDE.md`, part 11). Tested on the PC with `--smoke`, `--fightf` and `--homegoals`. Waves hold many enemies but few on the field (10, 12 or 14 at once; tanks 1, 2 or 3); a held wave pays timber; chapter chests pay 2, 4, 4 and 6 timber; the Market Stall buys and sells 5 timber; the campfire can always be lit again. |
| G1b and G2 (New, 20 Nov 2026) | **Built** 20 Nov 2026 (`docs/PHASE_G_PLAN.md`; described in `docs/GAME_GUIDE.md`, "Phase G1b and G2"). **G1b:** waves are squads (12 squads, roles, the squad rules, squads move as one road group); mission 1's first win gives 60 leaves. **G2, the Hearthtree:** the tree home and its campfire are called the Hearthtree; the Market (Thistle free) and the Mushroom Cottage (Sprig) come at Hearthtree level 2; barricades are rows of 3 on the 12 road spots (see Barricade placement below), each piece breaks on its own and repairs by tap; tower repair; the Wishing Well works by itself; shop cards are tiles in a grid with 32 code-drawn icons (`ui_icons.gd`). Tested on the PC: `--smoke` OK, `--fightf` 55 pass, `--homegoals` 45, `--rows` 46, `--campg` 45, `--enemyf` 22, `--cards` 55; no failures. |
| G3 (21–22 Nov 2026) | **Built** 21 Nov, retuned 22 Nov. The Bow Bench is the **Bow Shop**. Four bows: Twig (the original, free), Sunwood (Bow Shop 2), Ember (3) and Frost (5). Thorn Volley and Foxfire are hidden. Claude made the bow and arrow models in Blender with the owner's approval. Buy, upgrade and equip on the shop card. Shots have their own effects. `--bowshop` passed 61 checks. See `docs/GAME_GUIDE.md`, parts 3 and 11. |
| G4 (21–22 Nov 2026) | **Built** 21 Nov, updated 22 Nov. The Saddlery opens after mission 8 at Hearthtree 2. Learn Stomp, Ram, Pounce and Bellow. Wear one of Fire-spitter, Mossweave Saddle and Saddlebags at a time. Claude made the gear and six new mount animations in Blender. The cat moves in the saddle, carries her bow upright and shoots ahead. The mount takes the hits and has an amber health bar. `--saddlery` passed 52 checks. Backup `D:\DevCache\backup\pre_g4_20261121`. |
| Loop fixes (New, 22 Nov 2026, loop fixes) | **Built** 22 Nov 2026 (described in `docs/GAME_GUIDE.md`, part 11, "Loop fixes (22 Nov 2026)"). Five fixes from a loop check on 21 Nov: a camp fall takes 30% of the leaves gained in the lost chapter only; Hearthtree 2 to 5 need one mission earlier (missions 1, 5, 9, 12); the Hearthtree's repair is capped (10%, at most 900 leaves and 30 timber); a knocked-down tower's repair costs what "Mend the defences" costs for it; the Saddlery needs Hearthtree level 2. Tested on the PC: `--smoke` OK, `--homegoals` 46, `--rows` 48, `--campg` 47, `--saddlery` 46, `--fightf` 64, `--laststand` 1, `--raidloss` 12 pass and 2 old failures. Backup `D:\DevCache\backup\pre_loopfix_20261121`. |
| Bow and Hearthtree balance (New, 22 Nov 2026) | **Built** 22 Nov 2026 (described in `docs/GAME_GUIDE.md`, part 3 and part 11, "Bow and Hearthtree balance (22 Nov 2026)"). Timber prices changed at Hearthtree 3 and 5–8, and level 5 costs more leaves. Both prices now rise at every level. The Bow Shop sells four bows: Twig (free), Sunwood Longbow (Bow Shop 2), Ember Bow (Bow Shop 3), Frost Bow (Bow Shop 5), each with a pro and a con; Thorn Volley and Foxfire are hidden. Per-bow `draw_mult` and a 2.0 m range floor (`cat.min_range_m`). The Frost goal moved to Hearthtree 6. Tested on the PC: `--bowshop` 61 pass, `--homegoals` 48 pass, `--smoke` OK. |
| Barricades and the Well (22 Nov 2026) | Repair rows even during a wave. The price depends on the missing health of each piece. The Wishing Well mends damaged things back to full (3%, 6%, 10% a second between waves and 0.5%, 1%, 2% in waves). Pads open by Hearthtree level and the card explains when Build is off. `--campg` passed 49 checks. |
| Barricade placement (22 Nov 2026) | After mission 1, gates open at Hearthtree 1, middle pads at 3, right far pads at 4 and left far pads at 5. Fernwood and Bandit Thicket each have three evenly spaced pads. Each left middle pad sits near a bend. Built rows keep their saved pads and move with the roads when the Hearthtree grows. `--rows` passed 94 checks. |
| Cat bow carry (22 Nov 2026) | Updated on-foot clips in `CatRanger.glb`. `bow_face.gd` rolls the paw in place to keep the bowstring facing the cat's chest. |
| Tap to open | **Built** 19 November 2026 (notes in `docs/PHASE_A_PROGRESS.md`, "Tap to open"). No ground rings (never walk onto a ring to open a card): a leaf-pin badge with an icon floats over each usable thing (small far away, big and glowing in reach, a rim glow on the thing, a "!" when something is new). A tap on it, or on the thing, opens its card; out of reach the cat walks there first. Cards are dialogs in the middle of the screen with an X; a tap outside or the back button closes them. Attack arrows at the screen's edge (during waves, raids and the Gloomwood) show where foes off the screen come from. Tests `--taps`, `--arrows`; `--layout` and `--hudcheck` tap. |
| Layout + HUD | **Built** 18 November 2026 on the PC, from the user's phone play (notes in `docs/PHASE_A_PROGRESS.md`, "Camp layout and HUD"). The camp round the campfire: open ground round the fire and straight south of it, the home beside it, the Training Target and Bow Bench east of the fire, the Mushroom Cottage and Market Stall south-east, each on its own path, the Wishing Well on the lake's near shore (the lake beside the camp, not in it); nothing tall stands just south of where the cat walks. The HUD keeps the middle of the screen for the cat: one slim top bar (riches, the dish, the fight's bar and status; the phone's safe area kept), the boss bar, banners and toasts just under it, tips and the hint just above the bottom buttons, cards (docked sheets then; centred dialogs with an X since Tap to open), smaller and quicker pickup numbers. Tests `--layout`, `--layoutsave=1/2`, `--hudcheck` (`game/scripts/autotest_layout.gd`). |
| D | The Gloom Raids after every mission is won. **Built** 18 November 2026, steps D1–D9 and D11 on the PC; notes are in `docs/PHASE_A_PROGRESS.md`, "Phase D". It covers: the meter (fills only while playing); the Watch on the signpost; four raid kinds with a 30–60 s warning; the Gloom Herald (the Crow Drummer at 1.25x until its model comes) and the rout; shards and what they buy (Shardstone level 4, Lookout, Tracker, Gloomlit, Shardfire, selling to Bramble); wear, Patch, "Mend all"; nothing happens while the game is closed. |

**Earlier phone builds.** The 19 Nov 2026, 09:44 APK included the Gloomwood night road, Tap to open, attack
arrows, the fixed home spot and the moved lake. That APK was copied to the owner's Desktop as
`ProjectLEAF_2026-11-19.apk` while the phone was disconnected. The camp layout build of 18 Nov, 20:02 had
already been installed after backing up the save to `D:\DevCache\backup\phone_save_20261118_before_layout.json`.

**19 November 2026, from the user's phone play:**
- The home stands in **one spot at every level**, `world.HOME_SPOT` (-4.6, 0, 0.25): west of the fire, with open ground
  between them (it used to step back as it grew, and at level 1 it crowded the fire).
- **The lake moved 2.6 m south-west** to (-7.8, 0, 5.0), with the well, the fishing spot and the dock, so even the biggest
  home keeps a clear gap from the water. The woods' and hide spots' seeded sequences still read the old spots
  (`OLD_LAKE_C`, `OLD_HOME`), so the forest does not reshuffle. `--layout` checks the fire gap (at least 1.5 m) and the
  water gap (at least 1.5 m) at every level.
- **The old room dungeon is gone completely** (the user: remove it, do not test it): its 7 room-only models
  (`burrow_wall_1/2`, `burrow_wall_low`, `burrow_corner`, `burrow_door`, `burrow_sign`, `burrow_pillar`) and Old
  Grubber (its unused boss: code and data) were deleted. Backup: `D:\DevCache\backup\pre_homefix_20261119_0023`.

## The Burrows (Phase E and the Gloomwood): what is left

- **The user plays the Gloomwood on the phone**: is the path long enough, are
  the fights and Mossback (about 9,900 health) right at level 1, does the night read on the S24's screen? To try it
  without winning 15 missions, use the debug endgame start (below).
- **Rough spots still open:** the log-trap warning shows as a flat orange bar; some dark road patches look like holes;
  `--dungeonresume` needs a clean rerun (its last run clashed with another run on the same save); the full regression
  was skipped on 19 Nov to save quota; `--dungeonperf` was not rerun after the arena and light changes.
- The Meshy models of the new monsters (stand-ins until then): the Grubling, Glowcap and Amber Grub, the Root Snapper.
  When a model lands in `game/assets/enemies/<id>/`, delete `model`, `scale` and `tint` from its balance.json entry.
  The boss is Mossback at every level. Old Grubber was removed with the old rooms (19 November 2026).
- More dungeons are data plus models: a new `game/data/dungeons/<id>.json` and an entry in `balance.json`
  `burrows.list` (a map may end in a treasure instead of a boss). The user asked for later dungeons without a boss.
- Models for home levels 7 and 8 and their campfires (`home_tree_7/8`, `campfire_7/8`): level 6's show until then.
- A balance pass by play on the phone (run length, boss times, materials per run, prices), and `--dungeonperf
  --quality=low` on the S24 (`user://test_args.txt`).
- Optional: a `whoosh` sound for the dash (it plays `pop`), a dash clip for the cat, attachments shown on the models
  (they are card-only now), a proper Blender model for the arena's root gate and the standing stones (both are built in
  code now).

## Phase D: what is left

- The Gloom Herald's model (D10): the concept image is made. When the user's Meshy model comes, set
  `"model": "herald"` in balance.json and drop `scale`.
- A balance pass by play on the phone, and `--raidperf --quality=low` on the S24.
- The optional Moth Lantern and Bramble Snare (D12), only with the user's yes.
- Sounds for `raid_horn`, `shard` and `rout`. Stand-ins play until they exist.

## Next

- **G5:** play the 23 Nov APK on the phone and tune the prices, fights and Well by play.
- **Open question:** buildings never fade, so the cat can be hidden behind them, including behind the Tailor's Nook.
- **Thistle's Bellow:** the riding clearance fix reduced overlap. The last PC sweep still measured about 7 cm of
  overlap during Bellow. A smaller head throw in the clip is still open.
- **Later:** earning mount skills in dungeons is an idea. Paid outfits using premium currency and two or three
  more mission bosses are also for later.

**Everything done on 19–20 Nov 2026, and what is left:** `docs/SESSION_LOG_2026-11-19_20.md`.

- **Phase G (20 Nov 2026): the plan is AGREED** (`docs/PHASE_G_PLAN.md`, version 3). Build order:
  - G1: **built 20 Nov 2026**. The fixes: no timber to relight the ashes, timber each wave and to buy, wave size and tank limits. On the phone since 20 Nov (14:2x).
  - G1b: **built 20 Nov 2026**. Structured waves (squads). Mission 1's first win gives 60 leaves.
  - G2: **built 20 Nov 2026**. The Hearthtree; the Market (Thistle free) and the Cottage (Sprig) at level 2; barricade rows; tower repair; the automatic Well; shop-style cards.
  - G3: **built 21 Nov 2026**. The Bow Shop's final four-bow lineup was set on 22 Nov.
  - G4: **built 21 Nov 2026**. The Saddlery has four skills and three attachments. One attachment is worn at a time.
  - G5: tuning by the owner's play. This is next.

  The 20 Nov G1 build cleared the earlier mission 9 soft-lock by letting the cat relight the fire for 40 leaves.
  That install's backup was `D:\DevCache\backup\phone_save_20261120_before_g1.json`.

  **21 Nov 2026, from the owner's play:** a second soft-lock. Mission 11 needed Hearthtree level 4, the owner (mission
  10 won, about 8,000 leaves) could not afford it, and without replays fighting was the only way to earn leaves. Fixed
  on the PC: every mission's `needs_home` is 1 in `balance.json`, so missions never wait for the Hearthtree.
  `--homegoals` 44 pass, `--smoke` OK. **On the phone since 21 Nov 2026, 21:29** (the save was backed up first to
  `D:\DevCache\backup\phone_save_20261121_before_nogate\`: Hearthtree 3, 7,462 leaves, 96 timber, 10 missions won;
  unchanged after the install).

  Phase G1b and G2 were built on 20 Nov. The 23 Nov APK includes them and the later loop fixes.
  An old endgame save keeps its old levels until `--endgame --fresh`.

1. To try the raids and the Burrows without winning 15 missions: put a line `--endgame` in the app's
   `files/test_args.txt` (debug builds only; a separate save, see below).
2. The Meshy models for the Burrows creatures when the user makes them, then a balance pass by play; later dungeons
   (some without a boss) as data plus models.
3. At the very end: the bug review that was stopped earlier (workflow `review-today`, resumable), only if the user
   wants it.

## All props and models are made

- Phase C props (20: guardian stone, garden bed and crops, cooking pot, fishing spot, rod, catches): `camp_life.json`.
- Phase D props (6: the Watch signpost, Gloom shard, rubble, level-4 barricade, tower and spikes): `raids.json`.
- Phase E props (23 since the room walls, doors, sign and pillar were deleted on 19 Nov 2026: the hollow entrance,
  traps, chests, the spring, materials, level-5 defences): `burrows.json`.
- The Moss Warden (from the user's Meshy file): `game/assets/companions/moss_warden/`.
- Code notes for the D and E props are at the end of their specs ("Props as built").

## Waiting on the user (Meshy models)

- **New (21 Nov 2026, G4): the Saddlery building**, made by the owner in Meshy. Until it comes, the Bow Bench model is
  used, tinted brown. Claude's Fire-spitter, Mossweave Saddle and Saddlebags models are already in the game.
- **New Phase F models, made by the owner in Meshy** (see `CLAUDE.md` for the modelling and repair rules).
  - Until they come, the game uses stand-ins:
    - the Golden Grub: a small gold mole (its concept image is `concepts/enemies5/01_golden_grub.png`);
    - the Gloom Totem: Gloom props;
    - Training Target levels 3–5: the second Target model;
    - Bow Bench levels 4–5: the third Bench model.
  - Files go in `art/source/meshy/`. Claude cleans them up, colours, rigs and exports them in Blender.

Concept images are made and were sent; the game uses stand-ins until the models come:
- the Gloom Herald, the raid leader: `concepts/enemies4/01_gloom_herald.png`
- the Burrows creatures: `concepts/burrows/01_grubling.png`, `02_glowcap.png`, `03_root_snapper.png`,
  `05_amber_grub.png` (Old Grubber, `04_old_grubber.png`, is no longer needed: it was removed with the old rooms)
- later: models for each new guardian kind (not in the game yet: the user wants one guardian for now). Concepts are
  made for two: the Bramble Boar (`concepts/companions/04_bramble_boar.png`, a fighter) and the Lantern Owl
  (`concepts/companions/05_lantern_owl.png`, a helper)
- later: 2–3 more mission bosses (missions 4, 9, 12 end without a real boss)

## Decisions the user made on 17–18 November 2026

- **The camp.** One cat protecting its campfire camp. Not Clash of Clans: no villagers, no workers, no production
  timers. Say "camp", not "village". **Nothing happens while the game is closed.**
- **Missions.** 15–20 waves each, about 20 minutes, the camp and cat growing during a mission.
- **After the missions.** The Burrows (working name, accepted) are most of the game: go in, bring back what the camp
  needs, upgrade, go deeper. Several Burrows, more over time, free to enter. The cat goes in with its pet and mount
  only. Raids keep coming meanwhile.
- **Guardians.**
  - Not in the missions. Found only after the missions, in the Burrows, never sold. The first one is guaranteed.
  - **For now only one guardian, the Moss Warden** (the user, 18 November 2026, during Phase E): found sealed in Gloom
    crystals behind the Old Hollow's first boss, never on the way in. No other kinds, no guardian spots, no choosing at
    the stone yet; the collection below is for later.
  - Later: guardians are collected: every one found joins the camp's defence.
  - They fight in different ways, and some help with other things (never producing resources).
  - None ever goes into a Burrow.
  - Guardian spots follow the home level: 2 when the missions end, +1 per level, up to 5. That means home levels 7–8
    after the missions, paid mostly with Burrow materials.
  - Upgrades at the stone cost leaves.
- **Food.** Food matters from the start. A knocked-out mount is brought back with food; the pet never dies. Food also
  feeds the guardians.
- **Pets and mounts.** New pets and mounts are looks only, with the same strength.
- **Money.**
  - Sold: pets, mounts, cosmetics, and attachments for the pet and mount, which help in the Burrows and can also be
    earned by playing.
  - A premium currency (working name Moonpetals) is proposed.
  - **Rewarded ads only**: no interstitials, no banners.
  - Full proposal: `GAME_PLAN.md` section 0, "Making money". Nothing of it is built yet.
- **The hero.** The user kept the original Cat Ranger, not the Meshy remake.
- **Later.** 2–3 more mission bosses.

## Tools and paths

- Godot 4.7.2: `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`, the project at
  `D:\Projects\Project LEAF\game`. Set TEMP/TMP to `D:\DevCache\tmp`.
- Tests: `-- --autotest --fresh --<mode>`. Modes:
  - `--smoke`, the default mission-1 run, `--resume=1/2`
  - `--village`, `--siege`, `--laststand`, `--bars`, `--skins`, `--levels`
  - `--perf`, `--perfdiag`
  - `--guardian`, `--guardianab`, `--garden`, `--cook`, `--fishing`, `--feed`, `--camplife`
  - plus Phase D's raid modes
  - the Burrows: `--dungeon`, `--dungeonshots` (480x1040, `--quality=low` and `high`), `--dungeonfall`,
    `--dungeonresume=1/2`, `--boss`, `--dungeonperf`, `--dungeontreasure`, `--dungeonlevels`, and from Phase E
    `--burrowsave`, `--hollow`, `--dash`, `--traps`, `--burrowfoes`, `--topup`, `--burrowhooks` (in
    `game/scripts/autotest_e.gd`; see `game/README.md`). Phase E's room modes are gone with the rooms.
  - New (20 Nov 2026, G1b and G2): `--rows`, `--campg`, `--cards` (in `game/scripts/autotest_g2_*.gd`; `--cards` at 480x1040 with `--safe-top=73 --safe-bottom=42`); `--fightf` now checks squads.
  - G3, G4 and outfits: `--bowshop`, `--saddlery` and `--tailor` (see `docs/GAME_GUIDE.md`, Test modes).
  - Known old results: `--topup` 8 failures and `--raidloss` 2 failures (see `docs/CHANGES.md`).
  - the layout and the HUD: `--layout`, `--layoutsave=1/2`, `--hudcheck` (in `game/scripts/autotest_layout.gd`); run
    them at 540x960 and 540x1170; `--safe-top=N --safe-bottom=N` (HUD pixels) fake the phone's bars
  - **If the PC's screen is off or asleep, add `--disable-vsync` before `--`**: otherwise Godot runs at about 4 frames a
    second and the timed tests (the Warden's) fail. The runner `D:\DevCache\tmp\layout_hud\run.sh` does it.
- **Debug endgame start** (debug builds only): `--endgame` (on the phone, a line in `files/test_args.txt`) opens a
  separate save as if all 15 missions were won (home level 5, leaves, timber, shards, the Burrows open; the Warden is
  still to be found). It stays on until a launch with `--endgame-off`; the real save is never touched. The HUD says
  "Endgame test save". `--endgame --fresh` starts it over.
- APK: run from inside `game\` (the output path is relative to the project, so the APK lands in
  `game\build\ProjectLEAF.apk`): `--headless --path . --export-debug "Android" build/ProjectLEAF.apk`. Then
  `adb -s RFCX2035YHT install -r game\build\ProjectLEAF.apk`. adb is not on PATH: the Android SDK puts it in
  `C:\Users\marti\AppData\Local\Android\Sdk\platform-tools\adb.exe`. The adb daemon often restarts after an export, so
  run `adb wait-for-device` first.
  - **Set up again 21 Nov 2026** (after the Windows reinstall): the SDK (build-tools 36.0.0), Android Studio's Java,
    the Godot 4.7.2 export templates and the Samsung USB Driver 1.9.5.0. The local `tools/build_apk.ps1` fills blank
    Java and SDK paths in Godot's settings and uses environment variables for the existing debug keystore.
    With `-Install`, it backs up the phone's save using ADB `run-as`, installs, and compares the save hashes.
    Routine ADB stderr is allowed. The 23 Nov backup is `D:\DevCache\backup\phone_save_20261123_0152`.
- Phone tests: put arguments one per line in the app's `files/test_args.txt` (debug builds only), via `run-as`.
- Blender 5.3 (`D:\Blender` points to `C:\Program Files\Blender Foundation\Blender 5.3`): headless
  (`D:\Blender\blender.exe -b`), or live in the Blender that `tools/start_blender_mcp.ps1` opens, through the MCP bridge
  on port 9876 (`py -3.15-32 tools/blender_mcp.py` runs Blender scripts there). Leave the owner's open Blender alone.
  Agents working side by side use headless Blender (`CLAUDE.md`).
- Godot MCP (21 Nov 2026): local server `godot` in `.mcp.json`, from `tools/mcp/`, runs against Godot 4.7.2.
- Python (21 Nov 2026): only a 32-bit Python 3.15 through `py`, without numpy or Pillow. Blender's own Python has numpy.
- Git (21 Nov 2026): since the Windows reinstall, git refuses this folder ("dubious ownership"), because the folder's
  owner is the old Windows account. A one-off `git -c "safe.directory=D:/Projects/Project LEAF" <command>` works. The
  lasting fix, `git config --global --add safe.directory "D:/Projects/Project LEAF"`, is the owner's call (not done).
- Concept images: `tools/gen_concepts.ps1` (Codex CLI) with the Cat Ranger concept sheet as the style reference.
  Codex CLI (21 Nov 2026): not on PATH; it comes with the Codex desktop app (Store package `OpenAI.Codex`,
  `app\resources\codex.exe`, codex-cli 0.171, signed in with ChatGPT). The script finds it by itself. Codex also
  reviewed this update and supplied fixes and docs as patches from its read-only workspace.
- Backups:
  - `D:\DevCache\backup\pre_phase_c_20261118_0246`
  - `D:\DevCache\backup\pre_phase_d_20261118_0420`
  - `D:\DevCache\backup\pre_phase_e_20261118_1526` (and each Phase E step's files in `D:\DevCache\tmp\phase_e_steps\`)
  - `D:\DevCache\backup\pre_layout_hud_20261118_1739` (and each part's files in `D:\DevCache\tmp\layout_hud_steps\`)
  - `D:\DevCache\backup\pre_phase_g2_20261120_1429` (before G2; New, 20 Nov 2026)
  - `D:\DevCache\backup\pre_phase_g1_20261120_1359` (before G1)
  - `D:\DevCache\backup\pre_phase_f_20261119_1209` (before Phase F)
  - `D:\DevCache\backup\pre_dungeon_20261118_2003` (scripts, data, docs, GAME_PLAN.md and game/README.md before the
    Gloomwood; its runs and shots are in `D:\DevCache\tmp\dungeon\runs\`)
