# Raid Missions and Random Raids

Owner discussion and terminology correction, 23 November 2026. Work is on `development`.

## 1. Names and scope

The owner explicitly distinguishes **Raid Missions** from **Random Raids**. Do not rename the existing structured
missions simply to "Missions" or describe the random assaults as more campaign missions.

| System | Meaning | Status in this update |
|---|---|---|
| Raid Missions | The existing 15 structured missions, with 15/20 manually started waves, objectives and first-clear progression. | Signpost catalogue and replays implemented. |
| Random Raids | Recurring, randomly composed camp attacks unlocked after every Raid Mission is finished. | One continuous assault implemented; up to 50 raiders in small mixed groups across all four trails. Existing Watch controls retained. Expanded power scaling/recruits are future work. |

The dungeon/quest-recruitment proposal remains separate in `DUNGEON_EXPEDITIONS_PLAN.md`.

## 2. Signpost and replay changes implemented now

- Two persistent navigation buttons: **Raid Missions** and **Random Raids**.
- Raid Missions lists all 15 entries, grouped into **To finish** and **Completed**. Finished entries show their
  status and a **Replay** button. Future unfinished missions remain visible and explain their sequential lock.
- Within those groups missions descend from **15 to 1**. Spacious rounded cards use a number badge, mission name,
  short status and one action. Empty groups are omitted. Cards fade/settle on opening and view changes, with press
  feedback on buttons. Unchanged live refreshes preserve the rows and scroll instead of restarting the animation.
- Swipe anywhere on a card to scroll, including over a number badge or action button. The visible scrollbar is
  hidden, while scrolling remains enabled. A drag cancels a button press; a stationary tap activates it.
- Finishing a new unique Raid Mission opens the next one. Replaying a completed entry does not advance that chain.
- Random Raids is visible but locked until all 15 unique missions are finished. Completing the last one unlocks
  the view; the Raid Missions catalogue remains accessible afterward.
- Replay uses the existing balance setting: 50% of the mission's completion leaf/timber reward, plus normal wave
  and chapter payments. First-clear gifts, story progress, the first barricade gift and the final unlock do not duplicate.
- A saved mission can be resumed at its next uncleared wave. Starting another mission/replay cannot silently
  discard it: resume or explicitly give up the saved run first.
- Existing gates still apply: rebuild an extinguished campfire first, and meet an already pending random raid
  before starting a mission/replay. Tabs do not allow starting a second fight during an active fight.
- Home goals, building unlock messages and the Hollow entrance identify **Raid Missions** explicitly.
- Raid Mission save IDs, completion records, difficulty, wave-start controls and reward rates are preserved.

The Random Raids view retains Watch preparation/repair controls. Its former multi-wave execution has now been
replaced by the continuous assault described below. This does not change Raid Missions.

## 3. Random Raid combat: implemented assault and remaining direction

- Random Raids unlock after all Raid Missions, then remain a recurring challenge as the player grows stronger.
- **Implemented:** one raid is one continuous assault, started once with **Defend Camp**. Enemies arrive in small
  overlapping groups of 1–3 rather than one huge spawn. Groups rotate randomly across all four trails; no breaks or
  further Start wave buttons appear. The seeded roster is 36–46 plus the existing level increment, capped at 50 total
  including the leader and any boss summons. This is the current cap while recruited-party support is absent.
- Group members arrive 0.22 seconds apart; groups are separated by a random 1.1–2 seconds. Existing graphics-tier
  live caps remain. A full field delays arrivals until room opens, without clearing the field or creating a new wave.
- The leader arrives last and retains its rout. One defence grants one completion reward. Loss consolation uses
  the defended proportion. Resumes omit defeated member IDs, retain summons and damage, and require a player start.
  Legacy cleared waves reduce the remaining roster once; used campfire rebuilds remain used.
- Early endgame assaults are simpler, but still challenging. Later assaults bring more enemies and harder pressure.
- Track the player's developing combat strength and camp capability when planning assaults, including stronger
  cat attacks, mount capabilities, defences and guardians.
- The existing golem/camp guardian helps protect the camp. Later, quest-recruited friends can help defend it too;
  their exact assignments and abilities still need design.
- Retain the campfire-camp identity. "Village" in the conversation refers to this existing camp.

### Recommended scaling approach, still to be tuned

- Evaluate useful combat capability: cat damage and attack pace, range/specials and survival; mount combat stats,
  learned skills and attachments; built defences and their strength; guardian capability; future active defenders.
