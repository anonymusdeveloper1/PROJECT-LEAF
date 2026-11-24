# Project LEAF: the game

Godot 4.7.2, mobile renderer, portrait phone. The design is in `../GAME_PLAN.md` and the rules every 3D asset follows
are in `../docs/ASSET_RULES.md`.

## How it plays

- **Random Raids only:** Defend Camp starts one continuous attack. Groups of 1–3 arrive across all four trails,
  with no round breaks. A seeded roster and existing level increment are capped at 50 enemies including leaders
  and summons; graphics-tier live limits still apply. Defeated IDs, summons and damage survive saves. Old cleared
  waves get credit once. `--assault` / `--raidsave` covers 29 checks; Raid Missions retain their own wave rules.

- **Signpost:** **Raid Missions** lists all 15 structured missions under To finish and Completed. Finished missions
  can be replayed; unfinished ones open sequentially. **Random Raids** unlocks once all 15 are finished, while
  the completed catalogue stays available. A saved run must be resumed or explicitly given up before another starts.
  Missions descend from 15 to 1 in roomier cards with number badges, short status and one action. Opening and tab
  changes animate the cards; buttons respond to presses, while unchanged live refreshes preserve the list and scroll.
  Swipe over cards, badges or buttons to scroll; the signpost scrollbar is hidden. Verification: `--missions` covers
  39 catalogue/replay/touch checks; `--homegoals` covers 48 progression checks.

- **Acorn Towers:** each crossbow aims through 360° while its foundation stays fixed. Five upgrade looks reach
  5/6/7/8/9 m and deal 8/14/24/36/44 damage. Larger classic Twig arrows change size and colours with every tier;
  loading, bowstring draw, firing, recoil and the arrow's flight trail are visible.

- **Raid Missions and waves:** start a Raid Mission at the signpost, then tap **Start wave** for each following wave. Every wave
  waits as long as you need. Cleared waves save individually and numbering continues to 15 or 20; a restart or loss
  keeps them cleared. Old chapter saves remain compatible. Five-wave supply chests stay. Wave completion pays
  double the base leaf formula and timber; fresh enemy drops give 50% more golden leaves, rounded.

- **Late bow upgrades:** levels 6–10 add 20% of base damage each and their leaf prices are about 25% lower.
  Existing purchased levels gain the stronger damage automatically. The shop shows each next damage gain and cost.

- **Outfits:** the Tailor's Nook sells teal Dusk Ranger and crimson/gold Ember Ranger (formerly Nightfall).
  Existing Nightfall purchases become Ember Ranger. Riding speed is reduced 15% at every Market level.

- **Bag:** tap Bag at the bottom-left for one grid of square item slots with icons and counts. Currency counts sit
  above it. A preview shows the cat, seated on her current mount while riding. Tap a slot for its uses and actions.
  Gameplay continues. Garden and cooking cards show owned food, recipes show Have and Need, and gathering and trading
  show the resulting totals. In a dungeon, choose a quick-heal food or Auto, then use the labelled bottom button or
  Eat in the Bag. Both share the same cooldown. Materials show At camp and This run amounts.
- **Mounted aiming:** drag to turn the mount and run in that direction. The cat shoots across a strict 280-degree arc,
  leaving an 80-degree gap behind. Rear-quarter shooting turns her torso and arms while the hips and legs face the mount.
- **Fire-spitter:** the worn Saddlery attachment fires flame balls at the cat's arrow range and attack pace. Its firing
  unit automatically tracks enemies while the mount follows the joystick. A hit splashes nearby enemies and burns them;
  each upgrade increases both impact and burn damage by 40% of the base.
  Shots have a hot round core, animated flame tail and sparks. Impacts leave flickering ground fire that fades out
  after 3 seconds. Nearby hits refresh it; graphics quality limits patch and particle counts.
