# Project LEAF: the game guide

20 November 2026. This is the one place that describes the game as it is now. Parts 1 to 10 are for the owner, in
plain words. Part 11 is for whoever works on the code next. Part 12 lists the other documents.

The code (`game/scripts/`) and the numbers (`game/data/balance.json`) win when they disagree with this guide. If you
find a difference, fix the guide.

Three changes landed on 19 November 2026 and are marked **New (19 Nov 2026)**: tap to open (with the attack arrows),
the Gloomwood's night road, arena and harder fights, and **Phase F** (home goals, no replays, roads and patterns, fairer
waves, reasons to move). The notes for the first two are at the end of `docs/PHASE_A_PROGRESS.md`; the plan for Phase F
is `docs/PHASE_F_PLAN.md`.

**New (20 Nov 2026, G1b and G2).** Mission waves now come as **squads** (small teams with roles), and the camp is
called **the Hearthtree**: its shop is a set of tiles, barricades are built in rows on the road spots, and the Wishing
Well works by itself. Those parts are marked **(G1b)** or **(G2)**. The plan is `docs/PHASE_G_PLAN.md`.

---

## 1. The game in one page

**What it is.** A low-poly 3D action game for Android phones, held upright and played with one thumb. You are the
Cat Ranger, a small cat with a bow and a hooded cape. She guards her campfire camp in a forest clearing. The enemy is
the Gloom: violet, crystal-crusted forest creatures that come down four trails out of the woods. The cat shoots by
itself. You move her, pick where to stand, and spend what you earn to grow the camp and the cat.

**The loop.**

1. **Missions.** 15 missions, each 15 or 20 waves long. Every wave pays golden leaves. Between waves you shop, build
   and upgrade, so the camp and the cat grow during a mission. A player can spend about 20 minutes on mission 1.
   **New (19 Nov 2026, Phase F): no replays.** A won mission is done. You go on to the next one, and every win pays
   enough leaves to upgrade after it.
2. **The camp grows.** First wins bring new buildings, a mount (Thistle the hare), a pet (Sprig the leaf dragon), a
   garden with a cooking pot, and fishing. The tree home grows through 8 levels. **New (Phase F): the home has a goal
   list for each level.** It grows only when every goal is met and its price is paid. The next missions need the new
   home level, so the game keeps you from entering a mission with a camp that is too small.
   **New (20 Nov 2026, G2): the tree home is called the Hearthtree.** Its level names stay (Shed, Hut, Treehouse...).
   The Market (with Thistle, free) and the Mushroom Cottage (with Sprig) come at Hearthtree level 2.
3. **After mission 15** the game goes on two ways, side by side:
   - **Gloom Raids**: short attacks on the camp. A meter fills while you play; when it is full, a raid comes.
   - **The Gloomwood**: a dungeon at night. The cat walks a road past fights to a boss and brings home rare
     materials. They pay for the top upgrades. The first win frees the camp's guardian, the Moss Warden.

**The mood.** Bright and cute. Low-poly with visible facets and flat colours, like the Cat Ranger herself. The camp is
wild and lush: a hollow mossy tree home, round roofs and doors, warm lights, flowers, a market stall with a striped
awning, a lake beside it. The Gloom is violet crystal. The Gloomwood is a night road: dark, but always easy to see.

**What it is not.**

- **Not Clash of Clans.** One cat guards one campfire camp. No villagers, no workers, no build timers, nothing that
  makes resources by itself. It is a camp, never a village.
- **Nothing happens while the game is closed.** No timer runs, no raid attacks, no plant grows, nothing is lost. The
  game never reads the clock.
- **Not open world.** The camp is home and the enemies come to it. Going out happens in small separate places: the
  Gloomwood now, islands by boat later.
- **No menus.** You go to a thing and its card opens (part 2).
- **Never pay-to-win.** Money will only buy looks, and Burrow-only helpers that can also be earned by playing
  (part 9). None of the money side is built yet.

The owner plays it on a Samsung Galaxy S24. The phone has the G1 build from 20 November 2026, afternoon (Phase F and
G1). The build with G1b and G2 is ready on the PC and is not on the phone yet.

---

## 2. How to play

### Controls

| What | How |
|---|---|
| Move | Press anywhere on the screen and drag. A joystick appears under your thumb and goes away when you lift it. |
| Shoot | Automatic. The cat turns to the nearest enemy in range (5.5 m at the start) and keeps shooting, also while walking. |
| Hide | Stand in tall grass or a bush, outside the camp. Enemies can't see the cat. After 1.5 s hidden, the next shot is an **Ambush**: double damage. Not while riding. |
| Ride | Tap **Ride** (once Thistle has come). The cat is faster and Thistle thumps enemies that crowd in. Tap **Walk** to get off. |
| Feed | When the mount is knocked out, Ride turns into **Feed** (2 Sunberries). |
| Leaf Dash | **Gloomwood only.** Flick your thumb quickly as you lift it. The cat dashes 3 m and nothing can hurt it during the dash. Dash through an attack at the last moment (a **close call**) and the next arrow hits double. It recharges in 1.4 s; an arc under the health bar shows it. |
| Build | Buy a defence in the shop. A button such as "Barricade ×2" appears at the bottom. Tap it, walk the see-through piece to where you want it, tap **Place**, then **Done**. **New (G2): barricades are not built this way.** Tap a road marker instead (see the next block). |
| Barricade row (G2) | **New (20 Nov 2026, G2).** Each of the 12 road spots (3 per road) has a small marker. Tap it to build a **row of 3 pieces** for 90 leaves and 5 timber. Tap a built row to repair it. |
| Use a building | Tap it (see below). Its card opens. Tap a green button to buy. |
| Grow the home | Open the Hearthtree's card (the Shop). **New (Phase F):** the top section, "Grow the home", lists the goals. Tap **Go** on a goal and the card closes and the cat walks to the building that sells it, or tap **Show** to scroll the card to that row. |

On a PC: WASD or the arrow keys move, the mouse works as a finger, and Space dashes.

The camp's cards work only **between waves**. During a wave they say so; the signpost still works.

> **New (19 Nov 2026): tap to open.** Walking near something opens nothing, and there are no glowing ground rings.
> Each usable thing has a small leaf-shaped pin with an icon over it: small and dim far away, bigger and glowing with
> a "tap" ripple in reach, and a "!" when something is new or affordable. **Tap the pin, or the object itself**, and
> its card opens as a **dialog in the middle of the screen** (wooden header, round **X**), with the game still visible
> and dimmed behind it. The X, a tap outside, or the phone's back button closes it. Tapping something out of reach
> makes the cat walk there first (a drag cancels). Still walk-in: the Moonwell spring, traps and the Training
> Target's practice spot. Where this guide says "walk to" a building's ring, read "tap" it.
>
> **New: attack arrows.** During a wave or a raid, and in the Gloomwood, small orange arrows at the edge of the
> screen point toward foes you cannot see (one per direction), and pulse when the campfire or a building is hit from
> that side. Their size and strength are two numbers in `game/scripts/threat_arrows.gd`.

> **New (20 Nov 2026, G2): shop-style cards.** A card still opens as the centred dialog with an X. Inside, the things
> to buy are **tiles in a grid** (two per row on a phone). Each tile has an icon, a name, a short line, stat bars, a
> price and one button. Tiles are grouped under small headings. The Hearthtree's card shows its goal list first, then
> the sections **Grow**, **The cat**, **Buildings**, **Defences** and **Settings**. The Wishing Well has no wishes now (G2).

### The screen

