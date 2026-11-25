# Project LEAF architecture (agreed with the owner, 25 November 2026)

**Every agent reads this before writing game code.** It says where things live, which patterns the game uses and for
what, and the house rules that keep the game easy to grow.

- **Status:** this is the target. The game today is not built this way yet. It moves over **step by step during Phase
  H** (part 13), never all at once, and a test checks each move.
- **Why:** the game will keep growing (new enemies, outfits, mounts, pets, companions, biomes, expeditions, bosses). New
  content should be **a folder you drop in**, with little or no new code.
- **Related docs:** the work plan is `docs/PHASE_H_PLAN.md`; the game as it is, `docs/GAME_GUIDE.md` (part 11 for
  developers); speed measurements, `docs/PERFORMANCE.md`; models, `docs/ASSET_RULES.md`.

---

## 1. The layers

```
  ui/          windows, the HUD                         uses everything below, nothing uses it
  world/       the camp, expeditions, room types        uses parts, brains, abilities, core
  parts/ brains/ abilities/ commands/                   the pieces things are built from; use core
  core/        the 8 singletons, effects, grid          uses only data and content
  data/ content/                                         numbers, entries, models: no code depends upward
```

- **Dependencies only point downward.** A window may call a system; a system never calls a window.
- **Sideways talk goes through Events** (part 4, Observer). The fight never calls the HUD; it announces "enemy died" and
  the HUD listens.
- **Content never knows about code above it.** An enemy's entry says which parts it has; it doesn't know the HUD exists.

## 2. Folders

```
game/
  core/        data.gd, save.gd, save_upgrades.gd, events.gd, pools.gd, timers.gd, audio.gd, store.gd, quality.gd,
               effects.gd (the effects list), enemy_grid.gd
  parts/       health.gd, armour.gd, mover.gd, attack.gd, heal.gd, status.gd, effects_holder.gd, loot.gd,
               health_bar.gd, brain.gd, shooter.gd, skills.gd, attachment_slot.gd, level.gd …
  brains/      enemy/, boss/, companion/, cat/, mount/, game/      one small file per state
  abilities/   ability.gd (the shared toolbox) + one file per move: stomp.gd, ram.gd, heal_pulse.gd …
  commands/    move.gd, shoot.gd, ride.gd, use_skill.gd, use_potion.gd, place_defence.gd, buy.gd …
  world/       camp/, expedition/ (the run builder, room types), biome.gd
  ui/          kit/ (window frame, tabs, icon grid, item card, 3D view, confirm), windows/ (one file each), hud/
  content/     ONE FOLDER PER THING, grouped by kind:
                 enemies/thornling/       entry.json, model.glb, icon.png (and a .gd only if it is truly special)
                 bosses/mossback/
                 outfits/dusk_ranger/
                 mounts/thistle/
                 pets/sprig/
                 companions/moss_warden/
                 bows/sunwood/
                 defences/acorn_tower/
                 buildings/bow_shop/
                 crops/sunberries/
                 recipes/health_potion/
                 biomes/gloomwood/        look, props, room pieces, enemy list, music
                 expeditions/gloomwood/
                 offers/shards_small/
                 …
               index.json               the list of every folder (written by a tool, see part 5)
  data/        balance.json: only the general rules (the cat, fights, raids, waves, pools, the grid)
  tests/       one test file per system, the content check, and sample old saves
```

- **Today** the scripts are all in `game/scripts/`, the models in `game/assets/`, and every number in
  `game/data/balance.json`. They move into this layout during Phase H (part 13).
- **Moving a script:** move it together with its `.uid` file, update every `preload("res://…")` path, then run the
  smoke test. A move commit changes nothing else.

## 3. The eight singletons

A singleton is one shared object the whole game can reach (Godot calls them autoloads). They are handy but hide who
depends on whom, so **there are exactly eight**, each with one job:

| Singleton | Its one job | Today |
|---|---|---|
| **Data** | Reads `balance.json` and every content entry; answers "what is X?" (prices, stats, unlock rules). Never changes during play. | exists |
| **Save** | What the player owns and has done; load, save, and upgrading old saves by version (part 10). | exists |
| **Quality** | The graphics level (Low, Medium, High). | exists |
| **Events** | The event board: signals only, no logic (part 4, Observer). | new, H1 |
| **Pools** | Hands out reusable objects and takes them back (part 4, Object Pool). | new, H1 |
| **Timers** | Real-time jobs that keep running while the game is closed: crops, cooking, later any long job. | new, H3 |
| **Audio** | Plays sounds through a queue. Replaces today's static `Sfx` helper. | upgrade |
| **Store** | The shard store and rewarded ads behind one front door, with a real and a pretend provider. | new, H10 |

- **Not singletons:** `main.gd`, the HUD, the fight, raids, the world, the buildings. They are parts of the scene and are
  handed what they need, or listen to Events.
- **No ninth singleton** without the owner's yes and a line in this table.
- `Fx` stays a plain helper (static functions), but takes its effects from Pools.

## 4. The patterns, and exactly where each one is used

### Type Object: every kind of thing is a data entry
- The entry (in `content/<kind>/<id>/entry.json`) is the **type**: name, numbers, parts, model, price, unlock rule.
- The thing in the world points to its type and keeps only its own state (position, health, level).
- **Covers:** enemies, bosses, squads, bows, arrow upgrades, outfits, mounts, pets, companions, mount skills,
  attachments, crops, recipes and potions, defences, specialisations, buildings, biomes, expeditions, room pieces,
  boons, store offers, settings.

### Flyweight: share the heavy, identical things
- Meshes, textures and materials of a model are loaded once and shared (Godot does this for one file).
- The content entry is shared: 50 Thornlings read one entry.
- **One material per effect kind,** made once and reused. (Today some effects make a new material every time:
  shockwaves, swipes, flower rings.)
- **MultiMesh** (thousands of copies in one draw) for grass, trees, props and room dressing (done today), and later
  garden crops and, if ever needed, arrows in flight.

### Component: things are built from small parts
- **Parts:** Health, Armour, Mover (walk, fly, dig), Attack (melee, ranged, area), Heal, Status (burn, chill, slow,
  daze), Effects holder (potions, boons), Loot, Health bar, Brain (its states), Shooter (the bow), Skills,
  Attachment slot, Level.
- Parts are child nodes of the thing. A thing finds its parts by name. **Inside one thing, parts talk through that
  thing's own signals** (for example Health's `died`); only game-wide news goes on the Events board.

| Thing | Built from |
|---|---|
| Thornling, Brute, Beetle Knight… | Health (+ Armour for tanks), Mover, Attack, Status, Loot, Health bar, enemy Brain |
| Bosses | the same, plus a boss Brain with phases |
| The cat | Health, Mover, Shooter, Status, Effects holder |
| Mount | Health, Mover, Skills (the 3 chosen), Attachment slot |
| Golem, the friend, Sprig | Health, Mover, Attack or Heal, Brain with a fighting style (tank, healer, shooter) |
| Towers, spikes, barricade rows | Health, Level, plus Attack (towers) or a slow (spikes) |
| Training dummy | Health only |

- The entry lists the parts and their numbers. **A new enemy is usually just a new entry.** A new part (for example
  "teleports") is code once, then any entry can use it.

### State: the Brain is a set of small state scripts
- Each state is one short file with `enter()`, `exit()` and `update(delta)`, which returns the next state's name or
  nothing.

| Who | States |
|---|---|
| Enemies | Sleep, Walk the road, Chase, Attack, Daze, Flee (the Amber Grub), Down |
| Bosses | Phase 1, Phase 2, Enraged, each with its own attacks |
| The cat | Idle, Move, Shoot, Move-and-shoot, Riding, Fishing, Down |
| Golem, friend, pet | Sleep, Follow, Fight, Heal (the friend), Down, Rise |
| Mount | Walk, Run, Skill move (Ram and Pounce carry it), Knocked out |
| The game itself | Camp, Wave, Between waves, Random Raid, Expedition, Paused |

- **Today** these exist as a word (`state := "walk"`) and a big `match` inside `enemy.gd`, `player.gd` and
  `guardian.gd`.

### Command: actions are objects that anyone can issue
- **The cat:** Move, Shoot, Ride/Walk, Use skill, Use potion. The joystick, the buttons, auto-aim and the tests all send
  the same commands. Companion and mount brains send them to their own parts.
