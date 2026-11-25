# Performance and graphics levels

Work from 17 Nov 2026, to make Project LEAF run on weaker phones. This covers what changed for every level, what each
graphics level does, the measured results and how to run the benchmark.

## What changed for every level

- **Woods and trail scatter in 10 m cells** (`world.gd` `_scatter_cells`). Each kind of tree and plant used to be
  one MultiMesh round the whole map. Its box was never off screen, so all 270 trees and the undergrowth were drawn
  every frame and again in every shadow pass. With cells, what is off screen is skipped. Flowers, pebbles,
  mushrooms and small rocks no longer cast shadows (`NO_SHADOW`).
- **One shadow map for the sun** (`SHADOW_ORTHOGONAL`, 36 m), instead of four splits. The camera is 21.5 m away and
  looks 50° down, so the ground in view is 17–34 m off. The first two splits only covered the empty air in front of
  the lens.
- **Cloth fit** (`cloth_fit.gd`, which keeps the hero's hood, capelet and skirt off the body) was the biggest single
  CPU cost of a camp frame: about 1 ms on a desktop CPU, many times that on a phone. It now keeps its data in typed
  fields. It also groups its point tests by guard and skips a guard when a sphere round the whole panel is clear of
  it. It was checked frame by frame against the old version: the same 12,481 corrections over 666 frames, with at
  most 0.08° of rounding difference.
- **OpenGL fallback** (`rendering/rendering_device/fallback_to_opengl3=true`): phones without working Vulkan run the
  Compatibility renderer. That path was tested on the PC with no errors, and it picks Low by itself.

## Graphics levels (`scripts/quality.gd`, autoload `Quality`)

|                         | Low                                | Medium            | High          |
|---|---|---|---|
| 3D resolution           | about 540 px across (bilinear)     | about 810 px across (FSR 1) | full |
| MSAA                    | off                                | 2x                | 2x            |
| Sun shadows             | off; a soft blob under each character (`Fx.blob`) | 1024 px | 2048 px |
| Glow                    | off                                | off               | on            |
| Ground shader           | `ground_lite` (no cobbles, shore pebbles or cloud shadows; fewer noise layers) | full | full |
| Grass                   | 40% (tall hiding grass 70%), 5 blades per tuft | 70%   | 100%          |
| Lantern and home lights | off (the campfire light stays)     | on                | on            |
| Sunrays in the woods    | off                                | on                | on            |
| Particles               | 50%                                | 80%               | 100%          |
| Spring bones on enemies | off                                | on                | on            |
| Cloth fit worked out    | every 3rd frame                    | every 2nd frame   | every frame   |

The UI is always drawn at the phone's full resolution. On a frame where the cloth fit is not worked out, each bone
gets its last correction again, measured from what the bone hangs on.

**Picking the level.** On the first launch `Quality.detect()` guesses from the phone:
- the Compatibility renderer (no Vulkan) → Low;
- under 3.5 GB of memory or 4 cores or fewer → Low;
- under 5.5 GB → Medium at most;
- otherwise the GPU decides: Adreno, Mali, Xclipse, Immortalis, PowerVR;
- desktop → High.

The S24 (Xclipse 940) gets High. While the level is still the game's own pick, it watches the frame rate in 4 s
windows. Two slow windows in a row (under 48 fps) step it down one level and show a toast. At Low it holds a steady
30 fps instead. The player can set Auto, Low, Medium or High on the Shop card ("Graphics"). The choice is kept in
`user://settings.json`, apart from the save, so a new game keeps it.

## Measurements

### PC (RTX 3070, window 450×800, frame rate uncapped)

| | Before | After, High | After, Medium | After, Low |
|---|---|---|---|---|
| Camp: triangles per frame | 1.77 M | 247 k | 219 k | 86 k |
| Camp: draw calls | 178 | 156 | 152 | 95 |
| Camp: frame time | 1.86 ms | 1.26 ms | 1.04 ms | 0.9–1.1 ms |
| Fight (17 enemies): triangles | 1.89 M | 373 k | 349 k | 144 k |
| Fight: frame time | 2.94 ms | 2.08 ms | 1.85 ms | 1.5–1.6 ms |

The cloth fit took about 1.0 ms per frame before. It now takes 0.46 ms on High and about 0.25 ms on Medium and Low.

### Phone: Galaxy S24 (SM-S921B, Xclipse 940, 1080×2340, 120 Hz), final build

| | High | Medium (3D at 0.75) | Low (3D at 0.5) |
|---|---|---|---|
| Camp: fps | 81 | 120 (screen limit) | 119 (screen limit) |
| Camp: GPU time | 9.95 ms | 4.1 ms | 4.0 ms |
| Camp: triangles / draw calls | 297 k / 192 | 255 k / 181 | 100 k / 122 |
| Fight: fps | 114 | 114 | 116 |
| Fight: GPU time | 6.4 ms | 5.9 ms | 3.8 ms |
| Video memory | 234–249 MB | 166–181 MB | 126–142 MB |

The game itself is capped at 60 fps, so the S24 has plenty of headroom on High. When a phone sits at the screen's
limit, its GPU clocks down. That is why Medium and Low read about the same GPU time here, although Low draws a third
of the pixels and triangles. A weaker GPU would show the gap.

There is no phone "before" figure, because the APK from before this work had no benchmark mode. On the PC, the same
scene went from 1.77 M to 247 k triangles on High.

## H1: the pools (25 Nov 2026)

Arrows, damage numbers, text pop-ups, hit bursts and sprays, and leaf and timber pickups are now reused instead of
created and freed (`game/core/pools.gd`). Shockwave, swipe, flower_ring and bellow share one mesh and one material per
colour. Measured with `--perf` on the PC, quality High:

| Scene | Before | After |
|---|---|---|
| Camp | 2.2 ms frame (p95 2.38) | 1.88 ms (p95 2.08) |
| Fight, 17 foes | 4.02 ms (p95 6.27) | 2.94 ms (p95 3.70) |

Phone numbers are still to come. Pool sizes (`balance.json` `pools`) are first guesses, to be measured on the phone.

## Running the benchmark

The autotest mode `--perf` (in `autotest.gd`, `_perf` and `_measure`) builds a grown camp and measures 6 s standing
in the camp and 6 s walking through the meadow. Then it measures 8 s of a fight with 18 enemies that never die. It
logs `PERF <part> {...}` lines and writes `perf.json` and screenshots to the shots folder. It records:
- fps, average frame time and 95th-percentile frame time;
- GPU time and render CPU time;
- draw calls, triangles and objects;
- video memory.

`--perfdiag` also turns parts off one by one: cloth fit, cloth, companions, HUD and stations, player, then all
logic; and in the fight, enemy logic, enemy animation and the enemies themselves. That shows what each part costs.

**PC:**

```
Godot_v4.7.2-stable_win64_console.exe --path . -- --autotest --fresh --perf --quality=high --shots=D:/DevCache/tmp/perf_high
```

`--quality=low|medium|high` sets the level for that run only. Without it, a test runs at what `detect()` picks,
and tests never step down or save settings. To run on the OpenGL fallback, add
`--rendering-method gl_compatibility` before `--path`.

**Phone (debug build):** the launcher (`GodotAppLauncher`) does not pass intent extras on, so `Data.args()` also reads
a one-shot file `user://test_args.txt`, one argument per line, and deletes it. Every script uses `Data.args()`, not
`OS.get_cmdline_user_args()`. From Git Bash, with `MSYS_NO_PATHCONV=1` so the phone paths are not rewritten:

```
printf -- "--autotest\n--fresh\n--perf\n--quality=high\n" > args.txt
adb push args.txt /data/local/tmp/test_args.txt
adb shell run-as com.projectleaf.game cp /data/local/tmp/test_args.txt files/test_args.txt
adb shell am start -n com.projectleaf.game/com.godot.game.GodotAppLauncher
# about 60 s later:
adb logcat -d -s godot:* | grep PERF
adb exec-out run-as com.projectleaf.game cat files/autotest/perf.json
```

`--fresh` uses `leaf_save_test.json`, so the player's real save is never touched. Keep the phone's screen on while a
test runs.

## Phase C (18 Nov 2026): the Moss Warden, the garden, cooking and fishing

New per-frame costs: the Moss Warden thinks 4 times a second (one fetch of the foes group), moves, pushes the foes
within 3 m out of its body and follows a walk path planned only when its goal moves (AStarGrid2D over the camp's
footprints, cached until a footprint changes). Its spring chains run only on Medium and High. The garden and cooking
have no per-frame code (the plants are one merged mesh, rebuilt when a plot changes; a glint only while something is
ripe). Fishing runs code only while a line is out. The lake fireflies follow the particle share.

`--perf` on the PC (RTX 3070, `_veteran(6)`: garden, pot and Fishing Spot in the camp; `--warden` adds the Moss
Warden at its post):

| | High | High + Warden | Low | Low + Warden |
|---|---|---|---|---|
| Camp: frame time / triangles | 1.34 ms / 252 k | 1.39 ms / 251 k | 0.95 ms / 88 k | 0.95 ms / 88 k |
| Fight (17 enemies): frame time / triangles | 2.12 ms / 384 k | 2.23 ms / 395 k | 1.47 ms / 155 k | 1.56 ms / 157 k |

The Warden costs about 0.1 ms in the fight, inside the spec's 0.3 ms target. Not yet measured on the S24.

## Phase D (18 Nov 2026): the Gloom Raids

Per-frame costs that are new:
- `raids.tick` is O(1). The meter is saved quietly about once a minute.
- The Watch's crystal is updated only when the meter has moved 0.4 points.
- The HUD's raid bar redraws only when what it shows changes (half a meter point, a second of the countdown). It
  redraws every frame only while it pulses.
- `lane_guard` and `camp_check` run only at stir, at the horn, at wave 1 and when a card is built.

Live enemies in a raid are capped by graphics level: Low 18, Medium 24, High 28 (`gloom_raids.max_alive_by_quality`).
The rout drops at most 12 leaf pickups and makes at most 8 petal bursts on Low. The shard shower is at most 8 pickups
(4 on Low). No new lights: Shardfire recolours the fire's own light. Rubble is at most 3 piles per worn building.

`--raidperf` on the PC (RTX 3070, the default window, uncapped). The camp is a veteran with every mission won, facing
a level 23 siege raid on two trails (strength 3.81, waves of 16 / 20 / 14). Each level was measured for 30 s of wave 1
while the cat holds a trail mouth:

| | High | Medium | Low |
|---|---|---|---|
| Raid wave: frame time / p95 | 1.76 ms / 2.08 ms | 1.48 ms / 1.67 ms | 1.23 ms / 1.39 ms |
| Triangles / draw calls | 319 k / 189 | 286 k / 189 | 81 k / 100 |

These are below the 17-enemy mission fight above, so a raid costs no more than a mission. Not yet measured on the
S24: run `--raidperf --quality=low` there (through `user://test_args.txt`).

## Phase E (18 Nov 2026): the Burrows

A room is built in code 400 m from the camp (beyond the camera's far plane and the sun's shadow box, so the camp is not
drawn while the cat is below ground). Only one room exists at a time; walls, the south lip, corners and dressing are one
MultiMesh per prop kind; doors, pillars, chests, the spring, shrines and lifts are props. No lights are needed (glowing
faces are bright vertex colours); Sprig's lantern glow is an unshaded disc and floor pool, plus one OmniLight on Medium
and High only. Live monsters are capped by graphics level (`burrows.max_alive_by_quality`: Low 8, Medium and High 10)
plus the boss and at most 4 of its minions. Every Burrows timer clamps its frame time to 0.1 s.

`--burrowperf --quality=low|medium|high` on the PC (RTX 3070, 540x960, uncapped): the camp (6 s), then the busiest den
of the Gloomheart (depth 5) for 10 s with the room full of awake monsters (the test spawns past the cap: 11 on Low, 13
on Medium and High) while the cat moves:

| | High | Medium | Low |
|---|---|---|---|
| Camp: frame time / triangles / draw calls | 1.36 ms / 248 k / 176 | 1.13 ms / 219 k / 172 | 0.98 ms / 88 k / 106 |
| Busiest den: frame time / triangles / draw calls | 2.10 ms / 170 k / 162 | 1.80 ms / 170 k / 162 | 1.54 ms / 77 k / 127 |

The den draws fewer triangles than the camp at every level, but on Low it has more draw calls (127 against the camp's
106; the spec hoped for 80 or fewer). The monsters are most of it (each skinned model is several draw calls); a full
den is the worst case, most rooms hold fewer. The CPU time per frame is about 9 ms in the busiest den (the camp: 3-6
ms), mostly the monsters' thinking. Not yet measured on the S24: run `--burrowperf --quality=low` there (through
`user://test_args.txt`) and lower `max_alive_by_quality` if it stutters.

