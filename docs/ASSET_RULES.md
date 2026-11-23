# Project LEAF: rules for 3D assets

Every model in the game follows these rules, so it drops into the Godot project (`game/`) without changes. The game is
Godot 4.7.2, the mobile renderer, on Android phones in portrait. Blender is 5.2 at `D:\Blender\blender.exe`.

## This PC

- Work files go on D: (`D:\DevCache\tmp\<id>\`). C: has room again since 21 Nov 2026, so setting `TEMP` and `TMP` to
  `D:\DevCache\tmp` for Blender runs is optional.
- Run Blender headless: `D:\Blender\blender.exe -b <file> --python-exit-code 1 -P <script.py> -- <args>`.
- Use the Blender skills on this machine (Skill tool): `blender-core` first, then the skill for the task
  (`blender-game-optimization`, `blender-character-rigging`, `blender-animation`, `blender-export-pipelines`,
  `blender-hardsurface-modeling`, `blender-asset-qa`, and others).
- Do not run Godot on `game/`. Several people work at the same time, and the lead imports and tests in Godot.

## The look

- Low-poly with **visible facets**: flat shading (faces not smooth), chunky cute proportions, bright saturated matte
  colours. This is the same style as the Cat Ranger hero (`D:\3D Modeling Test\CatRanger\reference\concept_sheet.png`).
- **Colour = one flat colour per face**, stored as a colour attribute (domain CORNER, the active colour attribute),
  **not textures and not UVs**. Every mesh gets one material named `M_VertexColor` (a Principled BSDF whose Base
  Color comes from the colour attribute, roughness 1). In the game, every asset shares one shader that reads the vertex
  colour. That makes everything batch well and lets the game tint things, for example the violet Gloom or a white hit
  flash.
- Props use the shared colours in `art/palette.json`. Enemies take their colours from their concept images, staying
  close to the palette where they overlap (wood, leaves, violet crystals).
- Glowing parts (eyes, crystals, flames, lantern glass) are ordinary faces in a bright colour. The game adds the glow.

## Scale and orientation

- 1 Blender unit = 1 metre, Z up. Apply all transforms before export (scale 1, rotation 0).
- **Front faces Blender −Y** (which is Godot +Z, the same as the cat). For a building, the front is the side with the
  door or the work surface, where the player stands to use it.
- **Origin at ground level** (Z = 0, the lowest point of the feet or base sits on Z = 0), centred on the footprint.
- The hero cat is **1.235 m** tall (to the tip of the ears) and about 7,300 triangles. Size everything against it.

## Triangle budgets

The game puts up to about 40 enemies on screen.

| Asset | Max triangles |
|---|---|
| Thornling | 2,500 |
| Toadstool Brute, Raccoon Bandit, Bramble Boar | 6,000 each |
| Mossback (boss) | 12,000 |
| Gloom Moth | 3,000 |
| Frog Shaman, Beetle Knight, Crystal Snail | 5,000 each |
| The Owl Witch (boss) | 10,000 |
| Puffball Bomber | 3,000 |
| Pitcher Spitter | 4,000 |
| Stump Golem, Mole Sapper, Crow Drummer, Bramble the trader | 5,000 each |
| The Elder Thornstag (boss) | 12,000 |
| Grubling, Amber Grub (Phase E, the Burrows) | 2,000 each |
| Glowcap (Phase E) | 3,000 |
| Root Snapper (Phase E) | 3,500 |
| ~~Old Grubber (Phase E boss)~~ removed 19 Nov 2026 | - |
| Lumi (pet) | 3,000 |
| Bramblewool (mount) | 6,000 |
| Sprig (pet) | 3,000 |
| Thistle (mount) | 6,000 |
| Moss Warden (guardian) | 6,000 |
| Building | 3,000 (the treehouse, including its giant tree: 6,000) |
| Fence or palisade segment, gate | 600 |
| Defence (tower, spikes, bramble fence) | 1,500 |
| Big tree | 1,500 |
| Bush, rock | 300 |
| Fern, flower, mushroom, grass clump | 150 |
| Pickup or projectile (golden leaf, acorn) | 100 |

## Enemies: skeleton and animation

- Ids: `thornling`, `brute`, `raccoon`, `boar`, `bear`, and for the later woods `moth`, `frog`, `beetle`, `snail`, `owl`,
  and for the missions `stump`, `pitcher`, `mole`, `puffball`, `crow`, `stag`.
- The later enemies, the pet and the mount start as untextured Meshy 6 Lite meshes (`art/source/meshy/`). They are
  cut down to the budget, then coloured per face from their concept image (`concepts/enemies2/`, `concepts/companions/`).
- Output: `game/assets/enemies/<id>/<id>.glb` and `game/assets/enemies/<id>/<id>.json`.
- Working file: `art/blender/enemies/<id>.blend`. Scripts: `art/scripts/enemies/<id>/`. Preview renders:
  `art/previews/enemies/<id>/`.
- One armature named `RIG_<id>` with a root bone `root` at the origin. One skinned mesh named `SK_<id>`. Deform
  bones only in the export (no control or mechanism bones).
- **Spring bones:** the parts that should swing in the game (tails, cloth, leaves, ears, caps, manes) get chains of
  bones named `jig.<part>.<n>` (for example `jig.tail.1`, `jig.tail.2`, `jig.tail.3`), with a parent body bone. They
  stay still in the clips, because the game simulates them (Godot `SpringBoneSimulator3D`). Each chain is listed in
  the JSON.
- **Clips** (Blender actions, exported as glTF animations with exactly these names). They are in place, with no root
  motion. `Idle`, `Walk`, `Run` and `Charge` loop, and the rest play once. All are 30 fps.

| Enemy | Clips |
|---|---|
| all | `Idle`, `Walk`, `Attack`, `Hit`, `Die` |
| raccoon | + `Run`, `Grab` (bends down and snatches something from the ground) |
| boar | + `Windup` (paws the ground, head down, about 0.8 s), `Charge` (fast gallop) |
| bear | + `Slam` (both paws smash the ground), `Roar` |
| moth | it flies: `Idle` hovers with flapping wings, `Walk` is the flying-forward loop, `Attack` a quick dive and bite. Origin under the body (the game lifts it 1.05 m) |
| frog | + `Cast` (raises the staff, the crystal flares; event `cast`) |
| beetle | `Attack` is a spear thrust; the shield stays on the front-left arm |
| snail | `Attack` is a headbutt; optional `Slam` (the shell's crystals burst; event `impact`) |
| owl | + `Cast` (staff up, wings out; event `cast`), `Roar` (hoots with wings spread; event `roar`) |
| stump | `Attack` is a double-fist smash down at a building (event `hit`) |
| pitcher | `Attack` is the thorn spit (leans back, snaps the mouth forward; event `hit` = the spit) |
| mole | + `Dig` (burrows down until hidden, ~0.8 s) and `Emerge` (pops up out of the ground, ~0.6 s) |
| puffball | `Attack` is the burst: it swells up and pops (event `hit` = the pop) |
| crow | + `Drum` (loop ~1 s, beats the drum; event `beat` = the buff pulse) |
| stag | + `Windup` (paws the ground, antlers down, ~0.9 s), `Charge` (loop), `Slam` (rears and stamps; event `impact`), `Roar` (bellow; event `roar`) |
| grub (Phase E) | + `Emerge` (pops up out of the ground, ~0.6 s) |
| glowcap (Phase E) | + `Cast` (throws the spore ball overhand; event `cast`) |
| snapper (Phase E) | + `Windup` (the jaws gape, 0.7 s); `Attack` is the lunging bite (event `hit`); `Walk` a copy of `Idle` (it never moves) |
| amber_grub (Phase E) | + `Run`, `Dig` (burrows away, ~0.8 s); it never attacks (`Attack` may be a copy of `Idle`) |
| ~~grubber (Phase E boss)~~ removed 19 Nov 2026 | (was: + `Dig` (~0.8 s), `Emerge` (~0.7 s; event `impact`), `Windup` (curls into a ball, ~0.9 s), `Charge` (rolling loop), `Roar` (event `roar`); spring bones `jig.lantern.*`, `jig.roots.*`) |

- Animation style: lively and cartoony, with a clear pose and readable from far above, because the game camera looks
  down at about 50°. Weight shifts, overlap and anticipation. Keys on rotation and location only (no bone scale).
  `Die` ends collapsed on the ground.
- `<id>.json` (numbers in metres, seconds and metres per second):

```json
{
  "id": "raccoon",
  "fps": 30,
  "height_m": 1.2,
  "radius_m": 0.3,
  "aim_height_m": 0.6,
  "clips": {"Walk": {"seconds": 0.8, "loop": true}, "Attack": {"seconds": 0.7, "loop": false}},
  "ground_speed_m_per_s": {"Walk": 0.9, "Run": 2.4},
  "events": {"Attack": {"hit": 0.35}, "Grab": {"grab": 0.3}},
  "spring_chains": [{"root": "jig.tail.1", "end": "jig.tail.3", "stiffness": 2.0, "drag": 0.4, "gravity": 0.3, "radius": 0.05}],
  "tris": 5400
}
```

- `ground_speed_m_per_s` is how far the feet travel per second at playback speed 1, so the game can match the feet to
  the move speed.
- `events` are the moments the game needs: `hit` (the attack lands), `impact` (Slam), `grab`, and `roar`.
- `radius_m` is the body radius seen from above, for collisions. `aim_height_m` is where arrows aim (mid-body).

## Pet and mount

- Ids: `sprig` (the baby leaf dragon, about 0.4 m) and `thistle` (the giant hare, about 1.2 m at the shoulder).
- Output: `game/assets/companions/<id>/<id>.glb` and `<id>.json` (same JSON as an enemy). Same skeleton rules.
- Clips: sprig `Idle` (hovering), `Fly` (loop), `Attack` (spits a seed); thistle `Idle`, `Run` (loop, hopping),
  `Thump` (rears and stamps).
- Every mount has the same clips (`Idle`, `Run`, `Thump`) and a `saddle` bone; `Thump` is its signature ability and
  each mount plays it its own way (Bramblewool lowers its horns and rams). Every pet has `Idle`, `Attack` and either
  `Fly` (fliers) or `Run` (walkers, like Lumi). Same numbers for every look: only the visuals differ.
- New ids: `bramblewool` (the woolly ram mount) and `lumi` (the fox-kit pet), in `game/assets/companions/<id>/`.
- Guardians (Phase C): `moss_warden` in `game/assets/companions/moss_warden/` (6,000 triangles, 2.1 m, `radius_m`
  0.6). Clips `Idle`, `Walk`, `Sit` (loops), `Punch` (event `hit`), `Slam` (event `impact`), `Hit`, `Crumble` (event
  `down`; its last frame is the sleeping heap), `Reform` (event `up`). Spring chains `jig.*` run only on Medium and
  High. Every guardian look has exactly these clips and events; all numbers come from balance.json `guardian`.
- NPCs: `trader` (Bramble the hedgehog) in `game/assets/npcs/trader/`, clips `Idle` (loop), `Wave`, `Talk` (loop). Thistle's JSON adds `saddle_height_m`: the top of the saddle, where the cat stands.

## Props and buildings

- The village: `wishing_well`, `mushroom_cottage`, `market_stall` (3,000 triangles each; front faces −Y).
- Camp life (group `camp_life`, Phase C): `guardian_stone` (1,500; parts `rune_1`-`rune_3`), `garden_bed` (2,000; `marker_plot_1`-`6`), `cook_pot` (600; `marker_steam`), `fishing_spot` (900; part `rod`, `marker_tip`), `fishing_rod` (100; origin at the grip, `marker_tip`), `plot_weeds` (150), `soil_wet` (20), `plant_sprout` (60), the crops `<crop>_growing` / `_ripe` (150 each), the catches `fish_*`, `driftwood`, `sunken_chest` (100 each); front faces −Y.

- Output: one GLB per prop in `game/assets/props/<name>.glb`, plus one list per group: `game/assets/props/<group>.json`.
- Working file: `art/blender/props/<group>.blend`. Scripts: `art/scripts/props/<group>/`. Preview renders:
  `art/previews/props/<group>/`.
- **Parts the game moves are separate objects with set names**, with their origin at the pivot:
  - campfire: `flame`
  - gates: `door_L` and `door_R`, origin at the hinge
  - acorn tower: `turret`, origin on its turning axis. Its front faces −Y.
  - flags and banners: `banner`, origin at the pole
- **Markers** are empties exported as nodes: `marker_ring` (where the "use me" ring goes on the ground in front of a
  building) and `marker_shoot` (where a tower's acorn leaves the turret).
- `<group>.json` lists every prop:

```json
{"props": [{"name": "home_tent", "file": "home_tent.glb", "size_m": [2.0, 1.8, 1.7],
  "collision": {"shape": "box", "size_m": [1.8, 1.5]}, "tris": 900, "notes": "front door faces -Y"}]}
```

- `collision` is the footprint seen from above (`box` with x and y sizes, or `circle` with `radius_m`). The game uses
  it to stop the cat walking through things.

## glTF export (both)

- glTF binary (`.glb`), Y up (the exporter's default), apply modifiers, flat normals kept, **vertex colours exported
  as `COLOR_0`**, no textures, no cameras or lights. Enemies: skins and animations on, every action exported as its own
  animation, no `Armature`-level extra bones.
- After export, check the GLB itself, not just the .blend: read its JSON chunk and confirm `COLOR_0`, the triangle
  count, the animation names and the bone names. Re-import it into an empty Blender scene and render it to confirm it
  looks right.
- Use `blender-asset-qa` before calling an asset done: no flipped normals, no loose bits, transforms applied, origin
  on the ground.
