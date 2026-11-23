# Phase G plan: the next big update (version 3: the agreed plan, 20 November 2026)

The owner approved the plan ("the plan is good") and gave the last answers on 20 November 2026. This is the concrete
version to build from.

**23 Nov 2026.** G1–G4 and the session's follow-up fixes and outfits are on the owner's phone (installed at 01:52).
The branch `feature/g3-g4-bows-saddlery-outfits` was committed and merged into `development` on 23 Nov.
See `docs/CHANGES.md` for the session record. G5 is still to do.

- **Order:** it is built in 5 steps (G1–G5). Each step ends with an APK on the owner's phone.
- **Numbers:** every number is a first guess, kept in `game/data/balance.json` and tuned by play.
- **Nothing extra:** nothing outside this plan is added without the owner's yes (CLAUDE.md).

## How Phase G relates to Phase F (already on the owner's phone)

**Phase F** (built 19 Nov 2026, `docs/PHASE_F_PLAN.md`) is in the game now. Phase G builds **on top of it**.

**Phase F's waves stay**, with three changes in G1:
- Kept as built:
  - waves come mostly from every road, sometimes two, sometimes a rush down one;
  - the next wave's roads show in the top bar;
  - enemies come in groups;
  - missions 6, 13 and 15 have real last chapters;
  - mission 2 has fewer, softer boars and the boar daze;
  - Pitchers and Frogs shoot from afar;
  - the Golden Grub, the Gloom Totem and the pay bonuses.
- **What G1 changes:**
  - "no easy waves" swaps in stronger enemies instead of adding more;
  - rush waves are faster instead of bigger;
  - new limits on wave size and tanks.

**Phase F's archery stays and grows.** The goal lists and the five station levels stay. The next mission opens
when the previous one is won, at any Hearthtree level.
- **The Training Target:** stays as built. It trains Damage, Draw speed and Range, and gets the shop-style card in G2.
- **The Bow Bench:** became **the Bow Shop** in G3. The cat starts with Twig and can buy three more bows.
- **The looks of Target levels 3–5 and Bench levels 4–5:** made by the owner in Meshy from the concept images already
  sent. Stand-ins are used until then. When the files come, Claude finishes them in Blender and puts them in.

---

## Part A. What the owner decided

| Topic | Decision |
|---|---|
| The soft-lock and timber | Must be fixed first: the game can't be allowed to get stuck. |
| Waves | No more waves that are trivially easy, and no more crowds of tanks. |
| The campfire house | One name for the tree home and the campfire: **the Hearthtree** (it can be renamed any time). |
| Bows | A **Bow Shop**: each bow is bought, upgraded (its own damage levels) and equipped, with exactly one bow equipped. Each bow has its own design and arrows. **Claude designs the bows and arrows in Blender**. |
| Cards | **Everything** looks like a proper shop: item cards with a picture, name, short text, price and one button. |
| Market | **Offline only**, inside the game: trade with Bramble. No online auction. |
| Pet and Market | Both open at **Hearthtree level 2**. |
| Mounts | **Thistle is free for everyone.** Paid mounts (looks only) come **later**, not in this update: the foundation comes first. |
| The Saddlery | Build after **mission 8** at **Hearthtree 2**. Learn four skills and buy three attachments by playing. Learned skills can all trigger while riding. The mount wears one attachment at a time. |
| Barricades | Not bought in the shop. Built in **rows of 3** at the road spots, breaking visibly, repairable. |
| Acorn towers | A downed tower can always be repaired. |
| The Wishing Well | Automatic. It mends damaged things to full. Fully broken things still need a repair or a mission win. |
| Pay-to-win | **Never.** That is a rule. |

---

## Part B. The steps

### G1: fix what is broken (small, first; it unsticks the owner's save)

**What you'll see:**
- the burnt-out campfire can always be lit again;
- timber comes in every wave and can be bought;
- waves stop swelling into tank crowds.

**1. Relighting is never blocked.**
- After the camp falls, lighting the ashes costs **40 leaves, no timber**. If you have fewer than 40 leaves, it is
  **free**.
- During a mission, rebuilding the campfire (once a chapter) costs 10 timber, or **60 leaves if you have no timber**.