- **Top bar** (one slim strip under the phone's status bar):
  - left: golden leaves, timber and Gloom shards; in the Gloomwood, the satchel's materials too; the dish eaten this
    chapter; "Endgame test save" when the debug save is on.
  - right: the fight's bar. In a mission it is the campfire's health. **New (Phase F):** in a breather it also says
    where the next wave comes from: "Wave 6 of 20 in 12s · Next: every road", "Next: Fernwood and Mossback's Den" or
    "Next: a rush from Fernwood!". After the missions it is the Gloom meter or a
    raid's countdown. In the Gloomwood it is a row of pips, one per fight and one for the boss.
  - a second thin line appears when there is a status to show (for example the Gloomwood's name and level).
- **Just under it**: the boss's health bar, then **banners** (short headlines, about 2 s; a win or a loss is bigger
  and stays about 3.5 s), then **toasts** (one-line news) and the status line ("Rebuilding the campfire...",
  "Hidden in the grass").
- **Over the cat**: a red health bar. A hit drains it, and the part just lost shows grey for a moment. While riding,
  a thinner bar under it shows the mount's health. The Moss Warden has its own moss-green bar.
- **Bottom**: the buttons (Ride or Walk, Feed, Snack in the Gloomwood, defences to place, Place and Done). Just above
  them: the **tip** (each tip shows once, often with a gold arrow pointing where to go) and the "Drag anywhere to
  move" hint.
- **The middle third** stays clear for the cat. Nothing of the HUD goes there except the health bars and the arrow.

---

## 3. The camp

### The map

The camera looks north, down at the camp from the south. The **campfire** is the centre, with open ground all round
it and straight south of it.

- **North**: the four trails out of the woods, where enemies come from: **Fernwood**, **Toadstool Dell**, **Bandit
  Thicket** and **Mossback's Den**. The **signpost** stands north of the fire at the edge of its light.
- **West**: the **Hearthtree** (the tree home; it is also the shop), in one fixed spot at every level, with open ground
  between it and the fire.
- **South-west**: the **lake**, beside the camp and not in it. The **Wishing Well** stands on its near shore, the
  **Fishing Spot** on its south shore. Lily pads, a little dock, fireflies, now and then a jumping fish.
- **East**: the **Training Target** close to the fire, then the **Bow Bench**. Further east, past the firelight, the
  **Guardian Stone**.
- **South-east**: the **Mushroom Cottage** and the **Market** (Bramble the hedgehog trader stands by it). **New (G2):**
  the Market is called the Market, not the Market Stall, and both come at Hearthtree level 2.
- **South**: the **garden**. Further south, at the woods' edge, **the Old Hollow**, the way into the Gloomwood.
- On the campfire's north-east rim: the **cooking pot**.

Each building has its own path from the fire (the well's is a worn path with stepping stones). Nothing tall stands
just south of where the cat walks, so nothing hides the cat.

### The campfire and its light

The campfire is the heart of the camp. Its warm light on the ground **is** the camp:

- **Between waves** (and whenever no fight is on): nothing can hurt the cat in the light, no enemy steps into it,
  and the cat heals there.
- **During a wave**: enemies walk right into the camp and the light protects nothing.
- The light grows with the home level (it reaches 4 m from the fire at level 1, 7.7 m at level 8), and so does the
  campfire's health.

In a fight, enemies go for the campfire last but hardest. If it is destroyed, the **Last Stand** starts (part 4).

### The Hearthtree and the shop

The tree home and its campfire are both called **the Hearthtree** (New, G2; the level names stay).
The home's counter is the **shop**. It sells: the Training Target and the Bow Bench; the cat's own Health, Move speed
and Leaf magnet; acorn towers and thorn spikes, and their levels; "Mend the defences"; growing the home (see the goals
above); and the **Graphics** setting (Auto, Low, Medium, High). After the missions, "Mend all" sits at the top when
anything is damaged.

> **New (20 Nov 2026, G2): what changed at the shop.**
> - **Barricades** are no longer sold here. Build them as rows on the road markers (part 2). The barricade's level
>   (log, stone, and so on up to heartwood) is still upgraded on the Hearthtree's card.
> - **The Wishing Well** is no longer a shop item to wish at. Once built, it works by itself (see Buildings).
> - The card's sections are Grow, The cat, Buildings, Defences and Settings.

### Home levels

The home level caps everything: no station and no defence can be a higher level than the home. Station levels stop
at 3 (the Training Target and the Bow Bench go to 5); from home level 4 on, the home itself grows.

> **New (19 Nov 2026, Phase F): home goals.** Each home level from 2 to 8 has a **goal list**. The home grows only
> when **every goal is met and the price is paid**. Once mission 1 is won, the home's card has a **"Grow the home"**
> section at the top: one line per goal with a tick or its progress ("Damage 3/4"), and a **Go** button (the card
> closes and the cat walks to the building that sells it) or **Show** (scrolls the card to that row). At the bottom:
> "Grow your home to level N". The home's badge shows "!" when it can grow. A toast says when every goal is met.

| Level | Name | Price | Firelight reach | Campfire health | Tower spots |
|---|---|---|---|---|---|
| 1 | Shed | | 4.0 m | 120 | 2 |
| 2 | Hut | 500 leaves, 20 timber | 5.0 m | 300 | 3 |
| 3 | Treehouse | 3,500 leaves, 60 timber | 6.0 m | 600 | 4 |
| 4 | Big Treehouse | 9,000 leaves, 60 timber | 6.5 m | 900 | 5 |
| 5 | Great Tree Home | 8,000 leaves, 60 timber | 7.0 m | 1,300 | 6 |
| 6 | Tree Hall | 15,000 leaves, 200 timber, 20 amber, 8 glowstone | 7.5 m | 1,800 | 7 |
| 7 | Old Oak Hall | 25,000 leaves, 90 timber, 60 amber, 24 glowstone, 5 heartwood | 7.6 m | 2,400 | 8 |
| 8 | Heart Oak | 40,000 leaves, 135 timber, 90 amber, 45 glowstone, 9 heartwood | 7.7 m | 3,000 | 9 |

The goals (all of them must be met). The mission that ends each step is the first goal:

| Home | Goals | Opens |
|---|---|---|
| 2 | Mission 2 won. Training Target and Bow Bench built. Damage 4, Draw speed 2, Health 3. Twig Bow level 4. | Missions 3 to 6 |
| 3 | Mission 6 won (Mossback). Target, Bench, Cottage and Market at 2; Wishing Well built. Damage 6, Draw speed 5, Range 3, Health 5, Move speed 3. Sunwood Longbow level 4. 3 towers; Barricades level 2. | Missions 7 to 10 |
| 4 | Mission 10 won (the Shield Wall). Target, Bench, Cottage and Market at 3; Well 2; Garden 2. Damage 8, Draw speed 7, Range 5, Health 7, Move speed 5. A bow at level 7. 4 towers, 2 of them at level 3; Barricades level 3; Thorn Spikes level 2. | Missions 11 to 13 |
| 5 | Mission 13 won (the Owl Witch). Target and Bench at 4; Well 3; Garden 3. Damage 9, Draw speed 9, Range 7, Health 9, Move speed 7. A bow at level 9; Thorn Volley owned. 5 towers at level 3; Thorn Spikes level 3. | Missions 14 and 15 |
| 6 | All 15 missions won. The Gloomwood cleared once. Target and Bench at 5. Every stat at 10. A bow at level 10. | The raids and the Burrows go on |
| 7 | Gloomwood level 2 beaten | |
| 8 | Gloomwood level 3 beaten | |

**Mission gates:** missions 1 and 2 are played at home 1; missions 3 to 6 need home 2; 7 to 10 need home 3; 11 to 13
need home 4; 14 and 15 need home 5.

Levels 4 to 6 each have their own campfire: a stone hearth, a great bonfire, a crystal brazier. Levels 7 and 8 show
level 6's home and campfire until their own models are made.

**New (20 Nov 2026, G2): rows and the Market.** The Mushroom Cottage (Sprig) and the Market (Thistle) can be built at
Hearthtree level 2. The number of barricade rows allowed grows with the Hearthtree: 2, 3, 5, 7, 9 and 12 in all (see
Defences). Old saves keep their buildings.

### The buildings

| Building | What it does | How you get it |
|---|---|---|
| Signpost | Start the next mission, "Go" between waves, "Go on" or "Give up" a saved mission. No replays. After the missions it becomes **the Watch** (part 7). | From the start |
| Training Target | Damage, Draw speed and Range for the cat (Range from level 2). 5 levels. | Shop, after mission 1's first wave |
| Bow Bench | Bow levels; craft new bows. 5 levels. | Shop, after mission 1 is won |
| Market | Bramble the hedgehog trader. Thistle lives here, and the **Stable** (mount looks, colours, attachments) is on the Market's card. **Sells:** 5 timber for 50 leaves, 2 Sunberries for 30, 2 Fernmint for 30, 1 honey for 40, 1 fish for 25; after all missions also amber for 60, glowstone for 120 and heartwood for 400. **Buys:** timber (5 for 30 leaves), Gloom shards (5 for 100 leaves), and after the missions amber, glowstone and heartwood. (**New, G2:** the Market Stall is now called the Market.) | Hearthtree level 2 (New, G2). Thistle comes free with it. |
| Mushroom Cottage | Sprig lives here. The **Nest** (pet looks, colours, attachments). | Hearthtree level 2, New (G2). It was a gift for mission 3. |
| Wishing Well | **New (20 Nov 2026, G2): automatic, no wishes.** Once built, it mends the campfire, the buildings, the barricade pieces and the towers that are not broken: between waves up to 60%, 75% or 90% of their health (Well level 1, 2 or 3), at 3% a second. In a wave, +0.25%, 0.5% or 1% of their health a second. Broken things, ruins and the ashes need a repair, or a mission won. Its card shows this and its upgrade. | Shop, after 4 missions won |
| Garden and cooking pot | Grow food and cook dishes (part 6) | Gift for winning mission 1, with 4 Sunberries |
| Fishing Spot | Fishing at the lake (part 6) | Gift for winning mission 6 |
| Guardian Stone | The Moss Warden's home: its post, colours and upgrades (part 5) | Appears when the Warden is freed |
| The Old Hollow | The way into the Gloomwood (part 8) | Sealed with Gloom crystals from the first mission won; opens with mission 15's first win |

Most buildings have levels 1 to 3 (bought on their own card, never above the home level). **New (Phase F):** the
Training Target and the Bow Bench have **5 levels**. The station level caps what it sells: Target (or Bench) level
1 to 5 lets each stat (or bow) reach level 4, 6, 8, 9 or 10. Health, Move speed and Leaf magnet use the home level
instead. Target levels 3 to 5 show the second Target model, and Bench levels 4 and 5 the third Bench model, until the
owner decides how new models are made. Range now grows 0.2 m per level (it was 0.3).

**Buildings can be broken.** In a wave, enemies attack buildings. A building at 0 health is a **ruin**: it does
nothing until it is repaired (a ruined home closes the shop, a ruined stall means no riding, and so on). Winning a
mission mends every ruin for free.

> **New (20 Nov 2026, G2): tower repair.** A knocked-down acorn tower shows a repair marker. Tap it to repair the tower
> for 30% of what it cost (leaves, plus 1 timber per 30 leaves). When the camp falls, ruins stay and cost about 30% of what the building cost to
repair. After the missions, raids also leave **wear** (part 7).

---

## 4. Missions

### Starting one

Go to the signpost. Its card ("To the woods") shows the next mission: its waves and its enemies. Tap **Fight**.

> **New (19 Nov 2026, Phase F): no replays.** A won mission is done, and the signpost offers only the next one (or a
> saved run: "Go on" / "Give up"). If the next mission needs a bigger home, the card says "Needs home level X (yours
> is Y)", lists the missing goals, and has a **Home** button. A one-time tip after a win explains a locked mission.
> After a lost chapter the hint says "Spend your leaves on the goals at your home, then try again." After all 15
> missions the signpost is the Watch. The old "strength" note on the card is gone.

### Waves, chapters and breathers

- Missions 1 to 5 have **15 waves**, missions 6 to 15 have **20**. Waves come in **chapters of 5** (Scouts, Main
  assault, Onslaught, Finale).
- Each wave is a little stronger than the last (5% a wave, on top of 8% a mission) and has more enemies in total.
  **New (20 Nov 2026, G1): many enemies in a wave, few on the field.** A whole wave has 10 to 25 enemies in missions 1 to 5, 16 to 32 in missions 6 to 10, and 20 to 38 in missions 11 to 15 (first wave to last). At most 10, 12 or 14 are on the field at once (by mission group; it was 28). Tanks (Stump Golem, Toadstool Brute, Beetle Knight, Crystal Snail; a Bramble Boar counts as half) are at most 1, 2 or 3 at once. In a whole wave, tanks are at most 10% (missions 1 to 5) or 15% (missions 6 to 15). With a boss alive, at most 8 others are on the field.
  **No easy waves (Phase F, changed in G1).** An ordinary wave whose total health is under 85% of the wave before it swaps its weak enemies for stronger ones. It never adds enemies. (Not the first wave after a chapter break, not the boss wave.) Enemies also come in **bursts** of 2 to 4,
  0.4 s apart, not one by one, and spawn speed carries over between chapters. Missions 6, 13 and 15 have real last
  chapters and fewer helpers with the boss.
- Every chapter's last wave is an **elite wave** (the mission's tough enemy, more each chapter). The mission's last
  wave brings its **boss** or a big finale pack.
