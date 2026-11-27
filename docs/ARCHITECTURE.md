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
               effects.gd (the effects list), bag.gd (the Bag's counts and stacks, static functions), enemy_grid.gd
  parts/       health.gd, armour.gd, mover.gd, attack.gd, heal.gd, status.gd, effects_holder.gd, loot.gd,
               health_bar.gd, brain.gd, shooter.gd, skills.gd, attachment_slot.gd, level.gd …
  brains/      enemy/, boss/, companion/, cat/, mount/, game/      one small file per state (H6 built the enemies' as `states/enemy/` next to `parts/`; the rest move later)
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
                 buildings/bench/         (the Bow Shop; a building's id is the save's)
                 crops/sunberry/          (the folder is the id, and ids never change: the save says "sunberry")
                 recipes/health_potion/
                 biomes/gloomwood/        look, props, room pieces, enemy list, music
                 expeditions/gloomwood/
                 offers/shards_small/
                 …
               index.json               the list of every folder (written by a tool, see part 5)
  data/        balance.json: only the general rules (the cat, fights, raids, waves, pools, the grid)
  tests/       one test file per system, the content check, and sample old saves
```

- **Today** (H3) most scripts are still in `game/scripts/` (`core/`, `parts/`, `commands/` and `ui/` have their first
  files), the models are in `game/assets/`, and the numbers are in `game/data/balance.json` and the first content
  folders (`settings`, `crops`, `recipes`; H4 adds `bows` and `buildings`). They move into this layout during Phase H
  (part 13).
- **Today in `ui/windows/`** (H4): one window file per building. `building_window.gd` is the shared base (the rows,
  the pinned Upgrade `upgrade_footer`, `ask_upgrade` through the confirm window, `list_row`, `as_list`). Besides it:
  `hearthtree_window.gd` (with the static helpers `defences_tab.gd` and `stat_list.gd`), `target_window.gd`,
  `bow_shop_window.gd`, `well_window.gd`, `stone_window.gd`, `garden_card.gd`, `market_window.gd`,
  `saddlery_window.gd`, `tailor_window.gd`, `fishing_window.gd` and `build_menu_window.gd`, next to
  H3's garden and cooking windows. (H5 deleted `cottage_window.gd`.) A window only builds words and rows; the rules stay in `stations.gd` under their old
  names, and windows call them as `st.<name>`. The HUD makes the windows (`hud.windows`, `hud.confirm`), and
  `stations.use_windows` plugs each one into its marker.
  - Since H4 Stage 2 the nine buildings with levels (the Hearthtree, the Training Target, the Bow Shop, the Well, the
    Guardian Stone when awake, the garden, the Market, the Mushroom Cottage and the Saddlery; since H5 the Market has
    no levels and no Upgrade, and the Cottage is gone) end in the pinned
    Upgrade (`"footer": upgrade_footer()`), and their old "Upgrade" section is gone. Upgrade always opens the confirm
    window with what the next level gives (`gives`): the price shows in red and Confirm stays grey when you can't pay.
    The Tailor's Nook and the Fishing Spot have one level and no footer. (The Market, the Cottage and the Saddlery kept
    their tile rows until H5, below.)
  - **H5 (the Market, the Saddlery and the Tailor's Nook).** The Mushroom Cottage and its window are gone
    (`window_list.gd` has no `cottage`). The Hearthtree's pet-level goals: Show opens the build menu at the Market
    before it is built (`_menu_id` handles `pet_level`); Go walks to the Market and opens its Pets tab through the
    Market window's one-visit `open_on`.
  - `market_window.gd` has four bottom icon tabs, Sells, Buys, Mounts and Pets (`tabs_at: "bottom"`; each tab keeps its
    word as `"name"`, which `card.gd` also gives the tab button as `tab_name` and `accessibility_name`). It has no
    footer and no level, and opens on Sells unless `open_on(tab)` asked. API: `tab`, `TABS`, `select(t)`, `tab_ids()`,
    `tab_spec(t)`, `tab_lights(t)`, `entries(t)`, `inspect(id)`, `back()`, `trade`, `companions`.
    - `market_trade_tab.gd`: Sells and Buys are `ui/kit/icon_grid.gd` grids with one bundle's price, or a neutral
      payout. A tap opens `ui/kit/item_popup.gd` (amount, Buy or Sell), and the trade is
      `stations.market_trade(side, id, bundles)`.
    - `market_companions.gd`: Mounts and Pets have Ride, the pet's training row and grids of whole pictures with Use or
      Buy. A tap shows a detail view. Below the grid are colours, Gloomlit and the expedition gear. The actions are
      `stations._use_look`, `_buy_companion`, `_train_pet`, `_next_skin`, `_unlock_skin`, `_buy_attach` and `_wear`.
    - `market_words.gd` holds the Market's words (`say(key)` reads `Data.word`). Tab dots and the marker's "!" come
      from `tab_lights` over every tab.
  - `saddlery_window.gd` has two bottom tabs (Attachments, then Skills, icon and word); a fresh visit opens on
    Attachments. Attachments: Patch it up and the three attachments as big pictures (`icon_grid.gd`). A tap opens
    `attachment_inspect.gd` in the same window: the attachment turning in `model_view.gd`, fitted to the mount out now
    (`Data.gear_model`, stood as on the saddle bone through `mount.gear_frame()`), with Back and one button (Buy, Wear,
    Upgrade, or a grey Worn). Skills (`saddlery_skills.gd`): the three circles (`ui/kit/skill_triangle.gd`) over the
    round skill icons. Drag a learned skill in, tap a filled circle to empty it (`CompanionShop.assign_skill`, drawn in
    place); a tap on an icon opens its detail (Learn or Upgrade). The Saddlery's Upgrade is pinned on the Skills tab
    only; its confirm lists the next cap and the mount's speed and health (`gives`), and Confirm and Cancel come back to
    Skills. Every paying button passes the level it showed as Buy's `expected_level`. The Skills overview's `view_id`
    is `saddlery_skills:<learned levels>`, so a leaf pickup never redraws it under a drag.
  - `tailor_window.gd` is one card window row, `outfit_preview.gd`: a turning `ModelView` of a preview-only hero from
    the outfit file (or `original_base()`) on a scaled `stepping_stone`, one Buy, Wear or Wearing button, an `IconGrid`
    of outfit cards (unowned = grey, still tappable), and Back. Try-on only changes the picture; it never writes
    `Save.cat_skin` or calls `apply_skin`. The view is made once, moved across rebuilds and freed in `closed()`. API:
    `entries()`, `state(id)`, `selected_id()`, `try_on(id)`, `back()`, `pulse()`, `preview()`.
  - Kit (H5): `card.gd` gives each tab its `name` as `tab_name`; an icon-only tab draws a 52 px icon
    (`CardParts.TAB_ICON_ALONE`); `card_signpost._start_signpost_reveal` accepts a row that was already freed.
  - The pet (`pet.gd`) takes its model from its content entry and never hides.
  - `hearthtree_window.gd` has tabs at the top: **Hearthtree** (Mend all, Patch it up, "Nothing for sale yet", its
    goals and the Graphics row, with the pinned Upgrade), **Cat** (the cat's own upgrades, `stat_list.gd`).
    (H6 removed its **Defences** tab and `defences_tab.gd`: the Workshop took the shelf.) A tab shows once it has something, and
    there is no tab bar with one tab. The window always opens on the Hearthtree tab, and a tab shows a "!" dot while
    something on it can be bought. A goal's Go walks the cat to the marker that sells it; Show opens the Cat tab at its row,
    the Workshop, the Bag, a pad or a placed piece (H6), or the build menu at a building not built yet (`Data._goal` gives such goals the station
    `"build"`).
  - `bow_shop_window.gd` lists the bows as list rows: the bow in the paw shows Upgrade with its price, then a grey
    Equipped when it can't level now; other owned bows show Equip, the rest Buy or Locked. A tap on a bow's picture
    opens its inspect view (`bow_inspect.gd`) inside the shop's window: the bow turning in 3D with its arrow, its
    numbers, the arrow's real damage (`Data.arrow_damage(bid)`, the same number a shot uses, with the cat's Damage stat
    and a running potion), its one button and Back.
  - `build_menu_window.gd` is not a marker window: it lives at `hud.windows["build"]` and opens through the card as a
    `{"kind": "window"}` row. `entries()` is the one place that says what can be built and what is locked; it reads
    each building's `unlock` and `price` and `build_menu.locked_from_missions`, so a new building with
    `"arrives": "menu"` appears in the grid with no code change. Each open picture has its own Build button (one tap);
    a locked one is greyed with its needs and has none. A built building leaves the menu, and nothing can be built
    while the Hearthtree is in ruins.
  - The build icon next to the Bag (`ui/hud/action_buttons.gd`) opens the build menu and shows a small "!" dot while a
    building can be built and paid for (the cue the Hearthtree's marker gave before H4). Building from the menu sends
    the camera to the new building for about 2 s (`main.show_spot`; the joystick, a wave or going below ground ends it
    at once, and the cat keeps control) while the building rises out of the ground with dust and the flower ring
    (`Fx.rise`, from `stations.refresh(id, true)`). The build menu sends nothing itself; it hears
    `Events.building_upgraded` only through `stations.refresh`.
  - Known differences: the signpost's, the campfire's and the cooking pot's cards stay in `stations.gd` for now (they
    are not buildings: no save entry, no content folder). `window_list.gd` is a known list of names in code (house
    rule 3) until a building entry names its window.
  - Also known: in H4 the dialog host (its frame, the pinned footer, the tabs on top or at the bottom, each with an
    optional icon and a small "!" dot, and the visit hooks `card_opened`/`card_closed` on the window behind a card's
    builder) moved to `ui/kit/card.gd` in H4 Stage 3, as a pure file move. The stations forwarders (`_card_shop` and
    the rest) are gone: tests reach a window only through `main.hud.windows[<id>]`, `hud.windows["build"]` and
    `hud.confirm`.
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
| **Timers** | Real-time jobs that keep running while the game is closed: crops, cooking, later any long job. | exists, H3 (`core/timers.gd`; the jobs live in `Save.timers`) |
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
| Mount | Health, Mover, Skills (the 3 chosen), Attachment slot, Effects holder |
| Golem, the friend, Sprig | Health, Mover, Attack or Heal, Brain with a fighting style (tank, healer, shooter) |
| Towers, spikes, barricade rows | Health, Level, plus Attack (towers) or a slow (spikes) |
| Training dummy | Health only |

- The entry lists the parts and their numbers. **A new enemy is usually just a new entry.** A new part (for example
  "teleports") is code once, then any entry can use it.
- **Built so far (H3):** the Effects holder, `parts/effects_holder.gd` (no class_name; preload it), a child named
  "Effects" of the cat (`player.effects`) and of the mount (`mount.effects`). It runs `heal_over_time` and `stat_mult`
  effects on frame time (paused while `main.frozen`, not saved, cleared when its owner is knocked out), and on every
  start and end of a `stat_mult` hands its owner the full map of every running stat (the cat: `Data.set_effect_mults`,
  read by `Data.effect_mult`). Its API: `add(e, source)`, `has_source`, `left`, `mult`, `active()`, `clear()`,
  `step(dt)` and the signal `changed`.
- **Built in H6 (enemies):** `scripts/enemy.gd` is the one node; it makes its parts and finds them by the names `_health`,
  `_armour`, `_mover`, `_attack`, `_heal`, `_status`, `_loot`, `_bar` and `_brain` (child nodes of the enemy, with no
  process callbacks: the enemy's own `_tick` drives them).
  - `parts/health.gd` (signals `changed` and `died`; `apply_damage`, `set_hp`, `set_max_hp`, `heal`) and
    `parts/armour.gd` (`share`, `set_share`, `factor`, `reduce`). `hp` and `max_hp` on the enemy forward to Health.
  - **Armour is a part, and it lives in each enemy's entry** (`parts.armour.share`). It is set only when `setup(kind,
    patch, strength, armoured)` gets `armoured` true; bosses and a tank that is an expedition room's boss get false.
    Max health is `hp * mult * armour.factor()`.
  - `parts/enemy_mover.gd` (walk, flee, dig, pounce, blink, charge, dash, emerge, stride), `enemy_attack.gd`,
    `enemy_heal.gd` (heal and drum), `status.gd` (burn, frost, the thorn slow and its linger, the totem scan),
    `enemy_loot.gd`, `health_bar.gd` and `enemy_brain.gd` (`step`, `sleep_step`, `check_enrage`, `change_state`).
  - **One damage function:** `enemy._apply_damage(dir, amount, source)`, source `"hit"`, `"burn"` or `"spikes"`. Order:
    shield, daze weak spot, Bellow, Totem, `last_raw` (kept for the Ember burn), armour, wake (hit only), Health.
    `last_dealt` is after armour. `hurt_spikes(amount)` and `heal_raw(amount)` are the other two doors.
  - The old private names stay as one-line forwarders, so the tests did not change.
- **Built in H6 (defences):** a tower, a spike patch and a barricade row each carry their own `level`. The levels, caps,
  quotes and stats are `scripts/defence_levels.gd`; `tower.gd` reads `Data.defence_level_info(kind, level)` for its own
  level. Still plain scripts and dictionaries, not the `parts/level.gd` of the plan.

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

- **Today** (except the enemies, below) these exist as a word (`state := "walk"`) and a big `match` inside `player.gd` and
  `guardian.gd`.
- **Built in H6 (enemies):** `states/enemy/enemy_state.gd` is the base, and each special state is one file:
  `action_state`, `blink_state`, `charge_state`, `dash_state`, `dash_windup_state`, `daze_state`, `dig_state`,
  `down_state`, `emerge_state`, `flee_state`, `pounce_state`, `roam_state` (the old `_think`, as `think()`), `sleep_state`
  and `windup_state`. `parts/enemy_brain.gd` runs them. **Known difference:** the Brain still reads the enemy's
  `state` word, and the 44 places that set `state = "..."` were not changed, so the states are not yet the only way a
  state changes. Bosses' phases, the cat, the mount and the companions are still `match` blocks.

### Command: actions are objects that anyone can issue
- **The cat:** Move, Shoot, Ride/Walk, Use skill, Use potion. The joystick, the buttons, auto-aim and the tests all send
  the same commands. Companion and mount brains send them to their own parts.
- **Built so far:** Ride/Walk (H2, `commands/ride.gd`) and Use potion (H3, `commands/use_potion.gd`:
  `UsePotion.new(id)`, `can_run(main)` gives "" or the reason, `run(main)` takes one from the Bag and does its effects
  through `core/effects.gd`). The HUD's two potion buttons, the Bag's Use button and the tests send it. A command never
  calls the HUD and never saves; the caller shows a refusal.
- **Camp building:** Place, Move, Upgrade and Remove a defence, with **Undo** for placing from the Bag.
  - **Built in H6** (`commands/place_defence.gd`, `commands/undo_place_defence.gd`): `PlaceDefence.new(kind, spot,
    rotation_y)` and `UndoPlaceDefence.new(piece_id)`, each with `can_run(main)` (a reason or "") and `run(main)`. They
    take a tower or spikes out of the Bag into the camp and back, with the piece's level and wear. A command never saves
    and never calls the HUD; the facade (`defences.commit_placement`, `undo_place`) saves. The one place that places is
    `scripts/defence_placement.gd`, which holds the ghost and the **receipt** of the last placement; the receipt is
    dropped when a wave starts, the area changes or a save loads,. The HUD's
    Undo button and the tests send the same command. **Move and Remove** are not built (the owner said no Pick up
    button); **Upgrade** is `defences.upgrade_placed` and the Workshop's own is `stations.upgrade_workshop`, called
    from the window's confirm, not yet as commands.
- **Buying:** one **Buy** command used by every shop window. It checks the price and unlock rule, shows the confirm
  window, pays, marks the save, and announces `item_gained`. There is one way to buy anything.
  - **Built in H5** (`commands/buy.gd`): `Buy.new(kind, id, amount, expected_level, look_id)`, `can_run(main)` gives ""
    or the reason, `run(main)` pays and gives. `expected_level` is the level the button showed, so a stale tap buys
    nothing. The command never saves and never calls the HUD; it marks the save dirty. Besides the Bag's kinds,
    `item_gained(kind, id, amount)` now also carries `mounts`, `pets`, `outfits`, `attachments` and a colour's unlock
    key `skin:<slot>:<look>:<colour>`. `scripts/market_trade.gd` (`offers`, `quote`, `sell`) and
    `scripts/companion_shop.gd` (`choose`, `assign_skill`, `buy`) hold the rules the Buy command and the windows share.
  - The shop rules in `stations.gd` are thin callers: `_saddle_buy`, `_buy_skin`, `_buy_attach`, `_unlock_skin`,
    `_craft` and `_buy_piece` send `Buy.new(...).run(main)`. `_trade`, `_market_buy` and `_market_sell` go through
    `stations.market_trade(side, id, bundles)`. `_use_look` and `_assign_skill` go through CompanionShop, and
    `_buy_companion` and `_train_pet` serve the Market's companions. Each then saves, refreshes the live model and gives
    the receipt.
  - The mount's skills fire only from the Saddlery's circles: `mount.gd` `_try_moves()` and `try_move()` read
    `Data.active_skill_level(id)`; the order stays `mount_skills.priority`; the Fire-spitter keeps its own `worn_level`
    clock. `mount.max_hp()` reads `Data.mount_base_hp_at(Data.mount_level())`, the same table the Saddlery confirm shows.

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
| `fight_progress(done, total)` | progress changes in the current Raid Mission wave or the whole Random Raid attack |
| `riding_changed(on)` | the Ride command mounts or dismounts the cat |
| `mount_down_changed(down)` | the mount is knocked out or gets back up |
| `placing_changed(kind)` | defence placement starts or ends (empty kind) |
| `area_changed(inside)` | the cat enters or leaves an expedition |
| `boss_changed(boss)` | a boss appears or its encounter ends (null) |
| `campfire_hit()` | the campfire takes damage |
| `building_upgraded(id, level)` | any building levels up |
| `timer_finished(job_id)` | a Timers job ends |
| `quality_changed(level)` | the graphics level changes (moved from Quality) |
| `save_loaded()` | a save is loaded or upgraded |

- **Listeners:** the HUD, Audio, the Hearthtree goal lists, the raid meter, hints, the tests.
- **The rule:** an event says **what happened**. It never asks for an answer, and the sender never depends on who
  listens.
- **Today** (H3, 26 Nov 2026) there are 21 signals, and many direct calls like `main.hud.…` remain; those are replaced
  as each step rewrites its part. `timer_finished` is sent by Timers (`check()`) since H3. `building_upgraded` is sent
  by `stations.gd` since H4, when a building is built, upgraded, given by a mission or found (the Guardian Stone), or
  when the Hearthtree grows; `id` is the save's id (`home` for the Hearthtree).

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
- **Built in H6:** `abilities/ability.gd` (static tools: hurt every foe in a circle once each through the enemy grid,
  play a hit effect) and `abilities/explosive_acorns.gd`, the first ability on it. `acorn.gd` calls
  `ExplosiveAcorns.burst(main, impact, first, raw_damage, level)` when `Data.specialisation_level("explosive_acorns")`
  is above 0. The blast is 1.2 m for 30, 45 or 60% of the hit (the owner's Q3, in the specialisation's entry), hits
  each other foe once and never chains. The mount skills and the Fire-spitter have **not** moved onto it yet.

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
- **Built in H6** (`core/enemy_grid.gd`, `main.enemy_grid`, created first in `main._ready`; `balance.json enemy_grid`:
  `cell_m` 4, `slack_m` 0.5, `max_cells` 64 are first guesses, to be measured on the phone). An enemy calls `add` at the
  end of its setup, `move` after each physics frame while alive, and `remove` when it dies or leaves the tree (each safe
  to repeat). `candidates(min_xz, max_xz, group)` gives a **superset** of the foes that could touch the box, in the order
  they were registered (the order `get_nodes_in_group` gave), and `near(centre, r, group)` is a box around a point. The
  grid never decides a hit: every caller keeps its own exact distance, cone and sleep tests. Used by arrows, acorns,
  fireballs, the mount, towers, spikes (a 0.8 m box), the Frog's heal and the Crow's drum, the totem scan, the blast,
  `main.nearest_enemy` and the separation step. A box that spans more than `max_cells` cells walks every entry. **The
  allies' grid is not built.**
- **Today** (outside the grid) the Gloomwood is built whole when the cat goes in (its enemies spawn per fight and sleep until the cat is near).

### Dirty Flag: recompute only when something changed
- **The cat's final stats** (bow, levels, outfit, potions, boons): worked out when one of those changes, not every frame.
  (H3: the cat's Effects holder hands Data the full map of running potion stats only when a Damage or Speed Potion
  starts or ends.)
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
- **Timers:** the real clock, or a pretend one for tests (H3). `Timers.clock` is a Callable giving Unix seconds; a test
  sets it to a method of its own node (real now + an offset, or held still) and calls `Timers.use_real_clock()` when it
  ends, so no future `seen` stays in the test save. The 3 → 4 save step reads the same clock.
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

- **Built by H5** (kinds, listed in `content/index.json` in this order): `mounts` (thistle, bramblewool), `pets`
  (sprig, lumi), `outfits` (original, dusk_ranger, nightfall_ranger) and `attachments` (fire_spitter, saddle,
  saddlebags, mount_shoes, pet_lantern, pet_charm, pet_bell). Each kind adds `picture` (its whole-body or card picture)
  and its own fields; `shop` names the building that sells it. `scripts/shop_data.gd` reads them (`Data.shop_entries`,
  `owned_level`, `companion_model`, `shop_picture`, `attachment_entries`). `content/README.md` has the fields and price
  forms. The Cottage's entry is gone (its picture and model stay in `assets/`); the Market has `levels: [{}]`;
  `building_hp.stall` is `[0, 200]` and `Data.building_hp` applies `Save.market_hp_floor`. Home goal type
  `pet_level {level}`. `gloom_raids.shard_trade` is gone. `balance.json` no longer has `looks.mount`, `looks.pet`,
  `cat_skins`, `attachments` or `mount_attachments`; `looks.guardian` stays. A code word moves into `windows` and is
  read through `Data.word` (`pet_joins`, `head_outfits`, the Market's words).
- **Built by H6** (more kinds in `content/index.json`): `enemies` (24), `squads` (12), `defences` (barricade, spikes,
  tower) and `specialisations` (explosive_acorns, reinforced_barricades, deep_thorns); `buildings` gains `workshop`
  (11 in all). The enemy and squad catalogues left `balance.json`; callers read them only through `Data.enemy(id)`
  (`{}` for an unknown id), `enemy_has`, `enemy_role`, `squad` and `squad_ids`.
  - **An enemy's `entry.json`** has `role`, `height`, `radius`, `color`, `model` and `parts` (`health.max`,
    `armour.share`, `mover.speed`, `attack {...}`, `status`, `loot`, `health_bar`, `brain {aggro...}`). **Armour lives
    here**: Brute 0.20, Stump 0.25, Snail 0.30, Beetle 0.35 (the owner's Q3), with the health lowered so the time to kill
    stays the same. Bosses have no `armour` block.
  - **A defence's entry** has the kind's `levels` (each with its `price`, `hp`, `range`, `dps` or `slow`, `model`), the
    `from_bag` and the limit by home level (`max_by_camp_level`); the level-5 tier has `needs_burrows`. **A specialisation's entry** has `kind`, `effect` (the ability's id),
    `unlock`, `price` (to learn) and `upgrades` (the prices of levels 2 and 3). `Data.specialisation_level(id)` is 0 when
    not learned. Both read prices through `Data.entry_price(kind, id, level)`.
  - **Building layouts are data, one way for every building** (the H4 exception is closed). A building's entry has a
    `layout` block: `position`, `foot_radius` (or `foot_by_level`), `ring_offset`, `reserved {offset, r}`, `village {r,
    ring_r}`, `path {points, smooth, half_mult, peak, trunk_of, fork_at}`, `grass_radius`, `grass_always`,
    `models_by_level {level_from, step_down, models}`, `scale_at_camp`, `rotation_pi`, `ring_marker` and `stand_in`.
    `Data.building_layout(id)` reads it; `world.gd` and `stations.gd` keep no spot tables. `world.CAMP_ORDER` lists
    the buildings that take part. A test (`--layout`, with the parity of H5's numbers) checks the camp is unchanged.
  - **The Workshop's entry** is the first new building added this way: `position [13.5, 0, 4.8]`, `foot_radius` 2.13,
    its path forking from the Tailor's, `model: defence_workshop`, `stand_in: bow_bench_1` (warm tint), price 250
    leaves and 10 timber, `unlock {missions_won: 2}`, `arrives: "menu"`, five levels (the owner's Q2).

- **The folder name is the id.** Ids are lowercase with underscores and **never change after release**; the name the
  player sees can change (the Ember Ranger's id is still `nightfall_ranger`).
- **Shared fields** in every `entry.json` (a kind adds its own):

| Field | Meaning |
|---|---|
| `id` | the same as the folder name |
| `name`, `desc` | what the player sees (all player text lives in data, never in code) |
| `icon`, `model` | file names inside the folder (default `icon.png`, `model.glb`). **H3's crops and recipes, until their art moves into the folders:** `icon` is a picture id of `scripts/ui_icons.gd` (drawn in code; `hud.icon(id)`), and a crop's `model` is the base of its Props ids in `assets/props/` (`<model>_growing`, `<model>_ripe`) |
| `price` | always the same form: `{"leaves": 900, "timber": 10}` or `{"shards": 60}` |
| `unlock` | always the same form, for example `{"building": ["home", 3]}`, `{"missions_won": 5}`, `{"building": ["bench", 7]}`, `{"flag": "hollow_open"}`. `{}` is open from the start. `Data.unlocked(rule)` answers it: it knows `{}`, `building`, `flag` and `missions_won`, every part must hold, and another form warns and stays shut; `Data.unlock_missing(rule)` lists the parts not met |
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
  `heal_over_time`, `revive` (H3: brings a knocked-out mount back with `share` of its health), `slow`, `burn`, `chill`,
  `daze`, `shield`, `knockback` (the first list). A new type is code once; every potion, upgrade, attachment and boon
  can then use it. **Built in H3:** `heal`, `heal_over_time`, `stat_mult` and `revive`, through `Effects.known(type)`,
  `Effects.reason(e, main, source)` ("" when it can act now) and `Effects.apply(e, main, source)`; the source is the
  item id, and one effect per source runs at a time ("Already active"). `Effects.hud_potion("cat" | "mount")` names the
  potion each HUD button uses (`balance.json potions.hud`).
- **An effect's fields:** `type`; `target` (who it acts on: `"cat"` or `"mount"`; H3); `share` (of the target's max
  health: heal, heal_over_time, revive; H3); `stat` and `mult` (the stat becomes × (1 + mult)); `seconds`. For example
  the Health Potion's `{"type": "heal_over_time", "target": "cat", "share": 0.4, "seconds": 5}`.
- **Finding the folders:** `tools/build_content_index` writes `content/index.json` (every folder by kind) before each
  build; Data reads it at start. (Listing folders inside an exported Android game is unreliable, so the game never
  lists them itself.) The content test fails if the index is out of date. `*.json` is already in the export's include
  filter. **Until that tool exists** (H3), `index.json` is written by hand, and `--content` checks that it lists every
  entry folder and nothing else.
- **Bows and buildings** (H4) are content kinds (`content/bows/<id>`, `content/buildings/<id>`), with ids equal to the
  save's ids (`home` is the Hearthtree, `bench` the Bow Shop, `stall` the Market). Callers never read
  `Data.b["bows"]` or `Data.b["stations"]` (they are gone); they ask the Data API (`Data.building`, `building_levels`,
  `build_price`, `level_price`, `building_desc`, `menu_buildings`, `bow_info`, `bow_ids`, `bow_shop_level`,
  `bow_waits`, `has_bow` …).
  - A bow's model, arrow and shop picture stay in `assets/` by id (`player.bow_path`, `arrow.arrow_path`,
    `Data.bow_picture`). A building's picture is `assets/ui/buildings/<id>.png`, found through
    `Data.building_picture` (`""` when there is none yet, like the Saddlery).
  - A building's `arrives` field says how it comes: `menu` (bought in the build menu), `gift` (a mission gives it),
    `found` or `always`. `Data.from_menu` replaces the old `SHOP_BUILT` list.
  - **H4 exception:** buildings' models, spots, footprints and ring offsets stay in `stations.gd` and `world.gd` until
    a step adds a building with its own spot (the Workshop in H6). **H6 then moved every building's spot, foot, ring, path and models into its `layout` block** (below), so this exception is closed.
  - The window words live in `balance.json "windows"`, read through `Data.word(key)`. General building tables stay in
    `balance.json`: `building_hp`, `stat_cap_by_station_level`, `bow_cap_by_bench_level`, `bow_upgrade_curve` and the
    like.
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

- **A version number** (today 6). Every change to the save's form adds one upgrade step in `core/save_upgrades.gd`
  (2→3, 3→4, 4→5 and 5→6 are built), run in order when an older save loads. Before upgrading, the old file is copied to a
  backup. A step reads only frozen numbers (`balance.json save_upgrades.to_vN`) and erases every field it converts.
- **4→5 (H5, `core/save_upgrade_v5.gd`, frozen `save_upgrades.to_v5`):**
  - the Cottage's level becomes the shared `pet_level`, and Sprig and Lumi are owned;
  - the Market becomes one level (`stall` 1); its old level is the mount's carried tier (`saddlery.mount_credit`) and
    its earned health is `market_hp_floor`;
  - outfits and both attachment families move into `owned`;
  - a save from before G4 gets its G4 gifts once;
  - the learned skills fill `saddlery.skill_slots` in the old shop order (Stomp, Ram, Pounce).

  Save resets stations and the H5 fields on every load and keeps unknown kinds, ids and fields in `owned`. `attach` is
  now `{"mount", "pet"}` (the worn expedition gear) and `saddlery` is `{skills, skill_slots, worn, mount_credit}`.
  `Data.pet_level()` is the shared pet level and `Data.mount_level()` is the highest of 1, the Saddlery's level and
  `mount_credit` (0 while no mount is owned).
- **5→6 (H6, `core/save_upgrade_v6.gd`, frozen `balance.json save_upgrades.to_v6`):** defence levels move from one level
  per kind (`def_levels`) onto the pieces. A pure function on the dictionary; it never touches Save, Bag or the world.
  - Every tower and spikes record, and every barricade record (a single-piece old one too), gets `level` = its kind's
    old level, clamped to 1..the cap.
  - Held towers and spikes keep that level: when it is not 1, `defence_reserves[kind]` holds one `{level, wear?}` per
    held piece. Fresh level-1 stock needs no record, and empty kinds are not written.
  - A paid level above 1 with no piece to carry it (none placed, no row spot, none held) becomes
    `defence_legacy_credit[kind] = level`: the first new piece of that kind starts there (the owner: old saves keep what
    they paid for). A barricade in the Bag is refund stock and never counts.
  - `def_levels` is erased. **`Save.def_levels` is gone from the writer and the loader** (the owner's review rule).
    A file without it was already converted, so a second run checks and changes nothing.
  - A v6 file never meets the step, so the loader checks it: `scripts/save_defences.gd` (static) makes every placed
    record's level a whole number in 1..cap and reads the reserves and credits by the same rules.
  - `Save.STATIONS_DEFAULT` has `"workshop": 0`; a save with the Workshop keeps its level and its ruin flag like any
    other building. The Bag still counts towers and spikes in `items` (the reserves carry their levels).
- **What the player owns has one form for every kind:** `owned[kind][id] = {"level": 1, …}`, built in H5 for mounts,
  pets, outfits and attachments (`Data.owned_level`). **Not yet for the rest:** in H3 the
  Bag is a simple `bag` of counts (`{"berries": 5, "health_potion": 1}`: food, fish and potions; `core/bag.gd` writes
  it), towers and spikes stay in `items` and amber in `mats`. The Timers jobs are
  `timers` (`{"seen": Unix s, "jobs": {id: {"start", "len", "data", "told"}}}`).
- **New content** starts locked. **Unknown ids** in a save are kept but ignored, so content that is hidden or comes back
  later is not lost (an unknown id in the Bag is kept and never shown; a garden plot with an unknown crop id is kept as
  it is, shown as empty, and planting there replaces it). **Removed content** is refunded or turned into something else
  by an upgrade step (as amber, glowstone, heartwood and the keys become leaves in H1, and in H3 the pantry goes into
  the Bag, an old dish becomes a Health Potion, and a half-grown crop keeps its share as a Timers job).
- **Sample saves** of every version live in `tests/saves/` (today `v2_sample.json`, `v3_sample.json` and
  `v4_sample.json`; H5 added `v5_sample.json` and H6 `v6_sample.json`), and a test loads each one.

## 11. Tests

- `--content`: every folder in the index has the shared fields; its id matches the folder; its model and icon exist;
  prices use known currencies; unlock rules point to things that exist; effects use known types; `base` points to a
  real entry; the index is up to date. Then buy, save and load one entry of each kind. **In H3** (crops and recipes):
  the index is written by hand, so the test checks that it lists every entry folder and nothing else; the model check
  is `Props.has(<model>_ripe)` and `Props.has(<model>_growing)`, and the icon check is the `ui_icons.gd` id (a missing
  icon is a failure: the owner chose stand-ins drawn in code, so every icon exists); the effect types are checked in
  `--bag`.
- `--timers`: Timers' jobs with a pretend clock: they follow it, end "while the game is closed", wait when the clock is
  set back, and never mark the save dirty by the clock alone.
- `--saves`: loads every sample save and checks nothing is lost. Since H5 it loads the v2 to v5 samples: v4 is
  upgraded and compared with the step's output, v5 loads unchanged, an empty triangle stays empty, and a second file
  loaded in the same run inherits nothing.
- `--h5found` (H5): the 4→5 step case by case, the live Buy purchases, and the four new kinds' entries.
- `--campg` (`autotest_g2_camp.gd` and `autotest_g2_market.gd`, H5): the Market's tabs by real taps, trade amounts,
  gates and refusals, the shard trade being gone, Sprig, Lumi, training and the Hearthtree cap, the pet goal's Go
  opening Pets, the Cottage's old spot being open ground, and a real v4 save upgraded (Market flag, pet level, both
  looks, mount credit, Market HP floor).
- `--cards` (H5): the Market's picture grid (cells the same size, at most 3 a row on a phone, none under 44 px, no
  Button inside a cell, a one-pixel rounding allowed), four bottom icon tabs with names, no footer, neutral payouts on
  Buys; the synthetic window-kit checks (`autotest_g2_cards_kit.gd`) are kept.
- Since H5 the older modes (`--layout`, `--hudcheck`, `--taps`, `--bag`, `--topup`, `--homegoals`, `--buildmenu`,
  `--village`, `--wear`, `--shards`, `--burrowsave`) read the Market, Saddlery and Tailor windows only through
  `main.hud.windows[<id>]`. A test that needs the old Cottage's ground uses the fixture `(6.4, 0, 3.6)`, never
  `station_pos("cottage")`.
- `--workshop` (H6; `autotest_workshop.gd`, with `autotest_workshop_pieces.gd` and `autotest_workshop_rules.gd` loaded by
  it, 123 checks on the phone shape 480x1040): boot at v6, the Workshop's content, build and shop, Place and Undo, taps
  on pieces, levels and gates, repair, the Well, goal routes, the specialisations, armour and the save.
  `--workshop --foundation` (14) keeps the H5 gameplay check on the live boot.
- `--saves` (95 since H6) loads v2 to v6: the frozen v5 file is backed up and upgraded; a mixed-level v5 camp covers
  held stock, a worn tower, uneven row wear and a credit; a second load and a bare second file inherit nothing.
- `--content` (48) knows the new kinds. `--rows` (169), `--layout` (132, includes the Workshop's ground), `--bag`,
  `--campg`, `--hudcheck`, `--homegoals`, `--buildmenu`, `--taps`, `--topup`, `--wear`, `--shards` and `--laststand` were
  moved to per-piece levels and the Workshop; none reads `Save.def_levels` any more. The enemy modes (`--fightf`,
  `--enemyf`, `--assault`, `--burrowfoes`) passed unchanged in stage 1, which is the proof that the parts and states
  changed no behaviour.
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
| H6 (built, local) | Components and States for enemies (armour arrives here); the enemy grid; Place/Undo; the ability toolbox for specialisations; enemies, squads and defences as content folders. Also the Defence Workshop, per-piece levels, building layouts in data and the save at v6 |
| H8 | Components and States for the golem and the friend; fighting styles; the Gloomwood as the first biome; expeditions built room by room |
| H10 | the Store with its real and pretend providers; offers as content folders |
| later | the cat's and mount's own parts, mount skills as abilities, and anything not yet moved, when a step next touches them |

**Where the game is today** (27 November 2026, H6 built locally on `feature/h6-defence-workshop`, on top of H5; H2 to H5 are pushed and not merged):
- six autoloads (Events, Data, Save, Timers, Quality, Pools). New in H1: `game/core/` (events, pools, save upgrades);
  most other scripts are still in `game/scripts/`;
- **built so far in `core/`, `parts/`, `commands/`, `ui/` and `content/`:**
  - Timers (`core/timers.gd`, H3; the jobs live in `Save.timers`: the crops and the cooking pot);
  - the Bag model (`core/bag.gd`, H3; static functions, the only writer of the Bag's counts);
  - the effects list (`core/effects.gd`, H3) and the Effects holder (`parts/effects_holder.gd`, on the cat and the
    mount);
  - the commands Ride/Walk (H2) and Use potion (H3) in `commands/`;
  - the HUD under `ui/hud/` (H2), the first windows in `ui/windows/` (the garden and the cooking pot, H3; one window
    file per building, H4 Stage 1) and the kit in `ui/kit/`: `drag_source.gd` and `drop_slot.gd` (drag-and-drop, H3),
    `list_row.gd` (a building window's list row: picture, name and badge, up to 4 lines, price, one button; a tap on
    the picture is its own action), `confirm_window.gd` (the confirm before a rule runs: any title, lines and price;
    Cancel and Confirm go back to the window it came from, the X closes everything; `hud.confirm`),
    `card_parts.gd` (the pinned footer, a tab's icon and its "!" dot), `icon_grid.gd` (a grid of big picture cells,
    each with a name, a price line or a note, an optional one-tap button and a locked look; the build menu uses it,
    and H5's Market can) and `model_view.gd` (a small turning 3D picture inside a window: its own little world, lit
    like the Bag's picture of the cat, the camera fitted to what it shows; it draws only while it shows, about 10
    times a second on Low; the Bow Shop's inspect view uses it, and H5's attachments and the Tailor's Nook can) (H4).
    The dialog host, its frame and its tabs are `ui/kit/card.gd` (moved there in H4 Stage 3);
  - content folders: `content/settings/` (H2), `content/crops/` (5) and `content/recipes/` (5) (H3), `content/bows/`
    (6) and `content/buildings/` (11) (H4), `content/mounts/` (2), `pets/` (2), `outfits/` (3) and `attachments/` (7)
    (H5), listed by hand in `content/index.json`; the general rules stay in `balance.json`;
  - the Buy command (`commands/buy.gd`, H5) and the window files for the Market, the Saddlery and the Tailor's Nook
    (see part 2); `ui/kit/item_popup.gd` and `skill_triangle.gd` (H5);
  - **H6:**
    - enemies as parts (`parts/health.gd`, `armour.gd`, `enemy_mover.gd`, `enemy_attack.gd`, `enemy_heal.gd`, `status.gd`,
      `enemy_loot.gd`, `health_bar.gd`, `enemy_brain.gd`) and states (`states/enemy/`, 14 files); `enemy.gd` is their
      facade (1,537 lines, from 2,419);
    - the enemy grid (`core/enemy_grid.gd`);
    - the commands Place and Undo (`commands/place_defence.gd`, `undo_place_defence.gd`) over
      `scripts/defence_placement.gd`;
    - the ability toolbox (`abilities/ability.gd`, `explosive_acorns.gd`);
    - `content/enemies/` (24), `squads/` (12), `defences/` (3) and `specialisations/` (3), and `content/buildings/`
      is 11 (the Workshop added); every building's spot and look are in its `layout`;
    - the Defence Workshop: `ui/windows/workshop_window.gd`, `defence_piece_window.gd`, `defence_pad_window.gd`;
      rules in `scripts/workshop_rules.gd` and `defence_levels.gd`; `defences.gd` is the facade over
      `defence_levels.gd`, `defence_markers.gd`, `defence_persistence.gd` and `defence_placement.gd`;
    - per-piece levels, armour on the four tanks, Explosive acorns, Reinforced barricades and Deep thorns;
    - the save at version 6 (`core/save_upgrade_v6.gd`, `scripts/save_defences.gd`; part 10).
- a few very big files: `stations.gd` 1,800 lines (2,672 before H4; the H5 shop rules are thin callers), `enemy.gd` 2,419, `fight.gd` 2,207, `burrow_run.gd` 1,915,
  `defences.gd` 1,159 (1,334 before H6);
- the Events board has 21 signals; the HUD listens to Events (H2); many direct calls through `main` remain elsewhere;
- arrows, damage numbers, text pop-ups, hit effects and pickups are pooled (H1); since H6 arrows, towers, the mount,
  acorns and area moves ask the enemy grid instead of every enemy;
- states as words with `match` blocks for the cat, the bosses, the mount and the companions; the enemies have state files (H6), still switched by the `state` word;
- MultiMesh already used for grass, trees, props and the dungeon floor;
- the save at version 6 (5→6, H6, and 4→5, H5, are in part 10); version 4 (2→3 turns old amber, glowstone, heartwood and Hollow keys into leaves; 3→4, H3, moves the
  pantry into the Bag, old dishes into Health Potions and old crop growth into Timers jobs), dirty-flag flushing and
  atomic writes (H1).

## 14. Decided later, during the steps

- The exact fields of each kind's entry (made when that kind moves over).
- Pool sizes, the grid's square size, the sound limits (first guesses in `balance.json`, measured on the phone).
- When CLAUDE.md's rule "every gameplay number lives in `game/data/balance.json`" becomes "every number lives in
  `game/data/` and `game/content/`": with the Phase H rule changes, once the owner approves the plan.
