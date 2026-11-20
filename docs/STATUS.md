# Project LEAF: where we are (20 November 2026, after Phase E, the camp layout and HUD, the Gloomwood, the night road, Tap to open, Phase F, Phase G1, and G1b and G2)

**The full description of the game as it is now: `docs/GAME_GUIDE.md`.**

Read this first when work starts again. The full design is `GAME_PLAN.md` section 0 (Draft 7). Step-by-step build
notes are in `docs/PHASE_A_PROGRESS.md`. Each phase has its spec in `docs/PHASE_C_SPEC.md`, `PHASE_D_SPEC.md` and
`PHASE_E_SPEC.md`; read the decisions at the top of D and E first.

## Built and working (tested on the PC)

| Part | What it is |
|---|---|
| Phase A | Missions, enemies that attack buildings, the campfire Last Stand and rebuild, the camp falling, barricades and tower spots |
| Low-end phones | Low / Medium / High graphics, picked by the game and changeable on the Shop card; the forest culled in cells; one shadow map; a faster cloth fit; the OpenGL fallback; `--perf` benchmark (`docs/PERFORMANCE.md`) |
| A2 | Missions of 15 waves (missions 1–5) or 20 waves (6–15) in chapters of 5: elite waves, a boss at the end, 15 s breathers, chapter breaks that save ("Go on" / "Give up"), wave pay and chapter chests, a flee rule so a wave can never hang |
| A3 | Health bars over the cat and the mount; the mount takes hits while ridden |
| B | Home levels 4–6 with new campfires (hearth, bonfire, crystal brazier) and bigger tree homes; colour skins for every mount and pet ("Colours" row) |
| C | The garden and cooking pot (the gift for winning mission 1, with 4 Sunberries); cooking (a dish is eaten when the next chapter starts); fishing (after mission 6); feeding a knocked-out mount (2 Sunberries via the Ride button, which becomes "Feed"); the Moss Warden guardian built with the user's Meshy model but HIDDEN until the Burrows free it (`stations.free_guardian()`) |
| E | The Burrows. **Built** 18 November 2026, steps E0-E10 on the PC; notes in `docs/PHASE_A_PROGRESS.md`, "Phase E". The Old Hollow south of the camp (sealed from the first mission won, open after the last), free and unlimited entry (a Hollow key only adds a boon), traps, the Leaf Dash (a flick, Burrows only), the new monsters on stand-ins, the satchel (a knock-out keeps half), boons, saving and resuming a run, the mount and the pet going down with the cat (Feed and a Snack button), the Moss Warden freed from its Gloom seal behind the first boss, mastery 11-12, the Foxfire Bow, level-5 defences, the Warden's level 4 (leaves), home levels 7-8 (Burrow materials), attachments for the mount and the pet, and a debug endgame start. Its room runs (den, forks, doors, room templates) were **replaced the same evening** by the row below |
| Burrows as paths | **Built** 18 November 2026, evening, from the user's word ("a path to the boss, like World of Warcraft"): `docs/DUNGEON_SPEC.md`; notes in `docs/PHASE_A_PROGRESS.md`, "The Gloomwood (dungeon rework, 18 Nov 2026)". The Old Hollow leads into **the Gloomwood**, one continuous wood at night built from `game/data/dungeons/old_hollow.json` (`dungeon_map.gd`, `burrow_run.gd`): a 144 m path from the way in past nine fights (six with HUD pips: the sleeping camp, the burrow holes, the Glowcap clearing, the bramble bend, the bridge with its moths and elite, the old oak; plus three ambushes), the nook's Gloom-bound chest, the rolling logs and their chest, the Moonwell (spring, boon, root lift home) and the arena gate, to Mossback (about 9,900 health at level 1, `hp_mult` 2.2; enrages below 35%; up to 6 adds) in a stone-circle arena whose roots close behind the cat, then the chest, the Warden's seal on the first clear and the lift home. Replays are levels 1, 2, 3... (other monster pools, bigger packs, snappers from 2, elites from level 1 at 30%, the boss Gloomtouched from 4). Checkpoints at the way in, the Moonwell and the gate ("Go back in" starts there). Night look that needs no lights (glowing faces, halos and pools, fireflies; three lantern lights on Medium and High). Reworked on 19 November as a night road (see the next row). A map can end in a treasure instead of a boss. Tests in `game/scripts/autotest_e.gd` (`--dungeon` and others, `game/README.md`) |
| Night road and harder | **Built** 19 November 2026 (notes in `docs/PHASE_A_PROGRESS.md`, "Night road and harder"). The Gloomwood's floor is one night plane (`night_floor.gd`: flagstones, cobbles, planks, puddles, torches, lanterns; a stone-circle arena with a carved sigil, rune stones and giant swords). Much harder: strength 3.0 at level 1, +1 damage, bigger packs, elites from level 1, three ambushes, `max_alive` 8 / 12 / 12 (Low / Medium / High), the Moonwell heals 40% of the cat's health, pay up 25%. Raids do not come while the cat is in the Gloomwood: the meter and warnings wait. |
| Phase F | **Built** 19 November 2026 (plan: `docs/PHASE_F_PLAN.md`; described in `docs/GAME_GUIDE.md`). Tested on the PC with `--smoke` and the three new modes; **NOT yet on the phone**. Home goals for homes 2-8 (the home grows only when every goal is met and the price is paid; the home's card has a "Grow the home" section with Go / Show buttons and the badge shows "!"), mission gates by home level, **no replays**, much bigger win rewards, the Training Target and Bow Bench at 5 levels (caps 4/6/8/9/10), stat and bow prices +30%, Range +0.2 m a level. Missions: roads in patterns (surround, pincer, rush; mission 1 teaches them; the top bar says where the next wave comes from), bursts, no easy waves, real last chapters for missions 6, 13 and 15, an easier mission 2 and softer boars with a daze after a missed charge. Reasons to move: Pitchers and Frogs shoot from beyond the cat's reach, the Golden Grub, the Gloom Totem, and pay bonuses for a quick clear, an intact wave and going on early. The Gloom fades a step per mission won. Tests `--homegoals`, `--fightf`, `--enemyf`. Older tests that start a won mission or one past the gate need `fight.skip_gate`. |
| Phase G1 | **Built** 20 Nov 2026 (the fixes, step G1 of `docs/PHASE_G_PLAN.md`; described in `docs/GAME_GUIDE.md`, part 11). Tested on the PC with `--smoke`, `--fightf` and `--homegoals`; the APK goes to the phone next. Waves hold many enemies but few on the field (10, 12 or 14 at once; tanks 1, 2 or 3); a held wave pays timber; chapter chests pay 2, 4, 4 and 6 timber; the Market Stall buys and sells 5 timber; the campfire can always be lit again. |
| G1b and G2 (New, 20 Nov 2026) | **Built** 20 Nov 2026 (`docs/PHASE_G_PLAN.md`; described in `docs/GAME_GUIDE.md`, "Phase G1b and G2"). **G1b:** waves are squads (12 squads, roles, the squad rules, squads move as one road group); mission 1's first win gives 60 leaves. **G2, the Hearthtree:** the tree home and its campfire are called the Hearthtree; the Market (Thistle free) and the Mushroom Cottage (Sprig) come at Hearthtree level 2; barricades are rows of 3 on the 12 road spots (rows 2, 3, 5, 7, 9, 12 by home level), each piece breaks on its own and repairs by tap; tower repair; the Wishing Well works by itself; shop cards are tiles in a grid with 32 code-drawn icons (`ui_icons.gd`). Tested on the PC: `--smoke` OK, `--fightf` 55 pass, `--homegoals` 45, `--rows` 46, `--campg` 45, `--enemyf` 22, `--cards` 55; no failures. The APK was built 15:43; it is NOT on the phone yet. |
| Tap to open | **Built** 19 November 2026 (notes in `docs/PHASE_A_PROGRESS.md`, "Tap to open"). No ground rings (never walk onto a ring to open a card): a leaf-pin badge with an icon floats over each usable thing (small far away, big and glowing in reach, a rim glow on the thing, a "!" when something is new). A tap on it, or on the thing, opens its card; out of reach the cat walks there first. Cards are dialogs in the middle of the screen with an X; a tap outside or the back button closes them. Attack arrows at the screen's edge (during waves, raids and the Gloomwood) show where foes off the screen come from. Tests `--taps`, `--arrows`; `--layout` and `--hudcheck` tap. |
| Layout + HUD | **Built** 18 November 2026 on the PC, from the user's phone play (notes in `docs/PHASE_A_PROGRESS.md`, "Camp layout and HUD"). The camp round the campfire: open ground round the fire and straight south of it, the home beside it, the Training Target and Bow Bench east of the fire, the Mushroom Cottage and Market Stall south-east, each on its own path, the Wishing Well on the lake's near shore (the lake beside the camp, not in it); nothing tall stands just south of where the cat walks. The HUD keeps the middle of the screen for the cat: one slim top bar (riches, the dish, the fight's bar and status; the phone's safe area kept), the boss bar, banners and toasts just under it, tips and the hint just above the bottom buttons, cards (docked sheets then; centred dialogs with an X since Tap to open), smaller and quicker pickup numbers. Tests `--layout`, `--layoutsave=1/2`, `--hudcheck` (`game/scripts/autotest_layout.gd`). |
| D | The Gloom Raids after every mission is won. **Built** 18 November 2026, steps D1–D9 and D11 on the PC; notes are in `docs/PHASE_A_PROGRESS.md`, "Phase D". It covers: the meter (fills only while playing); the Watch on the signpost; four raid kinds with a 30–60 s warning; the Gloom Herald (the Crow Drummer at 1.25x until its model comes) and the rout; shards and what they buy (Shardstone level 4, Lookout, Tracker, Gloomlit, Shardfire, selling to Bramble); wear, Patch, "Mend all"; nothing happens while the game is closed. |

**The phone (19 November 2026):** the latest APK (19 Nov 2026, 09:44) holds all of this: the Gloomwood as a night road,
much harder, Tap to open with the attack arrows, the home at its fixed spot and the moved lake. A copy is on the
owner's Desktop as `ProjectLEAF_2026-11-19.apk`. It was NOT installed by adb this time, because the phone was not
connected. The phone runs the owner's real save, with the endgame test save switched off. (The phone before that had
the camp layout and HUD build of 18 Nov, 20:02; the save was copied to
`D:\DevCache\backup\phone_save_20261118_before_layout.json` first.)

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