- Between waves: a **15 s breather**. The camp is safe, the cat heals, the cards work. "Go" at the signpost skips it
  (it pays a little, see Pay). The top bar says where the next wave comes from.
- After each chapter: a **chapter break**. The campfire is fed back to full, a **chest** pays out, and **the game
  saves**. The camp waits until you tap Go at the signpost. If you close the game mid-mission, you come back to the
  start of that chapter: "Go on" or "Give up this mission" (giving up keeps what you earned).
- A wave can never hang: if its last 3 enemies do nothing for 45 s, they flee.

### Squads (New, 20 Nov 2026, G1b)

Mission waves are made of **squads**: small teams, each with roles.

- **Light:** Thornling, Moth, Raccoon, Puffball, Mole.
- **Fighter:** Boar.
- **Tank:** Brute, Stump Golem, Beetle Knight, Crystal Snail.
- **Support:** Pitcher, Frog Shaman, Crow Drummer.

The 12 squads:

| Squad | Who | From mission |
|---|---|---|
| Scouts | 3 or 4 Thornlings | 1 |
| Chief's Band | The Thornling Chief and 3 Thornlings (elite) | 1 |
| Boar Raid | 1 Boar, 2 Thornlings | 2 |
| Brute Wall | 1 Brute, 3 Thornlings | 3 |
| Stump Siege | 1 Stump Golem, 3 Thornlings | 4 |
| Bandits | 2 Raccoons, 2 Thornlings | 5 |
| Moth Cloud | 3 Moths | 7 |
| Moth Escort | 1 Brute, 2 Moths | 7 |
| Spitter Nest | 2 Pitchers behind, 2 Thornlings | 8 |
| Choir | 1 Frog, 1 Crow, 2 Thornlings, 1 Boar | 9 |
| Shield Wall | 2 Beetle Knights, 2 Moles | 10 |
| Crystal Creep | 1 Snail, 2 Puffballs | 11 |

**The rules for a wave:**

- From mission 2, a wave has at least 2 kinds of squad.
- From mission 3, no kind is more than about 40% of a wave, where possible. Missions 3 to 8 often cannot meet this,
  because Thornlings are in most squads. The game does its best.
- Wave sizes and the field and tank limits from G1 stay the same.
- Each chapter lists its squads. The bosses (missions 6, 13 and 15) come with escort squads. Elites lead their own
  small squads.

**How a squad moves:** a squad comes down one road together.

- The leader goes in front: an elite, else the tank, else the fighter.
- The light ones keep pace beside and behind. Support stays about 2.5 m behind.
- Within 6 m of the firelight, when the leader dies, or when the cat comes close, the squad breaks up. Each one then
  does its own job.
- Raids keep their old random waves.

### The four roads: patterns

> **New (19 Nov 2026, Phase F).** The four roads stay. Each wave of a mission has a pattern:
>
> | Pattern | Share | What happens |
> |---|---|---|
> | Surround | about 65% | All four roads, taking turns. The mission's own road sends a bit more. |
> | Pincer | about 20% | Two roads far apart |
> | Rush | about 15% | The mission's own road: the same number of enemies, 15% faster (G1: they used to bring 25% more), with a banner |
>
> Elites come down a different road (a flank). The boss wave is a surround. **Mission 1 teaches it:** chapter 1 uses
> one road, chapter 2 two, chapter 3 all four. In a breather the top bar names the next wave's roads, so barricades
> become a choice. Gloom Raids keep their old rules. The Gloom over the woods now fades a step with each mission won
> (it only changes the look).

### Pay

Kills drop golden leaves (pick them up; the Leaf magnet pulls them in, and what is left flies to the cat when the
wave ends). Each cleared wave pays a small bonus, each chapter a chest with timber, and the win pays the
mission's reward. **New (G1):** every mission wave held also pays 1 timber times the mission's pay scale (at least 1). Chapter chests pay 2, 4, 4 and 6 timber for chapters 1 to 4 (it was 1, 2, 2 and 3). All of it grows 20% per mission. The first win of a mission may give a gift (see the table below).
**New (Phase F): pay for active play.** A **quick clear** (the wave cleared within 20 s plus 3 s per enemy) and an
**intact wave** (no building or defence ruined, the fire never out) each pay **half the wave bonus again**. Going on
early from the signpost pays 0.5 leaves for each breather second skipped. The toast reads like "Wave 3 held! +5 leaves
· +1 timber · quick +3 · intact +3". The win rewards are much bigger than before (part 9).

### Enemies attack the camp

When an enemy is not busy with the cat it goes for, in order: a **barricade** blocking its trail, then a **tower**
within 7 m, then the **nearest building** within 9 m, then the **campfire**.

### Reasons to move

> **New (19 Nov 2026, Phase F).** The cat should not just stand and shoot.
>
> - **Ranged foes hang back.** Pitcher Spitters (8 m) and Frog Shamans (7.5 m) stop at that distance from a tower, a
>   building or the campfire and shoot it from there. That is beyond the cat's reach when she stands at the fire, and
>   beyond a tower's range. Walk out to them. Up close they still fight the cat.
> - **The Golden Grub** (from mission 2, about 1 wave in 3). A small gold grub (a stand-in model) runs round the camp,
>   outside the firelight, with a sack of 40 leaves. Shoot it within 14 s or it gets away. It never holds a wave up.
> - **The Gloom Totem** (from mission 3, about 1 ordinary wave in 3). A violet crystal spire (made from existing
>   Gloom props) grows on a road a few seconds into the wave. Enemies within 4 m are 25% faster and take 25% less
>   damage (a faint violet tint) until the cat breaks it. The wave waits for it.

### Defences

| Defence | Where it goes | What it does | Opens |
|---|---|---|---|
| Barricade row (New, G2: 90 leaves and 5 timber for 3 pieces) | Tap a road marker: 3 per trail, 12 in all | Blocks the road: enemies must break each piece | Rows allowed by Hearthtree level: 2, 3, 5, 7, 9, 12 |
| Acorn tower (90 leaves) | Anywhere free; how many is set by the home level (2 to 9) | Shoots acorns at enemies near it; enemies go for towers right after barricades | After 2 missions |
| Thorn spikes (70 leaves) | Anywhere free | Hurt and slow whatever walks over them | After 3 missions |

> **New (20 Nov 2026, G2): barricade rows.** Each piece breaks on its own. Below 50% health it is cracked (darker and
> leaning). At 0 it falls flat, with rubble, and enemies pass the gap. Tap a row to repair it: 30% of the row's cost per
> broken piece, half per cracked piece. A won mission mends all the free repairs. Old saves: placed barricades became
> rows, and bag pieces were refunded as leaves.

All acorn towers and thorn spikes share one level, bought in the shop and capped by the home level. The barricade's
level (log, stone wall, thorn gate, and so on) is upgraded on the Hearthtree's card. Towers and spikes get stronger each level. Level 4 (Shardstone and the shard levels) costs Gloom shards
and opens after the missions; level 5 (Heartwood, Amber, Amber Thorns) costs Gloomwood materials. Broken defences are
mended free when a mission is won; after a camp fall or a raid they stay broken until mended in the shop or with
"Mend all".

### The Last Stand and the camp falling

- **The campfire is destroyed**: the Last Stand. The fire's light is gone, the camp is not safe, and the cat fights
  alone in the dark. Once per chapter you can **rebuild** it: stand on the ashes for 4 s (a hit starts it over) and
  pay 10 timber, or 60 leaves when you have less than 10 timber (New, G1: so the camp can always be lit again). It comes back at 30% health.
- **The camp falls** if the cat is knocked out during the Last Stand, or the fire is destroyed a second time in the
  chapter.

### What a loss costs

| What happens | What it costs |
|---|---|
| The cat is knocked out while the fire burns | Nothing. It is back by the fire in 5 s. |
| The mount is knocked out | It stays out until fed (2 Sunberries) or the next chapter break (part 5). |
| The camp falls | The Gloom takes 30% of your unspent leaves. Ruins stay ruins. Broken defences stay broken. The campfire is ashes until you light it again at its spot (New, G1: 40 leaves and no timber, or free when you have fewer than 40 leaves; no mission starts before that). **The chapter starts over**, not the mission. A dish eaten this chapter goes back into the pot. No level is ever lost. |
| You give up a mission | Its next try starts at wave 1. What you earned stays. |

### The 15 missions

| # | Mission | Waves | Needs home | Trails | New threat | Ends with | First-win gift |
|---|---|---|---|---|---|---|---|
| 1 | First Embers | 15 | 1 | Fernwood | Thornlings (the tutorial) | Thornling Chief (a mini-boss) | Garden and pot, Bow Bench in the shop, 60 leaves (New, G1b: "+60 leaves for your first barricades"; it was 2 barricade pieces) |
| 2 | Bramble Pack | 15 | 1 | Toadstool Dell | Bramble Boars | 2 boars | None (New, G2: the Market and Thistle come at Hearthtree level 2) |
| 3 | Toadstool March | 15 | 2 | Bandit Thicket | Toadstool Brutes | 3 brutes | None (New, G2: the Cottage and Sprig come at Hearthtree level 2) |
| 4 | Stumps at Dusk | 15 | 2 | Mossback's Den | Stump Golems | 3 stumps | |
| 5 | Bandit Night | 15 | 2 | Fernwood, Dell | Raccoon Bandits | 2 brutes, 4 raccoons | |
| 6 | Mossback Wakes | 20 | 2 | Mossback's Den | | **Mossback** (boss) | Fishing Spot |
| 7 | Moth Swarm | 20 | 3 | Fernwood, Thicket | Gloom Moths | 6 moths, a stump | |
| 8 | Spitting Thicket | 20 | 3 | Dell, Thicket | Pitcher Spitters | 4 pitchers, a stump | |
| 9 | Croaking Choir | 20 | 3 | Thicket, Den | Frog Shamans, Crow Drummers | 2 crows, 3 frogs | |
| 10 | Shield Wall | 20 | 3 | Fernwood, Den | Beetle Knights, Mole Sappers | 3 beetles, 2 moles | |
| 11 | Crystal Creep | 20 | 4 | Dell, Den | Crystal Snails, Puffball Bombers | 2 snails, 4 puffballs | |
| 12 | Two Fronts | 20 | 4 | all four | everything from every trail | 2 stumps, 2 brutes | |
| 13 | The Owl Witch | 20 | 4 | Toadstool Dell | | **The Owl Witch** (boss) | |
| 14 | Gloom Tide | 20 | 5 | all four | everything at once | 2 snails, 2 stumps | |
| 15 | The Elder Thornstag | 20 | 5 | Thicket, Den | | **The Elder Thornstag** (boss) | Gloom Raids and the Old Hollow open |