**2. More timber.**
- **Each wave held** pays **1 timber** (x the mission's pay scale, rounded, at least 1).
- **Chapter chests** pay double timber: **2 / 4 / 4 / 6**.

**3. Buying timber.** Until the Market exists (G2), the Market Stall's card gets the two rows:
- "Buy 5 timber for 50 leaves";
- "Sell 5 timber for 30 leaves" (today it pays 60, which would let you buy and sell for profit).

**4. Many enemies, never a crowd** (the owner, 20 Nov: "more enemies, but not hard ones you cannot kill, and not
overcrowded" — what went wrong at the end of mission 9).

The idea: **a wave has many enemies in total, but only a handful are on the field at once, and only a few of them are
tanks.** As you kill some, the next ones come out of the woods. So there is always plenty to shoot, but never a wall.

| Rule | Missions 1–5 | Missions 6–10 | Missions 11–15 |
|---|---|---|---|
| Enemies in a whole wave (first wave → last wave of the mission) | 10 → 25 | 16 → 32 | 20 → 38 |
| **Most on the field at once** (today 28) | **10** | **12** | **14** |
| **Most tanks on the field at once** | **1** | **2** | **3** |
| Tanks in a whole wave (at most) | 10% of the wave | 15% | 15% |
| A boss wave | the boss plus at most 8 others on the field | the same | the same |

- **Tanks** are the Stump Golem, Toadstool Brute, Beetle Knight and Crystal Snail. A Bramble Boar counts as half a tank.
- **"No easy waves" (the 85% rule)** makes a weak wave stronger by swapping some weak enemies for medium ones (never
  past the tank limits). It never piles on extra bodies.
- **Rush waves:** the same number of enemies, 15% faster (the +25% enemies are gone).
- **Raids and the Burrows** keep their own limits.

**5. Retune missions 7–10** a little, after the owner plays G1.

**Technical:**
- `balance.json`: the `mission` keys `wave_cap`, `wave_cap_boss`, `tank_kinds`, `tank_cap_by_mission`, `timber_per_wave`;
  `chest_timber`; `raid.fire_rebuild` (leaves only); `mission.rebuild_leaves`; `trade` (buy and sell).
- `fight.gd`: `plan_queue`, the top-up, the rush count, wave pay, rebuild.
- `stations.gd`: relighting the ashes, the trade rows.
- **Tests:** `--smoke` and `--fightf` (updated for the limits).

---

### G1b: structured waves (APPROVED by the owner, 20 Nov 2026: "Yes, build squads")

Two small adjustments while writing the data (`balance.json` `squads`, `enemy_roles`, `mission.squad_rules`):
- **Stump Siege** is 1 Stump Golem and 3 Thornlings, without the Boar. Missions 1–5 allow only 1 tank at once, and a
  Boar counts as half a tank.
- **The 40% limit** on one kind starts at mission 3, because missions 1–2 only have Thornlings and Boars.

**What the owner saw after G1:** waves are big but not structured. Often the same enemy comes 10 times, or 10 of one
kind plus 10 of another. "Each wave should come structured: it's gonna come with a tank, it's gonna come with a lower,
both things gonna combine... so the enemies have some way they attack you. As you go missions, new enemies appear."

**Why it happens:** each enemy in a wave is picked one by one at random from the chapter's list. So the same kind
often comes many times in a row, and nothing makes them a team.

**The fix: waves made of squads.** A squad is a small team (3–5 enemies) with roles that work together:

| Role | Kinds | What it does in a squad |
|---|---|---|
| Light | Thornling, Gloom Moth, Raccoon Bandit, Puffball Bomber, Mole Sapper | Fast and many; flanks, steals, bursts, digs |
| Fighter | Bramble Boar | Charges in hard |
| Tank | Toadstool Brute, Stump Golem, Beetle Knight, Crystal Snail | Walks in front, soaks arrows, smashes buildings |
| Support | Pitcher Spitter, Frog Shaman, Crow Drummer | Stays behind: shoots, heals or drums the others stronger |

**The squads, and the mission each first appears in:**

| Squad | Who | From mission |
|---|---|---|
| Scouts | 3–4 Thornlings | 1 |
| Chief's Band (elite) | the Thornling Chief and 3 Thornlings | 1 |
| Boar Raid | 1 Boar and 2 Thornlings | 2 |
| Brute Wall | 1 Brute in front, 3 Thornlings behind | 3 |
| Stump Siege | 1 Stump Golem, 1 Boar, 2 Thornlings | 4 |
| Bandits | 2 Raccoons and 2 Thornlings (the Thornlings fight, the Raccoons grab leaves) | 5 |
| Moth Cloud | 3 Gloom Moths (fly over barricades) | 7 |
| Moth Escort | 1 Brute and 2 Moths | 7 |
| Spitter Nest | 2 Pitchers behind, 2 Thornlings in front | 8 |
| Choir | 1 Frog Shaman (heals) and 1 Crow Drummer behind, 2 Thornlings and 1 Boar in front | 9 |
| Shield Wall | 2 Beetle Knights in front, 2 Mole Sappers digging under | 10 |
| Crystal Creep | 1 Crystal Snail and 2 Puffball Bombers | 11 |

Bosses (Mossback, the Owl Witch, the Elder Thornstag) come with escort squads.

**The rules:**
- **A wave is a list of squads.** It grows by adding squads, not by repeating one enemy. Wave sizes stay as G1 set them
  (10 → 38 in a whole wave).
- **No pile of one kind.** A squad has at most 3 of one kind (Scouts up to 4 Thornlings), and one kind is at most about
  40% of a wave.
- **Mixed waves.** From mission 2 on, every wave has at least 2 different squad types. Each mission's new squad (the
  table) shows up often in that mission and less often later.
- **Squads move as a team.** A squad comes down one road together:
  - the tank walks in front and the light ones keep pace with it;
  - the support ones stay a few steps behind;
  - near the camp they break off and each does its own job.

  Squads take turns on the roads by the wave's pattern (all roads, two roads or a rush).
- **On the field:** still at most 10 / 12 / 14 at once (2–3 squads), and the tank limits stay.
- **Elite waves** are squads led by the mission's elite. The boss wave is the boss with escort squads.

**What changes for the player:** fewer "random crowds", more "here comes a Brute Wall from the east and a Spitter Nest
from the north". It is clear what to shoot first: the healer behind the wall, the boar before it charges.

**Technical:**
- `balance.json`: `squads` (each squad's members and roles) and each mission's chapters list squads instead of a
  random pool.
- `fight.gd`: `plan_queue` plans squads, and the spawner sends a squad's members together.
- `enemy.gd`: squad members follow their leader until near the camp, and support stays behind.
- **Tests:** `--fightf` is updated.

---

### G2: the camp (the Hearthtree, the Market, barricades, towers, the Well, shop cards)

**What you'll see:**
- the home and campfire are "the Hearthtree";
- the pet and the Market open at Hearthtree level 2;
- barricades are built on the road in rows of 3 that crack and break visibly;
- downed towers can be repaired;
- the Well quietly keeps the camp mended;
- every card looks like a shop.

**1. The Hearthtree.**
- The tree home and the campfire are named "the Hearthtree" everywhere (cards, tips, goals, docs).
- The fire is still the thing enemies attack and the camp's safe light.
- Growing it takes goals and payment. Hearthtree 2–5 ask for missions 1, 5, 9 and 12. Mission access follows
  wins alone. Upgrade prices rise at each level (see the price table in `docs/GAME_GUIDE.md`, part 3).
- A ruined Hearthtree costs 10% to repair, with a 20-leaf minimum and caps of 900 leaves and 30 timber.
- A camp fall takes 30% of the leaves gained in the lost chapter, up to the leaves the cat holds.
- The models stay.

**2. The pet at Hearthtree level 2.**
- The Mushroom Cottage (Sprig's home) is in the shop once the Hearthtree is level 2. Today it is a gift for winning
  mission 3.
- Saves that already have it keep it.

**3. The Market at Hearthtree level 2.**
- The Market Stall model becomes **the Market**, buildable at Hearthtree level 2.
- **Thistle comes free with it** (a save that already rides Thistle keeps it).
- Bramble the trader sells and buys:

| Bramble sells | Price | Bramble buys | Pays |
|---|---|---|---|
| 5 timber | 50 leaves | 5 timber | 30 leaves |
| 2 Sunberries | 30 leaves | 5 Gloom shards | as today |
| Other food (the garden and fishing ingredients) | priced like the berries | Burrow materials (after the missions) | per kind |
| Burrow materials (after the missions only) | per kind | | |

- The garden still grows food. The Market is the backup when you're short.
- Bramblewool and the colour skins stay as looks, as they are today. Paid mounts come later.

**4. Barricades in rows of 3.**
- The shop no longer sells barricades.
- Each road keeps its **3 build spots** (12 in all). Tap a spot to build a **row of 3 pieces** across the road: **90
  leaves and 5 timber**.
- **Pads open as the Hearthtree grows.** After mission 1, the four gates open at Hearthtree 1 and the middle pads
  at 3. The far pads on Fernwood and Bandit Thicket open at 4. The far pads on the left open at 5.
  The two right-hand roads each have three evenly spaced pads. Built rows move with their roads when camp grows.
- **Each piece breaks on its own, visibly:**
  - whole;
  - **cracked** below 50% (darker, tilted);
  - **broken** at 0 (it falls flat, with a rubble pile from the existing rubble prop).

  Enemies walk through the gap a broken piece leaves.
- **Repair:**
  - tap a built row at any time, even during a wave. A broken piece costs 30% of the row price. A damaged piece
    costs its missing share of that price, with a 50% floor for a cracked piece;
  - a mission won mends everything free (as today);
  - the Well mends a little all the time (6).
- The barricade's upgrade levels (log → stone → thorn → shard → heartwood) stay. They are bought on the Hearthtree's
  card and raise every row's health.
- **Old saves:** placed barricades become rows at their road spots. Leftover pieces in the bag are refunded as leaves.

**5. Tower repair.**
- Tap a knocked-down acorn tower's **Repair** badge between waves. It stands at full health for the same leaf
  price as that tower's share of **Mend the defences**.
- A mission won mends it free.

**6. The Wishing Well, automatic.**
- No more wishing. You never tap the Well to use it; its card only upgrades it (levels 1–3, as today, never above the
  Hearthtree).
- **Between waves:** damaged buildings, the fire, barricade pieces and towers mend to full at **3% / 6% / 10%**
  of max health a second (Well levels 1 / 2 / 3).
- **During waves:** they mend **0.5% / 1% / 2%** a second.
- **Broken things** (at 0) are **not** brought back by the Well. They need a repair (tap) or a mission won.
- It opens when it does today (after 4 missions won) and stays in the goal lists as today.

**7. Shop-style cards everywhere.**
- The card still opens as the centred dialog with an X, which the owner likes.
- Inside, things to buy are shown as **item cards in a grid** (2 a row on a phone). Each has:
  - a picture or icon;
  - the name;
  - one short line on what it does;
  - small stat bars or numbers;
  - the price with currency icons;
  - **one** clear button: Buy, Upgrade, Equip, Equipped, Repair or Build.
- **Used on:** the Hearthtree (its goal list stays at the top, in the same tidy style), the Training Target, the Bow
  Shop, the Market, the Cottage/Nest, the Saddlery and the Guardian Stone.
- Icons are drawn in code (as the marker badges are now). Bow pictures come from the bow models (G3).
- **Screenshots** of the new cards are sent with the G2 APK.

**Technical:**
- `hud.gd`: the item-card grid.
- `stations.gd`: the cards, Hearthtree naming, the Market, the Well.
- `defences.gd`: rows, damage stages, repair, Well mending.
- `data.gd`, `save.gd`: old saves.
- `balance.json`: `market`, `stations.camp.levels`, `raid.leaves_share`, `gloom_raids.repair`, `well.passive` and
  `defences.barricade` (`row`, `rings_by_home`, `pad_rule`, `repair_share`).
- **Tests:** `--smoke`, `--homegoals`, `--fightf`, `--rows`, `--campg` and `--layout`.

---

### G3: the Bow Shop and new bows

**Built 21 Nov 2026, retuned 22 Nov.** The Bow Bench became the **Bow Shop**. The shop has four bows, each with
its own arrows and shot effects. Thorn Volley and Foxfire are hidden.

**1. How the shop works.**
- The cat always has **exactly one** bow equipped. It starts with the Twig Bow.
- **Buy** a bow once.
- **Upgrade** its damage (levels 1–10, each level +10% damage, capped by the Bow Shop's level as now).
- **Equip** any bow you own, free, between waves.
- Each bow keeps its own level.

**2. The bows.**

| Bow | Opens at | Leaves / timber | Base damage | Trade-off |
|---|---|---|---|---|
| **Twig Bow** | Start (owned) | Free | 1.0x | The original bow. Normal range and draw. |
| **Sunwood Longbow** | Bow Shop 2 | 400 / 15 | 1.15x | Pierces one enemy and adds 1.5 m range. Draw takes 10% longer. |
| **Ember Bow** | Bow Shop 3 | 900 / 30 | 1.3x | Burns for 3 s at 25% of the hit's damage per second. Range is 0.8 m shorter. |
| **Frost Bow** | Bow Shop 5 | 1,600 / 50 | 1.45x | Slows enemies and freezes on the third hit. Draw takes 25% longer. |

Owning Frost is a goal for Hearthtree 6.

**3. The designs: Claude in Blender** (the owner's permission for bows).
- The shop bows have their own low-poly designs: Twig's original wood, Sunwood's gold, Ember's glowing cracks
  and Frost's pale blue ice. Claude also made models for Thorn Volley and Foxfire before their shop tiles were hidden.
- Each bow is fitted to the cat's existing bow bones (`SK_CatBow`), so drawing and shooting still bend it right. Each
  arrow is its own small model.
- The owner approved the models. The same models make the pictures on the shop cards.
- Updated Idle, Walk, Run and Shoot in `CatRanger.glb` improve the on-foot bow carry. `bow_face.gd` rolls her
  paw in place so the bowstring faces her chest while she carries it.

**Technical:**
- Bow meshes skinned to the cat rig's bow bones; `player.gd` swaps the bow mesh instead of tinting it; arrow meshes
  are picked per bow in `arrow.gd`.
- Burn, slow and freeze are in `enemy.gd`. Release, trail and hit effects are in `fx.gd`.
- `stations.gd`: the Bow Shop card.
- `balance.json`: `bows` (`craft`, `cost`, `draw_mult`, `range_bonus`, `burn`, `frost`, `fx`), `cat.min_range_m`
  and `cat.bow_face_max_deg`.
- **Tests:** `--smoke` and `--bowshop` (61 passes).

---

### G4: the Saddlery (mount skills and attachments)

**Built 21 Nov 2026, updated 22 Nov.** The Saddlery teaches mount skills and makes attachments.
Each learned skill can trigger while riding. Only the worn attachment is active.

**1. The building.**
- Buildable after **mission 8** is won, at **Hearthtree level 2**. Its level follows the Hearthtree (up to 5).
- It uses a **stand-in model** (the Bow Bench, tinted brown) until the owner makes one in Meshy.
- It has two shelves of item cards: **Skills** and **Attachments**.
- Every skill and attachment is bought (learned) once, then upgraded (levels 1–5, capped by the Saddlery's level), with
  leaves and timber. Levels 4–5 also need Burrow materials after the missions.
- **Never real money.**

**2. Thistle's Thump and Bramblewool's Ram stop being built-in moves.**
- A mount alone carries the cat (faster) and takes the hits while ridden.
- Its fighting comes from what it has learned and wears.
- **Old saves:** a save past mission 8 gets Stomp level 1 free, so nobody loses what they had.

**3. Skills** (the mount uses them by itself while you ride, each on its own timer, never two in the same moment):

| Skill | What it does (level 1) | Per level |
|---|---|---|
| **Stomp** (today's Thump) | Every 4 s, when an enemy is within 1.6 m: a shockwave round the mount, 2 m wide, 20 damage, a small push back | +40% damage |
| **Ram** (today's Ram) | Every 7 s, when enemies are ahead within 4 m: a short charge forward, 35 damage to each enemy in the path, knocking them aside | +40% damage |
| **Pounce** (new) | Every 9 s: leaps (with the cat) onto the biggest group of enemies within 6 m and lands with a 2.5 m blast, 40 damage, stunning them for 1 s | +40% damage, +0.1 s stun |
| **Bellow** (new) | Every 12 s, when 4 or more enemies are within 4 m: a mighty call that stuns them for 1.5 s (bosses 0.5 s); for 3 s they take 20% more damage | +0.2 s stun, +5% damage taken |

**4. Attachments** (wear one at a time):

| Attachment | What it does (level 1) | Per level |
|---|---|---|
| **Fire-spitter** | Every 3 s, a short cone of fire in front of the mount (2.5 m) when enemies are close: they burn, 8 damage a second for 2 s | +40% damage |
| **Mossweave Saddle** | The mount has 15% more health | +15% (level 5: +75%) |
| **Saddlebags** | Kills drop 5% more leaves (missions, raids and Burrows) | +5% (level 5: +25%) |

**5. Wearing gear.**
- Own all three and swap the worn attachment free between waves. The first bought is put on automatically.
- Claude made all three attachment models for each mount in Blender. Only the worn one appears on the mount.
  Thunder Shoes stay on the Stable as Gloomwood gear.

**6. Animations: Claude in Blender**, on the two mounts' existing rigs. Each skill has its own move for each mount:
- **Thistle:** Stomp (exists, today's Thump), Ram (new: a head-down dash), Pounce (new), Bellow (new: rears up and calls).
- **Bramblewool:** Ram (exists), Stomp (new: rears and slams its front hooves), Pounce (new), Bellow (new).

That is **6 new animations**. The cat bobs and leans with the mount and jolts with skills. She carries the bow upright
and tilted toward her. She shoots only ahead, so turn the mount to face foes behind you. The mount takes the hits
and has an amber health bar. The cat leans away to reduce head overlap. Some overlap remains during Thistle's Bellow.

**Technical:**
- `mount.gd`: the skills, attachments and timers.
- A new card in `stations.gd`.
- `ride_motion.gd`, `player.gd` and `lifebar.gd`: seated motion, forward aim and the mount's health bar.
- `balance.json`: `stations.saddlery`, `saddlery`, `mount_skills`, `mount_attachments` and the `mount` riding keys.
- `save.gd` stores skills, owned attachments and the one worn. The animations ship in the mounts' GLBs and clip lists.
- **Tests:** `--smoke` and `--saddlery` (52 passes).

---

### Follow-up: Tailor's Nook (built 23 Nov 2026)

At Hearthtree 3, build the outfit shop for 1,500 leaves and 40 timber. Original Ranger is free. Dusk Ranger and
Nightfall Ranger cost 3,000 and 6,000 leaves. They change looks only and their cloaks move with the cat.
The review fixed the Nook's footprint and interaction ring, assigned health to buildings built mid-fight,
blocked sales for missing outfit models and matched the clips to the loaded model. See `docs/GAME_GUIDE.md`,
part 11, for the files and tests (`--tailor` 63 passes, `--layout` 132).

---

### G5: tuning by the owner's play
- Mission by mission on the phone: wave limits, timber, the prices of bows, skills and attachments, the Well's mending.
- Paid mounts (looks only) are a later update, after this foundation.
- Later ideas: mount skills earned in dungeons, two or three more mission bosses, and paid outfits using premium
  currency. Still open: buildings can hide the cat when she walks behind them.

---

## Part C. Models and animations

| What | Who | Until then |
|---|---|---|
| Bow and arrow models | **Claude, in Blender** | Built. Four bows are available in the shop. |
| 6 mount skill animations | **Claude, in Blender** on the existing rigs | Built |
| The Saddlery building | **The owner, in Meshy** | The Bow Bench model, tinted |
| Fire-spitter, Mossweave Saddle and Saddlebags | **Claude, in Blender** | Built for both mounts |
| Tailor's Nook and cat outfits | **The owner, in Meshy**. Claude rebuilt damaged mesh parts to match. | Built |
| Training Target levels 3–5, Bow Bench levels 4–5 (from Phase F; concept images sent 19 Nov) | **The owner, in Meshy** | Target level 2's model, Bench level 3's model |
| The Gloom Totem and the Golden Grub (from Phase F; concept images sent 19 Nov) | **The owner, in Meshy** | Gloom crystal props; a small gold mole |
| Everything else (the Hearthtree, the Market, barricades, rubble, towers, the Well) | Existing models | — |

## Part D. Removed, added, changed, kept

| | What |
|---|---|
| **Removed** | Mission gates by Hearthtree level. Timber needed to relight the ashes. The +25% enemies in rush waves. Waves topped up with more bodies. Buying barricades in the shop. Wishing at the Well. Built-in mount moves. The Market Stall paying 60 leaves for 5 timber. |
| **Added** | Timber for each wave held. Buying timber, food and materials. Wave size and tank limits. Barricade rows and tower repair. The automatic Well. Shop cards, the Bow Shop (including Ember and Frost), the Saddlery's four skills, three attachments and six new animations, and the Tailor's Nook with cat outfits. |
| **Changed** | Tree home and fire are the Hearthtree. The pet and Market open at Hearthtree 2, with Thistle free. Double chest timber. Missions 7–10 retuned. Saddlery gear works wherever it is worn. A camp fall takes 30% of the lost chapter's leaf gains. |
| **Kept** | Hearthtree goal lists. The Training Target. The roads. The Golden Grub. The Gloom Totem. Pitchers and Frogs shooting from afar. The pay bonuses. The Gloom Raids. The Burrows. The pet attachments. |