## The Gloomwood (18 Nov 2026): dungeons as paths

The numbers in this section are from 18 Nov 2026, before the night road and the harder rework of 19 Nov (the boss's adds are now
capped at 6, not 4, and live monsters at 8 / 12 / 12 on Low / Medium / High). The 19 Nov numbers are in the next block.

A Burrow is now one map built in code 400 m from the camp (`dungeon_map.gd`, from `data/dungeons/<id>.json`): the
first time the cat goes in it is built behind the fade (about 0.45 s on the PC), then it is kept hidden and reused.
Ground in 16 m cells, and the woods, path dressing, lanterns, glow caps, crystals and holes as MultiMeshes in 14 m cells,
one per kind (the camp's way, a little bigger: what is off screen is culled, with fewer draw calls). Halos, pools of light and fireflies are three MultiMeshes with an
additive unshaded shader (`night_glow.gdshader`), the same on every level; on Medium and High three OmniLights follow
the lanterns nearest the cat (with Sprig's, four lights at most). Packs spawn asleep only when the cat comes within
28 m; the boss's adds are capped at 4 and live monsters per pack by graphics level (8 on Low, 10). Monsters steer round
the path's bends with a check 4 times a second.

`--dungeonperf --quality=low` on the PC (RTX 3070, 480x1040, uncapped): the camp (6 s), then the Gloomwood at the way
in (6 s), the Glowcap clearing with its pack awake and more spawned to the cap (10 s) and the arena with Mossback and
its adds (10 s):

| | Camp | Way in | Pack fight | Arena |
|---|---|---|---|---|
| Draw calls | 120 | 107 | 145 | 118 |
| Triangles | 94 k | 114 k | 131 k | 113 k |
| Frame time / p95 | 1.12 / 1.39 ms | 1.50 / 1.67 ms | 2.22 / 2.78 ms | 1.62 / 2.08 ms |
| CPU (process) | 2.7 ms | 2.4 ms | 9.7 ms | 4.2 ms |
| Monsters | 0 | 5 asleep | 16 (8 awake) | Mossback and its adds |

The busiest spot draws 1.21 times the camp's draw calls on Low; it draws more triangles (the bigger cells cull more coarsely), which Low handles easily. The
monsters are most of the CPU time in a fight, as in Phase E. Not yet measured on the S24: run `--dungeonperf
--quality=low` there (through `user://test_args.txt`).

**After the night road (19 Nov 2026)**, `--dungeonperf --quality=low` on the PC (draw calls / frame ms; measured before the
arena rim and the last light pass, and not rerun since): way in 107.4 / 1.65 before, 103.6 / 1.48 after; pack fight
149.8 / 2.38 before, 144.0 / 1.93 after; arena 115.7 / 1.75 before, 112.1 / 1.68 after. The map's first build takes about
0.76 s (0.46 s before). The night floor is one plane drawn from three baked maps (`night_floor.gd`; `_lite` shader on Low).