**New (Phase F): mission 2 is easier.** Fewer boars (none in waves 1 and 2), elite waves with 1, 1 and 2 boars, and a
final wave of 2 boars. Boars are also softer (see the enemies table). Missions are gated by home level (see Home
levels in part 3). Only missions 6, 13 and 15 end in a real boss. The owner wants 2 or 3 more bosses later (part 10).

### The enemies

| Enemy | What it does |
|---|---|
| Thornling | Small and quick; pounces; chases the cat when near |
| Thornling Chief | A big Thornling: mission 1's mini-boss |
| Toadstool Brute | Goes for buildings; its spore bursts slow the cat |
| Raccoon Bandit | Grabs golden leaves off the ground and runs away with them (never in raids) |
| Bramble Boar | Paws the ground, then charges in a straight line every 5 s (70 health; 22 damage to the campfire, 90 to a barricade). **New (Phase F):** a boar that misses its charge, or hits a barricade, a building or the Warden, is **dazed** about 1 s ("Bonk!") and takes 1.5 times damage. A tip explains it the first time. |
| Mossback (boss) | A huge mossy bear: swipes, slams the ground (a ring that hurts), roars up Thornlings, and its Gloom Dash |
| Gloom Moth | Flies over barricades and buildings; dives at the cat |
| Frog Shaman | Heals enemies near it; lobs Gloom bolts. Stops 7.5 m from a tower, building or the fire and shoots it from there |
| Beetle Knight | Its shield blocks most of an arrow from the front: hit it from the side, from hiding, or while it attacks |
| Crystal Snail | Slow and tough; its slime slows the cat; bursts crystal spikes round itself |
| The Owl Witch (boss) | Blinks next to the cat, throws homing orbs, curses the ground, calls moths |
| Stump Golem | A slow siege brute: double damage to buildings, towers and barricades |
| Pitcher Spitter | Stops 6 m from the cat, or 8 m from a tower, building or the fire, and spits thorns |
| Mole Sapper | Digs under a barricade and pops up behind it |
| Puffball Bomber | Waddles up to a building or the cat and bursts |
| Crow Drummer | Drums: enemies near it get faster and hit harder |
| The Elder Thornstag (boss) | Charges through barricades, stamps, calls Stump Golems |
| Golden Grub (bonus) | Runs round the camp with 40 leaves and escapes after 14 s (part 4, Reasons to move) |
| Gloom Totem | A crystal spire that speeds up and toughens enemies near it until the cat breaks it |

The Gloom Herald leads the raids (part 7); the Gloomwood has its own creatures (part 8).

---

## 5. Companions

### Thistle, the mount

- Comes free with the Market (New, G2: at Hearthtree level 2). Tap **Ride** and it bounds over; the cat hops into the leaf saddle.
- Riding: the cat runs 50%, 65% or 80% faster (by Market level) and keeps shooting. When enemies crowd in, Thistle
  **thumps** the ground (a shockwave that hurts and pushes them back). The cat can't hide while riding.
- **Thistle takes the hits** while the cat rides. Its health is the thin bar under the cat's.
- **Knocked out**, it throws the cat off. In a mission it stays out until you **feed** it 2 Sunberries with the Feed
  button (any time, even mid-wave; it comes back whole and the cat hops on) or until the next chapter break. In the
  Gloomwood it stays out until fed. Outside missions it rests 20 s and gets up by itself. With no food, the button
  says "No food".
- It is whole again at every chapter break and when a mission ends.

### Sprig, the pet

- Comes with the Mushroom Cottage (New, G2: at Hearthtree level 2). It flutters at the cat's shoulder and spits seed sparks at the nearest
  enemy, harder and faster with each cottage level.
- **The pet is never knocked out.** While the cat hides, Sprig only spits at enemies right next to it, so it never
  gives the cat away. In the Gloomwood it glows like a little lantern.

### Looks (same strength)

- **The Stable** (Market card): Thistle the hare or **Bramblewool** the ram. **The Nest** (cottage card): Sprig
  the leaf dragon or **Lumi** the fox kit. Every look does exactly the same: only the model, its move and its colours
  differ (Thistle thumps, Bramblewool rams, for the same damage).
- **Colours** row: Natural, Snow, Midnight, Autumn, Golden and more, per look. All free while testing; sold later.
- **Gloomlit** colours cost 60 Gloom shards per look. They are earned only, never sold.
- **Attachments** (after the missions): see part 8.

### The Moss Warden, the camp's guardian

- A big, slow golem of mossy stone and old roots, from the owner's Meshy model.
- **How you get it:** not in the missions, never sold. On the **first clear of the Gloomwood**, after Mossback falls,
  the Warden lies sealed in violet Gloom crystals at the arena's north edge. Stand on the seal for 3 s to break it.
  It comes home and lives by the Guardian Stone, east of the camp. Banner: "The Moss Warden is free! It will guard the
  camp while you are away."
- **What it does:** in a fight (raids and mission replays) it goes for whatever attacks your buildings, barricades,
  towers or campfire. It punches, and slams the ground when foes crowd it (small foes are dazed). It is too slow for
  fliers and thieves.
- **Knocked down**, it is a heap of stones that pulls itself together after 30 s, twice as fast if the cat stands
  next to it, or at once at the next breather.
- **Its post** (stone card, "Change"): guard the whole camp, or hold one trail's mouth.
- **Upgrades** at the stone cost leaves and a little timber (level 4: 2,500 leaves and 20 timber). It also grows with
  the home level.
- It **never goes into the Gloomwood**. Six colours; Lakeweed comes from a fishing treasure (part 6).
- **Only one guardian for now.** More kinds, each fighting or helping in its own way, are for later (part 10).

---

## 6. Food

Food matters from the start: it brings the mount back, and dishes give a boost.

### The garden

- South of the camp, the gift for winning mission 1 (with 4 Sunberries, so the pantry is never empty).
- 3, 5 or 6 plots by garden level. **Plant** (seed packets cost a few leaves), **water**, and **pick** when ripe (a
  glint shows it).
- **It grows one step for every wave the camp holds**, two while watered (watering lasts 3 to 5 waves). That means
  mission waves, replays and raid waves. It never grows with real time, while the game is closed, or while you wait
  in the camp. Ripe plants never rot. (Gloomwood runs do not grow it.)

| Crop | Gives | Ripe after |
|---|---|---|
| Sunberries | 3 Sunberries | 4 steps |
| Fernmint | 2 Fernmint | 5 steps |
| Honeybells | 2 honey | 6 steps |

The pantry holds up to 20 of each food.

### Cooking

- The pot sits on the campfire's rim and comes with the garden. Cook **one dish** between waves. It waits in the pot,
  is **eaten when the next chapter (or raid) starts**, and lasts that chapter. A held chapter uses it up; if the camp
  falls it goes back into the pot. No cooking on the ashes.

| Dish | Made from | Boost | Shown |
|---|---|---|---|
| Berry Tart | 3 Sunberries | shoots 15% faster | from the start |
| Fernmint Tea | 2 Fernmint | +2 health | from the start |
| Honey Cake | 2 honey, 1 Sunberry | pet, mount and Warden hit 40% harder | from the start |
| Hearth Stew | 2 Fernmint, 1 honey, 2 Sunberries | campfire 40% more health | from the start |
| Fish Skewers | 2 fish, 1 Fernmint | arrows hit 20% harder | once fishing is there |
| Warden's Root Stew | 2 fish, 2 Fernmint, 1 honey | Warden +50% health, back up in 15 s | fishing and the Warden |
| Golden Carp Feast | 1 Golden Carp, 2 Sunberries, 1 honey | a little of everything | once a Golden Carp was caught |

### Fishing

- The gift for winning mission 6, at the lake's south shore. Any time no wave is on: **Cast** on the card. After a
  wait (and a nibble or two) the float dips with a white, blue or gold "!": **tap anywhere**. Bigger catches need
  reeling: a ring closes on the float, tap while it is green. A miss costs nothing.
- Stop by walking away; a wave starting pulls the line in.
- Catches: Minnow and Sun Perch (fish), Silver Trout (2 fish), Driftwood (timber), Golden Carp (rare), Sunken Chest
  (leaves and timber). A rare catch comes at least once every 20 catches.
