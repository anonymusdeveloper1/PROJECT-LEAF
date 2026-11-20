# Project LEAF: rules for Claude and its agents

A low-poly 3D action game for Android, made in Godot 4.7.2 (`game/`). Read `docs/STATUS.md` first, then
`docs/GAME_GUIDE.md` (the game as it is; part 11 is for developers). The current work plan is `docs/PHASE_G_PLAN.md`
(agreed 20 Nov 2026; built in steps G1–G5). Phase F (`docs/PHASE_F_PLAN.md`) is already in the game.

## 3D models: the owner makes every one in Meshy (the owner's rule, 19 November 2026)

- **Claude never models a 3D model**, in Blender or anywhere else. That covers characters, enemies, pets, mounts,
  buildings, props, and new looks for upgrade levels.
- **The one exception (the owner, 20 November 2026): the cat's bows and their arrows.** Claude may design these in
  Blender, fitted to the cat's bow bones. Show the owner pictures before they go in.
- **When the game needs a new model,** tell the owner plainly what is needed: what it is, what it does in the game,
  and its rough size. The owner makes it with Meshy and puts the file in `art/source/meshy/`.
- **Concept images** (Codex CLI, `tools/gen_concepts.ps1`) are made only when the owner asks for one.
- **Until the model arrives,** the game uses a stand-in: an existing model or a tinted placeholder. Say which.
- **Blender is used only to finish the owner's file:** clean-up, colours, rig, animation and export, following
  `docs/ASSET_RULES.md` and `docs/AGENT_BRIEF_MESHY.md`. Run it headless only (`D:\Blender\blender.exe -b`). Never
  touch the owner's open Blender or port 9876.
- When offering the owner a choice, say exactly what each choice does. The owner should never have to guess what
  "the split" or a button means.

## Nothing new without the owner's yes (the owner's rule, 20 November 2026)

- **Don't add new creatures, mechanics or content the owner didn't ask for.** To fix a problem, describe each change in
  plain words, one by one, and wait for a clear yes before building it.
- **Keep everything that is in the game.** Don't remove anything unless the owner asks.

## Agents and models (the owner's rule, 19 November 2026)

Split the work into subagents and pick the model by how hard the task is:
- **Haiku**: simple, mechanical tasks (look-ups, renames, small doc or data edits, listing files).
- **Sonnet**: easy to medium, well-specified tasks (a test file, a tool script, a small self-contained feature).
- **Opus**: normal and hard tasks (game systems, enemy AI, balance, anything that spans several files or needs design
  judgement).

Rules for running agents side by side:
- **No git.** Each writing agent owns its own files, and two agents never edit the same file at the same time.
  `game/data/balance.json` is shared, so one owner edits it at a time.
- **Don't run Godot tests in parallel.** Runs share the test save (`user://leaf_save_test.json`) and clash. Agents may
  write code in parallel; the orchestrator runs the tests one after another.
- Brief every agent with the files it owns, what it must not touch, and the exact names of anything another agent
  will call.

## Working rules

- **Work on D:, keep C: clear.** Builds, caches and temp files go on D:. Set TEMP and TMP to `D:\DevCache\tmp` for
  Godot, Blender and any big command.
- **Back up before a big change** to `D:\DevCache\backup\pre_<work>_<date>`.
- **Git** (from 20 Nov 2026):
  - the repo is https://github.com/anonymusdeveloper1/PROJECT-LEAF (public);
  - **only the game goes in it:** `game/` (no `.godot` cache, no builds), `docs/*.md`, `CLAUDE.md` and
    `GAME_PLAN.md`. The art pipeline, concepts, tools and screenshots stay local (`.gitignore` is a whitelist);
  - **branches:**
    - `development`, the default, where the work lives;
    - `feature/<name>` for each new feature (e.g. `feature/g3-bow-shop`), merged into `development` when done;
    - `production`, updated only when a version is released;
  - commit and push under the owner's account only: **no Claude co-author or attribution lines** in commits or PRs
    (the owner's rule).
- **Test lightly** (the owner saves quota): run `--smoke` plus the changed feature's own mode, once. Add
  `--disable-vsync` before `--`. Get a build on the phone early; polish comes later, separately.
- **Every gameplay number lives in `game/data/balance.json`**, not in code.
- **Keep the design rules** in `docs/GAME_GUIDE.md` part 11:
  - one cat guarding a campfire camp (a camp, not a village);
  - nothing happens while the game is closed;
  - looks-only selling, and rewarded ads only;
  - nothing tall between the camera and where the cat walks;
  - no HUD in the middle third of the screen.
- **The owner speaks through speech-to-text.** Read words by sound when they don't fit: "kit" is the cat, "rows" are
  roads, "Google project" is the Godot project.
