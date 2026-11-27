# Phase H plan: expeditions, growing after the missions, and the new screens (version 1.2: a draft for the owner's yes, 25 November 2026)

**Version 1.1 (25 Nov 2026):** the three expedition materials become one, amber, which is only sold; the Hollow keys
are removed; the Burrows are now called expeditions (Part A, H1).

**Version 1.2 (25 Nov 2026):** the owner picked B1–B6 (Part B): Clover the hare druid, leaves/timber/shards on the HUD,
mixed icons, the Golden Carp fed to the mount or sold, the bows at Bow Shop 7 and 9, and a new boss for the intro's
last fight.

**Architecture (agreed 25 Nov 2026):** every step follows [`docs/ARCHITECTURE.md`](ARCHITECTURE.md): one folder per
thing, eight singletons, the patterns and where each is used, and the house rules. Its part 13 says which pieces each
step builds or moves over.

This plan merges the owner's three direction documents with the owner's answers of 25 November 2026. The documents
were written on 24 November 2026 and are on the Desktop:
- `Expeditions.docx`;
- `Game Progression and Addictiveness.docx`;
- `UX and some mechanics overhaul.docx`.

**H1 is merged; H2 and H3 are built on their branches (see each step).** The rest is built from this plan, and the
rule changes in Part A go into `CLAUDE.md`, `docs/STATUS.md` and `docs/GAME_GUIDE.md` part 11.

- **Order:** 12 steps, H0 to H11. Each step that changes the game ends with an APK on the owner's phone.
- **Numbers:** every number is a first guess, kept in `game/data/balance.json` and tuned by play.
- **New models:** Claude designs each one with Codex (one concept image per model). The owner makes it in Meshy.
  Claude builds the part that uses it **after the file arrives**. There are no stand-ins.
- **Nothing extra:** nothing outside this plan is added without the owner's yes (CLAUDE.md).

## How Phase H relates to Phase G

- **Phase G is in the game,** together with the 23–24 Nov work:
  - G1–G4 and the Tailor's Nook;
  - the supplies Bag;
  - aiming while riding;
  - the Fire-spitter;
  - the crossbow towers;
  - "Start wave";
  - the Raid Missions list;
  - Random Raids as one continuous assault.

  Phase H builds on top of all of it.
- **G5 (tuning by play)** becomes part of H11.
- **The Spectral Ranger outfit** (`docs/SKIN_DESIGN_WORKFLOW.md`) stays a separate job outside this plan.
- **Older direction docs:** this plan replaces `docs/DUNGEON_EXPEDITIONS_PLAN.md` and
  `docs/RAID_MISSIONS_AND_RANDOM_RAIDS_PLAN.md` wherever they differ.

---

## Part A. What the owner decided (25 November 2026)

| Topic | Decision |
|---|---|
| Purple shards | **Purple shards (Gloom shards) become the paid currency.** They can be bought with real money in the Market, and they **buy looks only**: mounts, pets, outfits, colour skins and fire looks. Everything shards buy today that makes you stronger moves to leaves and timber. Shards can still be found, rarely, on expeditions. |
| Raids while away | No raid comes while the cat is on an expedition, as today. |
| The crew | An expedition takes the pet, the mount and **one** companion (the golem or the friend). The other stays home. In the camp, both fight. |
| The intro expedition | A new one-time first run of the Gloomwood, after Raid Mission 15. The golem is freed halfway and the friend is rescued at the end. After it, the Gloomwood is the regular expedition and is different each run. |
| The friend | **Clover, the hare druid: a healer that also attacks** (Part B, B1). |
| Food | The 5 new recipes **replace every old dish**. Dishes already in a save become Health Potions. |
| Defences from the Bag | Towers and spikes, and any defence added later, are placed from the Bag. Barricade rows stay on the road pads. |
| Cottage and Market upgrades | The Mushroom Cottage is removed. The pet's upgrades move to the Market's **Pets** tab. The Market's mount speed and health levels move to the **Saddlery's Upgrade**. The Market itself has no levels. |
| Armour | The tanks get armour, so that armour piercing matters. |
| Day and night | Changes how the camp looks, nothing else, and only in the camp. On Low graphics the night only gets darker. |
| The raid bar | Fills as enemies are defeated, with no numbers. In Raid Missions it covers one wave; in Random Raids, the whole attack. |
| Joystick | The floating joystick stays. Ride/Walk goes bottom-right, above the potion buttons. |
| Leaves | **+30% leaves from enemies.** Enough that prices feel fair, not so much that the game feels broken. The whole price list is checked again in H9. |
| Expedition materials | **Amber, glowstone and heartwood become one material: amber.** It is rare, it pays for nothing, and you sell it to Bramble for a big return (first guess: 1,000 leaves and 1 purple shard each). Everything that cost materials costs leaves and timber instead. |
| Keys | **The Hollow keys are removed.** No keys, and no free boon at the start of a run. Boons still come from the shrines inside. |
| Names | The Burrows are now called **expeditions**, in the plan and in the game's text. |
| The Bag | 24 slots. Food stacks to 20. Potion limits: Health Potion 3, Mount Health Potion 3, Cooked Fish 10, Damage Potion 1, Speed Potion 2. |
| Timers | **Cooking and crops keep going while the game is closed.** This is built as **one general timer system**, so any later long job (crafting, building, expedition chests…) is easy to add. |
| Growing after the missions | Raid Missions usually end around **Hearthtree 4–5**, maybe earlier, and the game goes on. The Hearthtree keeps growing to level 10. Each level has a new look and costs a lot more. The Training Target, Bow Shop and other buildings with levels get more levels **without new looks**. Each new level allows more, such as stronger bows. |
| Mount skills | The 3 chosen skills are shared by every mount, so mounts stay looks only. |
| Old saves | Keep what they paid for. Each placed tower keeps today's level, and the Cottage's levels carry over to the pet's upgrades. |
| New models | Claude designs them with Codex, the owner makes them in Meshy, then Claude builds. No stand-ins. |
| Settings | The gear menu holds the graphics level and sound on/off. More is added later. |

**Rule changes.** When the owner approves the plan, these go into CLAUDE.md, GAME_GUIDE part 11 and the memory:
1. **"Nothing happens while the game is closed"** becomes: "Only timers keep running while the game is closed: cooking,
   crop growth, and later long jobs that use the timer system. Raids, fights, the Well and the rest of the camp still
   wait."
2. **Selling looks only stays.** Purple shards are the paid currency and buy only looks.
   - **Bramble stops buying shards for leaves.** Otherwise real money could buy leaves, which buy power. This removes
     the Market's "Sell 5 Gloom shards" row.
3. **The Mushroom Cottage leaves the camp.**
4. **Where numbers live** (from `docs/ARCHITECTURE.md`): "every gameplay number lives in `game/data/balance.json`"
   becomes "every number lives in `game/data/` (general rules) and `game/content/` (one folder per thing)", and every
   agent reads `docs/ARCHITECTURE.md` before writing game code.

---

## Part B. The owner's picks (25 November 2026)

All six open choices are decided. Fight numbers are first guesses, tuned by play.

**B1. The friend: Clover, the hare druid** (its model is designed in H0; it joins in H8).
- A long-eared hare with a twig staff, about the cat's height. The Gloom caged it at the end of the Gloomwood.
- **Heals:** a green beam on one friend at a time (the cat, the mount, the pet or the golem): the strongest steady heal.
  First guess: 4% of that friend's health a second, always on whoever is hurt most within 8 m.
- **Attacks:** throws thorn seeds that burst into small thorn patches. First guess: a seed every 3 s; a patch 1.5 m wide
  that lasts 4 s, slows enemies in it by 30% and pricks them for small damage.