- **The user plays the Gloomwood on the phone** (the 19 Nov APK has it, to be installed): is the path long enough, are
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

**Everything done on 19–20 Nov 2026, and what is left:** `docs/SESSION_LOG_2026-11-19_20.md`.

- **Phase G (20 Nov 2026): the plan is AGREED** (`docs/PHASE_G_PLAN.md`, version 3). Build order:
  - G1: **built 20 Nov 2026**. The fixes: no timber to relight the ashes, timber each wave and to buy, wave size and tank limits. On the phone since 20 Nov (14:2x).
  - G1b: **built 20 Nov 2026**. Structured waves (squads). Mission 1's first win gives 60 leaves.
  - G2: **built 20 Nov 2026**. The Hearthtree; the Market (Thistle free) and the Cottage (Sprig) at level 2; barricade rows; tower repair; the automatic Well; shop-style cards.
  - G3: the Bow Shop, the Ember Bow, and 5 bow and arrow models by Claude.
  - G4: the Saddlery. 4 skills and 3 attachments, earned only, all combinable.
  - G5: tuning.

  The owner's phone save is soft-locked at mission 9 until G1 is on the phone.

0. **Built 20 Nov 2026: G1b and G2, tested on the PC.** The APK waits for the phone, then the owner plays. After that, G3 (the Bow Shop and new bows).
   - The G1b and G2 APK was built at 15:43 and is not on the phone yet. Before it is installed, the phone's save is backed up to `D:\DevCache\backup\phone_save_20261120_before_g2.json`.
   - On the phone now: Phase F plus G1 (20 Nov 2026, 14:2x). The save was backed up first to `D:\DevCache\backup\phone_save_20261120_before_g1.json`: home 3, 8 missions won, the campfire in ashes, 2,129 leaves, 1 timber. That was the soft-lock; G1 lets it relight for 40 leaves.
   - An old endgame save keeps its old levels until `--endgame --fresh`.
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

- **New Phase F models, made by the owner in Meshy** (the owner's rule: Claude never models).
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
  `adb -s RFCX2035YHT install -r game\build\ProjectLEAF.apk`. adb is not on PATH: it is
  `C:\Users\marti\AppData\Local\Android\Sdk\platform-tools\adb.exe`. The adb daemon often restarts after an export, so
  run `adb wait-for-device` first.
- Phone tests: put arguments one per line in the app's `files/test_args.txt` (debug builds only), via `run-as`.
- Blender 5.2 headless only: `D:\Blender\blender.exe -b`. Never use the user's open Blender or port 9876.
- Concept images: `tools/gen_concepts.ps1` (Codex CLI) with the Cat Ranger concept sheet as the style reference.
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
