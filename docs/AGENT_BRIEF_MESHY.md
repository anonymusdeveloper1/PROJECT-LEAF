# Brief for agents turning a Meshy mesh into a game model

You are making ONE game-ready animated model for Project LEAF, a bright-fantasy low-poly Godot 4.7.2 mobile game at
`D:\Projects\Project LEAF`. Read `docs/ASSET_RULES.md` first and follow it exactly: -Y front, origin on the ground,
per-face COLOR_0 vertex colours with one material `M_VertexColor`, no textures and no UVs, the skeleton, clip and JSON
rules, and the GLB checks. Use the Blender skills (Skill tool): `blender-core` first, then
`blender-game-optimization`, `blender-character-rigging`, `blender-animation`, `blender-export-pipelines`,
`blender-asset-qa`.

## The source

`art/source/meshy/<source>.glb` is an UNTEXTURED grey Meshy 6 Lite mesh (100k–400k triangles, POSITION only). Its
colours must come from its concept image (named in your task, flat light-grey background; the prompt that made it is
next to it in `prompts/`). Meshy meshes are often a little different from the concept (pose, proportions, fused
props): keep the mesh's shape, fix what breaks the game (floating bits, props fused to the body, hair-thin parts).

## Proven pipelines to copy and adapt

Finished, working pipelines from the last batch (each has a `run_all.sh` or `run_*.sh` showing the order):
- `art/scripts/enemies/snail/`, `frog/`, `beetle/`, `moth/`, `owl/`, `bear/` (enemies; `owl` and `bear` are bosses)
- `art/scripts/companions/thistle/` (a quadruped mount with a `saddle` bone), `art/scripts/companions/sprig/` (a pet)
The usual order: prepare + decimate (protect the face), cut eyes into the face as flat faces, dump the mesh, fit a
camera to the concept silhouette, project the concept colours onto faces and snap them to a small palette, fill hidden
faces by rules, apply as per-face colours, build the rig and weights, animate (in place, 30 fps, keys on rotation and
location only, spring bones `jig.*` never keyed), export the GLB and JSON, verify the GLB from its JSON chunk,
re-import it into an empty scene and render it, make previews and a contact sheet. Copy what you need into YOUR
script folder and change it there. Never edit another model's folder.

## Rules on this PC

- Work files go in `D:\DevCache\tmp\<id>\`. C: has room again since 21 Nov 2026, so setting `TEMP` and `TMP` to
  `D:\DevCache\tmp` for Blender runs is optional.
- Blender 5.3 is `D:\Blender\blender.exe`. Run it headless only (`-b ... --python-exit-code 1 -P script -- args`).
  Do NOT use or start the Blender MCP or the live Blender (socket port 9876).
- Do NOT run Godot. Other agents are building other models at the same time: write only inside your own folders.
- Python (checked 21 Nov 2026, after the Windows reinstall): the system has only a 32-bit Python 3.15
  (`py -3.15-32`), without numpy or Pillow, and `python` / `python3` open the Microsoft Store. Blender's own Python has
  numpy (no Pillow), so run numpy steps inside Blender. Ask the owner before installing anything. In Git Bash, write
  scripts to files with the Write tool rather than heredocs with quotes.

## Quality bar

Reads clearly from a 50° top-down game camera at phone size. Faceted, flat-shaded, chunky low-poly. Colours match the
concept. No floating bits, no flipped normals, transforms applied. Lively, cartoony clips with anticipation and
overlap; loops close without a pop; `Die` ends lying on the ground. LOOK at your own preview PNGs with the Read tool and
fix what looks wrong before you finish.

## Final report (short)

Output paths, triangle count, bone count, clip names and lengths, the JSON contents, the contact sheet path, and any
problem left.
