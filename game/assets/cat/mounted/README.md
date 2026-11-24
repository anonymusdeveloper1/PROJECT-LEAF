# Mounted shooting animations

`shooting.res` is a native Godot AnimationLibrary on the existing Cat Ranger skeleton. It contains upper-body
Front, QuarterLeft, RearLeft, QuarterRight and RearRight loops, sampled at 30 fps from the owner's existing Shoot
animation. No geometry was changed. The draw, release, bowstring and arrow bones retain the original Shoot timing.

`player.gd` blends these at 0, ±75 and ±150 degrees relative to the mount. All five loops share one playback clock.
Gameplay now clamps the shooting arc to ±140 degrees (280 total); the wider authored poses remain blend controls.
The original procedural riding pose keeps the legs seated during both carrying and aiming. The animation layer
is filtered from the spine upward and contains no hips, root, leg or tail tracks. The character root faces the mount.
The saddle motion, mount clearance, head stabilization and cloth still run after the animation.

The owner requested torso-only aiming after testing the whole-body pivot. The spine and chest share the turn;
the authored chest rotation is bounded at 95 degrees each way. Neck and head keep the shooting gaze, while both arms
reach an over-shoulder bow placement. The wrists are repositioned together to retain the draw and release geometry.
The root, pelvis and legs stay aligned with the mount through target changes and rear shots.

The local reproducible bake script is `art/scripts/mounted_shoot/bake.gd` (art tools stay local per CLAUDE.md).
From the project root: Godot `--headless --path game --script ../art/scripts/mounted_shoot/bake.gd`.
It reads CatRanger.glb, uses the existing bone-turn and arm-reach helpers and saves this library. Outfit rigs use
the same bones. `--mountedaim` checks real rear shots, torso turns above a forward-facing seat, both mounts, outfits
and different bows. Add `-- --verify` to the bake command to report wrist reach errors without saving.
