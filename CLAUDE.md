# Project LEAF: rules for Claude and its agents

A low-poly 3D action game for Android, made in Godot 4.7.2 (`game/`). Read `docs/STATUS.md` first, then
`docs/GAME_GUIDE.md` (the game as it is; part 11 is for developers). The current work plan is `docs/PHASE_H_PLAN.md`
(started 25 Nov 2026; built in steps H0–H11), and **every agent reads `docs/ARCHITECTURE.md` before writing game
code**: Phase H moves the game over to it step by step. Phases F and G are already in the game.

## 3D models: the owner makes every one in Meshy (the owner's rule, 19 November 2026)

- **Claude never models a 3D model**, in Blender or anywhere else. That covers characters, enemies, pets, mounts,
  buildings, props, and new looks for upgrade levels.
- **The exceptions: the cat's bows and their arrows (the owner, 20 November 2026), and the mounts' attachments
  (Fire-spitter, Mossweave Saddle, Saddlebags; the owner, 22 November 2026).** Claude may design these in Blender,
  fitted to the cat's bow bones or the mounts' saddle bone. Show the owner pictures before they go in.
- **When the game needs a new model,** tell the owner plainly what is needed: what it is, what it does in the game,
  and its rough size. The owner makes it with Meshy and puts the file in `art/source/meshy/`.
- **Concept images** (Codex CLI, `tools/gen_concepts.ps1`) are made only when the owner asks for one.
- **Until the model arrives,** the game uses a stand-in: an existing model or a tinted placeholder. Say which.
- **Blender is used only to finish the owner's file:** clean-up, colours, rig, animation and export, following
  `docs/ASSET_RULES.md` and `docs/AGENT_BRIEF_MESHY.md`. When parts of the owner's Meshy mesh are too broken to clean,
  Claude may rebuild those parts as clean geometry that follows the owner's design (the owner, 23 November 2026: the
  outfit cloaks and the Tailor's Nook).
- **How Claude runs Blender** (the owner, 21 November 2026): headless (`D:\Blender\blender.exe -b`), or live in the
  Blender that `tools/start_blender_mcp.ps1` opens, through the MCP bridge on port 9876 (client:
  `py -3.15-32 tools/blender_mcp.py`). Never touch a Blender the owner opened themselves. Agents working side by side
  stay headless, so they don't clash in one live Blender.
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
  judgement), and **every review** of work done by Sonnet, Haiku and Codex (read-only).
- **Fable** (the owner, 25 November 2026): only the really hard problems, when Opus is stuck or a design is risky.
- **Codex CLI** (GPT-6.2 Sol, the owner's own quota; the owner, 25 November 2026): medium to fairly hard, well-fenced
  tasks and all concept images, never the hardest tasks. It runs read-only and returns a patch that Claude reads and
  applies. If Codex stops (quota, error), Sonnet or Haiku finishes the same brief.
- The full flow (brief, build, review, test, the owner) is in `docs/PHASE_H_PLAN.md`, Part F.

Rules for running agents side by side:
- **No git.** Each writing agent owns its own files, and two agents never edit the same file at the same time.
  `game/data/balance.json` is shared, so one owner edits it at a time.
- **Don't run Godot tests in parallel.** Runs share the test save (`user://leaf_save_test.json`) and clash. Agents may
  write code in parallel; the orchestrator runs the tests one after another.
- Brief every agent with the files it owns, what it must not touch, and the exact names of anything another agent
  will call.

## Working rules

- **Disks** (since the Windows reinstall, 21 Nov 2026): C: has room again, so tools may keep their caches and temp
  files in their default places on C:. The project, builds, backups and work files (`D:\DevCache\tmp\<work>\`) stay on
  D:. The test runners still set TEMP and TMP to `D:\DevCache\tmp`, which is fine.
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
- **Every gameplay number lives in data, not in code:** `game/data/balance.json` for the general rules, and
  `game/content/` (one folder per thing, `docs/ARCHITECTURE.md`) as Phase H moves content there (the owner, 25 Nov 2026).
- **Keep the design rules** in `docs/GAME_GUIDE.md` part 11:
  - one cat guarding a campfire camp (a camp, not a village);
  - **only timers keep running while the game is closed** (the owner, 25 Nov 2026): cooking, crop growth, and later
    long jobs that use the timer system. Raids, fights, the Well and the rest of the camp still wait;
  - looks-only selling: **purple shards are the paid currency and buy only looks**, and Bramble never buys shards for
    leaves (the owner, 25 Nov 2026); rewarded ads only;
  - nothing tall between the camera and where the cat walks;
  - no HUD in the middle third of the screen.
- **The Mushroom Cottage leaves the camp** in Phase H (H5); its pet upgrades move to the Market (the owner, 25 Nov 2026).
- **The owner speaks through speech-to-text.** Read words by sound when they don't fit: "kit" is the cat, "rows" are
  roads, "Google project" is the Godot project.