- The game opens in the cat's camp: its tree home (whose counter is the shop) and the campfire. There is no menu.
  Between waves nothing can hurt the cat in the campfire's warm light, and no enemy can step into it; during a wave
  foes press in to the edge of the light and try to put out the fire.
- **Move:** press anywhere and drag. A joystick appears under your finger. WASD or the arrow keys also work on a PC.
- **Use something:** tap it, or the little leaf-shaped badge floating over it (its icon says what it is). Its card
  opens as a dialog in the middle of the screen; if the cat is not close enough it walks there first (a drag stops it).
  Tap a green button to buy; the X, a tap outside the dialog or the phone's back button close it. Walking near
  something opens nothing. A badge grows and glows when the cat is close enough, and shows a "!" when something there
  is new or affordable.
- **Fight:** tap the signpost and start the next raid. Enemies come down the trails to the edge of the firelight and try to
  put out the campfire; the cat shoots by itself. Between waves, the signpost calls the next one. Small arrows at the
  screen's edge point toward foes off the screen (one per direction; one pulses when a building is hit from that side).
- **Build:** buy acorn towers and thorn spikes in the shop. Tap the build button, walk the ghost piece where you
  want it and tap Place. After raid 1, tap an open road pad between waves to build a three-piece barricade for
  90 leaves and 5 timber. Gate pads open at Hearthtree 1, middle pads at 3, and far pads at 4 on the right and 5 on
  the left. Tap a built row to repair it, including during a wave.
- **Upgrades are gated:** the home level (grown in the shop) caps every station and defence, and each station's level
  caps what it sells (see the plan, section 4).
- **Replays (23 Nov 2026):** completed Raid Missions remain available. Repeat completion pays the configured 50%
  of the first-clear completion reward plus normal wave/chest rewards; unique progression and gifts never duplicate.
- **Home goals:** each home level (2 to 8) has a goal list in `balance.json` (`stations.camp.levels[n].goals`). The home
  grows only when every goal is met and the price is paid. The home's card has a "Grow the home" section: a tick or
  progress per goal, a Go button (walks the cat to the building that sells it) or Show, and the Grow button. The badge
  shows "!" when the home can grow.
- **No gates (21 Nov 2026):** every raid's `needs_home` is 1, so the next raid opens as soon as the one before it
  is won (before, raids 3, 7, 11 and 14 needed home 2-5). Home 2 needs raid 2 won, home 3 raid 6,
  home 4 raid 10, home 5 raid 13, home 6 all 15 and the Gloomwood cleared once, homes 7 and 8 Gloomwood levels 2
  and 3.
- **Roads and waves:** each wave is a surround (all four roads), a pincer (two) or a rush (one, with a banner); raid 1
  teaches them. Enemies come in bursts and there are no easy waves. Pitchers and Frogs shoot from beyond the cat's reach;
  a Golden Grub and a Gloom Totem sometimes appear; a quick clear, an intact wave and going on early pay a bonus.

## Run it on this PC

```bash
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path "D:\Projects\Project LEAF\game"
```

Start from an empty save: add `-- --fresh` at the end. Open the editor: add `-e`.

## Automated test

Plays the first stage by itself (with a separate test save) and writes screenshots and `report.json`:

```bash
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "D:\Projects\Project LEAF\game" --resolution 540x960 -- --autotest --fresh "--shots=D:\DevCache\tmp\leaf_test"
```

Other modes (add after `--autotest --fresh`):
- `--smoke`: two screenshots of the camp.
- `--gallery`: each enemy close up, walking and attacking.
- `--grow`: the camp at home levels 1, 2 and 3 with defences.
- `--patch=N`: start at patch N (0 to 3) as a player who has come that far, and play its 5 waves.
- Phase C (each logs `EXPECT PASS` / `EXPECT FAIL` lines): `--guardian` (the Moss Warden: freed, its post, fighting,
  wrecking foes first, a charge blocked, knocked down and up again, the Last Stand, the camp falling, the post choice),
  `--guardianab` (Mossback Wakes with and without the Warden), `--garden`, `--cook`, `--fishing`, `--feed` (feeding a
  knocked-out mount), `--camplife` (the camp at home levels 1-6 with everything built).