- Three lake treasures, found in order: the **Lucky Lure** (bites come 25% sooner), the **Silk Line** (one more slip
  forgiven when reeling), the **Lake-moss Charm** (the Warden's Lakeweed colours).

### Food in the Gloomwood

- The **Feed** button works there too (2 Sunberries for the knocked-out mount).
- A **Snack** button: one piece of food heals the cat (fish +4, honey +3, Golden Carp +6, Fernmint +2, Sunberries +2;
  tried in that order so the mount's berries last). At most one every 3 s.
- A dish waiting in the pot **goes down with the cat** and lasts the run.

---

## 7. After the missions: Gloom Raids

Raids start with the first win of mission 15. They come only while you are playing in the camp.

### The meter and the Watch

- The signpost grows a horn and a crystal: **the Watch**. Its crystal and the top bar show the **Gloom meter**.
- The meter fills about 10 points a minute while you play in the camp with no fight on. It does **not** fill while
  you are idle (no touch for 45 s), while the cat is in the Gloomwood, or while the game is closed. Cooking, picking,
  fishing, replays and Gloomwood runs add a few points, but never past 95, so the horn always sounds while you are
  there. Empty to full takes about 10 minutes of play.
- At 75% the next raid is planned ("The Gloom stirs in the woods..."). At 100% the horn sounds.
- From 50% you can **Sound the horn** on the Watch card to call the raid early (30 s warning).

### A raid

1. **Warning**: 45 s (60 s for the first raid and elite raids; never under 30 or over 60). A banner says what is
   coming and from where, mist and eyes roll back onto the trail, a gold arrow points at it, and a countdown runs at
   the top right. The camp is safe and every card works. The countdown stops while you are idle. "Meet them now"
   starts it early.
2. **3 waves**, with 10 s breathers between them.
3. **The leader** walks in during wave 3: the Gloom Herald, or a boss in an elite raid. **Topple the leader and the
   raid breaks**: the rest flee and drop their leaves.

| Kind | From | Trails | Leader | Who comes |
|---|---|---|---|---|
| Siege (the first raid is always one) | raid 1 | 1 (2 from raid level 12) | Gloom Herald | Bruisers for your buildings: Stump Golems, Brutes, Boars, Beetles, Thornlings |
| Sky | raid 2 | 2 | Gloom Herald | Mostly Gloom Moths over the barricades: towers and your bow matter |
| Sneak | raid 3 | the least-guarded one, hidden until 15 s left | Gloom Herald | Thornlings, Moles, Puffballs |
| Elite (rare) | raid 5, then 4 raids apart at least | 2 | Mossback, then the Owl Witch, then the Elder Thornstag | A tough mix; pays double shards |

### Winning and losing

- **Held**: Gloom shards, leaves, timber and a Hollow key (2 for an elite raid). A **perfect defence** (no building
  lost, the fire never out) pays 50% more shards; a camp that was whole when the raid began pays 20% more. Perfect
  streaks put ribbons on the signpost.
- **Lost** (the camp falls): only the damage stays, plus 2 shards per wave held. Nothing is taken, the fire relights
  at once, and the next raid is a little gentler.
- **Raid level** (1 to 30) grows with the camp (home level, station levels, towers, defence levels, the Warden) and
  with raids won. The cat's own upgrades never make raids harder.

### Keeping the camp up

- Damage carries over between raids: **ruins**, **wrecked defences**, and **wear** (a building keeps the share of
  health raids took from it; it darkens and gets rubble piles at its foot).
- Fix it with **Patch it up** on a building's card, "Mend the defences" in the shop, or **Mend all** (or **Mend
  some**, when you cannot pay for all) on the Watch card and at the top of the shop. Each mended thing springs back
  with a flower ring. Ruin repairs after the missions are capped in price.
- The Warden is knocked down by raids and gets up by itself.

### What shards buy (earned only, never sold)

Defence level 4 (Shardstone barricades, level 4 towers and spikes; 50 to 90 shards plus leaves, needs home level 4);
**Lookout** (25: +15 s to get ready before every raid); **Tracker** (40: see the next raid at 75%, and sneak raids
can't hide); **Gloomlit** colours (60 per mount or pet look); **Shardfire** (100: the campfire burns blue-violet).
Bramble buys 5 shards for 100 leaves.

---

## 8. After the missions: the Gloomwood

**The Burrows** is the working name for the dungeons (accepted by the owner). The first one is **the Gloomwood**,
reached through **the Old Hollow** at the south edge of the camp. After the missions, the Burrows are most of the
game: go in, bring back what the camp needs, upgrade, go again on a harder level.

### Getting in

- The Old Hollow appears sealed with Gloom crystals (two violet eyes blink under them) from the first mission won. It
  opens with mission 15's first win.
- **Entry is free and unlimited.** It is blocked only while a fight is on or a raid is coming. A damaged camp only
  shows a warning on the card.
- The cat goes in with its **pet and mount**. The Warden stays home.
- The card: "The Gloomwood · Level N" (**Go in**), "Play another level" (lower levels are easier), "Use a Hollow key:
  yes/no", your materials, and any mending the camp needs.

### The road

One continuous road through a wood at night, about 158 m from the way in to the centre of the boss arena. It winds
mostly north, up the screen, so the cat always sees what is ahead. Packs sleep and **wake together** when the cat comes
near or hits one (waking one can wake a pack near it). Other monsters **burst out** of holes or fly in from the dark as
the cat passes. Everything that hurts a lot **glows on the ground** before it lands. There are no respawns in a run.

| Stop | What happens |
|---|---|
| **The way in** | A glade with torches. A "Go home" ring works until anything has woken (nothing lost). **Checkpoint.** |
| The sleeping camp | A dead campfire with a pack asleep round it |
| *The ambush in the ferns* | Thornlings jump out as the cat passes (no pip) |
| The burrow holes | Three holes: Grublings burst out as the cat passes each. A side path west leads to a nook with the **Gloom-bound chest**: open it, or break its seal for double loot and a Gloomtouched guard with two friends. |
| The Glowcap clearing | A bigger pack among glowing mushrooms |
| The bramble bend | A pack on the road |
| Rolling logs | Logs roll across the road on a rhythm. The chest at the end opens only if the cat was not hit. |
| *Moths from the dark* | Gloom Moths fly in (no pip) |
| **The Moonwell** (safe) | A spring that heals once, two boon shrines (take one), a **root lift home** with the whole satchel. Maybe an Amber Grub. **Checkpoint.** |
| The bridge | A wooden bridge over a dark stream. Moths fly in as the cat crosses; a pack with a Gloomtouched elite holds the far bank. |
| The old oak | A pack under the oak |
| *The gate's watch* | Grublings and Thornlings spring out (no pip) |
| **The arena gate** | An arch of roots. **Checkpoint.** |
| **The arena** | A big round clearing, about 22 m across, with five standing stones. **Mossback** sleeps at the north side. Step in and roots close behind the cat; the boss wakes with its bar. When it falls: its helpers vanish, the boss chest, a root lift home, and on the very first clear the Moss Warden's seal (the lift waits until the seal is broken). |

**Fighting Mossback:** its Gloom Dash into a standing stone dazes it for 2.5 s, and it takes 50% more damage then.
At most a few helpers are with it at once.

> **New (19 Nov 2026): the Gloomwood's look and difficulty.** The ground is a real **night road** of
> flagstones, bricks and cobbles that changes from section to section, with worn and mossy stretches, roots, barrels,
> old arrows and shields by the fights, and grass and leaves at its edges. **One colour scheme**: cool slate blue-grey
> stone with warm orange lantern and ember light. **Every torch and lantern throws a warm pool of light**, so it is
> dark but clearly visible, also on Low graphics. The **boss arena is a stone circle** with a carved sigil in the
> middle, ember cracks, rune stones and giant old swords round its rim. The dungeon is **much harder**: monsters have
> 50% more health and hit 1 harder,
> bigger packs, the three ambushes above, elites from level 1, the spring heals only part of the cat's health, and
> Mossback is much tougher and **enrages** near the end (faster, a second ring with each slam, more helpers). The goal:
> a cat that only stands and shoots must be knocked out before the end; a cat played with care (riding, feeding,
> snacks, dashing out of danger) must win. Measured: a standing endgame cat is knocked out just after the Glowcap
> clearing; Mossback has about 9,900 health at level 1 (was 3,000) and takes about 70 s for a cat that only shoots.
> Pay is up 25% to match. Tune by play on the phone.

### Levels

Each win opens the next level of the same road. Level 1 is open when the Hollow opens; beating level N opens N+1. Each
level is stronger, has bigger packs, brings other monsters and pays more. Mossback is the boss at every level, and
**Gloomtouched** (violet, bigger, much tougher) from level 4. The very first run uses fixed packs, the same for
everyone. The holes and the dark always send their own kinds; the packs come from the level's list:

| Level | Monsters in the packs | Pays |
|---|---|---|
| 1 | Thornlings, Grublings, Glowcaps, Boars, Moles | amber |
| 2 | Grublings, Glowcaps, Brutes, Puffballs, Frogs | amber, glowstone |
| 3 | Beetles, Moles, Crows, Boars, Thornlings, Grublings | amber, glowstone, heartwood |
| 4 | Moths, Pitchers, Glowcaps, Snails, Beetles | the same; Mossback is Gloomtouched |
| 5 and up | Stumps, Beetles, Glowcaps, Moths, Puffballs, Crows, Grublings | stronger and richer every level |

The Gloomwood's own creatures (stand-ins until the owner's models come): the **Grubling** bursts out of the ground,
the **Glowcap** keeps away and lobs spore bombs where the cat is going, the **Root Snapper** never moves and bites
along a line, and the rare **Amber Grub** runs for a hole and digs away after 10 s (catch it for leaves and amber).

### The satchel

Materials (**Root Amber**, **Glowstone**, **Heartwood**) go into the **satchel**. Leaves, timber and shards are banked
at once. A root lift (at the Moonwell, or after the boss) brings all of the satchel home. A knock-out (Sprig drags the
cat back up the hollow) or "Leave it" on a saved run brings half. "Go home" at the way in, before anything woke, is as
if the run never happened (a used key comes back).

### Boons and keys

- **Boons** last one run: Sharp Thorns (arrows +25%), Quick Paws (the dash recharges faster and goes further),
  Mossheart (+3 health), Sprig's Fury (Sprig spits 50% faster), Dewdrop Charm (healing dew three times as often),
  Lucky Paw (one more of each material in every chest). The Moonwell offers two; take one.
- **Hollow keys** are only a bonus: going in with one gives the run a boon from the start. You hold at most 3. The
  ring is filled to 3 when the Hollow opens; then keys come only from play (a raid held, a replay won, a level's first
  clear). A key that does not fit turns into 150 leaves. Nothing refills by time.
- **Dew drops** sometimes fall from kills and heal 1; a dew bud may bloom where a fight was won.

### Checkpoints and saving

The run is saved at each checkpoint (the way in, the Moonwell, the arena gate), when the cat is hurt, and when the app
is paused. Close the game and the run waits at the Hollow: **Go back in** puts the cat at the last checkpoint with its
saved health, boons and satchel. Fights before it stay won; fights after it are full again. Chests opened, the spring
drunk and the boon taken stay done.

### What materials buy

- **Mastery**: levels 11 and 12 of Damage, Draw speed, Health and Move speed, and of every bow.
- **The Foxfire Bow** (Bow Bench level 3; 2,000 leaves, 16 glowstone, 3 heartwood): goes through two enemies.
- **Level-5 defences**: Heartwood barricades, Amber towers, Amber Thorns.
- **Home levels 7 and 8** (part 3).
- **Attachments**, one worn per companion, helping **only in the Gloomwood**, bought and worn on the Stable and Nest
  cards (they show on the card only, not yet on the models). For the mount: the Mossweave Saddle (50% more health),
  Thunder Shoes (Thump 60% harder), Saddlebags (25% more loot). For the pet: the Glowworm Lantern (traps and spore
  bombs glow 0.3 s earlier), the Ember Charm (sparks 60% harder), the Dew Bell (+2 health for the cat).

The Warden's level 4 costs leaves and timber, not materials (the owner's rule: guardian upgrades cost leaves).

