# Project LEAF change log

Each merged branch adds an entry here, newest first.

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