- Phase D, the Gloom Raids (each logs `EXPECT PASS` / `EXPECT FAIL` lines): `--raid` (a raid held: the warning,
  meeting it early, the leader and the rout, the pay), `--raidloss` (a raid lost: only the damage stays), `--meter`
  (the meter fills only from clamped live play and actions), `--raidsave` (closing mid-raid: it comes back at its
  warning), `--raidresume=1` (with `--fresh`), then `--raidresume=2`, then `--raidresume=3` (a real restart),
  `--raidtypes` (siege, sky, sneak, elite), `--wear` (wear, Patch, Mend some, Mend all), `--shards` (shards and what
  they buy), `--raidintro` (the last raid's first win opens the raids), `--raidshots` (close-ups for review),
  `--raidperf` (with `--quality=low|medium|high`). Debug flags: `--raid-small` (2 short waves), `--raid-type=siege|sky|sneak|elite`,
  `--raid-warn=S`, `--raid-meter=N`.
- The Burrows (Phase E; dungeons as paths since docs/DUNGEON_SPEC.md; each logs `EXPECT PASS` / `EXPECT FAIL` lines;
  the tests are in `scripts/autotest_e.gd`): `--dungeon` (the whole Gloomwood at level 1 walked and fought for real:
  the way in, the sleeping camp waking, the burrow holes, the nook's Gloom-bound chest broken open, the Glowcap
  clearing, the bramble bend, the rolling logs and their chest, the Moonwell (checkpoint, spring, boon, lift), the
  bridge with its moths and elite, the old oak, the gate (checkpoint), Mossback in the arena timed, the seal, the
  chest, the lift home; screenshots at every stop), `--dungeonshots` (every stop and the map from above; run it at
  480x1040, the S24's HUD shape, with `--quality=low` and with `--quality=high`), `--dungeonfall` (a knock-out keeps
  half the satchel), `--dungeonresume=1` (with `--fresh`) then `--dungeonresume=2` (back in at the Moonwell with the
  saved health, boons and satchel; the fights before it stay won, the bridge after it is full again; "Leave it"),
  `--boss` (the arena only: the roots, the boss bar, the adds' cap, a Gloom Dash into a standing stone, the daze and the
  weak spot, the fight timed, the seal, the lift), `--dungeonperf` (with `--quality=low|medium|high`: draw calls and
  fps at the way in, in a pack fight and in the arena beside the camp's), `--dungeontreasure` (a map that ends in a
  treasure clearing: `data/dungeons/test_glade.json`), `--dungeonlevels` (levels 1-5: pools, pack sizes, snappers,
  elites, the boss Gloomtouched from level 4), how hard (19 Nov 2026): `--dungeonstand` (the endgame save's cat walks
  level 1 and just stands and shoots, no dodging, lunches or mount: it must be knocked out before the end; `=god` adds
  1,000 health to measure the health each fight takes and Mossback's time to kill; `=items` rides Thistle, feeds it
  and eats lunches but never dodges: it must still fall), `--dungeoncareful` (the same cat with the mount, lunches,
  dashes through telegraphs and backing off: it must win); `--floormaps=<dir>` saves the night floor's maps as
  pictures; kept from Phase E: `--burrowsave` (the save fields, currencies and
  costs, old saves, the reveal and the keys once, a Phase E room run closed kindly, nothing by time), `--hollow` (the
  sealed hollow from the first raid won, the reveal, the clearing and the path, the card's levels), `--dash` (the
  Leaf Dash, close calls, the flick gesture), `--traps` (log, thorns, crystal, spores, tide on the map; the logs'
  chest shut for a hurt cat), `--burrowfoes` (Grubling, Glowcap, Root Snapper, Amber Grub), `--topup` (mastery, the
  Foxfire Bow, level-5 defences, the Warden's level 4, home levels 7 and 8, the mount's attachments (moved to the Saddlery in G4)), `--burrowhooks` (Phase C and
  D hooks). Phase E's room-only modes (`--burrowroom`, `--burrow`, `--burrowfall`, `--burrowresume`,
  `--boss=bear|chief|grubber`, `--burrowtiers`, `--burrowperf`) are gone with the rooms (`--boss=...` now runs `--boss`).