- Avoid counting the same power twice through both an upgrade station and the stats it unlocks. Cosmetic mount
  looks are not a substitute for actual combat capability.
- Include successful defence progression so the challenge can grow over time. Give the first assaults a gentler
  introduction and account for losses. Exact weights, limits and recovery rules remain open.
- Use difficulty bands so upgrades still make the player feel stronger. Do not immediately cancel every upgrade
  with an equal enemy increase.
- Snapshot the assault when it is planned: enemies should not suddenly gain power when the player upgrades
  mid-fight. Decide how to prevent lowering threat by temporarily unequipping powerful gear.
- Scale enemy composition, numbers and attack pressure as well as stats. Preserve room to dodge and defend.
- Profile the simultaneous enemy budget on the phone. Every front should participate in the same assault; do not
  silently fall back to separated waves to satisfy a performance cap.

## 4. Recommended Random Raids menu

These are recommendations for discussion, not four newly implemented panels:

| Menu item | What the player sees or does |
|---|---|
| **Incoming Attack** | Whether the Gloom is gathering or an attack is ready; raid type, a readable danger rating and attacks from all four directions. Show available scouting information without exposing internal scoring formulas. |
| **Camp Readiness** | Campfire health, damaged towers/barricades, guardian readiness and later assigned friends. Offer clear repair/preparation actions with their real costs. Existing buildings keep their upgrade roles. |
| **Rewards** | Expected golden leaves, timber, shards and applicable existing bonus rewards. Exact amounts remain part of the balance pass. |
| **Recent Results** | Last defence outcome, raids held/lost, perfect defences and best streak. Detailed history can be added if useful; current saves already track totals/streaks, not a full new history log. |

Recommended main action: **Defend Camp** when an assault is ready. An optional **Call Raid** action can retain the
existing horn's ability to bring a raid forward. Trigger timing must be settled with the owner before changing
whether the initial attack waits for the player or arrives after a warning.

The menu should explain the incoming threat and how to prepare, while remaining compact on a phone. Recruited
friends appear there when that system exists; do not show them as an already functioning feature.

## 5. Decisions still open

- Final menu arrangement and which preparation actions belong directly on the signpost.
- Expanded threat inputs/weights, later caps with recruited support, and damage/health scaling. Current cap is 50;
  existing camp/renown level and victory/loss adjustments remain.
- When an incoming raid starts, the warning/preparation rules and the optional horn action.
- Additional raid-type tuning; existing types/leaders remain and all now use four trails.
- Guardian/friend assignments, downed-state rules and how camp defence coexists with dungeon travel.
- Reward amounts, completion conditions and loss consequences for the redesigned assault.
- Future power-scaling changes must retain the implemented legacy migration and member checkpoints.

Nothing in this discussion authorizes attacks or losses while the game is closed. Existing dungeon-travel and
pause protections remain until the owner changes them explicitly.

## 6. Compatibility and verification

- Keep internal `missions`, `mission_run`, `missions_done`, `fight.mode == "mission"` and raid save keys stable.
- Preserve unique first-clear progression while permitting replays, including older saves with completed missions.
- Preserve per-wave checkpoints, explicit give-up behaviour and priority for an already pending random raid.
- The new catalogue/replay tests are `autotest_missions.gd` (`--missions`). Home/progression checks use `--homegoals`.
- The catalogue/replay implementation passed smoke, 26 catalogue/replay checks and 48 home/progression checks.
  The subsequent descending-order/layout polish passed smoke and the expanded 30 catalogue/replay checks, including
  ordering before/after completion and stable live refreshes; phone-proportion screenshots were visually checked.
  The touch-scrolling fix passed smoke and 39 checks. Actual finger-event tests reproduced the blocked drags before
  the fix and cover card surfaces, both directions, hidden scrollbar and deliberate Start versus dragging.
- Remaining work needs separate tests for expanded player-power scaling, recruited companions and phone performance.
- The implemented continuous assault passed smoke, 29 `--assault` checks and 90 `--fightf` checks. `--raidsave` now
  runs the assault suite. Full player-power/companion scaling and phone performance still need their own work.

Backup for this update: `D:\DevCache\backup\pre_mission_menu_20261123`.
Layout polish backup: `D:\DevCache\backup\pre_signpost_polish_20261123`.
Touch scrolling backup: `D:\DevCache\backup\pre_mission_scroll_20261123`.