### More dungeons

More dungeons are **data plus models**: a new map file and one entry in the list (part 11). Not every dungeon needs a
boss: a map can end in a **treasure clearing** instead, and the owner wants some later dungeons without one.

---

## 9. Progress and money

### What you earn

| Currency | Where it comes from | What it buys |
|---|---|---|
| Golden leaves | Kills, waves, bonuses, chests, mission rewards, raids, the Gloomwood | Almost everything |
| Timber | Mission waves held (G1), chapter chests, mission rewards, driftwood, raids, the Gloomwood | Buildings, home levels, rebuilding the campfire; buy 5 for 50 leaves, sell 5 for 30 leaves (G1) |
| Gloom shards | Raids, Gloomwood boss chests | Part 7's list; sell 5 for 100 leaves |
| Hollow keys (0 to 3) | Raids held, a level's first clear | A boon at the start of a run |
| Root Amber, Glowstone, Heartwood | The Gloomwood only | Part 8's list |

### The chain (New, 19 Nov 2026, Phase F)

```
missions -> leaves and timber -> buildings (the home caps their level)
         -> the cat's stats and bows (each building caps them)
         -> the home's goals are met -> the home grows -> the next missions open
```

- **No replays.** Every win pays much more than before, so finishing a mission gives enough leaves to upgrade. The
  goals plus the home's price fit inside what the act's missions pay when each is won once; what is left is your
  choice (more towers, stats past the goal, food, repairs). The spare shrinks as the game goes on.
- **Win rewards (leaves)** for missions 1 to 15: 100, 180, 200, 300, 350, 700, 600, 700, 800, 900, 1,300, 1,400,
  2,000, 1,200, 1,500. Timber goes from 10 to 60.
- **Prices.** Stat and bow prices are 30% higher than before. Home prices are in part 3.
- **The camp fall** is unchanged (30% of unspent leaves). A lost chapter is played again, and its kills pay again.
- **After the missions** the Gloom Raids and the Burrows are the endless play. The home is not maxed when the
  missions end: homes 6 to 8 are dear, and mastery, mending and food pull on the same leaves.

### Growing stronger

The cat's stats (10 levels each, capped by the station, 4, 6, 8, 9 or 10 by the Target's level; Health, Move speed and Leaf magnet by the home level; most get 2 mastery levels after the missions), the bows (the
Twig Bow to start; the Sunwood Longbow at Bench level 2 goes through an enemy and reaches further; the Thorn Volley at
level 3 shoots three arrows; the Foxfire Bow in part 8), and the camp (part 3). Every exact price is in
`game/data/balance.json`. When the player has everything, the game is done and the Gloomwood is there for fun.

### The money plan (nothing of it is built yet)

The owner's rules (18 November 2026):

- **Rewarded ads only**: an ad plays only when the player taps a button that says what they get. No ads between
  screens and no banners, ever.
- **Sold**: looks (new pets and mounts with the same strength, colour skins, cosmetics) and **attachments** for the
  pet and mount, which help only in the Gloomwood and can also be earned by playing.
- **Never sold**: leaves, timber, shards, keys, materials, stats, mission progress, raid wins, the guardians, or
  anything that skips the missions. A player who never pays can get every gameplay thing by playing.

Claude's proposals, waiting for the owner (`GAME_PLAN.md` section 0, "Making money"): a premium currency (working name
**Moonpetals**, also earned in small amounts by playing); rewarded-ad gifts such as doubling a chapter chest, keeping
your leaves when the camp falls, one extra chance in the Last Stand, rerolling a boss chest, or a small food bundle,
with only a few per session; cat outfits, bow skins, emotes, camp decorations; a starter pack; a Forest Pass season;
supporter bundles. It would use Google Play Billing and an ad network through a Godot plugin.

---

## 10. What is waiting on the owner

### Meshy models

The game uses stand-ins until these come. Concept images are made. Put the Meshy file in `art/source/meshy/`.

| Model | Used as | Stand-in now | Concept image |
|---|---|---|---|
| Gloom Herald | Raid leader | The Crow Drummer, 1.25 times bigger | `concepts/enemies4/01_gloom_herald.png` |
| Grubling | Gloomwood | A small tinted Mole Sapper | `concepts/burrows/01_grubling.png` |
| Glowcap | Gloomwood | A small teal Toadstool Brute | `concepts/burrows/02_glowcap.png` |
| Root Snapper | Gloomwood | A tinted Pitcher Spitter | `concepts/burrows/03_root_snapper.png` |
| Amber Grub | Gloomwood | A small tinted Mole Sapper | `concepts/burrows/05_amber_grub.png` |

Later: the **Bramble Boar** (`concepts/companions/04_bramble_boar.png`, a fighter) and the **Lantern Owl**
(`concepts/companions/05_lantern_owl.png`, a helper) as new guardians; **2 or 3 more mission bosses** for missions
that end without one, for example 4, 9 and 12 (no concepts yet). Old Grubber (`concepts/burrows/04_old_grubber.png`)
is no longer needed.

### Play on the phone

- **New (20 Nov 2026, G1b and G2):** once the APK is on the phone, play it and check: do the squads read as teams on
  the roads, are the barricade rows and the Hearthtree's tiles easy to use, and is the Wishing Well's pace right?
- Play the Gloomwood once both changes land: is the road long enough, are the fights and Mossback right, does the
  night read well on the S24's screen?
- Check the top bar under the S24's real status bar and camera hole.
- A balance pass by play: run length, boss times, materials per run, prices, raids, the Warden, the garden's pace.

### Decisions

- **New models for Phase F.** The Golden Grub, the Gloom Totem and Training Target / Bow Bench levels 3 to 5 use
  existing models for now. The owner makes them in Meshy (part 11, Rules).
- The money proposals in part 9.
- The optional Moth Lantern and Bramble Snare (raid extras), only with the owner's yes.

### Later

- Claude's own to-do: Blender models for home levels 7 and 8 and their campfires; sounds (raid horn, shards, the rout,
  a dash whoosh, the Warden, garden and fishing); attachments shown on the models; the bug review held to the end.
- Planned: more dungeons (some without a boss); more guardians, collected in dungeons, with guardian spots following
  the home level; bonds, fletching special arrows, decorating, daily and weekly tasks, an endless mode (Phase F);
  islands by boat; the money side.

---

## 11. For developers

Godot 4.7.2, Mobile renderer with the OpenGL fallback on, portrait (viewport 720x1280, stretch `canvas_items`,
aspect `expand`), capped at 60 fps (the cat's cloth simulation depends on the frame rate). GDScript only. The project
is `game/` inside `D:\Projects\Project LEAF`. **It is not a git repository**: the backups below are the safety net.

### Architecture

- **One scene, built in code.** `main.tscn` is one Node3D with `scripts/main.gd`. Its `_ready()` builds, in order:
  `world.gd` (light, sky, ground, trails, woods, lake, collision), `fight.gd`, `raids.gd`, the joystick on a
  CanvasLayer (`joystick.gd`), the cat (`player.gd`), `defences.gd`, `garden.gd`, `cooking.gd`, `fishing.gd`,
  `stations.gd` (every building, its ring and its card), `burrow.gd`, the HUD (`hud.gd`), the camera. Companions are
  added later by `main.refresh_companions()`: `pet.gd`, `mount.gd`, `npc.gd` (Bramble), `guardian.gd`.
- **Autoloads** (`project.godot`): `Data` (`data.gd`: `balance.json`, the derived numbers, costs and currencies,
  `Data.args()`), `Save` (`save.gd`), `Quality` (`quality.gd`). Static helpers by `class_name`: `Fx` (effects),
  `Props` (loads Blender props or builds placeholders), `Sfx` (sounds; a missing sound plays nothing).
- **Markers and cards.** Each usable thing has a marker (`marker.gd`, the leaf-shaped badge); `interact.gd` picks the
  marker under a tap and opens its card with `hud.show_card(...)`, walking the cat there first if it is out of reach.
  A card is a dictionary `{title, sub, rows, anchor}` built by `stations._card_*()`, `burrow.card()` or
  `raids.card_watch()`; a row is `{text, note, cost, label, enabled, action, pulse}`. The home's card builds its
  "Grow the home" rows from `Data.home_goals(level)` (see Phase F below).
- **fight.gd** runs missions (`mode = "mission"`) and Gloom Raids (`mode = "raid"`, started by `raids.gd` with
  `start_raid`). A Burrows run never uses fight.gd's waves and must leave `fight.mode` at "mission"; `start_raid`
  refuses while any fight is active.
- **enemy.gd** is every enemy. It loads `assets/enemies/<id>/<id>.glb` and its JSON, or a stand-in from the
  `model`, `scale` and `tint` keys of its `balance.json` entry. When the real model lands, delete those three keys.
- **The no-clock rule.** Nothing reads the wall clock or saves a time. Timers clamp their frame time
  (`minf(delta, 0.1)`) and stop while `main.frozen` (the app is paused). Earlier phases checked this with a grep
  for clock calls outside the autotests; keep it that way.

### The far-away area contract (dungeons)

A dungeon is built in the same scene, far from the camp: at `burrows.origin` (400, 0, 0), beyond the camera's far
plane (120 m) and the sun's shadow box, so the camp is not drawn while the cat is in it.

- While a run is on, `main.area` points to the runner (`burrow_run.gd`, `main.burrows.runner`); otherwise it is
  null. Camp systems check it: the raid meter does not fill and a pending raid's warning waits (`raids.can_fill`,
  `blocked_reason` "away"), the Leaf Dash is enabled (`main.dash_enabled`), the HUD shows Ride/Feed and Snack only.