- **Camp building:** Place, Move, Upgrade and Remove a defence, with **Undo** for placing from the Bag.
- **Buying:** one **Buy** command used by every shop window. It checks the price and unlock rule, shows the confirm
  window, pays, marks the save, and announces `item_gained`. There is one way to buy anything.

### Observer: the Events board
- **Game-wide announcements** (first list; add more here as they are made):

| Event | Sent when |
|---|---|
| `enemy_died(kind, at)` | an enemy's Health reaches 0 |
| `damage_dealt(target, amount)` | any hit lands |
| `currency_changed(id, total)` | leaves, timber or shards change |
| `item_gained(kind, id, amount)` | anything goes into the Bag or is unlocked |
| `bag_changed()` | the Bag's contents change |
| `wave_started(n)`, `wave_ended(n, held)` | Raid Missions |
| `raid_started(spec)`, `raid_ended(won, perfect)` | Random Raids (moved from `raids.gd`'s signals) |
| `mission_won(n)` | a Raid Mission is won |
| `building_upgraded(id, level)` | any building levels up |
| `timer_finished(job_id)` | a Timers job ends |
| `quality_changed(level)` | the graphics level changes (moved from Quality) |
| `save_loaded()` | a save is loaded or upgraded |

- **Listeners:** the HUD, Audio, the Hearthtree goal lists, the raid meter, hints, the tests.
- **The rule:** an event says **what happened**. It never asks for an answer, and the sender never depends on who
  listens.
- **Today** there are 6 signals and about 730 direct calls like `main.hud.…`; those are replaced as each step rewrites
  its part.

### Prototype: variants written as "that one, but…"
- An entry can say `"base": "thornling"` and list only what is different, for example the Gloomtouched elite (+health,
  a glow), armoured variants, boss variants and room-piece variants.
- In Godot, every model is spawned from a ready-made template (`PackedScene`); that is already prototype.

### Subclass Sandbox: every special move shares one toolbox
- `abilities/ability.gd` gives safe tools: damage everything in a circle, knock back, apply an effect, play an animation
  and an effect, wait.
- Each move is a short file using only those tools: the mount skills (Stomp, Ram, Pounce, Bellow), the Fire-spitter,
  boss attacks, the friend's heal pulse, specialisations (for example Explosive acorns).
- **Today** the mount skills are functions inside `mount.gd` (`_stomp`, `_ram`, …).

### Object Pool: reuse instead of create and destroy
- **Pooled:** arrows, tower bolts, acorns, fireballs, fire patches, damage numbers and text pop-ups, hit effects, leaf
  and timber pickups, enemies (one pool per kind), expedition room pieces.
- **Rules:**
  - `Pools.take(key)` gives an object, `Pools.give_back(obj)` returns it. **A pooled object is never `queue_free`d.**
  - A pooled object has `reset()`, which puts it back to new. A waiting object is hidden and does not update.
  - Pool sizes (how many are made ahead) are in `balance.json`, per graphics level.
- **Measured** with the speed tests (`--perf`, `--raidperf`, `docs/PERFORMANCE.md`) on the owner's phone, before and
  after.
- **Today** nothing is pooled: each shot makes a new arrow node, a new copy of the arrow model and a new trail, and each
  hit makes a new damage number and a new effect.

### Spatial Partition: only look nearby
- **The enemy grid** (`core/enemy_grid.gd`): the ground is split into squares (first guess 4 m, in `balance.json`), and
  each enemy is filed under its square as it moves. These ask the grid instead of every enemy: arrows checking hits,
  towers picking targets, the cat's and mount's nearest enemy, area moves (Stomp, the Fire-spitter, blasts), and the
  friend finding hurt allies (a second grid for allies).
- **Expeditions are built room by room:** only the current room and its neighbours exist. The rest of the run is a
  small description (a seed, the room list, what is cleared or opened). Rooms behind the cat go back to the pool.
- **Today** every arrow checks every enemy each physics step, `main.nearest_enemy` loops over every foe, and the
  Gloomwood is built whole when the cat goes in (its enemies spawn per fight and sleep until the cat is near).

### Dirty Flag: recompute only when something changed
- **The cat's final stats** (bow, levels, outfit, potions, boons): worked out when one of those changes, not every frame.
- **The HUD and windows** redraw only what changed.
- **The raid power score** (H9).
- **Saving:** changes call `Save.mark_dirty()`, and the file is written once at a safe moment: the end of a wave or
  fight, closing a window, pausing, and **always when the phone sends the game to the background**.

### Event Queue: things that wait their turn
- **Sounds:** the same sound many times in one frame plays once (the limit is in `balance.json`).
- **On-screen messages:** one at a time.
- **Reward pop-ups** after a fight: one after another.

### Service Locator: swap the real thing for a pretend one
- **Store and ads:** the real Google Play provider, or a pretend one for tests and for before the Play Console is set up.
- **Audio:** real, or silent for tests.
- The Store and Audio singletons each hold their provider; the game only ever talks to the singleton.

### Update Method and data locality (through Godot)
- Things update themselves each frame (`_process`, `_physics_process`), but **anything that does not need to is
  switched off:** sleeping enemies, rooms far away, pooled objects that are waiting.
- **Data locality** (keeping data used together next to each other in memory) comes from the engine: MultiMesh,
  Godot's physics and packed arrays (the grid uses them). On a phone the bigger costs are usually drawing: draw calls,
  shadows, particles and lights.

### Not used
- **Bytecode** (a mini scripting language): too much for this game; entries with effect lists do the job.
- **Our own Game Loop or Double Buffer:** Godot already does both.

## 5. Content: one folder per thing

- **The folder name is the id.** Ids are lowercase with underscores and **never change after release**; the name the
  player sees can change (the Ember Ranger's id is still `nightfall_ranger`).
- **Shared fields** in every `entry.json` (a kind adds its own):

| Field | Meaning |
|---|---|
| `id` | the same as the folder name |
| `name`, `desc` | what the player sees (all player text lives in data, never in code) |
| `icon`, `model` | file names inside the folder (default `icon.png`, `model.glb`) |
| `price` | always the same form: `{"leaves": 900, "timber": 10}` or `{"shards": 60}` |
| `unlock` | always the same form, for example `{"hearthtree": 3}`, `{"missions_won": 5}`, `{"building": ["bow_shop", 7]}`, `{"flag": "hollow_open"}` |
| `hidden` | `true` keeps it out of the game until it is released (like the Foxfire Bow today) |
| `effects` | a list from the effects list, for example `[{"type": "stat_mult", "stat": "damage", "mult": 0.25, "seconds": 30}]` |
| `parts` | for things in the world: which parts and their numbers |
| `base` | the id of the entry it is a variant of (Prototype) |

- **Example, an enemy** (the shape only; the numbers are made up, not the Thornling's real ones):

```json
{
  "id": "thornling",
  "name": "Thornling",
  "desc": "A small, quick bramble creature.",
  "parts": {
    "health": {"max": 40},
    "mover": {"type": "walk", "speed": 2.6},
    "attack": {"type": "melee", "damage": 6, "every_s": 1.2, "reach_m": 1.1},
    "status": {},
    "loot": {"leaves": [3, 5]},
    "brain": {"type": "road_walker"}
  },
  "role": "light"
}
```

- **Example, an outfit** (made-up numbers): `{"id": "dusk_ranger", "name": "Dusk Ranger", "price": {"leaves": 2500}, "quiver":
  "dusk_quiver", "fx_color": "#8a7cff"}` plus its model fitted to the cat's skeleton.
- **The effects list** lives in `core/effects.gd`, one small function per type: `stat_mult`, `stat_add`, `heal`,
  `heal_over_time`, `slow`, `burn`, `chill`, `daze`, `shield`, `knockback` (the first list). A new type is code once;
  every potion, upgrade, attachment and boon can then use it.
- **Finding the folders:** `tools/build_content_index` writes `content/index.json` (every folder by kind) before each
  build; Data reads it at start. (Listing folders inside an exported Android game is unreliable, so the game never
  lists them itself.) The content test fails if the index is out of date. `*.json` is already in the export's include
  filter.
- **New folder from a template:** `tools/new_content <kind> <new_id> [--from <id>]` copies a template or an existing
  thing.
- **Balancing many entries:** `tools/content_table <kind>` prints every entry's numbers in one table, so 30 enemies can
  be compared side by side.

## 6. One arrow, start to finish

1. Auto-aim sends a **Shoot** command (Command).
2. The cat's **Shooter** part asks the **enemy grid** for the nearest Thornling (Component, Spatial Partition).
3. An arrow comes from the **pool**; its model is shared; its numbers come from the bow's entry (Object Pool, Flyweight,
   Type Object).
4. It hits: the Thornling's **Health** takes the damage, **Armour** reduces it, **Status** sets it burning (Component,
   effects list).
5. Health reaches 0: the **Brain** switches to **Down**, and `enemy_died` goes on the board (State, Observer).
6. Listeners: the HUD updates, the Hearthtree goals count the kill, **Audio** plays the sound (merged with others in that
   frame by the queue), **Loot** drops leaves from the pickup pool (Event Queue, Object Pool).
7. The arrow and the damage number go back to their pools; after its fall the Thornling goes back to its pool.
8. The save is marked **dirty** and written once at the end of the wave (Dirty Flag).

## 7. House rules

1. **One job per file.** A file that grows past about 800 lines is split.
2. **Dependencies point downward** (part 1). Sideways talk goes through Events.
3. **No lists of names in code.** Code never says `if kind == "thornling"`. If it needs to, something is missing: a data
   field or a part.
4. **Every number lives in data:** `game/data/balance.json` (general rules) and `game/content/` (entries).
5. **Ids are permanent;** player-facing names can change.
6. **Content can be built and kept hidden** (`hidden: true`) until the owner releases it.
7. **New content appears everywhere by itself:** shops, the Bag, the save, the tests. No list to remember to update.
8. **The save never breaks** (part 10).
9. **Typed GDScript everywhere:** every variable, argument and return value has its type. It catches mistakes early and
   runs faster.
10. **Every content kind has an "add one" checklist** (part 9) and a template.
11. **Nothing is added to the game without the owner's yes** (CLAUDE.md). These rules make adding easy; they don't
    decide what is added.

## 8. Agents and this structure

- Each agent owns its folders and files; two agents never edit the same file. Folders per thing make this easy: two
  enemies are two folders.
- `balance.json`, `core/events.gd` (the event list) and `core/save_upgrades.gd` are shared: one owner at a time.
- A new event, part, effect type, state or ability is added to this document in the same change.

## 9. Adding new things

| To add a new… | The owner makes (Meshy) | Claude adds (data) | New code? |
|---|---|---|---|
| **Outfit** | the outfit, fitted to the cat | price (leaves or shards), matching quiver, effect colours | none |
| **Mount** | model with the saddle bone, the standard moves | price, speed, health | none; skills and attachments fit every mount. Code only for a new way of moving (for example flying). |
| **Pet** | model | price, look | none; pet levels are shared |
| **Enemy** | model and its moves | parts, numbers, loot, where it appears (squads, biome lists) | none, unless it needs a new part or ability |
| **Boss** | model and its moves | parts, phases, which attacks | only new attack moves, one short file each |
| **Companion** | model and its moves | fighting style, numbers | none; a new style is code once |
| **Bow** | model (Claude may make bows) | numbers, its effect | none |
| **Defence** | model | parts, price, levels | none; it appears in the Workshop and the Bag |
| **Building** | model | unlock rule, levels, which tabs show which lists | only for a special window (like the cooking pot) |
| **Crop, recipe, potion** | crop model or a 2D icon | grow or cook time, ingredients, effects | none |
| **Biome** | room pieces and props | its look (ground, fog, light, colours), props, enemy list, music | only for a new trap or room type |
| **Expedition** | nothing, if it uses an existing biome | biome, length, boss, rewards, unlock | none |
| **Store offer** | nothing | what you get, how you pay | none (the product is added in the Play Console) |
| **Long job** | nothing | time and result | one small handler: what happens at the end |
| **Setting** | nothing | its entry | none |

- **Checklist for every new thing:**
  1. `tools/new_content` makes the folder.
  2. Fill `entry.json`; put the finished model and icon in the folder (models follow `docs/ASSET_RULES.md`).
  3. Rebuild the index; run the content test and the kind's own test mode.
  4. Keep it `hidden` until the owner says it goes in.
- **Biomes:** a biome is a look plus room pieces, props, an enemy list and music. The Gloomwood becomes the first biome
  (H8). An expedition picks a biome, a length, a boss and its rewards. The camp stays one camp (design rule).

## 10. The save

- **A version number** (today 2). Every change to the save's form adds one upgrade step in `core/save_upgrades.gd`
  (2→3, 3→4 …), run in order when an older save loads. Before upgrading, the old file is copied to a backup.
- **What the player owns has one form for every kind:** `owned[kind][id] = {"level": 1, …}`.
- **New content** starts locked. **Unknown ids** in a save are kept but ignored, so content that is hidden or comes back
  later is not lost. **Removed content** is refunded or turned into something else by an upgrade step (as amber,
  glowstone, heartwood and the keys become leaves in H1).
- **Sample saves** of every version live in `tests/saves/`, and a test loads each one.

## 11. Tests

- `--content`: every folder in the index has the shared fields; its id matches the folder; its model and icon exist;
  prices use known currencies; unlock rules point to things that exist; effects use known types; `base` points to a
  real entry; the index is up to date. Then buy, save and load one entry of each kind.
- `--saves`: loads every sample save and checks nothing is lost.
- `--pools`: after a wave, pool sizes are steady and no pooled object was freed.
- Each system keeps its own test mode, plus `--smoke`.
- **Tests never run in parallel** (they share the test save); light testing as in CLAUDE.md.

## 12. Ready for later (not built now; the structure doesn't block them)

- **Translations:** all player text is in data entries, so the game can be translated later.
- **Cloud saves (Google Play):** Save can get a cloud provider without changing the rest of the game.
- **Content updates:** a new biome with its enemies and boss ships as one set of folders.

## 13. Moving the game over, step by step

| Step | What is built or moved |
|---|---|
| H1 | `core/` with Events, Pools (arrows, damage numbers, hit effects, pickups), `save_upgrades.gd`, Dirty Flag saving; `balance.json` keeps the general rules; Data learns to read `content/index.json` |
| H2 | the HUD listens to Events; commands for the cat's buttons (Ride/Walk, potions); `hud.gd` split under `ui/hud/` |
| H3 | Timers; the effects list; crops and recipes as content folders; the Use-potion command |
| H4 | the window kit (`ui/kit/`); one window file per building; buildings and bows as content folders |
| H5 | the Buy command; outfits, mounts, pets and attachments as content folders |
| H6 | Components and States for enemies (armour arrives here); the enemy grid; Place/Undo; the ability toolbox for specialisations; enemies, squads and defences as content folders |
| H8 | Components and States for the golem and the friend; fighting styles; the Gloomwood as the first biome; expeditions built room by room |
| H10 | the Store with its real and pretend providers; offers as content folders |
| later | the cat's and mount's own parts, mount skills as abilities, and anything not yet moved, when a step next touches them |

**Where the game is today** (25 November 2026):
- five autoloads (Events, Data, Save, Quality, Pools). New in H1: `game/core/` (events, pools, save upgrades) and
  `game/content/index.json` (empty for now); the rest is in `game/scripts/`; every number in one `balance.json`;
- a few very big files: `stations.gd` 2,760 lines, `hud.gd` 2,362, `enemy.gd` 2,352, `fight.gd` 2,184,
  `burrow_run.gd` 1,897;
- the Events board has 14 signals; about 730 direct calls through `main` remain until H2;
- arrows, damage numbers, text pop-ups, hit effects and pickups are pooled (H1); every arrow still checks every enemy
  each physics step;
- states as words with `match` blocks;
- MultiMesh already used for grass, trees, props and the dungeon floor;
- the save at version 2, with versioned upgrades ready (no step yet), dirty-flag flushing and atomic writes (H1).

## 14. Decided later, during the steps

- The exact fields of each kind's entry (made when that kind moves over).
- Pool sizes, the grid's square size, the sound limits (first guesses in `balance.json`, measured on the phone).
- When CLAUDE.md's rule "every gameplay number lives in `game/data/balance.json`" becomes "every number lives in
  `game/data/` and `game/content/`": with the Phase H rule changes, once the owner approves the plan.