- The camp's layout and the HUD (18 Nov 2026; each logs `EXPECT PASS` / `EXPECT FAIL` lines; the tests are in
  `scripts/autotest_layout.gd`; run them at 480x1040, the S24's shape, with `--safe-top=73 --safe-bottom=42` for
  `--hudcheck`): `--layout` (the camp round the campfire at home levels 1-8 with every building built: open ground round
  and south of the fire, footprints, the lake, the trails, the Burrow's path, the markers' spots, nothing tall just south
  of where the cat walks, no two markers overlapping on the screen and none covering the cat at a marker's spot;
  top-down and game-camera shots, the walk to every building and a tap from a few metres that walks the cat there, the
  cat at each building before and after a tap), `--layoutsave=1` (with `--fresh`) then `--layoutsave=2` (an old save's
  tower and spikes on the new ground go back to the bag), `--hudcheck` (every card opened by a real tap as a dialog that
  fits inside the phone's bars, its X inside it, closed by its X or a tap outside, once by the back button; the
  signpost, the Watch and a raid's warning, building, a raid with a boss bar, the Gloomwood's cards, pips and arena,
  nothing of the HUD mid-screen), `--taps` (taps and markers, 19 Nov 2026: walking near opens nothing, a drag ending
  on a marker or a long press opens nothing, a tap on empty ground does nothing, a tap in reach opens at once and a far
  one walks the cat there first, a drag stops that walk, a tap on the thing itself works, a drag on the dim moves
  nothing, the X, a tap outside, back and Escape close a dialog, the markers far, near, in reach and fading over the
  cat), `--arrows` (a wave with foes off the screen on two trails: arrows toward them, gone after). Tests tap through `autotest.gd` `_tap` / `_use` / `_at_ring`: real touches through `Input`, so the joystick,
  `interact.gd` and the dialogs see what a finger does. `--safe-top=N` / `--safe-bottom=N` (HUD pixels)
  try the phone's status bar and gesture bar on a PC. If the PC's screen is off, add `--disable-vsync` (before `--`):
  otherwise Godot crawls at a few frames a second and the timed tests fail.