- `area.owns(p)` (x past `burrows.own_x`, 200) tells world, fight and enemy code that a point is in the dungeon.
- The area answers: `constrain`, `outside`, `steer`, `cam_focus`, `cam_dist`, `hide_at`, `flee_point`, `foes`,
  `spawn`, `wake_pack`, `strike`, `on_enemy_died`, `cat_down`, `persist`, `status_text`, `fight_pips`, `satchel`,
  `boss_enraged`.
- `dungeon_map.gd` builds the map from `data/dungeons/<id>.json` the first time the cat goes in (about 0.5 s, behind
  the fade), then keeps it hidden and reuses it; a graphics change rebuilds it. `night_floor.gd` draws the floor from
  the map's `floor` block. `trap.gd` runs traps in their own frame along the road.
- New dungeon: a new `game/data/dungeons/<id>.json` plus an entry in `balance.json` `burrows.list` (its `map`,
  `entrance`, `tiers`). End it with `"end": {"type": "boss", ...}` or `{"type": "treasure"}`; `test_glade.json` is a
  tiny treasure-end map used by `--dungeontreasure`. Bump the map's `version` when a fight, checkpoint or chest id
  changes: a saved run on another version is closed kindly (satchel banked, key given back).

### The data files

| File | What is in it |
|---|---|
| `game/data/balance.json` | Every number. Blocks: `cat`, `stats`, `stations`, `home_names`, `bows`, `defences`, `enemies`, `patches` (the 4 trails), `missions` and `mission` (the rules and pay; Phase F keys below), `raid` (the **mission** camp-falls numbers), `gloom_raids`, `guardian`, `garden`, `ingredients`, `cooking`, `fishing`, `looks`, `building_hp`, `burrows`, `attachments`, and (New, G1b and G2) `squads`, `enemy_roles`, `market`, `camp_name`. Most blocks start with a `_note`. |
| `game/data/dungeons/<id>.json` | One dungeon map: spine, clearings, branches, arena, fights, checkpoints, chests, traps, lanterns, `floor`, woods, theme, `end`. Positions are `[x, z]`, `{"s": arc length, "off": metres right}` or `{"in": clearing}`. |
| `game/assets/<group>/<id>/<id>.glb` and `.json` | Characters (enemies, companions, NPCs): clips, events, speeds, spring chains |
| `game/assets/props/*.glb` and `<group>.json` | Blender props and their lists (`camp_life.json`, `raids.json`, `burrows.json` and others) |
| `art/palette.json` | The shared colours for props |

The Android export includes `*.json` and leaves out `_autotest/*`, `build/*` and `*.md`.

### Phase F: home goals and fair missions (New, 19 Nov 2026)

The design is `docs/PHASE_F_PLAN.md`. The numbers are all in `balance.json`.

- **Data keys.**
  - `stations.camp.levels[n]`: the price (`leaves`, `timber`, and amber, glowstone and heartwood for homes 6 to 8) and
    `goals`. Goal types: `mission {n}`, `station {id, level}`, `stat {id, level}`, `bow {id, level}`, `bow_any
    {level}`, `bow_owned {id}`, `towers {count, level}`, `defence {id, level}`, `all_stats {level}`, `depth {n}`.
    `needs_burrows` and `needs_depth` on homes 6 to 8 are kept for older code.
  - `stations.target` and `stations.bench`: 5 levels. `stat_cap_by_station_level` and `bow_cap_by_bench_level`:
    `[0, 4, 6, 8, 9, 10]`.
  - `missions[i].needs_home` (the home level to start it), `reward` (leaves, timber), optional `strength_mult`,
    `elite_by_chapter`, `boss_adds`, `pool_first` with `first_waves`.
  - `mission.roads` (pattern shares, `favoured_weight`, `rush_count`, `rush_speed`, `teach_mission`,
    `teach_roads_by_chapter`), `mission.burst` (`size`, `spacing`), `mission.min_wave_ratio` (0.85),
    `mission.boss_adds` (0.6), `mission.bonus` (`quick_*`, `intact_share`, `early_per_s`), `mission.golden_grub` and
    `mission.totem` (`from_mission` is a 0-based index, `chance`, timing).
  - `enemies`: `boar` (`miss_daze`, `daze_hurt`), `pitcher` and `frog` (`siege_range`), `golden_grub` (`ai`,
    `bonus: true`) and `gloom_totem` (`ai: "totem"`, `anchored`).
- **`data.gd`:** `home_goals(level)`, `home_goals_met(level)`, `home_price(level)`, `home_can_grow()`,
  `mission_needs_home(i)` and `mission_unlocked(i)`.