- **Fragile:** it stays far back, behind the fight. When knocked down, it gets up after a while, like the golem, and
  the Well mends it.
- **Upgraded at the Guardian Stone:** its window gets two tabs, the Moss Warden and Clover. No new building.
- Its fighting style is the **healer** style (`docs/ARCHITECTURE.md`).

**B2. The three currencies on the HUD: leaves, timber and purple shards.** Amber, the one expedition material, is an
item in the Bag.

**B3. Icons: mixed.**
- **Things that have a model** use pictures rendered from that model, as the shop cards do now: bows, mounts, pets,
  attachments, outfits and buildings.
- **Flat things** get 2D icons that Claude designs with Codex in the game's colours, for the owner's yes: potions,
  ingredients, seeds, skills, tabs and currencies.

**B4. The Golden Carp: fed to the mount, or sold.**
- Like every fish, it can be fed to the mount from the Bag to mend its health. Being rare, it mends more: first guess
  50% at once (a raw fish mends 10%).
- Bramble also buys it (first guess: 300 leaves).
- It is not used in cooking; Cooked Fish uses ordinary fish.

**B5. Stronger bows:** Bow Shop level 7 opens **Thorn Volley** (3 arrows in a fan, 65% damage each) and level 9 opens
the **Foxfire Bow** (145% damage, goes through 2 enemies, a little more range), with their existing designs. Their
prices are leaves and timber (H1).

**B6. The intro expedition's last fight: a new boss, the Hollow Jailer** (the owner's pick, 25 Nov 2026, from three
concepts in `concepts/h_bosses/`).
- **The Hollow Jailer:** a hunched giant of old roots, bark and stone, about 4 m tall, corrupted by violet Gloom
  crystals, carrying Clover's cage on its back. It pounds the ground with its fists (a ring that hurts), throws crystal
  boulders, and its roots grab at the cat's feet. Beat it and the cage cracks open: Clover is free.
- Concept: `concepts/h_bosses/h10_boss_hollow_jailer.png`.
- **In H0,** Claude proposes 2–3 boss ideas in words (what it is, how it fights, its size) for the owner's pick, then
  makes its concept image with Codex. The owner makes it in Meshy; Claude rigs it and makes its moves.
- It is built from parts, and its attacks are short ability files (`docs/ARCHITECTURE.md`).

---

## Part C. The steps

### H0: designs for the new models (starts at once, runs alongside H1–H2)

**What you'll see:** one concept image per new model, each with a short note: what it is, what it does in the game,
and its rough size.

- **Who makes what:**
  - Claude makes each image with Codex (`tools/gen_concepts.ps1`), using the cat sheet as the style reference. A batch
    has at most 5 images.
  - The owner makes the model in Meshy and puts the file in `art/source/meshy/`.
  - Claude then cleans it, colours it, rigs it and exports it, following `docs/ASSET_RULES.md` and
    `docs/AGENT_BRIEF_MESHY.md`.
- **The friend is Clover** (B1). **The intro boss** (B6) starts with 2–3 ideas in words for the owner's pick, then its
  concept image.
- **If a model is late,** its step goes ahead with everything else, and only the part that needs the model waits.

| Model | Needed for | Rough size | Notes |
|---|---|---|---|
| Emberpepper plant and the picked pepper | H3 | knee-high to the cat (about 0.4 m) | red-orange peppers |
| Swiftroot plant and the pulled root | H3 | leaves about 0.3 m tall | pale blue-green root |
| Defence Workshop | H6 | about the Bow Shop's size (3 × 3 m) | low, so it never hides the cat |
| Clover, the hare druid (B1) | H8 | about the cat's height | Claude rigs it and makes its moves: idle, walk, heal (the beam), throw seeds, knocked down, get up |
| The Hollow Jailer, the intro boss (B6) | H8 | about 4 m tall, with Clover's cage on its back | Claude rigs it and makes its moves: idle, walk, 2–3 attacks, hit, defeated |
| Fletcher's Hut | H9 | about the Bow Shop's size | arrows, feathers, a workbench |
| Hearthtree level 9 and level 10 | H9 | grows on from level 8 ("Heart Oak") | must not block the camera's view of the cat |

- **Batch 1:** Emberpepper, Swiftroot, the Defence Workshop, Clover and the Fletcher's Hut.
- **Batch 2:** Hearthtree levels 9 and 10, and three boss ideas; the owner picked the Hollow Jailer.
- **Done 25 Nov 2026:** all concepts are made and reviewed (`concepts/h_*`, sheet `concepts/phase_h_concepts_sheet.png`).
  The owner makes the models in Meshy.

---

### H1: quick fixes and numbers

