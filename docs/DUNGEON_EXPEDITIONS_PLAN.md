# Dungeon expeditions, discoveries and recruitment

Recorded 23 November 2026 on `development` from the owner's dungeon discussions.

**Status: agreed design direction, not implemented.** Subsequent raid requirements are recorded in
`RAID_MISSIONS_AND_RANDOM_RAIDS_PLAN.md`. This document records future work; new dungeons, quests, recruits and
expedition selection are not yet playable. Detailed implementation and balance remain to be discussed.

## 1. What the owner wants

- A single-player dungeon adventure with the feeling of travelling with a small party.
- Companions are characters found and helped through quests, then recruited to the campfire camp. They become
  people the player knows and can take along, rather than strangers appearing through an online party system.
- A target of **ten distinct dungeons before release**. Names, themes, maps, characters and assets are not chosen yet.
- Random dungeon selection and increasing challenge, with dungeon identity separate from difficulty.
- Meaningful differences on return visits: encounters, events, routes and discoveries, beyond stronger enemy stats.
- Discoveries and quests can permanently change a dungeon.
- A completed expedition ends, but its dungeon remains replayable. Death ends the attempt and returns the cat to camp.

The owner liked the combined expedition direction and specifically endorsed permanent discoveries, separating
difficulty from dungeon identity, varied repeat visits, and the run ending without permanently completing a dungeon.
The owner refined recruitment into quests that bring characters home to the campfire.

## 2. What actually exists today

| Item | Current implementation |
|---|---|
| Playable dungeon | **The Gloomwood**, internal ID/map `old_hollow`; the sole entry in `balance.json` → `burrows.list`. |
| Other map file | `game/data/dungeons/test_glade.json`: a small development test ending in treasure. Not offered to players and not a second finished dungeon. |
| Current progression | Higher levels reuse the Gloomwood road while changing strength, enemy packs and rewards. |
| Existing foundation | Continuous dungeon maps, packs and ambushes, optional branches, traps, chests, a boss or treasure ending, boons, food, satchel, checkpoint saving and a seeded run. |
| Existing companions | The cat's pet and mount accompany the cat. The Moss Warden is rescued in the Gloomwood and becomes a **camp guardian**. |
| Missing systems | A dungeon pool for player expeditions, persistent dungeon evolution, a recruitment quest system and recruited adventuring buddies. |

Relevant implementation: `game/scripts/burrow.gd`, `burrow_run.gd`, `dungeon_map.gd`, `save.gd`,
`game/data/balance.json` and `game/data/dungeons/old_hollow.json`.

## 3. The proposed expedition loop

1. At camp, review quests and choose which recruited companion to take.
2. The expedition system offers a dungeon and shows its name, danger and expected rewards. Prepare food and supplies.
3. The cat and companions gather at the entrance and travel into the dungeon together.
4. Explore its current routes, encounters and events. Make discoveries and advance quests.
5. Complete the run's objective, which may be a boss or a treasure/other authored ending, then return to camp.
6. Bank the run's rewards and apply earned quest/discovery changes. Another expedition can revisit that dungeon.

| Outcome | Direction |
|---|---|
| Successful expedition | Finish that attempt, receive completion rewards and return to camp. The location remains available. |
| Cat dies in the dungeon | End that attempt and return to camp. Previously completed discoveries, recruitment and permanent upgrades remain. Exact loot loss is still open. |
| App closes or pauses | Preserve the existing expedition and its choices. Resume it; closing the app is not a defeat or a new random roll. |

First-clear records, discovered secrets and best results may still be recorded. They must not permanently close
the dungeon or prevent replay. Existing earned unlocks remain meaningful.

## 4. Dungeon identity, random selection and difficulty

### Identity and selection

- Each dungeon has its own authored setting, visual identity, enemy themes, hazards and final encounter/objective.
- Random selection draws from the available dungeon pool. Avoid consecutive repeats and favour less recently
  visited locations; the exact shuffle/weighting rule is not settled.
- Show the destination and danger before committing so the player can prepare useful food and a companion.
- Active quests need reliable access to their required dungeon. A quest expedition or equivalent selection rule
  should prevent recruitment progress from depending on repeated lucky random picks. Exact UI is open.

### Difficulty

- Difficulty belongs to the expedition, separately from the dungeon's identity. The player should not experience
  the whole system as selecting "Gloomwood level 2" on the same road again.