- **`fight.gd`:** `plan_wave(w)` (a wave's pattern, roads and groups), `plan_queue(w, p, prev_hp)` (the spawn queue,
  topped up to `min_wave_ratio` until G1; since G1 it swaps weak enemies for stronger ones, see Phase G1), `preview_text()` (the breather's "Next: ..." line). `fight.skip_gate` (tests only)
  lets a test start any mission. The groups **"bonus"** (the Golden Grub: it never holds a wave up) and **"totems"**
  (the Gloom Totem: a foe the wave waits for).
- **Old tests.** Tests that start a won mission (replays) or a mission past the home gate, after `_veteran`, fail or
  need `skip_gate`.

### Phase G1: the fixes (New, 20 Nov 2026, G1)

The design is `docs/PHASE_G_PLAN.md` (step G1). The numbers are all in `balance.json`.

- **Data keys.**
  - `mission.wave_limits` (groups with `max_alive`, `tanks_at_once`, `tank_share`; `tank_weight`; `boss_others_on_field`).
    The groups are missions 1 to 5, 6 to 10 and 11 to 15.
  - `mission.timber_per_wave` (timber for a held wave, times the pay scale), `mission.chest_timber` (chapters 1 to 4)
    and `mission.rebuild_leaves` (60: the rebuild price when the cat has under 10 timber).
  - `trade.buy` and `trade.sell` (the Market's timber trade: 5 timber for 50 leaves, or 30 leaves back).
  - `raid.fire_rebuild` (40 leaves: lighting the ashes after the camp falls).
- **`fight.gd`:** `rebuild_cost()`, `wave_limits()`, `tank_weight()`, `field_state()` and `wave_timber()`.
  `plan_queue` now swaps weak enemies for stronger ones instead of topping up.
- **`stations.gd`:** `_fire_cost()` (the ashes price) and `_trade(buying)` (the Market's buy and sell).
- **Tests:** `--smoke`, `--fightf` and `--homegoals` (run on the PC on 20 Nov 2026).

### Phase G1b and G2: squads and the Hearthtree (New, 20 Nov 2026)

The design is `docs/PHASE_G_PLAN.md` (steps G1b and G2). The numbers are in `balance.json`.

- **G1b, squads.**
  - Data: `missions[].chapters[].squads` (the squads of each chapter), `boss_escort` (the escort squads of missions 6,
    13 and 15), `squads` (the 12 squad definitions), `enemy_roles` (light, fighter, tank or support for each enemy)
    and `mission.squad_rules` (from mission 2 at least 2 kinds; from mission 3 about 40% per kind at most).
  - `fight.gd`: `plan_queue` now plans squads; the old pool code is `_pool_queue`; `_spawn_squad` spawns one squad on
    one road. Raids keep their old random waves.
  - `enemy.gd`: `_keep_formation` (the spacing and pace of a squad member) and `leave_squad` (the break-up rule: within
    6 m of the firelight, the leader dead, or the cat close).
  - Mission 1's first win gives 60 leaves, not barricade pieces.
- **G2, the Hearthtree.**
  - `camp_name` in `balance.json`, and `Data.camp_name(cap)` for the name. Level names are unchanged.
  - The Mushroom Cottage and the Market have `needs_home` 2. The `market` block holds its sells, buys and prices. Thistle
    comes free with the Market. Old saves keep their buildings and pets.
  - Barricades are rows on the 12 road spots (3 per road). The allowed rows follow the home level (2, 3, 5, 7, 9, 12).
    Each piece has its own health: cracked below 50%, broken at 0. Repair costs 30% of the row's cost per broken piece,
    half per cracked one. Old placed barricades became rows; bag pieces were refunded as leaves.
  - Tower repair: a repair marker on a knocked-down tower, 30% of its cost.
  - The Wishing Well is automatic (no wishes). Its heal percents and the rates in waves are in `balance.json`.
  - Shop cards: `ui_icons.gd` draws 32 icons in code. `hud.gd` has the row kinds `section` and `item` (items are tiles,
    two per row on a phone). A row is still `{text, note, cost, label, enabled, action, pulse}`, with `kind` for these two.
- **Tests:** `--rows` (`autotest_g2_def.gd`), `--campg` (`autotest_g2_camp.gd`), `--cards` (`autotest_g2_cards.gd`,
  screenshots; run at 480x1040 with `--safe-top=73 --safe-bottom=42`), and `--fightf`, updated for squads.
- **Results on the PC:** `--smoke` OK, `--fightf` 55 pass, `--homegoals` 45, `--rows` 46, `--campg` 45, `--enemyf` 22,
  `--cards` 55; no failures.
- **Backup** before G2: `D:\DevCache\backup\pre_phase_g2_20261120_1429`.

### Graphics levels (`quality.gd`)

| | Low | Medium | High |
|---|---|---|---|
| 3D drawn at | about 540 px across | about 810 px (FSR 1) | full |
| Sun shadows | off (a soft blob under each character) | 1024 px | 2048 px |
| Glow | off | off | on |
| Grass | 40% | 70% | 100% |
| Lantern and home lights | off (the campfire's stays) | on | on |
| Particles | 50% | 80% | 100% |
| Spring bones on enemies | off | on | on |
| Cloth fit worked out | every 3rd frame | every 2nd | every frame |

The first launch guesses the level from the phone (no Vulkan, little memory or few cores means Low; the S24 gets High).
While the level is the game's own pick, two slow 4 s windows in a row step it down with a toast; at Low it holds a
steady 30 fps. The player picks Auto, Low, Medium or High on the Shop card. The choice lives in
`user://settings.json`, apart from the save. Live monsters are capped by level (raids 18/24/28; dungeon packs in
`burrows.max_alive_by_quality`). `--quality=low|medium|high` sets the level for one run. Measurements:
`docs/PERFORMANCE.md`.

### Saving

| File (`user://`) | What |
|---|---|
| `leaf_save.json` | The real save |
| `leaf_save_test.json` | Any `--autotest` run (never touches the real save) |
| `leaf_save_endgame.json` | The debug endgame save |
| `endgame_slot.txt` | Marker: while it exists, a debug build keeps opening the endgame save |
| `settings.json` | The graphics level |
| `test_args.txt` | One-shot arguments for a debug build on the phone; deleted after reading |

On the phone `user://` is the app's `files/` folder (package `com.projectleaf.game`; reach it with
`adb shell run-as com.projectleaf.game`). The game saves after every purchase, every wave cleared, every chapter break
(`Save.mission_run`) and every mission end. Raids save quietly (`Save.save_game(true)`) every 10 meter points, at stir,
at full, at each wave held, and on pause, focus-out or close (`main._notification` calls `raids.persist()` and
`burrows.persist()`). A Burrows run saves at checkpoints, when hurt (throttled) and on pause. Old saves load field by
field with defaults (`d.get`); `save_v` is 2. A dish eaten mid-chapter goes back into the pot on load.

### The debug endgame start

Debug builds only. `--endgame` opens a **separate save** as if all 15 missions were won: home level 5, a grown cat
(Training Target and Bow Bench at 5; Well, Cottage, Stall and Garden at 3; Guardian Stone at 0), 8,000 leaves, 300 timber, 60 shards, 3 Hollow keys, food, the Gloomwood open (the Warden still to be found). The HUD
says "Endgame test save". It stays on at every launch until one launch with `--endgame-off`; then the real save is
back, untouched. `--endgame --fresh` starts it over (an older endgame save keeps its old levels until then). On the phone, put the argument on a line in `files/test_args.txt`.
Release builds ignore both.

### Test modes

Run from Git Bash with TEMP and TMP on D:. **Add `--disable-vsync` before `--`**: with the PC's screen off or asleep,
vsync holds Godot at about 4 fps and the timed tests fail.

```bash
export TEMP='D:\DevCache\tmp' TMP='D:\DevCache\tmp'
"/d/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --path "D:/Projects/Project LEAF/game" \
  --resolution 540x960 --disable-vsync -- --autotest --fresh --smoke "--shots=D:/DevCache/tmp/leaf_test"
```

The runner `D:\DevCache\tmp\final19\run.sh <folder> <args...>` does all that, stops on a parse error and counts the
`EXPECT PASS` / `EXPECT FAIL` lines. Sizes: 540x960, 480x1040 (the S24's shape), 540x1170 (this PC clamps it to
540x1061). Common flags: `--fresh`, `--shots=<dir>`, `--quality=`, `--safe-top=N --safe-bottom=N` (fake the phone's
bars, in HUD pixels), `--cat1` / `--cat2` (hero model).

| Area | Script | Modes |
|---|---|---|
| Missions and camp | `autotest.gd` | default (all 15 waves of mission 1), `--smoke`, `--resume=1` then `=2`, `--village`, `--siege`, `--laststand`, `--bars`, `--skins`, `--levels`, `--grow`, `--gallery`, `--patch=N`, `--grasswalk`, `--lake`, `--perf`, `--perfdiag` |
| Warden, garden, cooking, fishing | `autotest.gd` | `--guardian`, `--guardianab`, `--garden`, `--cook`, `--fishing`, `--feed`, `--camplife` |
| Gloom Raids | `autotest.gd` | `--raid` (with `--raid-small`, `--with-warden`), `--raidloss`, `--meter`, `--raidsave`, `--raidresume=1/2/3`, `--raidtypes`, `--wear`, `--shards`, `--raidintro`, `--raidshots`, `--raidperf`; flags `--raid-type=`, `--raid-warn=`, `--raid-meter=` |
| The Gloomwood | `autotest_e.gd` | `--dungeon`, `--dungeonshots`, `--dungeonfall`, `--dungeonresume=1` then `=2`, `--boss`, `--dungeonperf`, `--dungeontreasure`, `--dungeonlevels`, `--dungeonstand` (`=god`, `=items`), `--dungeoncareful`, `--floormaps=<dir>`; kept from Phase E: `--burrowsave`, `--hollow`, `--dash`, `--traps`, `--burrowfoes`, `--topup`, `--burrowhooks` |
| Layout and HUD | `autotest_layout.gd` | `--layout`, `--layoutsave=1` then `=2`, `--hudcheck`, `--taps`, `--arrows` |
| Phase F | `autotest_f_home.gd`, `autotest_f_fight.gd`, `autotest_f_enemy.gd` | `--homegoals` (the goals, the gate, the home's card), `--fightf` (patterns, the teaching roads, no easy waves, the gate, a live wave with the grub and the bonuses, the Gloom fade), `--enemyf` (the boar's daze, the pitcher and frog standoff, the Golden Grub, the totem's buff) |
| G1b and G2 (New, 20 Nov 2026) | `autotest_g2_def.gd`, `autotest_g2_camp.gd`, `autotest_g2_cards.gd` | `--rows` (barricade rows), `--campg` (the Hearthtree camp), `--cards` (shop cards; screenshots at 480x1040 with `--safe-top=73 --safe-bottom=42`); `--fightf` now checks squads |

Details of every mode: `game/README.md`. After adding a new script, run Godot once with `--headless --import` so it
gets its `.uid`.

**On the phone** (debug build): the launcher does not pass arguments, so write them one per line to
`files/test_args.txt` (push to `/data/local/tmp`, then `run-as ... cp`; the exact commands are in
`docs/PERFORMANCE.md`, "Running the benchmark").

### Building and installing the APK

From inside `game\` (the preset's output path is relative to the project), with TEMP and TMP set to
`D:\DevCache\tmp`:

```bash
cd "/d/Projects/Project LEAF/game"
"/d/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . \
  --export-debug "Android" build/ProjectLEAF.apk
```

The APK lands in `game\build\ProjectLEAF.apk` (debug, signed, arm64 only, preset "Android" in `export_presets.cfg`).
adb is not on PATH: it is `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`. The adb daemon often restarts after an
export, so run `adb wait-for-device` first, then `adb -s <serial> install -r game\build\ProjectLEAF.apk` (the S24's
serial is in `docs/STATUS.md`). Before installing over the owner's game, copy the phone's save to
`D:\DevCache\backup\phone_save_<date>.json` (for example `adb exec-out run-as com.projectleaf.game cat
files/leaf_save.json > ...`). If the phone is on the endgame save and the owner wants the real one, put
`--endgame-off` in `files/test_args.txt`.

### Backups

Copies before each big change are in `D:\DevCache\backup\pre_*` (the latest: `pre_phase_g2_20261120_1429`, `pre_phase_g1_20261120_1359`, `pre_phase_f_20261119_1209`, `pre_homefix_20261119_0023`,
`pre_markers_dungeon2_20261119_0052`, `pre_dungeon2_20261119_0053`); phone saves in `D:\DevCache\backup\phone_save_*`
and `game\build\phone_save_backup\`; per-step copies in `D:\DevCache\tmp\<work>\`. Back up what you touch first.

### Work in progress (19 to 20 Nov 2026)

- **Phase G1 is built and tested on the PC** (20 Nov 2026), not yet on the phone. See "Phase G1" above.
- **New (20 Nov 2026): G1b and G2 are built and tested on the PC.** The APK was built at 15:43 and waits for the phone.
  See "Phase G1b and G2" above.

- **Phase F is built and tested on the PC** (`--smoke` and the three Phase F modes), not yet on the phone. Every number
  is a first guess, to be tuned by play. The Golden Grub (the mole, small and gold), the Gloom Totem (existing Gloom
  props) and Target levels 3 to 5 / Bench levels 4 and 5 use existing models until the owner decides how new ones are
  made.
- The Gloomwood's road and difficulty are in the live project; only `--dungeon` has been run since, so the full
  regression is still to do.

### Rules

- **Work on D:, keep C: clear.** Builds, caches, downloads, renders and worktrees go on D:. Shared caches are in
  `D:\DevCache`. Set TEMP and TMP to `D:\DevCache\tmp` for Godot, Blender and any big command.
- **Never touch the owner's open Blender or port 9876.** Run Blender headless only: `D:\Blender\blender.exe -b`.
- **3D models: the owner makes every one in Meshy** (their rule, 19 Nov 2026, in `CLAUDE.md`). Claude never models.
  - Claude tells the owner what is needed and uses a stand-in until the file comes.
  - Concept images (Codex CLI, `tools/gen_concepts.ps1`) are made only when the owner asks.
  - Blender only finishes the owner's file (clean-up, colours, rig, animation, export), per `docs/ASSET_RULES.md` and
    `docs/AGENT_BRIEF_MESHY.md`.
- Keep the design rules: nothing moves while the game is closed; camp, not village; looks-only selling; nothing tall
  between the camera and where the cat can walk; nothing of the HUD in the middle third of the screen.
- The owner tests on the phone: build complete and playable, keep testing light, and back up first.

---

## 12. Where to read more

- `docs/STATUS.md`: where things stand, what is next, tools and paths. Read it first when work starts again.
- `GAME_PLAN.md`: the whole design. Section 0 (Draft 7) holds the direction and the owner's decisions; it wins over
  the older sections below it.
- `docs/PHASE_A_PROGRESS.md`: build notes for every phase, the choices made, and the test results.
- `docs/PHASE_C_SPEC.md`: the Moss Warden, the garden, cooking and fishing (as specified; the build notes win).
- `docs/PHASE_D_SPEC.md`: the Gloom Raids and keeping the camp up.
- `docs/PHASE_E_SPEC.md`: the Burrows. Only the decisions at the top still hold; its rooms are gone.
- `docs/DUNGEON_SPEC.md`: dungeons as paths; the Gloomwood.
- `docs/PERFORMANCE.md`: graphics levels and measurements on the PC and the S24.
- `docs/ASSET_RULES.md`: the rules every 3D model follows.
- `docs/AGENT_BRIEF_MESHY.md`: the brief for turning a Meshy mesh into a game model.
- `game/README.md`: how to run the game, every test mode, and what each script does.
- `docs/screens/`: older screenshots of the camp, the lake, the cards and the enemies.