**Status (26 Nov 2026):** H1 is done: points 1 to 7 are built, tested, played by the owner on the phone and merged into `development` (Lucky Paw's chests now give 50% more leaves and timber, never more amber).

**What you'll see:**
- a Random Raid keeps fighting after its leader falls;
- enemies drop more leaves;
- the Well comes earlier and mends faster;
- one expedition material, amber, that you sell; no more keys;
- "expedition" instead of "Burrow" in the game's text.

**1. Raiders stay until they're killed.**
- When a Random Raid's leader falls, the rest keep fighting until they are killed. The raid ends, and pays, when the
  last one is down.
- The leader still arrives last.
- Nothing else about how enemies act changes.

**2. More leaves.** Enemies drop **+30% leaves** in Raid Missions, Random Raids and the Gloomwood. Chests and wave pay
stay as they are.

**3. The Wishing Well.**
- It can be built at **Hearthtree 3**. Today it needs 4 missions won. A save that already has it keeps it.
- It has no button; its window only has its Upgrade.
- It still mends only things that are not broken.
- **Faster during waves:**
  - 1% / 1.5% / 2.5% of max health a second at Well levels 1 / 2 / 3 (today 0.5% / 1% / 2%);
  - so anything damaged is at least half mended within a minute;
  - between waves it stays at 3% / 6% / 10%.
- **It also mends the Moss Warden** while the golem is standing, and the friend from H8. A knocked-down golem still
  gets up by its own rules.

**4. One expedition material: amber.** This comes first so that the new Bag, Market and windows are built for one
material, not three.
- **Glowstone and heartwood are gone;** amber is the only one left. The Heartwood barricade keeps its name and look;
  only the material goes.
- **Amber pays for nothing.** Every price that asked for amber, glowstone or heartwood now asks for leaves and timber
  only: Hearthtree 6–8, stat and bow mastery, Saddlery levels 4–5, the pet and mount trinkets (Glowworm Lantern, Ember
  Charm, Dew Bell, Thunder Shoes), level-5 defences and the Foxfire Bow. First guess for the new price: each material
  in the old price becomes the leaves Bramble asks for it today (amber 60, glowstone 120, heartwood 400). For example, Hearthtree 8
  becomes about 54,400 leaves and 200 timber. H9 checks every price again.
- **Amber is rare** (first guesses): the boss drops 1; the sealed Gloom-bound chest 1 in 2; an elite 1 in 10; the
  Amber Grub 1 in 2; a first clear 1. Ordinary kills and chests no longer drop it. That is about 1–2 a run.
- **Selling it:** Bramble buys amber for **1,000 leaves and 1 purple shard** each (first guesses). Bramble stops
  selling amber, because buying it would have no use.
- It still goes into the satchel during a run, and a knock-out keeps half, as today.

**5. No more keys.**
- The Hollow keys are removed: the "Use a Hollow key" row on the way-in card, the free boon at the start of a run, the
  keys in the Bag, and the keys from Random Raids and first clears. Random Raids pay as today, without the key.
- Boons still come from the shrines inside the Gloomwood.

**6. Old saves keep their value.** When an old save loads, its glowstone, heartwood and amber, and any keys, turn into
leaves at what Bramble pays for them today (amber 25, glowstone 50, heartwood 150, a key 150), so nothing is lost and
nothing jumps to the new amber price. A run that was saved halfway has its satchel turned the same way.

**7. "Burrow" becomes "expedition".** Every place the game's text says Burrow or the Burrows says expedition instead,
for example the cards that say "needs Burrow materials". The Gloomwood and the Old Hollow keep their names.

**Technical:**
- `fight.gd`: the rout on the leader's death is removed for Random Raids.
- `raids.gd`: the end and pay of a raid, without keys.
- Leaf drop numbers in `balance.json`.
- `stations.well`: `needs_home` 3 instead of `needs_missions`.
- `well.passive.regen_by_level`.
- The Well's mending reaches the guardian.
- Amber and keys: `balance.json` (every price, `burrows.drops`, `burrows.keys`, `market`), `data.gd` (paying),
  `save.gd` (the old-save change), `burrow.gd` and `burrow_run.gd` (drops, the way-in card, keys), `inventory.gd`,
  `stations.gd` (the texts) and the tests that use keys or three materials.
- **Architecture first pieces** (`docs/ARCHITECTURE.md` part 13): `core/` with Events and Pools (arrows, damage
  numbers, hit effects, pickups), `save_upgrades.gd` (the amber and keys change is its first upgrade step), saving once
  at safe moments (Dirty Flag), and Data reading `content/index.json`. Speed is measured before and after the pools.
- **Who:**
  - Sonnet: points 1–3;
  - Opus: points 4–7 (one owner for `balance.json` and `save.gd` at a time, so they go one after the other);
  - Opus: the architecture first pieces, before points 4–7 (they use the save upgrades).
- **Tests:** `--smoke`, the Random Raid and Well test modes, the Gloomwood mode, `--campg` (the Market),
  `--inventory`, and the new `--saves`, `--pools` and `--perf` before and after.

---

### H2: the new HUD and Settings

**Built (26 Nov 2026) on `feature/h2-hud`** (commits `c030041`, `1d0377c` and `042d78c`). It waits for the owner's phone
review before it merges into `development`. What was decided and built (the owner's sketch and answers, 26 Nov 2026):

| Where | What |
|---|---|
| Top-left | The three currencies only (leaves, timber, shards), small, no dark strip, always all three. Below ground the satchel follows them. |
| Top-centre | The raid bar, with no words and no numbers. Under it, only in fights, a thin campfire bar (gold to red, flashes when the fire is hit). Under that, the words line: the next wave's roads, the wave, the raid's name, the Gloom words or the Gloomwood level. It never counts enemies left. |
| Top-right | The Settings gear. |
| Over the cat | The health bar (and the mount's while riding). The Bag shows health as bars too, with the currencies packed under them. |
| Bottom, row 1 | The Bag (left), the build icon (a house) next to it, the snack or potion slot at the right. |
| Bottom, row 2 | The defence buttons (smaller) just above the Bag; Ride/Walk (or Feed while the mount is knocked out) at the right, above the snack slot. |
| While placing | Place and Done, centred at the bottom; the Bag group slides out. |

- Nothing goes in the middle third of the screen. The floating joystick stays as it is.
- **Start wave stays on the signpost's card only.** There is no Start wave button on the screen.
- **The build icon** opens the Hearthtree's card at its Buildings shelf from anywhere in the camp. It is hidden below
  ground, and in a wave it gives the usual "A wave is on!". H4 swaps in the real build menu.

**1. Health as bars,** with no numbers: over the cat's head, and in the Bag.

**2. All three currencies** are always shown, top-left.

**3. The raid bar** fills as the fight is beaten, with no numbers:
- in a Raid Mission it is the share of this wave beaten, and an empty track between waves;
- in a Random Raid it is the Gloom meter (violet), then the warning countdown (gold to red), then the share of the
  whole attack beaten;
- in the Gloomwood the same place holds the fight pips.

**4. Settings** (the gear):
- Graphics: Auto, Low, Medium or High;
- Sound on or off;
- saved in their own small file (`user://settings.json`), not in the game save, and never written during autotests;
- the texts come from `game/content/settings/graphics/entry.json` and `.../sound/entry.json`; room for more later.

**5. Buttons slide in and out** with a short fade (0.2 s) instead of popping. A button that is sliding out stops
taking touches at once.

**Technical (as built):**
- `hud.gd` is now a facade in `game/ui/hud/` with its parts beside it (`top_bar.gd`, `fight_bar.gd`, `messages.gd`,
  `action_buttons.gd`, `card.gd`, `settings_window.gd`, `slide.gd` and more; the list is in `docs/GAME_GUIDE.md`
  part 11). Public names are kept.
- The HUD listens to Events (`currency_changed`, `fight_progress`, `riding_changed`, `mount_down_changed`,
  `placing_changed`, `area_changed`, `boss_changed`, `campfire_hit`, `wave_ended`, `raid_ended`).
- Ride/Walk sends the Ride command (`game/commands/ride.gd`).
- `game/core/settings_file.gd`, `Quality.set_level` and `set_auto`, `Sfx.set_sound`.
- **Who:** Opus agents.
- **Tests:** the new `--settings` (40 checks); `--hudcheck` is now 121 checks (real taps on Ride, the gear, a graphics
  row, the Bag and the build icon; a mission wave, the Last Stand and a raid's attack; the raid bar fills);
  `--inventory` 56; `--layout` and `--smoke` as before. The layout test checks nothing enters the middle third and no two
  edge controls overlap. One old fail in `--raidshots` ("the Watch card": the card is now called "Random Raids") predates
  H2 and is still there.
- Screenshots come with the APK.

---

### H3: food, potions and the Bag

**Built (26 Nov 2026) on `feature/h3-food-bag`** (commits `f0f181a` and `09dc171`, then a stage 3 clean-up). The branch
starts from `feature/h2-hud`, so it merges after H2. It is not pushed yet and waits for the owner's phone test. The
game as built is in `docs/GAME_GUIDE.md` part 6 (and part 11 for developers). Below: the plan, with what changed
marked **As built**, then the owner's answers and the defaults that were built.

**What you'll see:**
- crops and cooking keep going while the game is closed;
- a garden window that looks like the garden;
- a cooking pot you drag ingredients into;
- 5 potions;
- a new Bag;
- defences are placed from the Bag.

**1. The timer system** (new, general).
- One part of the game keeps every long job: a growing crop, a pot cooking, and anything added later.
- Each job saves when it started and how long it takes, by the phone's clock. It keeps going while the game is closed.
  When you come back, it is further along or done.
- **Adding a new long job later** means one new entry in `balance.json` plus what happens when it finishes.
- **If the phone's clock is set back,** jobs never run backwards. They wait until the clock catches up.
- Only these jobs run while the game is closed. Raids, fights, the Well and the rest of the camp wait (rule change 1).

**2. The Garden.**
- **The window looks like the garden:** its plots are laid out as they are in the camp, with the seeds in a row below.
- **Planting:** drag a seed onto an empty plot. You pay when you drop it. Seeds cost as today (10 / 12 / 15 leaves);
  the new seeds are priced the same way.
- **Water** waters every planted plot. Watered crops grow twice as fast for 5 minutes. **As built:** 5, 6 and 7
  minutes at garden levels 1, 2 and 3 (levels 2 and 3 keep their longer watering); free, no cooldown; a seed planted
  afterwards is dry.
- **Picking:** tap a ripe plant and it goes into the Bag. If the Bag is full, "Bag full" shows and the crop stays ripe.
- **As built:** Emberpepper seeds cost 20 leaves and Swiftroot seeds 18, both from garden level 1.
- **Growing time is real time** (first guesses):

| Crop | Gives | Grows in |
|---|---|---|
| Sunberries | 3 berries | 4 min |
| Fernmint | 2 herbs | 5 min |
| Honeybells | 2 honey | 6 min |
| **Emberpeppers** (new) | 2 peppers | 8 min |
| **Swiftroots** (new) | 2 roots | 7 min |

**3. Cooking.**
- **The window:** the pot is at the top with ingredient slots. Your ingredients are below as big icons with their
  counts.
- **Cooking a recipe:**
  - drag ingredients into the slots; when they make a recipe, **Cook** lights up;
  - cooking takes 30 s to 1 min, and the timer runs while the game is closed;
  - **Collect** puts the result in the Bag.
  - **As built:** 3 slots; a tap on an ingredient also fills the next slot, and the window has a recipe list (Q15).
- There is one pot for now. More can be added later through the timer system.
- **The recipes:**

| Recipe | Ingredients (first guesses) | What it does | Bag limit | Cooks in |
|---|---|---|---|---|
| **Health Potion** | 2 Fernmint, 1 honey | Heals the cat by 40% of its health over 5 s | 3 | 40 s |
| **Mount Health Potion** | 2 Sunberries, 1 honey | Revives a knocked-out mount with half its health. That is all it does. **As built: with full health** (the owner, 26 Nov 2026). | 3 | 45 s |
| **Cooked Fish** | 1 fish | Heals the mount to full over 10 s | 10 | 30 s |
| **Damage Potion** | 2 Emberpeppers, 1 honey | Arrows hit 25% harder for 30 s | 1 | 60 s |
| **Speed Potion** | 2 Swiftroots, 1 honey | The cat moves 25% faster for 20 s | 2 | 50 s |

- **Raw fish** can be eaten from the Bag to heal the mount a little (10%). The rare **Golden Carp** mends it by 50% at
  once, or Bramble buys it for 300 leaves (B4; first guesses).
- **Every old dish is gone:** Berry Tart, Fernmint Tea, Honey Cake, Hearth Stew, Fish Skewers, Warden's Root Stew and
  the Golden Carp Feast. Dishes in a save become Health Potions, up to the limit of 3; any extra are refunded as leaves
  (**as built:** 50 leaves each, Q5). Feed and the snacks below ground are gone too (Q1, Q2).

**4. The Bag.**
- **24 slots in a grid,** like Minecraft. Only things you own take a slot.
- **Stacking:**
  - garden food and fish stack to 20 in a slot, and use more slots if you have more;
  - each potion has one stack with its own limit.
- **Using an item:** tap it to see its name, what it does and its button: **Use** for potions and fish, **Place** for
  towers and spikes.
- **Removed:** Eat, Quick heal and Use auto. The pantry limit of 20 is replaced by the stacks.

**5. Potion buttons on the HUD (bottom-right).**
- The Health Potion button appears only when the cat is hurt and you have one.
- The Mount Health Potion button appears only when the mount is knocked out and you have one. **As built:** it takes
  Ride's place (row 2), and the Health Potion button is in row 1 at the right.
- The Damage and Speed potions are used from the Bag. **As built:** while one works, a line under the currencies shows
  it (Q22).

**6. Placing defences from the Bag.**
- Towers and spikes you buy go into the Bag. Until the Workshop (H6), they are bought where they are bought today.
- **Place** shows where the piece can go, the same places as today. Then it drops in with a small bounce and a puff of
  dust. This is made in code, with no new cat animation. **As built:** the ghost is also red by the lake and the home
  (Q25), and the defence buttons above the Bag stay as a shortcut (Q4).

**Technical (as built):**
- `game/core/timers.gd` (the `Timers` autoload, right after `Save`; the jobs live in `Save.timers`), `game/core/bag.gd`
  (the Bag's counts and stacks), `game/core/effects.gd` and `game/parts/effects_holder.gd` (what potions do),
  `game/commands/use_potion.gd` (the Use-potion command), `game/ui/windows/garden_window.gd` and
  `cooking_window.gd`, and the drag kit `game/ui/kit/drag_source.gd` and `drop_slot.gd`.
- `garden.gd`, `cooking.gd` and `inventory.gd` rewritten; the potion buttons in `ui/hud/action_buttons.gd`.
- Save version 4 (`core/save_upgrades.gd`): `bag` and `timers`; the pantry, dishes and old crop growth move over.
- **Crops and recipes are content folders** (`game/content/crops/`, `game/content/recipes/`), not `balance.json`
  `garden.crops` and `cooking.recipes` (ARCHITECTURE part 13). `balance.json` has the new `timers`, `bag` and
  `potions`, and `garden.water_s_by_level`, `garden.water_speed` and `cooking.pot_slots`. Stage 3 removed the old keys.
- **Who:** Opus agents built the core, the potions, the Bag and the garden and cooking logic; the two windows were
  separate parts; each stage had an Opus review.
- **Tests:** `--smoke`; new `--timers` (a fake clock: jobs finish while the game is "closed" and wait when the clock is
  set back), `--content`, `--bag` (also `--inventory`), `--garden`, `--cook`; `--feed` runs the potions checks; `--saves`
  upgrades the v3 sample and loads the new v4 sample; `--saves --startup=1` then `=2` tests a real first launch with a
  v3 save on disk.

**The owner's answers (26 Nov 2026):**
- **Q1:** the Mount Health Potion replaces Feed (the Feed button and its 2 Sunberries are gone). It brings the mount
  back with **full** health, and its button takes Ride's place.
- **Q2:** only Health Potions heal the cat below ground. No food is eaten anywhere.
- **Q6:** stand-in icons drawn in code: a small bottle in each recipe's colour, a red pepper, a pale root. Designed
  icons only when the owner asks.
- **Q15:** yes: a tap on an ingredient fills the next empty slot, and the pot's window has a read-only recipe list.
- **Q22:** yes: the line under the currencies shows a running Damage or Speed Potion ("Damage +25% · 24 s").
- **Q25:** yes: the placing ghost uses the start-up check's rule, so it is red by the lake and the home. Drawing the
  allowed ground is not built.

**Built by default** (no answer came, so the build map's "If no answer" line was built):
- Q5: 50 leaves for each old dish past the potion limit (this cannot happen today). Q7: an old half-grown crop keeps
  its share. Q9: Swiftroot 18 leaves, Emberpepper 20, both from garden level 1. Q10: watering 5, 6 and 7 min by garden
  level.
- Q12: the garden and pot cards stay closed in a wave; the timers keep running. Q17: a catch swims away when the Bag is
  full; buying is refused with "Bag full" before you pay; things already paid for always go in. Q18: amber, towers and
  spikes stack to 20. Q24: the Golden Carp sells at any time for 300 leaves; Bramble sells no peppers or roots. Q28: a
  simple `bag` of counts in the save (towers and spikes stay in `items`), and no Undo for placing (H6). Q30: the plan's
  clock rule (a clock set back makes jobs wait; no cap on a clock set forward).
- Q4: the row-2 defence buttons stay as a shortcut. Q8: watering is free with no cooldown. Q11: Gloom +2 once per
  garden visit that picks, +3 on the Cook tap only. Q13: the pot keeps cooking while the fire is out. Q14: 3 slots,
  nothing leaves the Bag until Cook. Q16: Cook is refused when the result would not fit; a full Bag at Collect keeps it
  in the pot. Q19: the Bag sorts itself. Q20: a potion still working cannot be used again ("Already active"); effects
  pause with the game, end on a knock-out and are lost when the game closes. Q21: the Speed Potion works while riding;
  the Damage Potion is for arrows only. Q26: fish and Cooked Fish mend a standing mount only.
- Decided by the plan, not asked: raw garden food has no Use (Q3); the Health Potion button shows whenever the cat is
  hurt (Q23); crops and recipes are content folders (Q27); the old dish boosts go with the dishes (Q29); both old
  dishes in a save, waiting and eaten, become Health Potions.

**Known points (the owner's call: noted, not fixed now):**
- `--dungeoncareful` now loses at the boss in about 2 runs of 3 (passed 1 of 3: the boss took 25 health in the run it
  won and 32 in a run it lost, from a 14-health cat). Below ground only Health Potions heal now (Q2), and the careful
  test cat has 3 Health and 3 Mount Health Potions. Expeditions are rebuilt in H8 and balanced in H11.
- The garden's card scrolls about 150 px at 540x960 to reach its Upgrade row (the window itself fits). At the phone's
  shape (480x1040 with safe insets) nothing scrolls.
- Cooked Fish uses a bottle icon like the other recipes (the owner chose bottles); its light orange is close to the
  Damage Potion's orange.

---

### H4: building windows, part 1 (the shared window, the Hearthtree, the Target, the Bow Shop, the build menu)

**Built (26 Nov 2026) on `feature/h4-building-windows`** (commits `e3fd019`, `63059eb` and `f72b03f`, the stage 3
clean-up). The branch starts from `feature/h3-food-bag`, so it merges after H3. It is pushed to GitHub but not merged,
and waits for the owner's phone test. The game as built is in `docs/GAME_GUIDE.md` part 3 ("The building windows") and
part 11 for developers; the change list is in `docs/CHANGES.md`. Below: the plan, then **As built** and the owner's
answers.

**What you'll see:** every building opens the same tidy window, with one Upgrade button that never scrolls away, and a
build menu.

**1. One window style for every building.**
- It opens as today's centred dialog with an X.
- Buildings with levels have an **Upgrade** button fixed at the bottom; it never scrolls away.
- **Upgrade** closes the window and opens a confirm window. It says exactly what the next level gives and what it
  costs, with Confirm and Cancel.
- **For later steps:** each building's window moves out of `stations.gd` into its own file. Later steps can then work on
  different buildings side by side.

**2. The Hearthtree.**
- **Two tabs: Hearthtree and Cat.**
  - The **Hearthtree** tab shows only what it needs to grow (the goal list, ticked or not) and the Upgrade button.
  - The **Cat** tab lists Health, Move speed and Leaf magnet. Each row shows its level and what the next level gives,
    with its own button.
- **The defence levels** sit on a temporary third tab, **Defences**, until the Workshop takes them over (H6). Today
  they are bought on the Hearthtree's card.

**3. The Training Target.**
- A vertical list: Damage, Draw speed and Range. Each row has its icon, level, what the next level gives and one button.
- Upgrade is at the bottom. There is nothing else.

**4. The Bow Shop.**
- The same list, for the bows. Each row's button is Buy, Upgrade, Equip or Equipped.
- **Tap a bow's picture to inspect it:** the bow shown big, turning slowly, with its arrow and its numbers.
- Upgrade is at the bottom.

**5. The Well and the Guardian Stone** get the same style. The friend's tab comes in H8.

**6. The build menu** (the icon next to the Bag).
- It shows big icons of every building you can build, and the locked ones greyed out with what they need.
- **Tap one** for its detail view (its picture, what it does, its price) and **Build**.
- Build puts the building on its own spot in the camp, as today, and the camera shows it going up.
- The window and its icons animate in.

**Technical:**
- `stations.gd` is split into one window file per building.
- `hud.gd`: the shared window and confirm parts.
- **Who:**
  - Opus: the window style, the split and the buildings;
  - Sonnet: the build menu, in a new file.
- **Tests:** `--smoke`, `--homegoals`, `--bowshop` and `--layout`.

**As built (H4):**
- **The Hearthtree** has three tabs at the top: Hearthtree, Cat and Defences. A tab shows once it has something (no tab
  bar with one tab), the window opens on the Hearthtree tab, and a tab gets a "!" when something on it can be bought
  (the owner's yes). Mend all, Patch it up and "Nothing for sale yet" stay at the top and Graphics at the bottom. A goal
  has Go (walks the cat) or Show (opens the tab, or the build menu at a building not built yet).
- **The pinned Upgrade** (the owner's Q1 (c) and Q2 (a)): the Hearthtree, the Target, the Bow Shop, the Well, the
  Guardian Stone (awake), the garden, the Market, the Cottage and the Saddlery end in an Upgrade that never scrolls
  away. It always opens a confirm window; the price is red and Confirm grey when you can't pay. Buy, Equip and Build
  stay one tap. (H5 later took the Market's and the Cottage's Upgrade away with their levels.)
- **The Bow Shop** (Q10 (a), Q11): one row per bow (Upgrade, then a grey Equipped for the bow in the paw; Equip; Buy;
  Locked). A tap on a bow's picture opens its inspect view with its real arrow damage.
- **The build menu** (Q12 to Q16): the build icon opens a grid of building pictures that fade in one by one, each open
  one with its own Build; locked ones are greyed with their needs; a detail view; nothing can be built while the
  Hearthtree is in ruins. A dot on the icon replaces the Hearthtree marker's "!" for buildings. The camera glides to a
  new building for about 2 s while it rises out of the ground.
- **Tips** (Q17 (a)): both building tips say "tap the build icon next to the Bag".
- **Code:** one window file per building in `ui/windows/`, the kit in `ui/kit/`, bows (6) and buildings (11) as content
  folders; `stations.gd` went from 2,672 to 1,723 lines. New `--buildmenu`; `--homegoals`, `--bowshop` and `--cards`
  rewritten.

---

### H5: building windows, part 2 (the Market and pets, the Saddlery, the Tailor's Nook)

**Built (27 Nov 2026) on `feature/h5-market-saddlery-tailor`** (commits `098b04f` and `b24159d`, then a stage 3
clean-up). The branch starts from `feature/h4-building-windows`, so it merges after H4. It is local, not pushed, and
waits for the owner's phone test. The game as built is in `docs/GAME_GUIDE.md` parts 3 and 5 (and part 11 for
developers). Below: the plan, then **As built** and the owner's answers.

**What you'll see:**
- the Market looks like the owner's pictures 2 and 3, and sells mounts and pets;
- the Cottage is gone;
- the Saddlery has a skill triangle;
- the Tailor's Nook looks like picture 1.

**1. The Market.**
- **Tabs along the bottom, icons only:** Sells, Buys, Mounts, Pets, and Shards from H10.
- **Sells and Buys:** grids of big icons with the price under each. Tap one for a small popup with its name, what it is,
  and Buy or Sell with an amount.
- **Mounts:** a vertical grid showing each whole mount and its price. Thistle is free and Bramblewool is there; paid
  mounts come later.
- **Pets:**
  - the same kind of grid for Sprig and Lumi;
  - Sprig's upgrade levels are here (today they are the Cottage's levels). Each level makes the pet hit harder and
    faster;
  - Sprig costs what the Cottage costs today.
- **No Upgrade button:** the Market has no levels. Its mount levels move to the Saddlery.
- **Bramble no longer buys Gloom shards** (rule change 2).
- **Amber** is on the Buys tab at its H1 price.

**2. The Mushroom Cottage leaves the camp.**
- The pet stays with the cat, as today.
- **Old saves:** the Cottage's level becomes the pet's level, so nothing is lost.

**3. The Saddlery.**
- **Two tabs at the bottom: Attachments and Skills.**
- **The Skills tab:**
  - at the top, **3 circles joined in a triangle**. Drag up to 3 learned skills into them; those are the skills the
    mount uses;
  - below, every skill as a round icon in a grid, 3 or more to a row. Tap one for its details and Learn or Upgrade;
  - the 3 chosen skills are shared by every mount;
  - the **Upgrade** button on the Skills tab upgrades the Saddlery itself. Each Saddlery level now also raises the
    mount's speed and health (moved from the Market) and the skills' level cap.
- **The Attachments tab:**
  - big icons; tap one for a detail view with its 3D model turning, and Buy, Upgrade or Wear;
  - one attachment is worn at a time, as today.
- **Old saves:** learned skills are kept, and the first 3 learned go into the triangle. The Market's mount levels move
  over to the Saddlery.

**4. The Tailor's Nook** (like picture 1, in the game's colours).
- The cat stands big in the middle, turning slowly, with the outfit cards below. Locked outfits are grey.
- Tap a card to try the outfit on, then Buy or Wear.

**Technical:**
- The Market, Saddlery and Tailor window files from H4.
- `mount.gd` (the 3-skill choice), the pet code, `world.gd` (the Cottage is removed) and `save.gd`.
- `balance.json`: `market`, `pet`, `saddlery` and `mount`.
- **Who:**
  - Opus: the Market, pets and removing the Cottage;
  - Opus: the Saddlery;
  - Sonnet: the Tailor's Nook.

  Each agent owns its own window file. `save.gd` and `balance.json` have one owner at a time.
- **Tests:** `--smoke`, `--saddlery`, `--tailor` and `--layout`.

**The owner's answers (26 Nov 2026):**
- **Q1 (B):** Sprig costs 160 leaves and gives the pet. **Lumi is a looks-only pet look with her own Buy at 400 leaves**,
  and fights exactly like Sprig at the shared pet level. Her Buy shows only once the pet is owned. An old save that had
  the Cottage (any level) owns **both** for free; a fresh save owns neither.
- **Q2 (A):** the mount keeps the tier an old Market had paid for (`saddlery.mount_credit`). The Saddlery stays at its
  real level. `Data.mount_level()` is the highest of 1, the Saddlery's level and that credit, and 0 while no mount is
  owned. The Skills confirm says when the building is catching up.
- **Q3:** the triangle holds **0 to 3** skills, never 4. An old save that learned all four fills it in the old shop
  order (**Stomp, Ram, Pounce**); Bellow stays learned in the grid.
- **Q4 (A):** Hearthtree 3 asks for a **built Market** and **pet level 2**; Hearthtree 4 asks for **pet level 3**.
  Every other goal stays.
- **Q5 (A):** a new Market has **200** health. An old Market keeps the 200, 340 or 500 its player earned.
- **Q6 (A):** mount level 4 is **1.6575x** walking speed and **18** base health; level 5 is **1.785x** and **24**.
- Everything in the build map's second list of defaults stood.

**As built (H5):**
- **The Market:** four icon tabs at the bottom (Sells, Buys, Mounts, Pets); no levels, no footer, no Upgrade.
  Sells and Buys are grids of big pictures with the price; a tap opens a popup (amount, You pay or You get, Buy or Sell).
  On Buys the price is what Bramble pays you, shown neutral. **Bramble no longer buys Gloom shards.** Amber shows after
  the Raid Missions. The "Shards" tab is H10's.
- **Mounts and Pets tabs:** the whole of each mount and pet; colours, Gloomlit and the Gloomwood gear moved here. Sprig
  costs the Cottage's old 160 leaves; the pet's training (350; 900 and 30 timber) is on the Pets tab, capped by the
  Hearthtree.
- **The Cottage** is gone from the camp, the build menu, the marker and the code; the pet stays with the cat. The old
  Cottage ground is open.
- **The Saddlery:** two tabs; Attachments as pictures with a turning detail view; Skills with the triangle of three
  circles and a round icon grid; the pinned Upgrade is on Skills, and its confirm shows the mount's speed and health.
  The mount fires only the skills in the circles.
- **The Tailor's Nook:** the cat turning on a stand with the outfit cards below; unowned cards grey and still
  tryable; one Buy, Wear or Wearing button.
- **Save version 5** (`owned`, `pet_level`, `market_hp_floor`, the circles); a Buy command (`commands/buy.gd`) used by
  every shop window; mounts, pets, outfits and attachments as content folders (the plan's step H5 in
  `docs/ARCHITECTURE.md` part 13).
- **Built in** three stages by agents as Part F sets out: the foundations (stage 1), the live switch and the windows
  (stage 2), then the older tests, the clean-up and the docs (stage 3).
- **Tests (all pass on the PC):** `--h5found` (new, 60), `--campg` 110, `--saddlery` 156, `--tailor` 76, `--cards` 147,
  `--saves` 85, `--content` 48, `--layout` 118, `--hudcheck` 130, `--taps` 22, `--bag` 110, `--topup` 23, `--homegoals`
  92, `--buildmenu` 47, `--shards` 21, `--wear` 10, `--smoke`, `--village` and the default run. `--dungeoncareful`
  was not run (its H3 point stands).
- **Known points (noted, not fixed now):** nothing of H5 has been tried on the phone; the Nook's stand size may need
  tuning; two unused word fallbacks (`H5_WORDS`) remain in the Saddlery's files; `--village` logs "no button Walk"
  (no checks in that mode).

---

### H6: the Defence Workshop, upgrading each defence, armour

**Needs the Workshop model.**

**What you'll see:**
- a new building for all defences;
- tap any tower, barricade row or spike patch to upgrade just that one;
- three specialisations;
- tanks with armour.

**1. The Defence Workshop.**
- Built from the build menu after mission 2, when towers open.
- **Its window:**
  - **Defences:** buy towers and spikes into the Bag, and see how many you have and the limit;
  - **Specialisations** (point 3);
  - **Upgrade** at the bottom: Workshop levels 1–5, never above the Hearthtree. More levels come in H9.
- The temporary Defences tab on the Hearthtree (H4) goes away.

**2. Each defence is upgraded on its own.**
- **Tap a placed piece** (a tower, a barricade row or a spike patch) to open a small window with:
  - its level;
  - what the next level gives;
  - Upgrade, with the confirm window;
  - Repair when it is damaged, as today.
- A piece's level is capped by the Workshop's level.
- **Barricade rows** keep their looks by level (log → stone → thorn → shard → heartwood), now per row.
- **No more shards for power:** Shardstone, tower level 5 and spikes level 4 cost leaves and timber instead.
- **Old saves:** every placed piece gets today's level for its kind.

**3. Specialisations.**
- These are the owner's three examples. Each is learned once at the Workshop, then upgraded (levels 1–3), and works on
  every piece of its kind:

| Specialisation | For | What it does at level 1 (first guesses) | Per level |
|---|---|---|---|
| **Explosive acorns** | Acorn Towers | Each hit bursts in a small blast (1.2 m) for 30% of the hit's damage | +15% |
| **Reinforced barricades** | Barricade rows | +25% health, and a piece cracks at 35% health instead of 50% | +15% health |
| **Deep thorns** | Thorn Spikes | The slow is 30% stronger and lasts 1 s after an enemy steps off | +10% slow |

- Any more specialisations need the owner's yes.

**4. Armour on the tanks.**
- The Toadstool Brute, Stump Golem, Crystal Snail and Beetle Knight get **armour**, which blocks a share of each hit.
  First guesses: Brute 20%, Golem 25%, Snail 30%, Beetle Knight 35%.
- **Their health is lowered to match,** so they take as long to kill as today and the missions don't get harder.
- **Armour piercing** (the Fletcher's Hut, H9) ignores part of the armour, so tanks then go down faster.
- Bosses get no armour for now.

**Technical:**
- `defences.gd` (per-piece levels and specialisations), the Workshop window file and `enemy.gd` (armour).
- `save.gd`: per-piece levels.
- `balance.json`: `stations.workshop`, `defences.*`, `specialisations` and each tank's `armour`.
- **Who:**
  - Opus: defences and the Workshop;
  - Opus: armour in `enemy.gd`.
- **Tests:** `--smoke`, `--rows`, `--campg` and a new `--workshop`.

---

### H7: day and night

**What you'll see:** the camp goes through morning, day, evening and night.

1. **A day lasts 12 minutes,** a first guess within the owner's 10–15. Night is about 3 of those minutes.
2. **It changes only the look:** the sky's colour, the sun's angle and colour, and how long the shadows are.
3. **At night the campfire and other glowing things shine brighter** on Medium and High. On Low, the night only gets
   darker.
4. **Night is never too dark to see enemies.**
5. **It runs on play time, only in the camp,** waves included. It waits during expeditions and while the game is
   closed.

**Technical:**
- `world.gd` (the sun, sky and fog), `quality.gd` and the campfire's light.
- `balance.json`: `day_night`.
- **Who:** one Sonnet agent.
- **Tests:** `--smoke` and a new `--daynight` (the day goes round, and Low adds no lights).

---

### H8: expeditions (the intro, the friend, the crew screen, a Gloomwood that changes)

**Needs Clover's model** (B1) **and the intro boss's model** (B6).

**What you'll see:**
- a one-time intro expedition;
- the golem and a new friend;
- a crew screen;
- a Gloomwood that is different each run.

**1. Expeditions open after Raid Mission 15,** as the Gloomwood does today.

**2. The intro expedition** (once).
- The first trip into the Gloomwood is a special one-time run with 5–10 minutes of hard fights.
- **Halfway:** the Mossback fight. Then you free the Moss Warden from its Gloom cage, and it fights beside you for the
  rest.
- **At the end:** the Hollow Jailer carries Clover's cage on its back (B6). Beat it to crack the cage and free Clover,
  who moves into the camp.
- **If you leave or fall,** you try again: from the start, or from halfway if the golem is already free.
- **Saves that already freed the Warden:** the halfway cage is empty, and the rest plays the same.

**3. The crew screen** (before each expedition).
- The cat sits in a circle at the top with 3 slots around it: mount, pet and companion.
- Below it are rows that scroll sideways: **Mounts, Pets, Companions** (the Moss Warden and the friend).
- **Drag** a card into a slot; drag it out to empty the slot.
- There is only one companion slot. The other companion stays home to guard the camp (no raid comes while you are
  away).
- **Go** starts the expedition.

**4. The Gloomwood changes each run.**
- **What changes:** each run puts its rooms together in a different order, with different enemy squads and treasure in
  different places. The boss is always at the end.
- **Rewards:**
  - leaves and timber as today, and now and then amber to sell (H1);
  - **sometimes purple shards** (first guess: 1 run in 5, 3–5 shards).
- **Two more expedition bosses** (the owner, 25 Nov 2026): **Old Croakmaw** (the Gloom toad) and **the Thornwyrm**
  (the bramble serpent), from the boss ideas not picked for the intro; the owner made both in Meshy
  (`art/source/meshy/phase_h/`). My pick for where they go, to confirm when H8 starts: the changing Gloomwood picks its
  end boss each run from Mossback, Old Croakmaw and the Thornwyrm. Each is built from parts, its attacks are short
  ability files, and Claude colours, rigs and animates it in Blender.
- **Later:** up to 10 expeditions picked at random, each needing new models. They are not part of this plan; for now
  there is only the Gloomwood.

**5. The friend in fights.**
- It comes on an expedition if you pick it. In the camp it fights in Raid Missions and Random Raids beside the golem.
- It heals one friend at a time with its green beam and slows enemies with thorn seeds (B1).
- When knocked down, it gets up after a while, like the golem. The Well mends it.
- It is upgraded at the Guardian Stone, which gets a Moss Warden tab and a Clover tab (B1).

**Technical:**
- `burrow_run.gd` (the intro and the changing rooms) and the room pieces in `data/dungeons/`.
- A new `friend.gd`, the crew screen (a new file), the Guardian Stone window and `save.gd`.
- `balance.json`: `expeditions`, `friend` and `crew`.
- **Who:**
  - Opus: the intro and the changing Gloomwood;
  - Opus: the friend and the crew screen;
  - Claude: rigs and animates Clover and the intro boss in Blender (headless), once the owner's Meshy files arrive.
- **Tests:** `--smoke`, the Gloomwood mode, a new `--intro` and a new `--crew`.

---

### H9: growing after the missions

**Needs the Fletcher's Hut model and the Hearthtree level 9 and 10 models.**

**What you'll see:**
- the Hearthtree grows on to level 10;
- every building has more levels;
- the Fletcher's Hut;
- Random Raids that grow with you.

**1. The Hearthtree.**
- The goal lists are set so that Raid Missions usually end around **Hearthtree 4–5**.
- **It grows on to level 10:**
  - levels 6–8 keep the looks they have today, and levels 9 and 10 get the owner's new models;
  - each level after the missions costs much more, in leaves and timber;
  - each level raises the caps of the other buildings.

**2. More levels for the other buildings, with no new looks.**
- **The Training Target and Bow Shop** get levels 6–10. Each level raises the stat and bow level caps, which are
  4 / 6 / 8 / 9 / 10 today, up to 15 at level 10. Bow Shop level 7 opens Thorn Volley and level 9 the Foxfire Bow (B5).
- **The Saddlery, Workshop, Well and Guardian Stone** get more levels in the same way. Those levels raise:
  - the skill and attachment caps;
  - each defence piece's level cap;
  - the Well's mending;
  - the golem's and the friend's levels.
- These levels cost leaves and timber.

**3. The Fletcher's Hut.**
- It opens when Raid Mission 15 is won, and is built from the build menu.
- It has no levels of its own.
- **Its window:** a grid of your bows. **Upgrade arrows** on a bow opens a window with three upgrades for that bow's
  arrows. Each upgrade has levels and is paid in leaves:

| Arrow upgrade | Per level (first guesses) |
|---|---|
| **Faster arrows** | +10% arrow speed, so runners are easier to hit |
| **Knockback** | Hits push enemies back a little (bosses less) |
| **Armour piercing** | Ignores 10% of a tank's armour. This is not the same as the Sunwood's pierce, which passes through an enemy. |

- Each arrow upgrade's level cap follows the Hearthtree's level.

**4. Random Raids grow with you.**
- The game works out your power from the cat's stats, the bow, the defences, and the golem's and friend's levels.
- **As that power rises, each Random Raid gets stronger:**
  - more enemies, still at most 50;
  - stronger kinds;
  - more elites.
- The pay grows with it.
- It never jumps: each raid is at most a little stronger than the last.

**5. A check of all prices.**
- With +30% leaves (H1), Claude checks the whole price list, so that:
  - a mission win pays for about one upgrade worth having;
  - the Hearthtree's path matches "the missions end around Hearthtree 4–5";
  - amber's sale price and how often it drops keep expeditions worth playing without flooding you with leaves.
- The changes are listed for the owner before they go in.

**Technical:**
- `balance.json`: `stations.*.levels`, `stat_cap_by_station_level`, `bow_cap_by_bench_level`, `fletcher` and the raid
  scaling.
- The building window files, `arrow.gd` (speed and knockback), `enemy.gd` (piercing and knockback) and `raids.gd` (the
  power score).
- **Who:**
  - Opus: the levels and the Fletcher's Hut;
  - Opus: raid scaling;
  - Haiku: the price table edits after the owner's yes.
- **Tests:** `--smoke`, `--homegoals`, `--bowshop`, a new `--fletcher` and a new `--raidscale`.

---

### H10: the shard store (last)

**What you'll see:** a Shards tab in the Market.

1. **The Shards tab** sells packs of purple shards for real money. The owner decides the pack sizes and prices in the
   Play Console.
2. **Shards buy looks only:** mounts, pet looks, outfits, colour skins and fire looks. Looks that are bought with leaves
   today can still be bought with leaves.
3. **Before the store opens,** every power item still priced in shards is moved: the Lookout and Tracker go to leaves
   and timber, and the defences were already moved in H6. A test checks that nothing that makes you stronger costs
   shards.
4. **Google Play Billing:**
   - it uses Godot's Play Billing plugin and needs the owner's Play Console merchant account with the products set up;
   - it is built **switched off** until the owner has set that up;
   - the owner does every payment step, including test purchases.
5. **Ads stay rewarded only.**

**Technical:**
- The Market window file and a new `store.gd`.
- `balance.json`: `store`, and the shard prices of the looks.
- **Who:** one Opus agent.
- **Tests:** `--smoke` and a new `--store` (switched off, and no power costs shards).

---

### H11: tuning by the owner's play (includes G5)

- On the phone, mission by mission and run by run, tune:
  - leaves and prices;
  - the Well;
  - the potions and cooking times;
  - the crops' growing times;
  - the armour;
  - the raid scaling;
  - expedition rewards.
- Still open from Phase G: buildings can hide the cat when she walks behind them.

---

## Part D. Models and pictures

| What | Who | Before step |
|---|---|---|
| Emberpepper and Swiftroot plants | Claude designs them (Codex), the owner makes them (Meshy), Claude finishes them (Blender): models arrived 25 Nov 2026, colours painted in Blender | H3 |
| The Defence Workshop | the same | H6 |
| Clover (the friend) | the same, and Claude rigs and animates it | H8 |
| The Hollow Jailer (the intro boss) | made by the owner (Meshy "Crystalvine Colossus"); Claude colours, rigs and animates it | H8 |
| Old Croakmaw and the Thornwyrm (expedition bosses) | made by the owner (Meshy "Crystalback Toad", "Crystalvine Dragon"); Claude colours, rigs and animates them | H8 |
| The Fletcher's Hut | made by the owner: the "Feathercraft Hut" is the one used (the owner, 25 Nov 2026) | H9 |
| Hearthtree levels 9 and 10 | the same (concepts ready; models still to come) | H9 |
| Flat 2D icons | B3 | from H2 |
| Bows, arrows, mount attachments | Claude in Blender (the owner's earlier exceptions) | only if needed |
| Everything else | existing models | — |

## Part E. Removed, added, changed, kept

| | What |
|---|---|
| **Removed** | The Random Raid rout. The Mushroom Cottage. Every old dish. Eat, Quick heal and Use auto. The pantry limit. The Market's levels. Bramble buying shards. Shard prices on anything that makes you stronger. The Well's "4 missions won" need. Glowstone and heartwood (merged into amber). Material prices on upgrades. Bramble selling amber. The Hollow keys. |
| **Added** | The timer system. The garden and cooking windows. 5 recipes. Emberpeppers and Swiftroots. Potions and potion buttons. The new Bag. Placing from the Bag. The new HUD. Settings. The build menu. Upgrade with a confirm window. The Hearthtree's Cat tab. Inspecting bows. The Market's Mounts and Pets tabs. The Saddlery's skill triangle. The Defence Workshop, upgrades for each defence piece, and specialisations. Tank armour. Day and night. The intro expedition and its new boss (the Hollow Jailer). Two more expedition bosses (Old Croakmaw, the Thornwyrm). Clover, the friend. The crew screen. A Gloomwood that changes each run. Hearthtree levels 9–10. Building levels 6–10. The Fletcher's Hut. Random Raids that grow with you. The shard store. |
| **Changed** | +30% leaves from enemies. The Well comes at Hearthtree 3, mends faster and mends the golem. Crops and cooking run in real time. Pet upgrades are in the Market. Mount speed and health are in the Saddlery. 3 chosen mount skills. Purple shards are the paid currency and buy looks only. Amber is a rare find that Bramble buys for a lot. The Burrows are called expeditions. |
| **Kept** | Everything else: Raid Missions and squads, Random Raids as one assault, barricade rows on the road pads, crossbow towers, the Bow Shop's bows, the Tailor's outfits, fishing, Mossback, the Guardian Stone, Bramble. The design rules stay: a camp, not a village; rewarded ads only; nothing tall between the camera and the cat; no HUD in the middle third. |

## Part F. How it gets built

- **Before H1** (on the owner's yes): Part A's rule changes go into CLAUDE.md, GAME_GUIDE part 11, STATUS.md and the
  memory.
- **Branches:**
  - one per step (`feature/h1-quick-fixes`, `feature/h2-hud`, …), merged into `development` when that step's APK is
    good;
  - `production` changes only at a release;
  - no Claude lines in commits or PRs.
- **Backups:** before each big step, to `D:\DevCache\backup\pre_h<N>_<date>`.
- **Architecture:** each step builds or moves over the pieces listed for it in `docs/ARCHITECTURE.md` part 13, and
  follows its house rules (part 7).
- **Who does what** (the owner, 25 Nov 2026). Claude (the main session) orchestrates: it writes every brief, hands
  out the work, reads every patch before it goes in, runs the tests and talks to the owner.

| Worker | Takes | Never takes |
|---|---|---|
| **Fable** | only the really hard problems, when Opus is stuck or a design is risky (for example the component and state rebuild of enemies in H6, or building expeditions room by room in H8) | routine work |
| **Opus** | hard building: game systems, the architecture's core pieces, anything across many files or needing design judgement; **and every review** of work by Sonnet, Haiku and Codex (read-only, against the brief and `docs/ARCHITECTURE.md`) | mechanical work |
| **Codex CLI** (GPT-6.2 Sol, the owner's quota) | medium to fairly hard, well-fenced tasks: a window on the window kit, a tool, moving content into folders, tests, docs; and every concept image | the hardest tasks (those go to Opus or Fable) |
| **Sonnet** | easy to medium, well-specified pieces; **picks up anything Codex leaves unfinished** (its quota ran out, it failed, or its patch was refused) | game-wide design |
| **Haiku** | simple, mechanical work: look-ups, renames, small data or doc edits, installing finished files; picks up small Codex leftovers | anything needing judgement |

- **The flow of every piece of work:**
  1. **Brief:** Claude writes it: the goal, the files the worker owns, what it must not touch, the exact names others
     will call, and which parts of `docs/ARCHITECTURE.md` apply.
  2. **Build:** the worker chosen above. Workers write in parallel only on separate files; the big shared files
     (`hud.gd`, `stations.gd`, `fight.gd`, `enemy.gd`, `save.gd`, `balance.json`) have one owner at a time.
  3. **Codex's way of working:** it runs read-only and returns a git patch; Claude reads the patch, checks it applies,
     and applies it. If Codex stops (quota, error) the same brief goes to Sonnet or Haiku, which finish from where it
     stopped.
  4. **Review:** an Opus agent, read-only, checks the work against the brief, the architecture's house rules and the
     owner's rules. Real problems go back to the worker; anything that changes how the game plays goes to the owner.
  5. **Test:** Claude runs `--smoke` and the step's own test modes, one at a time.
  6. **Owner:** an APK on the phone; the owner reviews everything before a step is merged.
- **Tests:**
  - light: `--smoke` plus the step's own mode, run once, with `--disable-vsync` before `--`;
  - never run in parallel.
- **After every step:** an APK on the phone (`tools/build_apk.ps1 -Install`), with screenshots of the new screens.
  `docs/CHANGES.md`, `docs/GAME_GUIDE.md` and `docs/STATUS.md` are updated.