- Higher challenge can combine stronger enemies with different packs, hazards, objectives and encounter behaviour.
- A name plus a clear danger rating is the proposed presentation. Labels and numeric progression are not final.
- Recommended progression: successful expeditions gradually raise the challenge; defeats do not increase it.
  Consider how a first visit teaches an unfamiliar dungeon before adding harder variations.
- Difficulty formula, limits, player control, party scaling and reward scaling still need a balance discussion.

Ten maps with only larger health values would not provide the intended replay experience. Each needs authored
content that the variation system can meaningfully combine.

## 5. How a dungeon changes on repeat visits

Keep two kinds of state distinct:

| Kind | Examples | Lifetime |
|---|---|---|
| Expedition variation | Available route, patrol composition, ambush, optional miniboss, hidden encounter, rescue opportunity, treasure event, final encounter variation. | Chosen for a particular run and preserved when that run resumes. |
| Permanent discovery | A barrier removed, passage unlocked, recruit rescued, new wing discovered, quest chapter completed or a new inhabitant taking over after an event. | Stored across runs, victories, defeats and app restarts. |

Recommended design rules:

- Give repeat visits a substantial recognizable difference when authored alternatives are available.
- Mix larger changes, such as an alternate route or encounter, with smaller changes to packs, traps and rewards.
- Permanent discoveries unlock future possibilities; they are not forgotten when a run is rerolled.
- Use logical authored combinations. A temporary route change must not make a required quest impossible.
- Let the player's actions drive lasting changes. Nothing progresses or damages the camp while the game is closed.
- Randomness remixes the content we author. New discoveries still require routes, events and encounter variants
  to be designed; do not promise unlimited unique content from a small set of random enemy spawns.

Illustrative possibilities, **not yet final content**: fallen roots force a side path; a mushroom cave becomes
accessible; an optional champion guards a chest; a rescued explorer reveals a sealed doorway; a former boss's
territory gains a different inhabitant.

## 6. Recruitment quests and life at the campfire

### Recruitment loop

**Discover character → help through a quest → bring them safely to camp → build a relationship → choose Take along.**

- Meet potential recruits during exploration and quests: stranded explorers, prisoners or lost travellers are
  examples. Characters, names, personalities and exact stories remain to be chosen.
- Finding someone starts a relationship. Helping might involve recovering supplies, defeating a threat or opening
  an escape route. Longer recruitment stories can span several visits.
- Important recruits should have reliable discovery conditions. A first recruitment quest should teach the
  system and give players a dependable introduction.
- Completed quest steps stay recorded between attempts. Decide separately how an unfinished rescue behaves
  when the cat dies and exactly when the recruit becomes permanently unlocked.
- After recruitment, the character stays around the campfire. Interactions can include conversation, follow-up
  quests and choosing who accompanies the next expedition.
- This remains a small camp with companions. Recruitment does not introduce resource-producing villagers,
  production workers or a settlement simulation.

### Adventuring buddies

- Party assistance is controlled by AI, with automatic following and abilities suitable for the existing mobile controls.
- The proposed first prototype has **one active recruited buddy** alongside the existing pet/mount. Final active
  party size, the resident roster and later additional slots are open decisions.
- A **protector** is the recommended first role: briefly draw attention and help the cat survive dangerous moments.
- A **healer** is a possible later role with limited emergency healing, so food and player decisions remain useful.
  These roles are suggestions, not final character specifications.
- Define following, path recovery, target assistance, danger avoidance and knocked-down/revival behaviour before
  tuning power. AI assistance should support the player's adventure without making it depend on fragile escort AI.
- Companions need an identity and reason to join, rather than being only a numerical damage bonus.

### Existing guardians

The Moss Warden rescue is a useful existing pattern for earning a camp ally. It does not currently implement a
recruited adventuring buddy. Existing guardians' camp-defence role remains; this plan does not automatically send
the Warden or all camp guardians into dungeons. Define adventuring recruits separately unless the owner changes that rule.

## 7. Rewards, supplies and survival

- Use the established economy: golden leaves, timber, cooking ingredients and rare upgrade materials.
- Companion progression and cosmetic rewards are possibilities; their exact form is not decided.
- Preserve the cat's existing food/items economy and the decision to avoid cat armour/gear inventory.
- Keep dungeon entry free as the starting recommendation. Preparing meals, carrying healing food and earning
  completion rewards should remain meaningful.