- Phase F (19 Nov 2026, home goals and fair raids; each logs `EXPECT PASS` / `EXPECT FAIL` lines; tests in
  `scripts/autotest_f_home.gd`, `autotest_f_fight.gd` and `autotest_f_enemy.gd`): `--homegoals` (the goals of every home
  level, no raid gate, the home's card and its Go / Show rows, the badge), `--fightf` (patterns, the teaching roads, no easy
  waves, manual starts, rewards, wave checkpoints, restart/loss retries, legacy saves, Gloom Raids, the gate, a live
  wave with the Golden Grub and the bonuses, the Gloom fade; 90 passes), `--enemyf` (the boar's daze, the
  pitcher and frog standoff, the Golden Grub, the totem's buff). `fight.skip_gate` (tests only) lets an older test start
  any raid; older tests that start a won raid (replays) or one past the home gate after `_veteran` fail or need it.
  Run them one after another, never in parallel (they share the test save).

**New (21 Nov 2026, G3):** `--bowshop` (`scripts/autotest_g3_bow.gd`): the Bow Shop card, buying (leaves and timber),
upgrading, equipping only between waves, Sunwood's pierce, Volley's fan, Ember's burn (and no burn while frozen), each
bow's own model and arrow in the cat's paw, and close-up shots `bowshop_<id>.png`. Current PC result: 77 pass,
including the stronger late upgrades, real arrow/burn damage and leaf affordability (23 Nov 2026).

**New (21 Nov 2026, G4):** `--saddlery` (`scripts/autotest_g4_saddle.gd`): the Saddlery card, its skills and attachments
(buying, upgrading, the caps by the Saddlery's level). Results on the PC: 44 pass. `--topup` was updated for the saddle
that moved to the Saddlery: 15 pass, 8 fail. The 8 are older stat, bow, mastery and home-7-8 expectations from before
Phase F's caps, not from G4.

The supplies inventory is covered by `--inventory` (`scripts/autotest_inventory.gd`, 53 PC passes). It checks the shared
slot grid, currency layout, cat and ridden-mount preview, touch input, food counts, harvesting, cooking, Market purchases,
live enemy movement, healing, dungeon resume and older saves. Run after `--smoke`, sequentially, with `--disable-vsync` before `--`.

Mounted targeting is covered by `--mountedaim` (`scripts/autotest_mounted_aim.gd`, 69 PC passes). It checks real arrows at wide
bearings on both mounts, torso aiming above a forward-facing root, hips and feet, outfits with different bows,
rear blind spots, left/right steering with the forward gait, target reacquisition, Ram direction and dismounting
mid-shot. The Saddlery mode passed 94 checks, including flame-ball splash, upgrades, firing pace, arrow range and tracking while steering.

## Debug start: the endgame (debug builds only)

The raids and the Burrows open only after all 15 raids are won. To play them at once, start a debug build with
`--endgame` (on the PC: `... -- --endgame`; on the phone: a line `--endgame` in the app's `files/test_args.txt`, as
for the other phone test arguments). It opens a **separate save** (`user://leaf_save_endgame.json`), never the real
one: every raid won, home level 5, a grown cat (Target and Bench at 5, Well, Cottage, Stall and Garden at 3; an older endgame save keeps its levels until `--endgame --fresh`), 8,000 leaves, 300 timber, 60 Gloom shards, 3 Hollow keys, food in
the pantry and the Burrows open (the Moss Warden is not there yet: it is found in the first Burrow). The HUD says
"Endgame test save" at the top left. The slot stays on at every launch until a launch with `--endgame-off`; then the
real save is back, untouched. `--endgame --fresh` starts the endgame save over. Release builds ignore both.

## Android

```bash
"D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\Projects\Project LEAF\game" --export-debug "Android" "D:\Projects\Project LEAF\game\build\ProjectLEAF.apk"
```

## What is where

| File | What it does |
|---|---|
| `data/balance.json` | Every number: enemies, waves per patch, upgrade prices, caps per station level, bows, defences |
| `scripts/main.gd` | Builds everything and ties it together: camera, the markers and their cards, leaves, respawn, stage events |
| `scripts/marker.gd` | A thing the cat can use: the leaf-shaped badge floating over it (its icon drawn from SVG in code), small and dim far away, big and glowing in reach with a rim glow on the thing, a "!" when something there is new; its reach |
| `scripts/interact.gd` | Taps: a short touch that barely moves picks the marker (or the thing) under it and opens its card, or walks the cat there first |
| `scripts/world.gd` | The map: light, sky and fog, ground, the firelight (the safe camp), trails, woods, the Gloom, collision |
| `scripts/stations.gd` | The camp: the tree home and its shop card, the campfire's fire, Training Target, Bow Shop (New, 21 Nov 2026, G3: the Bow Bench), the Saddlery (New, 21 Nov 2026, G4: its card and items), signpost |
| `scripts/mount.gd` | New (21 Nov 2026, G4): the mount's skills (Stomp, Ram, Pounce, Bellow) and attachments (Fire-spitter, Mossweave Saddle, Saddlebags) on their own timers, and the Pounce and Ram movement; the mount has no built-in move of its own |
| `scripts/defences.gd` | Road barricades, towers and spikes: buying, placing (the ghost; barricades at the road spots), levels, enemies hitting them |
| `scripts/fight.gd` | Stages and waves, the campfire's health, winning and losing, the first stage's unlocks; Gloom Raids run here too (mode "raid") |
| `scripts/raids.gd` | The Gloom Raids after the raids: the meter, the plan, the warning, pay, the camp check and Mend all, the Watch card, nothing while closed |
| `scripts/enemy.gd` | All enemies: loads `assets/enemies/<id>/<id>.glb` and its JSON, or a placeholder; their behaviour |
| `scripts/player.gd` | The Cat Ranger from the prototype, with upgrades, bows, respawn; New (21 Nov 2026, G3): swaps the equipped bow's model into the cat's bow bones |
| `scripts/arrow.gd` | New (21 Nov 2026, G3): the cat's arrows, one per bow (the Ember Bow's flame trail; `launch(..., burn, bow_id)`); a plain arrow when a bow has no file |
| `scripts/hud.gd` | Leaves, timber, the fight, banners, tips and the cards (dialogs in the middle of the screen, with a close button) |
| `scripts/threat_arrows.gd` | The arrows at the screen's edge toward foes off the screen in a wave, a raid or below ground |
| `scripts/grass.gd` | Grass that bends away from whoever walks through it |
| `scripts/burrow.gd` | The Burrows in the camp (Phase E): each hollow (sealed, the reveal, its marker and card with the levels), Hollow keys |
| `scripts/burrow_run.gd` | A Burrows run (`main.area` while the cat is in a dungeon): fights (packs and spawners), checkpoints, chests, the Moonwell, boons, the boss and its arena, the satchel, the Moss Warden's seal, the camera, saving and resuming |
| `scripts/dungeon_map.gd` | One dungeon's map built from `data/dungeons/<id>.json`: the path, clearings and arena (the walkable ground for `constrain`), the night woods kept off the camera's side, lanterns, glow caps, halos and fireflies, the stream and bridge, the gate, the stones |
| `scripts/night_floor.gd` | A dungeon's night floor (its map's `floor` block): one plane drawn by `shaders/night_ground.gdshader` (`_lite` on Low) from a ground map, a light map (the lanterns' and torches' pools baked in) and a style map (the road's sections); torches, stone lanterns, barrels, relics, roots, the arena's swords and rune stones, grass tufts and big leaves |
| `scripts/trap.gd` | Burrows traps in their own frame on the map: rolling logs, thorn plates, falling crystals, spore vents, the Gloom tide |
| `data/dungeons/old_hollow.json` | The Gloomwood's map (the first Burrow); `test_glade.json` is a tiny treasure-end map for the tests |
| `scripts/guardian.gd` | The Moss Warden (Phase C): its post, punches and slams, crumbling and pulling itself together, a walk path round the camp |
| `scripts/garden.gd`, `scripts/cooking.gd` | The garden (grows a step per wave held) and the cooking pot (one dish, eaten when the next chapter starts) |
| `scripts/fishing.gd`, `scripts/fishing_ui.gd` | Fishing at the lake between waves: cast, wait, tap on the bite, reel in the green |
| `scripts/fx.gd` | Leaf bursts, confetti, flower rings, petals, damage numbers, the boss's shockwave |
| `scripts/props.gd` | Loads Blender-made props from `assets/props/` with the shared vertex-colour material, or builds placeholders |
| `shaders/` | vertex-colour look (with the Gloom tint and hit flash), grass, ground, the markers' rim glow, mist |
| `assets/cat/` | The Cat Ranger, copied from `D:\3D Modeling Test\CatRangerGame` |
| `assets/enemies/`, `assets/props/` | Models made in Blender (see `../docs/ASSET_RULES.md`). A missing one shows as a placeholder |
| `assets/sfx/` | Placeholder sounds made by `../tools/make_sfx.py` |

The cat's cloth simulation depends on the frame rate, so `project.godot` caps it at 60.