- Recruits and permanent discoveries are lasting rewards; repeatedly finishing a location still pays normal run rewards.
- The existing game banks leaves/timber/shards immediately and keeps half the satchel's materials on knockout.
  The proposed return-to-camp rule does **not** settle a replacement loot-loss policy; discuss that before changing it.
- Buddy abilities, food, reward rates and upgrade costs need to be balanced together.

## 8. First prototype and expansion

Recommended starting scope, subject to detailed design:

1. Rework the existing Gloomwood with one recruitable buddy, two alternate routes and several changing events.
2. Deliver one complete quest story linking the dungeon and camp.
3. Test whether returning to the dungeon feels different and whether the buddy helps without cluttering combat.
4. Expand to three distinct playable dungeons and test selection, difficulty and quest access across the pool.
5. Build toward the owner's target of ten distinct dungeons before release.

Example prototype story, **not a committed NPC or quest**: discover a stranded explorer, recover their supplies,
help them reach safety and welcome them to the campfire. Later they offer to show the cat a sealed Gloomwood passage.
Completing that quest permanently unlocks the passage as a future expedition route.

## 9. Implementation considerations for later

- Separate persistent discovery/quest/recruit state from the temporary expedition snapshot.
- Store destination, difficulty, party, seed, selected variations, encounter progress and checkpoint state for resume.
- Build on the current data-driven maps and existing run/checkpoint code; no implementation schema is finalized here.
- Migrate existing saves without erasing dungeon unlocks, the Warden, mastery access, materials or owned upgrades.
  Decide how old dungeon-depth progress maps onto the new difficulty system and how an existing saved run continues.
- Preserve boss and treasure endings. Validate each route/event combination for reachability and quest completion.
- Plan combat readability and AI/particle/enemy budgets for the phone, including the pet and mount already present.
- New characters, enemies, props and map visuals follow `CLAUDE.md` and `docs/ASSET_RULES.md`: the owner supplies
  new 3D models. Approved existing assets can be reused while testing; new model briefs follow the chosen designs.

These are implementation requirements to resolve with the design, not permission to begin building the whole system now.

## 10. Historical rules clarified by this direction

- `DUNGEON_SPEC.md` describes the current continuous Gloomwood path. Its old restriction against alternate routes
  is superseded **for the future expedition design** by the newly agreed route/discovery direction.
- The older "nobody lives at camp" wording does not exclude quest-recruited companions in this future design.
  The camp remains a campfire camp, with the existing rules against workers and automatic production.
- The old guardian-stays-home rule still concerns camp guardians; adventuring recruits are a separate proposed role.
- Existing gameplay is still described by `GAME_GUIDE.md` and `STATUS.md`. This document does not mark these plans built.

## 11. Open decisions and next conversation

- Ten dungeon names, themes, maps, encounters and model requirements.
- First recruit's identity, role, abilities, quest chain and exact recruitment conditions.
- Active party size and how it coexists with the mount, pet and camp guardians.
- Difficulty progression, danger labels, party scaling and reward balance.
- Random selection rules and the way the player accesses quest-specific expeditions.
- Quest/discovery persistence details, unfinished rescues, companion knockout/revival and loot loss on death.
- Which routes/events change per run, which discoveries are permanent and how those changes are presented.
- Migration from the existing depth/level system and handling saved runs during the transition.

**Subsequent raid discussion, 23 Nov 2026:** the owner clarified **Raid Missions** (the structured missions) versus
**Random Raids** (recurring assaults), requested completed-mission replays and described simultaneous attacks from
all directions that scale with player/camp strength. Later recruited friends should help defend the camp too.
See `RAID_MISSIONS_AND_RANDOM_RAIDS_PLAN.md` for the built menu/replay changes, future assault direction and open
menu questions. Preserve the dungeon/recruitment direction while incorporating those later decisions.

## 12. Acceptance goals when implementation is authorized

- The dungeon name identifies a location independently of its current difficulty.
- Random selection avoids unwanted repeats and does not strand recruitment quests behind bad luck.
- A repeated visit can show a meaningful authored variation; earned permanent discoveries remain earned.
- Recruitment connects finding/helping a character, their presence at camp and their availability for adventures.
- A run can be won or lost without permanently removing its dungeon from the pool.
- Death returns the cat to camp; completed permanent progress remains. Pausing/resuming preserves the current run.
- Required routes and objectives remain reachable in all valid combinations.
- Companions work with the existing controls and food economy, and combat remains readable on the phone.
- Older saves retain their owned progression through an explicitly designed migration.
