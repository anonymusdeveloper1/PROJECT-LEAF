# Project LEAF: the game guide

27 November 2026. This is the one place that describes the game as it is now. Parts 1 to 10 are for the owner, in
plain words. Part 11 is for whoever works on the code next. Part 12 lists the other documents.

The code (`game/scripts/`) and the numbers (`game/data/balance.json`) win when they disagree with this guide. If you
find a difference, fix the guide.

Three changes landed on 19 November 2026 and are marked **New (19 Nov 2026)**: tap to open (with the attack arrows),
the Gloomwood's night road, arena and harder fights, and **Phase F** (home goals, progression, roads and patterns, fairer
waves, reasons to move). The notes for the first two are at the end of `docs/PHASE_A_PROGRESS.md`; the plan for Phase F
is `docs/PHASE_F_PLAN.md`.

**New (20 Nov 2026, G1b and G2).** Raid waves now come as **squads** (small teams with roles), and the camp is
called **the Hearthtree**: its shop is a set of tiles, barricades are built in rows on the road spots, and the Wishing
Well works by itself. Those parts are marked **(G1b)** or **(G2)**. The plan is `docs/PHASE_G_PLAN.md`.

**New (26 and 27 Nov 2026, H4 and H5).** The building windows were rebuilt: one shared window style with a pinned
Upgrade, the build menu, and new windows for the Market, the Saddlery and the Tailor's Nook. **The Mushroom Cottage is
gone**; the pet is bought and trained at the Market. They are described in part 3 ("The building windows") and part 5,
and marked **(H4)** or **(H5)**. The plan is `docs/PHASE_H_PLAN.md`.

---

## 1. The game in one page

**What it is.** A low-poly 3D action game for Android phones, held upright and played with one thumb. You are the
Cat Ranger, a small cat with a bow and a hooded cape. She guards her campfire camp in a forest clearing. The enemy is
the Gloom: violet, crystal-crusted forest creatures that come down four trails out of the woods. The cat shoots by
itself. You move her, pick where to stand, and spend what you earn to grow the camp and the cat.

**The loop.**

1. **Raid Missions.** 15 structured missions, each 15 or 20 waves long. Every wave pays golden leaves. Between waves
   you shop, build and upgrade. The signpost lists missions from 15 down to 1 in spacious numbered cards, grouped
   into unfinished missions and completed ones marked Finished, with Replay. Cards animate on opening/tab changes.
   Replays pay repeat rewards while first-clear progress and gifts stay one-time. Each new unique win opens the next mission.
2. **The camp grows.** First wins bring new buildings, a mount (Thistle the hare), a pet (Sprig the leaf dragon), a
   garden with a cooking pot, and fishing. The tree home grows through 8 levels. **New (Phase F): the home has a goal
   list for each level.** It grows only when every goal is met and its price is paid. Its level caps upgrades;
   Raid Missions open sequentially without requiring a larger home.
   **New (20 Nov 2026, G2): the tree home is called the Hearthtree.** Its level names stay (Shed, Hut, Treehouse...).
   The Market (with Thistle and Bramblewool, free) comes at Hearthtree level 2. (New, H5: the Mushroom Cottage is gone;
   Sprig is bought at the Market's Pets tab.)
3. **After Raid Mission 15** the game goes on two ways, side by side:
   - **Gloom Raids**: short attacks on the camp. A meter fills while you play; when it is full, a raid comes.
   - **The Gloomwood**: a dungeon at night. The cat walks a road past fights to a boss and brings home rare
     amber, which Bramble buys. The first win frees the camp's guardian, the Moss Warden.

**The mood.** Bright and cute. Low-poly with visible facets and flat colours, like the Cat Ranger herself. The camp is
wild and lush: a hollow mossy tree home, round roofs and doors, warm lights, flowers, a market stall with a striped
awning, a lake beside it. The Gloom is violet crystal. The Gloomwood is a night road: dark, but always easy to see.

**What it is not.**

- **Not Clash of Clans.** One cat guards one campfire camp. No villagers, no workers, no build timers, nothing that
  makes resources by itself. It is a camp, never a village.
- **Only timers keep running while the game is closed** (the owner's rule change, 25 Nov 2026; built in H3, 26 Nov
  2026). Crops grow and the cooking pot cooks by the phone's clock, also while the game is closed (part 6). Nothing
  else moves: no raid attacks, no fight goes on, and the Gloom meter, the Well and the mount's rest all wait. A running
  potion pauses while the game is in the background and ends if the game is closed (it lasts 5 to 30 s). Nothing else
  is lost.
- **Not open world.** The camp is home and the enemies come to it. Going out happens in small separate places: the
  Gloomwood now, islands by boat later.
- **No menus.** You go to a thing and its card opens (part 2).
- **Never pay-to-win.** Money will only buy looks, and expedition-only helpers that can also be earned by playing
  (part 9). None of the money side is built yet.

The owner plays on a Samsung Galaxy S24. The APK with the full update was installed at
01:52 on 23 Nov 2026. The changes were committed on `feature/g3-g4-bows-saddlery-outfits` and merged into
`development` that day (see `docs/CHANGES.md`).

---

## 2. How to play

### Controls

| What | How |
|---|---|
| Move | Press anywhere on the screen and drag. A joystick appears under your thumb and goes away when you lift it. |
| Shoot | Automatic. The cat turns to the nearest enemy in range (5.5 m at the start) and keeps shooting, also while walking. |
| Hide | Stand in tall grass or a bush, outside the camp. Enemies can't see the cat. After 1.5 s hidden, the next shot is an **Ambush**: double damage. Not while riding. |
| Ride | Tap **Ride** once Thistle has come. The cat is faster and the mount takes the hits. Drag to turn the mount and run in that direction. The cat shoots across a 280-degree arc, leaving an 80-degree gap directly behind. Its skills come from the Saddlery. Tap **Walk** to get off. |
| Potions | **New (H3, 26 Nov 2026):** when the cat is hurt and the Bag holds a Health Potion, its button shows at the bottom right: tap it to heal. When the mount is knocked out and the Bag holds a Mount Health Potion, that button takes Ride's place. The other potions and fish are used from the Bag. Feed is gone. |
| Leaf Dash | **Gloomwood only.** Flick your thumb quickly as you lift it. The cat dashes 3 m and nothing can hurt it during the dash. Dash through an attack at the last moment (a **close call**) and the next arrow hits double. It recharges in 1.4 s; an arc under the health bar shows it. |
| Build | Buy an acorn tower or thorn spikes in the shop. **New (H3): it goes into the Bag.** Tap its button above the Bag (such as "Tower ×2"), or open the Bag, tap it and tap **Place**. Walk the see-through piece to where you want it, tap **Place**, then **Done**. The piece drops in with a small bounce and a puff of dust. **New (G2): barricades are not built this way.** Tap a road marker instead (see the next block). |
| Barricade row | After raid 1, tap an open road pad to build a **row of 3 pieces** for 90 leaves and 5 timber between waves. Pads open as the Hearthtree grows. Tap a built row to repair it at any time, including during a wave. See Defences. |
| Use a building | Tap it (see below). Its card opens. Tap a green button to buy. |
| Grow the home | Open the Hearthtree's card (the Shop). **New (Phase F):** the top section, "Grow the home", lists the goals. Tap **Go** on a goal and the card closes and the cat walks to the building that sells it, or tap **Show** to scroll the card to that row. |

On a PC: WASD or the arrow keys move, the mouse works as a finger, and Space dashes.

Most camp cards work between waves. During a wave, the signpost and built barricade rows can still be tapped.

**New (H3, 26 Nov 2026) · the Bag.** Tap **Bag** at the bottom-left. At the top are the health bars and the three
currencies. Below them the cat (seated on her mount while riding) stands beside the selected item's details, and under
that is a grid of **24 square slots**. Only things you have take a slot. Tap a slot to see its name, how many you have,
what it is for, and its one button: **Use** for potions and fish, **Place** for towers and spikes. Gameplay continues
while the Bag is open. The X, a tap outside, Escape or Android Back closes it. How things stack and what happens when
the Bag is full: part 6. Picking, cooking, fishing and trading say what you got or spent and your new total.

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
> that side. Their size and strength are two numbers in `game/ui/hud/threat_arrows.gd`.

> **New (20 Nov 2026, G2): shop-style cards.** A card still opens as the centred dialog with an X. Inside, the things
> to buy are **tiles in a grid** (two per row on a phone). Each tile has an icon, a name, a short line, stat bars, a
> price and one button. Tiles are grouped under small headings. The Hearthtree's card shows its goal list first, then
> the sections **Grow**, **The cat**, **Buildings**, **Defences** and **Settings**. The Wishing Well has no wishes now (G2).

### The screen

**New (H2, 26 Nov 2026):** the screen was redrawn from the owner's sketch. Buttons slide and fade in and out over
0.2 seconds instead of popping, and a button that is sliding out stops taking touches at once.

- **Top-left**: the three currencies only, small, with no dark strip: golden leaves, timber and Gloom shards. All three
  always show. Below ground the satchel follows them (amber and what you carry). **New (H3):** while a Damage or Speed
  Potion works, a small line under them shows it and the seconds left, for example "Damage +25% · 24 s" (both when
  both run). It hides when none runs.
- **Top-right**: the **Settings gear** (round), always shown. See "Settings" below.
- **Top-centre**: the **raid bar**. It has no words and no numbers, and it never counts enemies left. It shows progress:
  - in a Raid Mission, the share of this wave beaten; between waves the track is empty;
  - in a Random Raid, first the Gloom meter (violet), then the warning countdown (gold to red), and during the attack
    the share of the whole attack beaten;
  - in the Gloomwood, the fight pips (one per fight and one for the boss) in the same place.
- **Under the raid bar, only during fights**: a thin **campfire bar** (gold to red) that flashes when the fire is hit.
  In the Last Stand it pulses red.
- **The words line** under them says what is next or what is on: the next wave's roads ("Next: every road", "Next:
  Fernwood and Mossback's Den", "Next: a rush from Fernwood!"), "<mission> · wave 6 of 20", the raid's name, the Gloom
  words, the Gloomwood's name and level, and in the Last Stand "Last stand: rebuild the fire".
- **Just under that group**: the boss's health bar, then **banners** (short headlines, about 2 s; a win or a loss is
  bigger and stays about 3.5 s), then **toasts** (one-line news) and the status line ("Rebuilding the campfire...",
  "Hidden in the grass"). They never reach the middle third. A toast that does not fit waits until the banner fades.
- **Over the cat**: a red health bar. A hit drains it, and the part just lost shows grey for a moment. While riding,
  a thinner amber bar shows the mount's health. The Moss Warden has its own moss-green bar. The **Bag** shows the same
  health as bars (no "Health n/n" text), with the currencies packed under them.
- **Bottom, first row**: the **Bag** (left), the **build icon** (a house) next to it, and at the right the **Health
  Potion** button (New, H3): it shows only when the cat is hurt and the Bag holds one, with the potion's picture and
  "×N". It turns grey while it cannot work now (for example while a potion is still healing). The build icon opens
  the build menu from anywhere in the camp. It is hidden below ground, and in a wave it
  gives the usual "A wave is on!". **New (H4):** it opens the build menu (part 3). A small dot on it shows when a
  building can be built and paid for.
- **Bottom, second row**: the defences to place (smaller buttons) just above the Bag, and **Ride** or **Walk** at the
  right. **New (H3):** while the mount is knocked out, the **Mount Health Potion** button takes Ride's place (only when
  the Bag holds one).
- **While placing a defence**: **Place** and **Done** sit centred at the bottom. The Bag group and both potion buttons
  slide out.
- **Start wave** is on the signpost's card only. There is no Start wave button on the screen.
- Above the buttons: the **tip** (each tip shows once, often with a gold arrow pointing where to go) and the "Drag
  anywhere to move" hint.
- **The middle third** stays clear for the cat. Nothing of the HUD goes there except the health bars over the cat and
  the arrows. The layout test checks this.

### Settings

The gear at the top-right opens the Settings window:
- **Graphics:** Auto, Low, Medium or High.
- **Sound:** on or off.

The choices are saved in their own small file (`user://settings.json`), not in the game save, so a new game keeps them.
Autotests never write it. The texts come from `game/content/settings/graphics/entry.json` and
`game/content/settings/sound/entry.json`.

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
- **East**: the **Training Target** close to the fire, then the **Bow Shop** (New, 21 Nov 2026, G3: it was the Bow Bench). Further east, past the firelight, the
  **Guardian Stone**.
- **South-east**: the **Market** (Bramble the hedgehog trader stands by it). **New (G2):**
  the Market is called the Market, not the Market Stall, and it comes at Hearthtree level 2. **New (21 Nov 2026, G4):**
  the **Saddlery** stands south-east past the Market, on its own path.
  The **Tailor's Nook** stands farther east. **New (H5):** the Mushroom Cottage is gone; its old spot is open ground,
  and a tower or spikes placed there stay where they are.
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
The home's counter is the **shop**. It sells: the Training Target and the Bow Shop (New, 21 Nov 2026, G3: it was the Bow Bench); the cat's own Health, Move speed
and Leaf magnet; acorn towers and thorn spikes, and their levels; "Mend the defences"; growing the home (see the goals
above); and the **Graphics** setting (Auto, Low, Medium, High). After the raids, "Mend all" sits at the top when
anything is damaged.

**New (H4, 26 Nov 2026): the shop is a window with tabs.** It has **Hearthtree**, **Cat** and **Defences** tabs along
the top. A tab shows once it has something, and there is no tab bar while only one tab shows. The window always opens
on the Hearthtree tab, and a tab gets a small "!" when something on it can be bought. Mend all, Patch it up and
"Nothing for sale yet" stay at the top of the Hearthtree tab, and Graphics at the bottom. The Cat tab lists Health,
Move speed and Leaf magnet, each with its level, what the next level gives, and its own button. The Defences tab holds
the old defences shelf until a later step (H6) gives it its own place. See "The building windows" below.

> **New (20 Nov 2026, G2): what changed at the shop.**
> - **Barricades** are no longer sold here. Build them as rows on the road markers (part 2). The barricade's level
>   (log, stone, and so on up to heartwood) is still upgraded on the Hearthtree's card.
> - **The Wishing Well** is no longer a shop item to wish at. Once built, it works by itself (see Buildings).
> - The card's sections are Grow, The cat, Buildings, Defences and Settings.

### Home levels

The home level caps each station and defence. Most stations stop at level 3. The Training Target, Bow Shop and
Saddlery go to 5. From home level 4 on, the home itself grows.

> **New (19 Nov 2026, Phase F): home goals.** Each home level from 2 to 8 has a **goal list**. The home grows only
> when **every goal is met and the price is paid**. Once raid 1 is won, the home's card has a **"Grow the home"**
> section at the top: one line per goal with a tick or its progress ("Damage 3/4"), and a **Go** button (the card
> closes and the cat walks to the building that sells it) or **Show** (scrolls the card to that row). At the bottom:
> "Grow your home to level N". The home's badge shows "!" when it can grow. A toast says when every goal is met.

| Level | Name | Price | Firelight reach | Campfire health | Tower spots |
|---|---|---|---|---|---|
| 1 | Shed | | 4.0 m | 120 | 2 |
| 2 | Hut | 500 leaves, 20 timber | 5.0 m | 300 | 3 |
| 3 | Treehouse | 3,500 leaves, 40 timber | 6.0 m | 600 | 4 |
| 4 | Big Treehouse | 9,000 leaves, 60 timber | 6.5 m | 900 | 5 |
| 5 | Great Tree Home | 10,500 leaves, 80 timber | 7.0 m | 1,300 | 6 |
| 6 | Tree Hall | 17,160 leaves, 110 timber | 7.5 m | 1,800 | 7 |
| 7 | Old Oak Hall | 33,480 leaves, 150 timber | 7.6 m | 2,400 | 8 |
| 8 | Heart Oak | 54,400 leaves, 200 timber | 7.7 m | 3,000 | 9 |

**New (22 Nov 2026): new prices for homes 3, 5, 6, 7 and 8** (leaves and timber; they were 3,500/60, 8,000/60, 15,000/200, 25,000/90 and 40,000/135). Homes 2 and 4 are unchanged. Each level costs more than the one before.

**New (H1, 25 Nov 2026): no expedition materials in any price.** Homes 6, 7 and 8 now cost 17,160 leaves + 110 timber, 33,480 + 150 and 54,400 + 200: the old leaves plus amber x 60, glowstone x 120 and heartwood x 400 (what Bramble used to ask for them). Every other price that asked for materials works the same way (part 8).

The goals (all of them must be met). The raid that ends each step is the first goal:

| Home | Goals | Raids usually played at this level (not required since 21 Nov 2026) |
|---|---|---|
| 2 | Raid 1 won (First Embers). Training Target and Bow Shop built. Damage 4, Draw speed 2, Health 3. Twig Bow level 4. | Raids 3 to 6 |
| 3 | Raid 5 won (Bandit Night). Target and Bow Shop at 2; the Market built and the pet at level 2 (New, H5, the owner's answer: this was "Cottage and Market at 2"). (New, H1, 25 Nov 2026: this list no longer asks for the Wishing Well, which opens at Hearthtree 3; Hearthtree 4 still asks for Well level 2.) Damage 6, Draw speed 5, Range 3, Health 5, Move speed 3. Sunwood Longbow level 4. 3 towers; Barricades level 2. | Raids 7 to 10 |
| 4 | Raid 9 won (Croaking Choir). Target and Bow Shop at 3; the pet at level 3 (New, H5: this was "Cottage and Market at 3"; the Market has no levels any more); Well 2; Garden 2. Damage 8, Draw speed 7, Range 5, Health 7, Move speed 5. A bow at level 7. 4 towers, 2 of them at level 3; Barricades level 3; Thorn Spikes level 2. | Raids 11 to 13 |
| 5 | Raid 12 won (Two Fronts). Target and Bow Shop at 4; Well 3; Garden 3. Damage 9, Draw speed 9, Range 7, Health 9, Move speed 7. A bow at level 9. (New, 22 Nov 2026: Thorn Volley is hidden, so it is no longer a goal here.) 5 towers at level 3; Thorn Spikes level 3. | Raids 14 and 15 |
| 6 | All 15 raids won. The Gloomwood cleared once. Target and Bow Shop at 5. Every stat at 10. A bow at level 10. Own the Frost Bow (New, 22 Nov 2026: moved here from Hearthtree 5; Frost needs Bow Shop 5). | The raids and the expeditions go on |
| 7 | Gloomwood level 2 beaten | |
| 8 | Gloomwood level 3 beaten | |

**New (22 Nov 2026, loop fixes): each Hearthtree level asks for one raid earlier.** Home 2 needs raid 1 won (was 2),
home 3 raid 5 (was 6), home 4 raid 9 (was 10), home 5 raid 12 (was 13). Home 6 still needs raid 15, and
homes 7 and 8 are unchanged. So a player stuck on an act's last raid (a boss) can grow the Hearthtree first, if they can pay.

**No raid gates (the owner, 21 Nov 2026).** Raids never wait for a Hearthtree upgrade: the next raid opens as
soon as the one before it is won, whatever the Hearthtree's level. Before this change, the owner reached raid
11 without enough leaves for Hearthtree 4 and could not play the next raid to earn more. Growing the Hearthtree
still needs its goals and its price, and still opens the Market and more barricade rows.

Levels 4 to 6 each have their own campfire: a stone hearth, a great bonfire, a crystal brazier. Levels 7 and 8 show
level 6's home and campfire until their own models are made.

**Rows and the Market.** The Market (with Thistle and Bramblewool) can be built at Hearthtree level 2. (New, H5: the
pet's level goals ask for the Market. **Show** on one opens the build menu at the Market until it is built, and **Go**
opens the Market on its Pets tab.)
Barricade pads open at Hearthtree levels 1, 3, 4 and 5. See Defences for each road's layout.

### The buildings

| Building | What it does | How you get it |
|---|---|---|
| Signpost | **Raid Missions:** 15 down to 1 in spacious animated cards; To finish / Completed, Start / Replay, and saved-run resume. **Random Raids:** unlocks after all 15 Raid Missions, retaining Watch controls (part 7). | From the start |
| Training Target | Damage, Draw speed and Range for the cat (Range from level 2). 5 levels. | Shop, after raid 1's first wave |
| Bow Shop | **New (21 Nov 2026, G3): the Bow Bench is now the Bow Shop** (same place, same model). One card with a tile per bow, one button each: **Upgrade** for the equipped bow, **Equip** for an owned bow (between waves only; during a wave it says "Between waves"), **Buy** for a bow not owned yet (or "Needs Bow Shop level N"). Buying equips the bow if no wave is on. Each bow keeps its own level. Bow levels; 5 levels. See part 11 for the bows' data. **New (22 Nov 2026):** the shop has four bows, in the table below the buildings. | Shop, after raid 1 is won |
| Market | Bramble the hedgehog trader. **New (H5): the Market is one window with four icon tabs at the bottom: Sells, Buys, Mounts and Pets** (see "The building windows" below). It has no levels and no Upgrade. **Sells:** 5 timber for 50 leaves, 2 Sunberries for 30, 2 Fernmint for 30, 1 honey for 40, 1 fish for 25. Food goes into the Bag; with no room the picture says "Bag full" and nothing is paid (New, H3). He does not sell Emberpeppers or Swiftroots. Bramble sells no materials (New, H1, 25 Nov 2026). **Buys:** timber (5 for 30 leaves), a Golden Carp for 300 leaves at any time (New, H3, 26 Nov 2026), and after the missions amber: 1 amber for 1,000 leaves and 1 Gloom shard. **New (H5, the owner's rule): Bramble no longer buys Gloom shards** (5 for 100 leaves is gone). **Mounts and Pets:** Thistle and Bramblewool (free with the Market), Sprig (160 leaves) and Lumi (400 leaves), the pet's training, colours and the Gloomwood gear. A new Market has 200 health; one an old save already upgraded keeps its 340 or 500. (**New, G2:** the Market Stall is now called the Market.) | Hearthtree level 2 (New, G2). Thistle and Bramblewool come free with it. |
| Tailor's Nook | **New (23 Nov 2026).** Outfits for the cat (part 9). **New (H5):** its window shows the cat turning on a stand, with the outfits as cards below. It has one level. If its own model file is missing, a purple Market Stall stands in for it. | Build from the Hearthtree's card at Hearthtree level 3 for 1,500 leaves and 40 timber. |
| Saddlery | **New (21 Nov 2026, G4).** The mount's **Skills** (Stomp, Ram, Pounce, Bellow) and **Attachments** (Fire-spitter, Mossweave Saddle, Saddlebags), each bought (level 1) and upgraded to level 5, capped by the Saddlery's level. Skill and attachment levels 4 and 5 open after the Raid Missions (New, H1, 25 Nov 2026: they cost leaves and timber only, no materials). Earned only, never paid with money. Its spot is south-east past the Market. Stand-in model: the Bow Bench, tinted brown. It can be attacked and ruined like other buildings. | Built from the Hearthtree's card once 8 raids are won and the Hearthtree is at level 2 (New, 22 Nov 2026, loop fixes: at Hearthtree 1 its tile says "Needs the Hearthtree at level 2"; before that a Locked tile says "Win 8 raids first"). Build 900 leaves and 30 timber. Levels 2 to 5 cost 1,500/50, 3,000/80, 5,000/120 and 8,000/160 (leaves/timber), never above the Hearthtree's level. |
| Wishing Well | **New (20 Nov 2026, G2): automatic, no wishes.** Once built, it mends the campfire, the buildings, the barricade pieces and the towers that are not broken: **New (22 Nov 2026): it mends everything that isn't broken back to full, by itself**: the campfire, the Hearthtree and buildings, barricade pieces and towers. Between waves 3%, 6% or 10% of max health a second (Well level 1, 2 or 3); in waves 0.5%, 1% or 2% a second. Broken things (0 health), ruins and the ashes still need the player's repair. Card text: "Mends everything that isn't broken back to full · 6% a second between waves, 1% in waves · broken things need a repair". Its card shows this and its upgrade. **New (H1, 25 Nov 2026):** it is built at **Hearthtree 3** (it used to need 4 raids won; a save that already has it keeps it). Its card has only its Upgrade row, and the card's subtitle shows its rates. In waves it mends **1%, 1.5% or 2.5%** of max health a second (it was 0.5, 1 and 2); between waves 3%, 6% and 10% as before. It also mends the standing Moss Warden; a downed golem gets up by its own rules. A worn Well is still repaired from the signpost's Mend list. | Shop, at Hearthtree 3 |
| Garden and cooking pot | Grow food in real time and cook potions (part 6; New, H3). Garden levels 2 and 3 cost 400 and 1,000 leaves. | Gift for winning raid 1, with 4 Sunberries |
| Fishing Spot | Fishing at the lake (part 6) | Gift for winning raid 6 |
| Guardian Stone | The Moss Warden's home: its post, colours and upgrades (part 5) | Appears when the Warden is freed |
| The Old Hollow | The way into the Gloomwood (part 8) | Sealed with Gloom crystals from the first raid won; opens with raid 15's first win |

Most buildings have levels 1 to 3 (bought on their own card, never above the home level). **New (Phase F):** the
Training Target and the Bow Shop have **5 levels** (the Market has none since H5; the pet's own level goes up at the Market, part 5, and the mount's by the Saddlery). The station level caps what it sells: Target (or Bow Shop) level
1 to 5 lets each stat (or bow) reach level 4, 6, 8, 9 or 10. Health, Move speed and Leaf magnet use the home level
instead. Target levels 3 to 5 show the second Target model, and Bow Shop levels 4 and 5 the third Bow Shop model, until the
owner decides how new models are made. Range now grows 0.2 m per level (it was 0.3).

### The building windows (New, H4 26 Nov and H5 27 Nov 2026)

Every building opens a window in the same style: the centred dialog with an X, the building's name, and its content.
**Buildings with levels end in an Upgrade button that never scrolls away** (the Hearthtree, the Training Target, the Bow
Shop, the Well, the Guardian Stone once it is awake, the garden and the Saddlery). **Upgrade always opens a confirm
window** (the owner's answer, H4): it lists what the next level gives, with the price in red and Confirm grey when you
can't pay. Cancel and Confirm go back to the building's window. Buy, Equip and Build stay one tap. A ruined building
shows only its repair card.

- **The Bow Shop (H4).** One row per bow. The bow in the paw shows Upgrade with its price, then a grey **Equipped** when
  it can't level now; another owned bow shows Equip (between waves); a bow not owned shows Buy, or Locked with what it
  needs. **Tap a bow's picture** to inspect it: the bow turns in 3D with its arrow, with its numbers and "Each arrow
  hits for N", the real damage with the cat's Damage upgrades and any running potion.
- **The build menu (H4).** The build icon next to the Bag opens a grid of building pictures that fade in one after
  another. Each open one has its own **Build** button. A locked one is greyed with what it needs. Tap a picture for its
  detail view (its picture, what it does, its price). A building you have built leaves the menu. Nothing can be built
  while the Hearthtree is in ruins. When you build, the camera glides to the new building for about 2 seconds while it
  rises out of the ground with dust and the flower ring. Touching the joystick, a wave, or going below ground ends the
  shot at once. The tips say "tap the build icon next to the Bag".
- **The Market (H5).** It opens on **Sells**. The four tabs at the bottom are pictures only: Sells, Buys, Mounts, Pets
  (each tab still has its name for screen readers). It has no footer and no Upgrade.
  - **Sells and Buys:** a grid of big pictures with one bundle's price under each. On Buys the number under the picture
    is what Bramble **pays you**, in a neutral colour, never red. **Tap a picture** and a small popup opens with the
    name, what it is, an amount (+ and -), "You pay" or "You get", and one Buy or Sell button. Amber shows only after
    all the Raid Missions are won. A picture is grey when one bundle can't be traded, for a reason other than money
    (the Bag is full, or Bramble has none left).
  - **Mounts:** Ride or Walk, then the whole of Thistle and Bramblewool. A mount shows Equipped, or Use if it is owned.
    Tap a picture for a bigger view with its description. Below the grid: the colours (**Next** cycles them), the
    Gloomlit colour (60 Gloom shards per look), and Thunder Shoes once the Gloomwood is open. Both mounts ride, fight
    and wear gear the same.
  - **Pets:** a training row (the pet's level, its next damage and time between sparks, and the price), then Sprig
    and Lumi. **Sprig costs 160 leaves** and joins the cat. **Lumi costs 400 leaves** and is a look only: she fights
    exactly like Sprig, at the same level (the owner's answer, H5). Lumi's picture says "Buy Sprig first" until the pet
    is owned. Switching between them keeps the level. The colours, the Gloomlit colour and the Gloomwood gear show once
    the pet is owned.
  - A "!" dot on a tab, and on the Market's marker, shows when something there can be bought.
- **The Saddlery (H5).** Two icon tabs at the bottom, **Attachments** then **Skills**; a fresh visit opens on
  Attachments.
  - **Attachments:** Patch it up (when raids wore it), then the three attachments as big pictures. Tap one to see it
    turning in 3D, fitted to the mount that is out, with what it does, its level and the next level, its price, and
    one button: Buy, Wear, Upgrade, or a grey Worn. One attachment is worn at a time, as before.
  - **Skills:** three circles joined in a triangle sit at the top, over a grid of round skill icons, at least three
    across. **Tap a skill** for its detail and Learn or Upgrade. **Drag a learned skill into a circle** to use it; tap
    a filled circle to empty it. **The mount uses only the skills in the circles** (the owner's answer, H5: up to 3,
    never 4), and the circles are shared by every mount. A fourth learned skill stays in the grid.
  - **The Saddlery's Upgrade** is pinned on the Skills tab only. Its confirm lists the next level's skill cap and the
    **mount's speed and health**, because the mount's level now comes from the Saddlery (part 5). A player short of
    leaves can still open it and see the price in red.
- **The Tailor's Nook (H5).** The cat stands large on a low stand and turns slowly, with the outfit cards below. An
  outfit you don't own is grey and can still be tried on. **Tap a card to dress the preview** (it changes only the
  picture, never what the cat wears). One button shows Buy, Wear or Wearing, under the same rules as before (part 9).
  Back closes the Nook.

### The bows (New, 22 Nov 2026)

The Bow Shop sells four bows. Each costs more and hits harder than the one before, and each has a pro and a con. A bow
unlocks when the Bow Shop reaches its level (the Hearthtree caps that level). At Bow Shop level 5 every bow can be
bought. Bow Shop 4 raises the bow level cap but unlocks no new bow. Thorn Volley and Foxfire stay hidden.

| Bow | Unlocks | Cost | Damage | Draw | Pro | Con |
|---|---|---|---|---|---|---|
| Twig Bow | From the start | Free | 1.0x | Normal | Original bow, normal range | No special |
| Sunwood Longbow | Bow Shop 2 | 400 leaves, 15 timber | 1.15x | Takes 10% longer | Goes through 1 enemy and reaches 1.5 m farther | Slower draw |
| Ember Bow | Bow Shop 3 | 900 leaves, 30 timber | 1.3x | Normal | Sets enemies burning | 0.8 m shorter range |
| Frost Bow | Bow Shop 5 | 1,600 leaves, 50 timber | 1.45x | Takes 25% longer | Slows enemies and freezes on the third hit | Slowest draw |

The Training Target still trains the cat's general Damage, Draw speed and Range; the cat handles every bow better.
Better bows are how damage grows later. Each bow's own level-ups are still bought at the Bow Shop; Frost's level-ups
cost about 1.3x Ember's. Each bow has its own arrow, release burst, trail and hit effect.

**Late upgrades (23 Nov 2026):** bow levels 6–10 each add 20% of base damage instead of 10%, and cost about 25% fewer
leaves. Levels 2–5 and mastery increments keep 10%. Already-owned levels gain the extra damage automatically.
Ember 5→9 costs 1,480 leaves; the Bow Shop displays the next upgrade's actual damage gain. Raid rewards stay the same.

**Buildings can be broken.** In a wave, enemies attack buildings. A building at 0 health is a **ruin**: it does
nothing until it is repaired (a ruined home closes the shop, a ruined stall means no riding, and so on). Winning a
raid mends every ruin for free.

> **New (20 Nov 2026, G2): tower repair.** A knocked-down acorn tower shows a repair marker. Tap it to repair the tower.
> **New (22 Nov 2026, loop fixes): the tower's repair costs the same as "Mend the defences" for that tower**, leaves
> only (for example 27 leaves in the raids, 41 after the raids, at tower level 2). It was 30% of the tower and its
> upgrades, plus timber.
>
> **New (22 Nov 2026, loop fixes): the Hearthtree's repair is capped.** A knocked-down Hearthtree costs 10% of what it
> cost, at least the `ruin_min` minimum, at most 900 leaves and 30 timber, in the raids too (for example Hearthtree 4:
> 900 leaves and 14 timber; it was 3,930 leaves and 42 timber). Other buildings keep the 30% price for a ruin. After the
> raids, raids also leave **wear** (part 7).

---

## 4. Raids

### Starting one

Go to the signpost. Its card ("To the woods") shows the next raid: its waves and its enemies. Tap **Fight**.

> **Updated 23 Nov 2026:** the signpost separates **Raid Missions** from **Random Raids**. All 15 Raid Missions
> remain listed, including completed ones with Replay. New unfinished missions unlock sequentially; existing saved
> runs must be resumed or explicitly given up before another starts. Random Raids unlock after all 15 unique
> completions. Raid Missions remain replayable afterward. Replay completion rewards use the existing 50% setting;
> normal wave/chest pay remains, and first-clear gifts and unique progression never duplicate.

### Waves and supply chests

- Raids 1 to 5 have **15 waves**, raids 6 to 15 have **20**. Waves come in **chapters of 5** (Scouts, Main
  assault, Onslaught, Finale).
- Each wave is a little stronger than the last (5% a wave, on top of 8% a raid) and has more enemies in total.
  **New (20 Nov 2026, G1): many enemies in a wave, few on the field.** A whole wave has 10 to 25 enemies in raids 1 to 5, 16 to 32 in raids 6 to 10, and 20 to 38 in raids 11 to 15 (first wave to last). At most 10, 12 or 14 are on the field at once (by raid group; it was 28). Tanks (Stump Golem, Toadstool Brute, Beetle Knight, Crystal Snail; a Bramble Boar counts as half) are at most 1, 2 or 3 at once. In a whole wave, tanks are at most 10% (raids 1 to 5) or 15% (raids 6 to 15). With a boss alive, at most 8 others are on the field.
  **No easy waves (Phase F, changed in G1).** An ordinary wave whose total health is under 85% of the wave before it swaps its weak enemies for stronger ones. It never adds enemies. (Not the first wave after a chapter break, not the boss wave.) Enemies also come in **bursts** of 2 to 4,
  0.4 s apart, not one by one, and spawn speed carries over between chapters. Raids 6, 13 and 15 have real last
  chapters and fewer helpers with the boss.
- Every chapter's last wave is an **elite wave** (the raid's tough enemy, more each chapter). The raid's last
  wave brings its **boss** or a big finale pack.
- Between every wave: **unlimited time**. The camp is safe, the cat heals, and the cards work. Tap **Start wave**
  at the signpost when ready. There is no automatic start and no early-start payment. The top bar previews its roads.
- **Every cleared wave saves.** Closing the game resumes the next uncleared wave; a camp fall retries only the
  failed wave. Numbers continue from 1 through 15 or 20, including 5→6, 10→11 and 15→16.
- Every five waves, a **supply chest** pays out and the campfire refills. The chapter structure still controls enemy
  pools and these rewards. Older chapter-only saves keep their original checkpoint. **Give up** is an
  explicit choice to restart that raid while keeping what was earned.
- A wave can never hang: if its last 3 enemies do nothing for 45 s, they flee.
  **New (H1, 25 Nov 2026):** this is for Raid Missions only, and it has not changed. Random Raids work differently (part 7).

### Squads (New, 20 Nov 2026, G1b)

Raid waves are made of **squads**: small teams, each with roles.

- **Light:** Thornling, Moth, Raccoon, Puffball, Mole.
- **Fighter:** Boar.
- **Tank:** Brute, Stump Golem, Beetle Knight, Crystal Snail.
- **Support:** Pitcher, Frog Shaman, Crow Drummer.

The 12 squads:

| Squad | Who | From raid |
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

- From raid 2, a wave has at least 2 kinds of squad.
- From raid 3, no kind is more than about 40% of a wave, where possible. Raids 3 to 8 often cannot meet this,
  because Thornlings are in most squads. The game does its best.
- Wave sizes and the field and tank limits from G1 stay the same.
- Each chapter lists its squads. The bosses (raids 6, 13 and 15) come with escort squads. Elites lead their own
  small squads.

**How a squad moves:** a squad comes down one road together.

- The leader goes in front: an elite, else the tank, else the fighter.
- The light ones keep pace beside and behind. Support stays about 2.5 m behind.
- Within 6 m of the firelight, when the leader dies, or when the cat comes close, the squad breaks up. Each one then
  does its own job.
- Raids keep their old random waves.

### The four roads: patterns

> **New (19 Nov 2026, Phase F).** The four roads stay. Each wave of a raid has a pattern:
>
> | Pattern | Share | What happens |
> |---|---|---|
> | Surround | about 65% | All four roads, taking turns. The raid's own road sends a bit more. |
> | Pincer | about 20% | Two roads far apart |
> | Rush | about 15% | The raid's own road: the same number of enemies, 15% faster (G1: they used to bring 25% more), with a banner |
>
> Elites come down a different road (a flank). The boss wave is a surround. **Raid 1 teaches it:** chapter 1 uses
> one road, chapter 2 two, chapter 3 all four. In a breather the top bar names the next wave's roads, so barricades
> become a choice. Gloom Raids keep their old rules. The Gloom over the woods now fades a step with each raid won
> (it only changes the look).

### Pay

Kills drop golden leaves (pick them up; the Leaf magnet pulls them in, and what is left flies to the cat when the
wave ends). Each cleared wave pays a small bonus, each chapter a chest with timber, and the win pays the
raid's reward. **Updated 23 Nov 2026:** fresh enemy kill drops give 50% more golden leaves, rounded; returned stolen
leaves keep their original amount. Each campaign wave pays **6 + wave number** leaves and **2 timber**, multiplied
by the existing pay scale (1 + 0.2 × raid index, then rounded). Both base wave amounts are doubled. Five-wave chests
still pay 2, 4, 4 and 6 timber, with the same scaling. First-clear rewards and gifts stay as listed below.
**New (Phase F): pay for active play.** A **quick clear** (the wave cleared within 20 s plus 3 s per enemy) and an
**intact wave** (no building or defence ruined, the fire never out) each pay **half the wave bonus again**. These
bonuses use the stronger wave pay. Waiting or pressing Start wave never pays extra leaves.

### Enemies attack the camp

When an enemy is not busy with the cat it goes for, in order: a **barricade** blocking its trail, then a **tower**
within 7 m, then the **nearest building** within 9 m, then the **campfire**.

### Reasons to move

> **New (19 Nov 2026, Phase F).** The cat should not just stand and shoot.
>
> - **Ranged foes hang back.** Pitcher Spitters (8 m) and Frog Shamans (7.5 m) stop at that distance from a tower, a
>   building or the campfire and shoot it from there. That is beyond the cat's reach when she stands at the fire, and
>   beyond a tower's range. Walk out to them. Up close they still fight the cat.
> - **The Golden Grub** (from raid 2, about 1 wave in 3). A small gold grub (a stand-in model) runs round the camp,
>   outside the firelight, with a sack of 40 leaves. Shoot it within 14 s or it gets away. It never holds a wave up.
> - **The Gloom Totem** (from raid 3, about 1 ordinary wave in 3). A violet crystal spire (made from existing
>   Gloom props) grows on a road a few seconds into the wave. Enemies within 4 m are 25% faster and take 25% less
>   damage (a faint violet tint) until the cat breaks it. The wave waits for it.

### Defences

| Defence | Where it goes | What it does | Opens |
|---|---|---|---|
| Barricade row (90 leaves and 5 timber for 3 pieces) | Tap a road marker. Each road has a gate, a middle pad and a far pad. | Blocks the road until enemies break a piece | After raid 1. The four gates are available at Hearthtree 1, the middle pads at 3, and the far pads at 4 on the right and 5 on the left. |
| Acorn tower (90 leaves) | Anywhere free; how many is set by the home level (2 to 9) | Crossbow aims through 360° and shoots large Twig-style arrows; enemies go for towers right after barricades | After 2 raids |
| Thorn spikes (70 leaves) | Anywhere free | Hurt and slow whatever walks over them | After 3 raids |

> Each piece breaks on its own. Below 50% health it cracks, darkens and leans. At 0 it falls flat and enemies pass
> through the gap. Tap the row to repair it. Winning a raid repairs the defences for free.
>
> **Barricade placement (22 Nov 2026).** Each pad lies across the curve of its own road.
>
> - **Hearthtree 1–2.** The gate pad on each road is 2.4 m along the road from the firelight (4 pads in all).
> - **Hearthtree 3.** The middle pad opens (8 pads in all). On the right it sits halfway along the road between the
>   gate and far pad. On the left it sits on the outer bend, at least 5 m along the road from the gate.
> - **Hearthtree 4.** The far pads open on the two roads to the right of the campfire, Fernwood and Bandit Thicket.
>   These pads are 0.8 m closer to camp than the far pads on the left (10 pads in all).
> - **Hearthtree 5 and up.** The far pads on the left open (12 pads in all).
>
> Empty pads show a marker once they open. Build between waves and tap built rows to repair them at any time.
> Existing rows keep their road and pad and move with it, including when the Hearthtree grows. Rows built on a
> now-locked pad in an older save still work and can be repaired.
>
> **New (22 Nov 2026): the card says why Build is off.** When Build can't be pressed, the card gives the reason in plain
> words: "A wave is on: build between waves"; "Needs 90 leaves and 5 timber" (the price); or "Barricades open later".
> The old "N of M rows" badge and "Grow the Hearthtree for more rows" are gone. The barricade tip ends "...More spots
> open as the Hearthtree grows." (History: the 20 Nov limit of 2, 3, 5, 7, 9 and 12 rows is replaced by this.)
>
> **New (22 Nov 2026): repairs work any time.** A built row's marker stays tappable in a wave, and its Repair is enabled.
> Building new rows and repairing towers still happen only between waves. The price per piece is 30% (`repair_share`)
> of the row's build price, times:
> - broken: 1;
> - cracked: its missing share of health, at least 0.5 (it was a flat 0.5 before, which let a nearly broken piece be
>   mended cheaply in a wave);
> - hurt but not cracked: its missing share of health.

All acorn towers and thorn spikes share one level, bought in the shop and capped by the home level. Upgrading
a defence type updates every placed piece of that type. **Acorn arrows (23 Nov 2026):** the five existing tower
models reach 5/6/7/8/9 m and deal 8/14/24/36/44 damage. Their arrows grow 1.6× to 2.4× the cat's Twig arrow and
change tip/fletching colours at each tier: leaf/silver, pale blue, gold, violet and amber. Only the upper crossbow
turns and tilts. Loading, string draw, release, recoil and the arrow trail are animated. Broken towers stop and
hide their arrow until repaired. An upgrade loads the new tier automatically.

**New (H3, 26 Nov 2026): towers and spikes are placed from the Bag.** A tower or spikes you buy goes into the Bag (it
takes a slot; 20 stack in one). With no room, the shop tile says "Bag full" and nothing is paid. Its tile says "2 in
the Bag · place it from the Bag". Place it with its button above the Bag, or from the Bag: tap it, then **Place**. The
Bag closes and the green or red ghost shows in front of the cat. Below ground Place says "Place it in the camp". A
placed piece drops in with a small bounce and a puff of dust. **The ghost is now red by the lake and by the home**
(the owner's yes, 26 Nov 2026): it uses the same rule as the start-up check, so a piece is never put somewhere that
sends it back to the Bag at the next start. A piece sent back that way always goes in, even into a full Bag. There
is no Undo yet (H6).

Buying a barricade level on the Hearthtree's card makes every row tougher at once. Towers and spikes get stronger each level. Level 4 (Shardstone and the shard levels) costs Gloom shards
and opens after the raids; level 5 (Heartwood, Amber, Amber Thorns) costs leaves only and still opens with the Gloomwood (New, H1, 25 Nov 2026: it asked for expedition materials before). Broken defences are
mended free when a raid is won; after a camp fall or a raid they stay broken until mended in the shop or with
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
| The mount is knocked out | It stays out until a Mount Health Potion brings it back, or the next chapter break (part 5; New, H3). |
| The camp falls | The Gloom takes 30% of the leaves gained since this chapter began, never more than you hold. Savings, completed supply chests and gains during chapter breaks are safe. Ruins and broken defences stay damaged. Rebuild the ashes at the campfire before resuming. **Retry only the failed wave**; all earlier cleared waves stay cleared. No level is lost. |
| You give up a raid | Its next try starts at wave 1. What you earned stays. |

### The 15 raids

| # | Raid | Waves | Needs home | Trails | New threat | Ends with | First-win gift |
|---|---|---|---|---|---|---|---|
| 1 | First Embers | 15 | 1 | Fernwood | Thornlings (the tutorial) | Thornling Chief (a mini-boss) | Garden and pot, Bow Shop in the shop, 60 leaves (New, G1b: "+60 leaves for your first barricades"; it was 2 barricade pieces) |
| 2 | Bramble Pack | 15 | 1 | Toadstool Dell | Bramble Boars | 2 boars | None (New, G2: the Market and Thistle come at Hearthtree level 2) |
| 3 | Toadstool March | 15 | 2 | Bandit Thicket | Toadstool Brutes | 3 brutes | None (New, G2: the Market comes at Hearthtree level 2; H5: Sprig is bought there) |
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

**New (Phase F): raid 2 is easier.** Fewer boars (none in waves 1 and 2), elite waves with 1, 1 and 2 boars, and a
final wave of 2 boars. Boars are also softer (see the enemies table). Only raids 6, 13 and 15 end in a real boss.
The owner wants 2 or 3 more bosses later (part 10).

### The enemies

| Enemy | What it does |
|---|---|
| Thornling | Small and quick; pounces; chases the cat when near |
| Thornling Chief | A big Thornling: raid 1's mini-boss |
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
- Riding: the cat runs 27.5%, 40.25%, 53%, 65.75% or 78.5% faster. **New (H5):** this is the **mount's level**, which
  comes from the **Saddlery's level** (the Market has no levels now); it is level 1 until the Saddlery is built. Base
  health goes 6, 9, 13, 18 and 24 with the same levels (the owner's answer: levels 4 and 5 are 1.6575x speed with 18
  health, and 1.785x with 24). An old save keeps the level its Market had earned until the Saddlery catches up, and the
  Skills confirm says so (the owner's answer). (All tiers were reduced 15% on 23 Nov.) She sways and leans with the mount and carries her
  bow upright and tilted toward her. **Updated 23 Nov 2026, after phone play** · the mount faces joystick travel and
  runs forward. The cat shoots up to 140 degrees either side, a 280-degree arc with an 80-degree rear gap.
  It releases held targets outside that arc. Dedicated left/right rear-quarter shooting animations turn
  her torso, shoulders, arms and head above a seat that stays aligned with the mount. Turn the mount for enemies directly behind.
  She can't hide while riding. The mount uses the skills in the Saddlery's circles.
- **Thistle takes the hits** while the cat rides. Its health is the thin amber bar under the cat's.
- **Knocked out**, it throws the cat off. **New (H3, 26 Nov 2026, the owner's answer): the Mount Health Potion
  replaces Feed.** In a fight it stays out until a **Mount Health Potion** brings it back, or until the next chapter
  break. In the Gloomwood it stays out until a potion. The potion's button takes Ride's place while the mount is out
  and the Bag holds one. It works any time, even mid-wave: the mount gets up with **full health** and the cat hops on.
  If the Market is in ruins, the mount comes to the cat instead. Outside fights in the camp it rests 20 s and gets up
  by itself, as before. Sunberries are now only for cooking.
- **Mending a standing mount** (New, H3): raw fish mends 10% of its health at once, the Golden Carp 50%, and Cooked
  Fish mends it to full over 10 s. Use them from the Bag, ridden or not, also with the Market in ruins. They do not
  bring back a knocked-out mount. When not ridden, it also gets 1 health back every 2 s.
- It is whole again at every chapter break and when a raid ends.

### The Saddlery: the mount's skills and attachments (New, 21 Nov 2026, G4)

- **New (H5):** the Saddlery has its own window with Attachments and Skills tabs, and its Upgrade also raises the mount's
  speed and health (part 3, "The building windows").
- Build it from the build menu once 8 raids are won and the Hearthtree is at level 2 (part 3).
  Buy skills and attachments with leaves and timber. Levels 4 and 5 open after the Raid Missions (until then the tile says "Level 4 opens after the Raid Missions", or "Level 5 ..." for an item at level 4). Item levels are
  capped by the Saddlery's level.
- **Skills.** The mount uses them by itself while the cat rides in a fight, each on its own timer. Never two at once: a
  shared gap of 0.6 s. **New (H5): only a skill in one of the three circles fires.** The order they are tried in does
  not follow the circles; it stays Bellow, Pounce, Ram, Stomp.

  | Skill | What it does (level 1) | Per level |
  |---|---|---|
  | **Stomp** | Every 4 s, when an enemy is within 1.6 m: a shockwave that reaches 2 m, 20 damage, a push | +40% damage |
  | **Ram** | Every 7 s, when enemies are ahead within 4 m: a short charge, 35 damage to each enemy in the path, knocked aside | +40% damage |
  | **Pounce** | Every 9 s: leaps with the cat onto the biggest group within 6 m, 2.5 m blast, 40 damage, 1 s stun (bosses 0.5 s) | +40% damage, +0.1 s stun |
  | **Bellow** | Every 12 s, when 4 or more enemies are within 4 m: 1.5 s stun (bosses 0.5 s), and they take 20% more damage for 3 s | +0.2 s stun, +5% damage |

  Stomp, Ram and Pounce miss flying enemies. Bellow reaches them.
- **Attachments.** Own all three and wear one at a time. Only the one worn shows on the mount and gives its benefit.
  The first one you buy is put on automatically. Swap owned attachments for free between waves at the Saddlery.

  | Attachment | What it does (level 1) | Per level |
  |---|---|---|
  | **Fire-spitter** | Flame balls at the cat's current arrow range and firing pace. Its firing unit automatically tracks enemies while riding, including to the side and rear. Each hit deals 8 damage to the enemy and foes within 1.25 m, plus 8 burn damage a second for 2 s | +40% of base impact and burn damage |
  | **Mossweave Saddle** | The mount has 15% more health | +15% (level 5: +75%) |
  | **Saddlebags** | Kills drop 5% more leaves (raids, raids and the expeditions) | +5% (level 5: +25%) |

  The worn Saddlery attachment works in raids, raids and the expeditions. Claude made the models for both mounts.
  Fire-spitter speed follows the cat's draw upgrades and current bow, independently of the mount skill gap (the old
  dish boosts are gone since H3).
  **Flame visuals (23 Nov 2026):** shots have a hot round core, directional flame tail and sparks. Hits create a
  glowing scorch with low, animated ground flames. It extinguishes after 3 seconds, fading during the last 0.8 s;
  nearby hits refresh the same fire. This is a visual effect alongside the existing impact damage and enemy burn.
  Graphics quality caps ground patches at 4 / 6 / 8 and reduces particle counts on Low.
  Range follows the cat's range upgrades and bow. The cannon assists her focused enemy or finds another enemy in range;
  only its firing unit swivels, with the harness fixed and joystick steering preserved.
- **The mounts have no built-in move any more.** A mount carries the cat faster and takes the hits. Its fighting comes
  from the Saddlery.
- **Old saves.** A save from before H5 that learned skills keeps them all, and they fill the circles in the old shop
  order: **Stomp, Ram, Pounce** (Bellow stays learned, in the grid). Fewer learned skills fill fewer circles.
  A pre-G4 save with raid 8 won gets Stomp level 1 (and it goes into a circle). An old Mossweave Saddle becomes saddle level 3.
  Old Saddlebags become level 5. If there is no worn choice in the save, the highest-level owned attachment goes on.
  Ties go to Saddlebags, then Mossweave Saddle, then Fire-spitter.
- **Animations** (Claude made them in Blender, on the owner's mount rigs; besides Idle, Run and Thump, which are
  unchanged): Thistle has Stomp (a copy of its old Thump), Ram (a head-down dash), Pounce and Bellow (rears and calls).
  Bramblewool has Stomp (rears and slams its hooves), Pounce and Bellow; its Ram is the old one.

### Sprig, the pet

- **New (H5): bought at the Market's Pets tab for 160 leaves.** (It came with the Mushroom Cottage before; the Cottage
  is gone.) It flutters at the cat's shoulder and spits seed sparks at the nearest enemy, harder and faster with each
  **pet level**. The levels are trained on the Pets tab: level 2 costs 350 leaves, level 3 costs 900 leaves and 30
  timber, never above the Hearthtree's level. Sparks: 6, 10 or 16 damage, every 1.3, 1.1 or 0.9 seconds.
- The pet stays with the cat even if the Market is ruined or was never built (an old save's pet comes along).
- **Old saves (H5):** the Cottage's level becomes the pet's level, and a player who had the Cottage (any level) owns
  **both Sprig and Lumi** for free. A fresh save owns neither.
- **The pet is never knocked out.** While the cat hides, Sprig only spits at enemies right next to it, so it never
  gives the cat away. In the Gloomwood it glows like a little lantern.

### Looks (same strength)

- **The Mounts tab** (Market): Thistle the hare or **Bramblewool** the ram. **The Pets tab** (Market, H5; it was the
  Nest on the Cottage's card): Sprig the leaf dragon or **Lumi** the fox kit. Every look does exactly the same: only
  the model, its move and its colours differ (the model and its animations). Lumi costs 400 leaves.
- **Colours** row: Natural, Snow, Midnight, Autumn, Golden and more, per look. All free while testing; sold later.
- **Gloomlit** colours cost 60 Gloom shards per look. They are earned only, never sold.
- **Attachments** (after the raids): see part 8. **New (21 Nov 2026, G4):** the mount's Mossweave Saddle, Saddlebags
  and Fire-spitter are at the Saddlery (above).

### The Moss Warden, the camp's guardian

- A big, slow golem of mossy stone and old roots, from the owner's Meshy model.
- **How you get it:** not in the raids, never sold. On the **first clear of the Gloomwood**, after Mossback falls,
  the Warden lies sealed in violet Gloom crystals at the arena's north edge. Stand on the seal for 3 s to break it.
  It comes home and lives by the Guardian Stone, east of the camp. Banner: "The Moss Warden is free! It will guard the
  camp while you are away."
- **What it does:** in a fight (raids and raid replays) it goes for whatever attacks your buildings, barricades,
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

## 6. Food, potions and the Bag

**New (H3, 26 Nov 2026).** You grow food in the garden and catch fish at the lake, cook them into potions at the pot,
and keep everything in the Bag. **Crops and cooking run in real time, by the phone's clock, also while the game is
closed** (the only things that do). The 7 old dishes, the pantry and its limit of 20, eating food, the snacks below
ground and Feed are gone. Garden food is only for cooking; fish and the Golden Carp can also mend the mount.

### The Bag

- **24 square slots** in a grid (4 rows of 6). Only things you have take a slot. The Bag sorts itself: food first,
  then potions, amber, and towers and spikes. (Moving things between slots yourself is not built.)
- **Stacks:** food, fish, amber, towers and spikes stack to **20** in a slot and use more slots when you have more:
  45 Sunberries take 3 slots (20, 20 and 5).
- **Potions:** each potion is **one stack with its own limit**: Health Potion 3, Mount Health Potion 3, Cooked Fish
  10, Damage Potion 1, Speed Potion 2. A potion's slot shows how many of its limit you have, for example "2/3".
- **Tap a slot** to see its name, how many you have and what it is for, and its one button:
  - **Use** for potions and fish. It closes the Bag when it works. When it cannot work now, the reason shows under the
    button ("Full health", "Already active", "Only for a knocked-out mount" and so on). The reason shows only while it
    is still true: if the cat gets hurt while the Bag is open, "Full health" goes away and Use works.
  - **Place** for towers and spikes (part 4). Below ground it says "Place it in the camp".
  - Food and amber have no button. Their line says what they are for ("For cooking at the pot.", "Rare. Bramble buys
    it.").
- An empty Bag says "The Bag is empty". Below ground, amber shows the run's satchel ("At camp N · This run N").
- **When the Bag is full:**
  - a fishing catch that does not fit swims away ("Bag full, the rest swims away");
  - buying food from Bramble, or a tower or spikes, is refused with "Bag full" before you pay;
  - a ripe crop stays ripe ("Bag full"), and a finished potion waits in the pot;
  - Cook is refused when its potion would not fit ("No room in the Bag");
  - things already paid for always go in, even past 24 slots (the grid then adds a row): pieces sent back to the Bag
    at the start, an old save's food and potions, amber brought home from the Gloomwood, and the garden's 4 Sunberries.

### The garden

- South of the camp, the gift for winning raid 1 (with 4 Sunberries).
- **3, 5 or 6 plots** by garden level (levels 2 and 3 cost 400 and 1,000 leaves; level 3 also gives +1 on every
  harvest).
- **The garden's window looks like the bed in the camp:** plots 3, 2, 1 on the top row and 6, 5, 4 below. A plot not
  open yet is dim and says which garden level opens it ("Garden 2"). The seeds are in a row under the plots, with
  Water under them.
- **Planting:** drag a seed onto an empty plot. You pay when you drop it. A seed you cannot pay for does not drag.
- **Growing:** in real time, also while the game is closed. Each plot shows a sprout, then the growing plant, a bar
  and the time left ("3:12"); a ripe plot says "Ripe: tap" and a gold glint shows over the bed. Ripe plants never rot.
  When crops ripen, a toast says so ("Ripe in the garden: Sunberries"), and the garden's badge pulses.
- **Water:** free, with no cooldown. It waters every growing plot that is not watered yet. Those plots grow **twice
  as fast for 5 minutes** at garden level 1, 6 minutes at level 2 and 7 minutes at level 3 (or until they are ripe,
  if that is sooner). The soil looks dark and wet meanwhile. A seed planted afterwards is dry: tap Water again for
  it. A watered plot can be watered again once its watered time ends. The line under Water says it: "Watered plants
  grow twice as fast for 5 min".
- **Picking:** tap a ripe plot and its crop goes into the Bag. If it does not fit, "Bag full" shows and the plant
  stays ripe. The Gloom meter gets +2 once per garden visit that picks something (after the raids).
- The garden's card is closed during a wave, but the crops keep growing. Pick them after the wave.

| Crop | Gives | Seed | Grows in |
|---|---|---|---|
| Sunberries | 3 Sunberries | 10 leaves | 4 min |
| Fernmint | 2 Fernmint | 12 leaves | 5 min |
| Honeybells | 2 honey | 15 leaves | 6 min |
| **Emberpeppers** (new) | 2 Emberpeppers | 20 leaves | 8 min |
| **Swiftroots** (new) | 2 Swiftroots | 18 leaves | 7 min |

All five seeds are there from garden level 1. Bramble sells Sunberries, Fernmint, honey and fish, but not Emberpeppers
or Swiftroots.

### Cooking

- The pot sits on the campfire's north-east rim and comes with the garden. One pot.
- **The window:** the pot with **3 slots** at the top, and under them your ingredients as big icons with their counts.
  The count shown is what is left after the pieces already in the slots; at 0 an icon is grey and does not drag.
- **Filling the pot:** drag an ingredient into a slot, or **tap** it to fill the next empty slot. Tap a filled slot to
  empty it. Nothing leaves the Bag until you tap Cook, and the slots empty when the window closes, so nothing is lost.
- When the pieces make a recipe exactly, its name and what it does show, and **Cook** lights up.
- **Cooking** takes 30 s to 1 min in real time, also while the game is closed. The pot shows the recipe's icon, a bar
  and "Ready in 0:32". When it is done, a toast says so ("Health Potion is ready at the pot") and the pot's badge
  pulses. **Collect** puts it in the Bag. If the Bag is full, "Bag full" shows and it waits in the pot.
- One thing cooks at a time: a second Cook says "Cooking already", or "Collect first" when the last one is done.
- A **recipe list** at the bottom of the window shows every recipe you know and what it needs.
- The Gloom meter gets +3 on each Cook tap (after the raids), never when the cooking ends.
- **The fire out** (the Last Stand, the ashes): the pot's badge hides and you cannot cook or collect, but the cooking
  goes on. The pot's card is closed during a wave.
- When a crop ripens and the pot finishes in the same moment (for example when you open the game after a long time
  away), one toast says both: "Ripe in the garden: Sunberries · Health Potion is ready at the pot".

### The recipes

| Recipe | Ingredients | What it does | Bag limit | Cooks in |
|---|---|---|---|---|
| **Health Potion** | 2 Fernmint, 1 honey | Heals the cat by 40% of its health over 5 s | 3 | 40 s |
| **Mount Health Potion** | 2 Sunberries, 1 honey | Brings a knocked-out mount back on its feet with **full** health (the owner, 26 Nov 2026) | 3 | 45 s |
| **Cooked Fish** | 1 fish | Mends the mount to full health over 10 s | 10 | 30 s |
| **Damage Potion** | 2 Emberpeppers, 1 honey | The cat's arrows hit 25% harder for 30 s | 1 | 60 s |
| **Speed Potion** | 2 Swiftroots, 1 honey | The cat moves 25% faster for 20 s (also while riding) | 2 | 50 s |

- Cooked Fish shows once the Fishing Spot is built; the other four from the start.
- **The Health Potion** needs a hurt cat. **The Mount Health Potion** only works on a knocked-out mount, and Cooked
  Fish and raw fish only on a standing, hurt one (part 5).
- **A potion that is still working** cannot be used again ("Already active"), so none is wasted. Running potions pause
  while the game is paused, end when the cat is knocked out, and are lost when the game closes (they last 5 to 30 s).
- The Damage Potion is for the cat's arrows only, not towers, the pet or the mount's skills.
- The old dish boosts (shooting faster, +2 health, companions hitting harder, a tougher campfire, the Warden's stew)
  went with the dishes.
- **The icons** of the potions, Emberpeppers and Swiftroots are simple stand-ins drawn in code (a small bottle in each
  potion's colour, a red pepper, a pale root), until the owner asks for designs.

### Potion buttons

- **The Health Potion button** (bottom right, row 1) shows when the cat is hurt and the Bag holds one. In the camp the
  cat heals by itself, so it may show for a moment there too.
- **The Mount Health Potion button** takes Ride's place (row 2) while the mount is knocked out and the Bag holds one.
- Each shows the potion's picture and "×N". It turns grey and cannot be tapped while it cannot work now (for example
  while a Health Potion is still healing).
- Both hide while you place a defence. The Damage Potion, the Speed Potion, Cooked Fish and fish are used from the Bag.

### Fishing

- The gift for winning raid 6, at the lake's south shore. Any time no wave is on: **Cast** on the card. After a
  wait (and a nibble or two) the float dips with a white, blue or gold "!": **tap anywhere**. Bigger catches need
  reeling: a ring closes on the float, tap while it is green. A miss costs nothing.
- Stop by walking away; a wave starting pulls the line in.
- Catches: Minnow and Sun Perch (fish), Silver Trout (2 fish), Driftwood (timber), Golden Carp (rare), Sunken Chest
  (leaves and timber). A rare catch comes at least once every 20 catches.
- Three lake treasures, found in order: the **Lucky Lure** (bites come 25% sooner), the **Silk Line** (one more slip
  forgiven when reeling), the **Lake-moss Charm** (the Warden's Lakeweed colours).
- **New (H3):** fish go into the Bag. A fish mends the mount by 10% at once, or cooks into Cooked Fish. The **Golden
  Carp** mends the mount by 50% at once, or Bramble buys it for 300 leaves. It is not used in cooking. When the Bag is
  full, the rest swims away.

### Healing in the Gloomwood

- **Only Health Potions heal the cat** below ground (the owner's answer, 26 Nov 2026), besides the dew drops, dew buds,
  the Moonwell's spring and the Mossheart boon (part 8). There is no Snack button and no food to eat.
- The Mount Health Potion brings the knocked-out mount back there too.
- Brew your potions at the pot before you go in: the Bag goes with the cat.

### Old saves (save version 4)

An older save is upgraded once when it loads (a backup is made first):
- the pantry's food goes into the Bag, all of it;
- a dish waiting in the pot, or one eaten in a mission that was saved, becomes a **Health Potion** (up to 3 in the Bag;
  each one more would pay 50 leaves, which cannot happen today);
- a half-grown crop keeps its share: a crop 2 of 4 steps along is half grown and ripens in the rest of its new time.
  Old watering is dropped.

---

## 7. After the raids: Gloom Raids

Raids start with the first win of raid 15. They come only while you are playing in the camp.

### The meter and the Watch

- The signpost grows a horn and a crystal: **the Watch**. Its crystal and the top bar show the **Gloom meter**.
- The meter fills about 10 points a minute while you play in the camp with no fight on. It does **not** fill while
  you are idle (no touch for 45 s), while the cat is in the Gloomwood, or while the game is closed. Cooking, picking,
  fishing, replays and Gloomwood runs add a few points, but never past 95, so the horn always sounds while you are
  there. Empty to full takes about 10 minutes of play.
- At 75% the next raid is planned ("The Gloom stirs in the woods..."). At 100% the horn sounds.
- From 50% you can **Sound the horn** on the Watch card to call the raid early (30 s warning).

### A raid

1. **Preparation**: the horn announces a waiting Gloom Raid. A banner shows its kind and trails, and the camp stays
   safe. Scouts may reveal hidden trails during preparation; reaching the old warning time never starts combat.
   Tap **Defend Camp** at the signpost to begin.
2. **One continuous assault**, with no intermediate waves or preparation breaks. Small mixed groups of **1–3**
   arrive across **all four trails**, 0.22 seconds apart within groups and 1.1–2 seconds between groups. The seeded
   roster starts at 36–46 plus the existing level increment, with a **50-enemy total cap** including leader and boss
   summons. A separate live-enemy limit keeps the field manageable; more arrive as room opens. Completion also pays
   **7 golden leaves and 2 timber** on top of the final raid reward. **Raid Missions retain their normal wave system.**
3. **The leader** joins last: the Gloom Herald, or a boss in an elite raid. **New (H1, 25 Nov 2026): the raid is held
   when every raider is defeated**: toppling the leader no longer makes the rest flee.
   The leader's banner and the signpost card say "defeat every raider to hold the camp". If the last 1 to 3 raiders
   do nothing for `flee_after` (45 s), they walk once to the campfire, so the raid can still end.

| Kind | From | Trails | Leader | Who comes |
|---|---|---|---|---|
| Siege (the first raid is always one) | raid 1 | All four, mixed groups | Gloom Herald | Bruisers for your buildings: Stump Golems, Brutes, Boars, Beetles, Thornlings |
| Sky | raid 2 | All four, mixed groups | Gloom Herald | Mostly Gloom Moths over the barricades: towers and your bow matter |
| Sneak | raid 3 | All four; hidden until the preparation reveal | Gloom Herald | Thornlings, Moles, Puffballs |
| Elite (rare) | raid 5, then 4 raids apart at least | All four, mixed groups | Mossback, then the Owl Witch, then the Elder Thornstag | A tough mix; pays double shards |

### Winning and losing

- **Held**: Gloom shards, leaves, timber (New, H1, 25 Nov 2026: no Hollow key any more). A **perfect defence** (no building
  lost, the fire never out) pays 50% more shards; a camp that was whole when the raid began pays 20% more. Perfect
  streaks put ribbons on the signpost.
- **Lost** (the camp falls): only the damage stays, plus 2 shards per complete third of the assault defended. Nothing is taken, the fire relights
  at once, and the next raid is a little gentler.
- **Raid level** (1 to 30) grows with the camp (home level, station levels, towers, defence levels, the Warden) and
  with raids won. The cat's own upgrades never make raids harder.
- **Resume:** defeated enemies stay defeated; unresolved members return with the saved roster, summons and camp
  damage. The assault waits for Defend Camp again. Old multi-wave saves receive credit for their cleared portion.

### Keeping the camp up

- Damage carries over between raids: **ruins**, **wrecked defences**, and **wear** (a building keeps the share of
  health raids took from it; it darkens and gets rubble piles at its foot).
- Fix it with **Patch it up** on a building's card, "Mend the defences" in the shop, or **Mend all** (or **Mend
  some**, when you cannot pay for all) on the Watch card and at the top of the shop. Each mended thing springs back
  with a flower ring. Ruin repairs are capped in price (the Hearthtree's: part 3; New, 22 Nov 2026, loop fixes).
- The Warden is knocked down by raids and gets up by itself.

### What shards buy (earned only, never sold)

Defence level 4 (Shardstone barricades, level 4 towers and spikes; 50 to 90 shards plus leaves, needs home level 4);
**Lookout** (25: +15 s to get ready before every raid); **Tracker** (40: see the next raid at 75%, and sneak raids
can't hide); **Gloomlit** colours (60 per mount or pet look); **Shardfire** (100: the campfire burns blue-violet).
(New, H5, the owner's rule: Bramble no longer buys shards for leaves.)

---

## 8. After the raids: the Gloomwood

**The expeditions** (called the Burrows in the code) are the dungeons. The first one is **the Gloomwood**,
reached through **the Old Hollow** at the south edge of the camp. After the raids, the expeditions are most of the
game: go in, bring back what the camp needs, upgrade, go again on a harder level.

### Getting in

- The Old Hollow appears sealed with Gloom crystals (two violet eyes blink under them) from the first raid won. It
  opens with raid 15's first win.
- **Entry is free and unlimited.** It is blocked only while a fight is on or a raid is coming. A damaged camp only
  shows a warning on the card.
- The cat goes in with its **pet and mount**. The Warden stays home.
- The card: "The Gloomwood · Level N" (**Go in**), "Play another level" (lower levels are easier), your amber, and any mending the camp needs. (New, H1, 25 Nov 2026: the "Use a Hollow key" row is gone.)

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
> a cat that only stands and shoots must be knocked out before the end; a cat played with care (riding, potions,
> dashing out of danger) must win. Measured: a standing endgame cat is knocked out just after the Glowcap
> clearing; Mossback has about 9,900 health at level 1 (was 3,000) and takes about 70 s for a cat that only shoots.
> Pay is up 25% to match. Tune by play on the phone.
>
> **Known (H3, 26 Nov 2026):** since only Health Potions heal below ground, the careful test cat (`--dungeoncareful`,
> with 3 Health and 3 Mount Health Potions) now loses at the boss in about 2 runs of 3. The owner's call: noted, not
> retuned now. Expeditions are rebuilt in H8 and balanced in H11.

### Levels

Each win opens the next level of the same road. Level 1 is open when the Hollow opens; beating level N opens N+1. Each
level is stronger, has bigger packs, brings other monsters and pays more. Mossback is the boss at every level, and
**Gloomtouched** (violet, bigger, much tougher) from level 4. The very first run uses fixed packs, the same for
everyone. The holes and the dark always send their own kinds; the packs come from the level's list:

| Level | Monsters in the packs | Pays |
|---|---|---|
| 1 | Thornlings, Grublings, Glowcaps, Boars, Moles | amber (rare) |
| 2 | Grublings, Glowcaps, Brutes, Puffballs, Frogs | amber (rare) |
| 3 | Beetles, Moles, Crows, Boars, Thornlings, Grublings | amber (rare) |
| 4 | Moths, Pitchers, Glowcaps, Snails, Beetles | amber (rare); Mossback is Gloomtouched |
| 5 and up | Stumps, Beetles, Glowcaps, Moths, Puffballs, Crows, Grublings | stronger and richer every level |

The Gloomwood's own creatures (stand-ins until the owner's models come): the **Grubling** bursts out of the ground,
the **Glowcap** keeps away and lobs spore bombs where the cat is going, the **Root Snapper** never moves and bites
along a line, and the rare **Amber Grub** runs for a hole and digs away after 10 s (catch it for leaves and, half the time, amber).

### The satchel

**Amber** (Root Amber) is the one expedition material (New, H1, 25 Nov 2026: glowstone and heartwood are gone). It goes into the **satchel**. Leaves, timber and shards are banked
at once. Amber is rare and pays for nothing: you sell it to Bramble. Where it drops (`balance.json` `burrows.amber`; a number like 0.5 is a 1 in 2 chance): the boss or end chest 1, the Gloom-bound chest 0.5 (breaking its seal doubles it, like all its loot), a Gloomtouched elite's kill 0.1, the Amber Grub caught 0.5, and a level's first clear 1 (straight into the satchel). Ordinary kills and the other chests drop none. A root lift (at the Moonwell, or after the boss) brings all of the satchel home. A knock-out (Sprig drags the
cat back up the hollow) or "Leave it" on a saved run brings half. "Go home" at the way in, before anything woke, is as
if the run never happened.

### Boons

- **Boons** last one run: Sharp Thorns (arrows +25%), Quick Paws (the dash recharges faster and goes further),
  Mossheart (+3 health), Sprig's Fury (Sprig spits 50% faster), Dewdrop Charm (healing dew three times as often),
  Lucky Paw (chests give 50% more leaves and timber, but never more amber: the owner, 25 Nov 2026). The Moonwell
  offers two; take one. Boons come only from
  the shrines inside the Gloomwood.
- **No Hollow keys** (New, H1, 25 Nov 2026): there is no key boon at the start of a run, no key row on the way-in card,
  and no key from raids, replays or first clears.
- **Dew drops** sometimes fall from kills and heal 1; a dew bud may bloom where a fight was won.

### Checkpoints and saving

The run is saved at each checkpoint (the way in, the Moonwell, the arena gate), when the cat is hurt, and when the app
is paused. Close the game and the run waits at the Hollow: **Go back in** puts the cat at the last checkpoint with its
saved health, boons and satchel. Fights before it stay won; fights after it are full again. Chests opened, the spring
drunk and the boon taken stay done.

### What amber buys: nothing

Amber is sell-only: Bramble buys 1 amber for 1,000 leaves and 1 Gloom shard. Nothing is bought with it. Lucky Paw never gives more of it.

### Prices that used to ask for materials (now leaves)

Everything that used to ask for materials now asks for leaves (timber is unchanged): the old leaves plus amber x 60, glowstone x 120 and heartwood x 400. Examples:

- **Mastery**: levels 11 and 12 of Damage, Draw speed, Health and Move speed (760 and 1,450 leaves), and of every bow (about 1,200 and 2,100; Frost 1,380 and 2,340).
- **The Foxfire Bow** (Bow Shop level 3; 5,120 leaves): goes through two enemies. (New, 22 Nov 2026: hidden, not sold; see the bows in part 3.)
- **Level-5 defences**: Heartwood barricades, Amber towers, Amber Thorns (tower level 5 is 5,760 leaves). They still open only after the expeditions do.
- **Home levels 6 to 8** (part 3): 17,160, 33,480 and 54,400 leaves, with 110, 150 and 200 timber.
- **Gloomwood attachments** are bought and worn on the Market's Mounts and Pets tabs (H5; they were on the Stable and
  Nest cards), one per companion. On the Mounts tab,
  **Thunder Shoes** make Stomp 60% stronger in the Gloomwood. On the Pets tab, the Glowworm Lantern makes traps and
  spore bombs glow 0.3 s earlier, the Ember Charm makes sparks 60% harder, and the Dew Bell gives the cat +2 health.
  The Mossweave Saddle and Saddlebags are Saddlery gear and work wherever the mount wears them.

The Warden's level 4 also costs leaves and timber (the owner's rule: guardian upgrades cost leaves).

### More dungeons

More dungeons are **data plus models**: a new map file and one entry in the list (part 11). Not every dungeon needs a
boss: a map can end in a **treasure clearing** instead, and the owner wants some later dungeons without one.

---

## 9. Progress and money

### What you earn

| Currency | Where it comes from | What it buys |
|---|---|---|
| Golden leaves | Kills, waves, bonuses, chests, raid rewards, raids, the Gloomwood. **New (H1, 25 Nov 2026):** the leaves that defeated enemies drop in Raid Missions, Random Raids and the Gloomwood are 30% more (`kill_leaf_bonus` 1.3, applied after the mission's 1.5). Stolen leaves, chests, wave pay and raid pay are not raised. | Almost everything |
| Timber | Raid waves held (G1), chapter chests, raid rewards, driftwood, raids, the Gloomwood | Buildings, home levels, rebuilding the campfire; buy 5 for 50 leaves, sell 5 for 30 leaves (G1) |
| Gloom shards | Raids, Gloomwood boss chests | Part 7's list; never sold for leaves (H5) |
| Root Amber | The Gloomwood only (rare) | Nothing: sell it to Bramble for 1,000 leaves and 1 shard |

### The chain (New, 19 Nov 2026, Phase F)

```
missions -> leaves and timber -> buildings (the home caps their level)
         -> the cat's stats and bows (each building caps them)
         -> the home's goals are met -> the home grows and the camp unlocks more options
```

- **Raid Mission rewards.** First clears pay the listed completion reward; replays pay 50% of that leaf/timber reward,
  plus normal wave/chest pay. Unique progression and gifts remain one-time. The
  goals plus the home's price fit inside what the act's raids pay when each is won once; what is left is your
  choice (more towers, stats past the goal, food, repairs). The spare shrinks as the game goes on.
- **Win rewards (leaves)** for raids 1 to 15: 100, 180, 200, 300, 350, 700, 600, 700, 800, 900, 1,300, 1,400,
  2,000, 1,200, 1,500. Timber goes from 10 to 60.
- **Prices.** Stat and bow prices are 30% higher than before. Home prices are in part 3.
- **The camp fall** takes 30% of the leaves gained in the lost chapter only (New, 22 Nov 2026, loop fixes; it was 30% of
  all unspent leaves). Only the failed wave is retried; completed waves and their rewards stay completed.
- **After the raids** the Gloom Raids and the Burrows are the endless play. The home is not maxed when the
  raids end: homes 6 to 8 are dear, and mastery, mending and food pull on the same leaves.

### Growing stronger

The cat's stats (10 levels each, capped by the station, 4, 6, 8, 9 or 10 by the Target's level; Health, Move speed and Leaf magnet by the home level; most get 2 mastery levels after the raids), the bows (**New, 22 Nov 2026:** the four shop bows in the table in part 3, Twig to start and Frost last; Thorn Volley and
Foxfire are hidden), and the camp (part 3). Every exact price is in
`game/data/balance.json`. When the player has everything, the game is done and the Gloomwood is there for fun.

### Cat outfits

Outfits from the Tailor's Nook change the cat's look and keep her stats the same. **Original Ranger** is free
and owned from the start. **Dusk Ranger** costs 3,000 leaves and **Ember Ranger** costs 6,000 leaves.
Dusk wears teal; Ember wears crimson with gold trim and cream lining. Ember is the renamed Nightfall outfit;
existing owners keep it. Both preserve the cat's orange fur, face and gear.

Buy an outfit between waves and the cat puts it on at once. If you buy during a wave, tap **Wear** between waves
to put it on. Switching is free between waves, and the game saves what she wears.

**New (H5): the Nook's window.** The cat stands on a stand and turns. Tap an outfit card to **try it on** (only the
picture changes; the cat's real outfit does not). An outfit you don't own is grey but can still be tried on. The one
button reads Buy, Wear or Wearing. The window opens on the outfit she wears.

Paid outfits will use premium currency later. If the game cannot take an outfit's currency yet, its tile says
**Coming later**.

### The real-money plan

The owner's rules (18 November 2026):

- **Rewarded ads only**: an ad plays only when the player taps a button that says what they get. No ads between
  screens and no banners, ever.
- **Sold**: looks (new pets and mounts with the same strength, colour skins, cosmetics) and **attachments** for the
  pet and mount, which help only in the Gloomwood and can also be earned by playing.
- **Never sold**: leaves, timber, shards, amber, stats, raid progress, raid wins, the guardians, or
  anything that skips the raids. A player who never pays can get every gameplay thing by playing.

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
| Saddlery (New, 21 Nov 2026, G4) | The Saddlery building | The Bow Bench, tinted brown | None yet (made only when the owner asks) |
| Gloom Herald | Raid leader | The Crow Drummer, 1.25 times bigger | `concepts/enemies4/01_gloom_herald.png` |
| Grubling | Gloomwood | A small tinted Mole Sapper | `concepts/burrows/01_grubling.png` |
| Glowcap | Gloomwood | A small teal Toadstool Brute | `concepts/burrows/02_glowcap.png` |
| Root Snapper | Gloomwood | A tinted Pitcher Spitter | `concepts/burrows/03_root_snapper.png` |
| Amber Grub | Gloomwood | A small tinted Mole Sapper | `concepts/burrows/05_amber_grub.png` |

Later: the **Bramble Boar** (`concepts/companions/04_bramble_boar.png`, a fighter) and the **Lantern Owl**
(`concepts/companions/05_lantern_owl.png`, a helper) as new guardians; **2 or 3 more raid bosses** for raids
that end without one, for example 4, 9 and 12 (no concepts yet). Old Grubber (`concepts/burrows/04_old_grubber.png`)
is no longer needed.

### Play on the phone

- The 23 Nov APK is on the phone. Check whether squads read as teams, the barricade rows and camp cards are easy
  to use, and the Wishing Well's pace feels right.
- Play the Gloomwood: is the road long enough, are the fights and Mossback right, and does the night read well
  on the S24's screen?
- Check the top bar under the S24's real status bar and camera hole.
- A balance pass by play: run length, boss times, materials per run, prices, raids, the Warden, the garden's pace.
- **New (H3, 26 Nov 2026):** on the H3 APK, try dragging seeds and ingredients with a finger (the game's first
  drag-and-drop), close the game while crops grow or the pot cooks and come back later, use the potion buttons in a
  fight, and check that the old save's food, dishes and crops came over. On the PC at 540x960 the garden's card scrolls
  about 150 px to reach its Upgrade row (the window itself fits); at the phone's shape nothing scrolls.

### Decisions

- **New models for Phase F.** The Golden Grub, the Gloom Totem and Training Target / Bow Bench levels 3 to 5 use
  existing models for now. The owner makes them in Meshy (part 11, Rules).
- The money proposals in part 9.
- Buildings never fade, so the cat can be hidden behind them. How to handle that is open.
- The optional Moth Lantern and Bramble Snare (raid extras), only with the owner's yes.
- **New (H3):** the potion, Emberpepper and Swiftroot icons are stand-ins drawn in code. Designed icons come only when
  the owner asks. Cooked Fish has a bottle like the other recipes (the owner chose bottles); its light orange is close
  to the Damage Potion's orange.
- **New (H3):** the Gloomwood is harder without food heals (part 8, under "The road"). It is retuned in H8 and H11.

### Later

- **Random Raids redesign (23 Nov 2026; combat not implemented):**
  [`RAID_MISSIONS_AND_RANDOM_RAIDS_PLAN.md`](RAID_MISSIONS_AND_RANDOM_RAIDS_PLAN.md) records the owner's direction
  for one simultaneous assault from all four trails, adapting to player/camp capability, with guardian and later
  recruited-friend defence. The new catalogue/navigation is built; the existing random-raid combat backend remains.

- **Agreed direction, 23 Nov 2026; not implemented:** [`DUNGEON_EXPEDITIONS_PLAN.md`](DUNGEON_EXPEDITIONS_PLAN.md)
  records random expeditions across ten distinct dungeons as a release target, difficulty separate from location,
  meaningful variations, permanent discoveries and companions recruited to the campfire through quests. The current
  game still has one playable dungeon. Exact party, quest and difficulty rules remain to be discussed.

- Claude's own to-do: Blender models for home levels 7 and 8 and their campfires; sounds (raid horn, shards, the rout,
  a dash whoosh, the Warden, garden and fishing); attachments shown on the models; the bug review held to the end.
- Planned: more dungeons (some without a boss); more guardians, collected in dungeons, with guardian spots following
  the home level; bonds, fletching special arrows, decorating, daily and weekly tasks, an endless mode (Phase F);
  islands by boat, mount skills earned in dungeons, and paid outfits using premium currency.

---

## 11. For developers

Godot 4.7.2, Mobile renderer with the OpenGL fallback on, portrait (viewport 720x1280, stretch `canvas_items`,
aspect `expand`), capped at 60 fps (the cat's cloth simulation depends on the frame rate). GDScript only. The project
is `game/` inside `D:\Projects\Project LEAF`. **Since 20 Nov 2026 it is a git repository** holding only the game and
the docs (see `CLAUDE.md`). The art pipeline, concepts and tools stay local, so the backups below are still their
safety net.

### Architecture

- **One scene, built in code.** `main.tscn` is one Node3D with `scripts/main.gd`. Its `_ready()` builds, in order:
  `world.gd` (light, sky, ground, trails, woods, lake, collision), `fight.gd`, `raids.gd`, the joystick on a
  CanvasLayer (`joystick.gd`), the cat (`player.gd`), `defences.gd`, `garden.gd`, `cooking.gd`, `fishing.gd`,
  `stations.gd` (every building, its ring and its card), `burrow.gd`, the HUD (`ui/hud/hud.gd`, H2), the camera. Companions are
  added later by `main.refresh_companions()`: `pet.gd`, `mount.gd`, `npc.gd` (Bramble), `guardian.gd`.
- **Autoloads** (`project.godot`). **New (H1, 25 Nov 2026; H3 added Timers):** six now, in this order: `Events`
  (`core/events.gd`, first: the signals and who sends them; read the file), `Data` (`data.gd`: `balance.json`, the
  derived numbers, costs and currencies, `Data.args()`; it also reads `content/index.json` through `catalog()` and
  `item()`), `Save` (`save.gd`), `Timers` (`core/timers.gd`, H3: the real-time jobs), `Quality` (`quality.gd`) and
  `Pools` (`core/pools.gd`). Static helpers by `class_name`: `Fx` (effects), `Props` (loads Blender props or builds
  placeholders), `Sfx` (sounds; a missing sound plays nothing), and since H3 `Bag` (`core/bag.gd`) and `Effects`
  (`core/effects.gd`).
- **Markers and cards.** Each usable thing has a marker (`marker.gd`, the leaf-shaped badge); `interact.gd` picks the
  marker under a tap and opens its card with `hud.show_card(...)` (the code is in `ui/hud/card.gd`), walking the cat there first if it is out of reach.
  A card is a dictionary `{title, sub, rows, anchor}` built by `stations._card_*()`, `burrow.card()` or
  `raids.card_watch()`; a row is `{text, note, cost, label, enabled, action, pulse}`. The home's card builds its
  "Grow the home" rows from `Data.home_goals(level)` (see Phase F below).
- **fight.gd** runs raids (`mode = "mission"`) and Gloom Raids (`mode = "raid"`, started by `raids.gd` with
  `start_raid`). A Burrows run never uses fight.gd's waves and must leave `fight.mode` at "raid"; `start_raid`
  refuses while any fight is active.
- **enemy.gd** is every enemy. It loads `assets/enemies/<id>/<id>.glb` and its JSON, or a stand-in from the
  `model`, `scale` and `tint` keys of its `balance.json` entry. When the real model lands, delete those three keys.
- **The clock rule** (changed in H3, 26 Nov 2026). Only `core/timers.gd` reads the wall clock, through `Timers.clock`
  (and the 3→4 save step reads that same clock). Its jobs (the crops and the pot) are the only things that run while
  the game is closed. Everything else still runs on frame time: it clamps it (`minf(delta, 0.1)`) and stops while
  `main.frozen` (the app is paused), and that includes the raids, the Well, the mount's rest and the potions' effects.
  A grep for `get_unix_time` outside the autotests should find only `core/timers.gd` and `core/save_upgrades.gd`.

### The far-away area contract (dungeons)

A dungeon is built in the same scene, far from the camp: at `burrows.origin` (400, 0, 0), beyond the camera's far
plane (120 m) and the sun's shadow box, so the camp is not drawn while the cat is in it.

- While a run is on, `main.area` points to the runner (`burrow_run.gd`, `main.burrows.runner`); otherwise it is
  null. Camp systems check it: the raid meter does not fill and a pending raid's warning waits (`raids.can_fill`,
  `blocked_reason` "away"), the Leaf Dash is enabled (`main.dash_enabled`), the HUD hides the build icon and the
  defence buttons (H3: Ride and the two potion buttons stay; Feed and Snack are gone).
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
  changes: a saved run on another version is closed kindly (satchel banked).

### The data files

| File | What is in it |
|---|---|
| `game/data/balance.json` | The general rules. Blocks: `cat`, `stats`, `stations`, `home_names`, `bows`, `defences`, `enemies`, `patches` (the 4 trails), `missions` and `mission` (the rules and pay; Phase F keys below), `raid` (the **raid** camp-falls numbers), `gloom_raids`, `guardian`, `garden`, `ingredients`, `cooking`, `fishing`, `looks`, `building_hp`, `burrows`, `attachments`, `save_upgrades`, (New, G1b and G2) `squads`, `enemy_roles`, `market`, `camp_name`, and (New, H3) `timers`, `bag`, `potions`. Most blocks start with a `_note`. |
| `game/content/<kind>/<id>/entry.json` | **New (H2, H3):** one folder per thing (`docs/ARCHITECTURE.md` part 5): `settings/` (graphics, sound), `crops/` (5) and `recipes/` (5). `content/index.json` lists every folder by kind; it is written by hand until `tools/build_content_index` exists, and `--content` checks it. |
| `game/data/dungeons/<id>.json` | One dungeon map: spine, clearings, branches, arena, fights, checkpoints, chests, traps, lanterns, `floor`, woods, theme, `end`. Positions are `[x, z]`, `{"s": arc length, "off": metres right}` or `{"in": clearing}`. |
| `game/assets/<group>/<id>/<id>.glb` and `.json` | Characters (enemies, companions, NPCs): clips, events, speeds, spring chains |
| `game/assets/props/*.glb` and `<group>.json` | Blender props and their lists (`camp_life.json`, `raids.json`, `burrows.json` and others) |
| `art/palette.json` | The shared colours for props |

The Android export includes `*.json` and leaves out `_autotest/*`, `build/*` and `*.md`.

### Phase F: home goals and fair raids (New, 19 Nov 2026)

The design is `docs/PHASE_F_PLAN.md`. The numbers are all in `balance.json`.

- **Data keys.**
  - `stations.camp.levels[n]`: the price (`leaves` and `timber`; no materials since H1) and
    `goals`. Goal types: `mission {n}`, `station {id, level}`, `stat {id, level}`, `bow {id, level}`, `bow_any
    {level}`, `bow_owned {id}`, `towers {count, level}`, `defence {id, level}`, `all_stats {level}`, `depth {n}`.
    `needs_burrows` and `needs_depth` on homes 6 to 8 are kept for older code.
  - `stations.target` and `stations.bench`: 5 levels. `stat_cap_by_station_level` and `bow_cap_by_bench_level`:
    `[0, 4, 6, 8, 9, 10]`.
  - `missions[i].needs_home` (the home level to start it; **all 1 since 21 Nov 2026**, so no raid is gated), `reward` (leaves, timber), optional `strength_mult`,
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
  lets a test start any raid. The groups **"bonus"** (the Golden Grub: it never holds a wave up) and **"totems"**
  (the Gloom Totem: a foe the wave waits for).
- **Old tests.** Tests that start a won raid (replays) or a raid past the home gate, after `_veteran`, fail or
  need `skip_gate`.

### Phase G1: the fixes (New, 20 Nov 2026, G1)

The design is `docs/PHASE_G_PLAN.md` (step G1). The numbers are all in `balance.json`.

- **Data keys.**
  - `mission.wave_limits` (groups with `max_alive`, `tanks_at_once`, `tank_share`; `tank_weight`; `boss_others_on_field`).
    The groups are raids 1 to 5, 6 to 10 and 11 to 15.
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
  - Data: `missions[].chapters[].squads` (the squads of each chapter), `boss_escort` (the escort squads of raids 6,
    13 and 15), `squads` (the 12 squad definitions), `enemy_roles` (light, fighter, tank or support for each enemy)
    and `mission.squad_rules` (from raid 2 at least 2 kinds; from raid 3 about 40% per kind at most).
  - `fight.gd`: `plan_queue` now plans squads; the old pool code is `_pool_queue`; `_spawn_squad` spawns one squad on
    one road. Random Raids instead use their own single roster of small mixed groups across all four trails.
  - `enemy.gd`: `_keep_formation` (the spacing and pace of a squad member) and `leave_squad` (the break-up rule: within
    6 m of the firelight, the leader dead, or the cat close).
  - Raid 1's first win gives 60 leaves, not barricade pieces.
- **G2, the Hearthtree.**
  - `camp_name` in `balance.json`, and `Data.camp_name(cap)` for the name. Level names are unchanged.
  - The Mushroom Cottage and the Market have `needs_home` 2 (H5: the Cottage's entry is gone). The `market` block holds its sells, buys and prices. Thistle
    comes free with the Market. Old saves keep their buildings and pets.
  - Barricades are rows on the 12 road spots (3 per road). Each piece cracks below 50% health and breaks at 0.
    Old placed barricades became rows and bag pieces were refunded as leaves. The session's later pad and repair
    rules are under "Barricades and the Well" below.
  - Tower repair: a repair marker on a knocked-down tower. The badge price now matches Mend (see Loop fixes).
  - The Wishing Well is automatic (no wishes). Its heal percents and the rates in waves are in `balance.json`.
  - Shop cards: `ui_icons.gd` draws 32 icons in code. `ui/hud/shop_tiles.gd` and `card.gd` have the row kinds `section` and `item` (items are tiles,
    two per row on a phone). A row is still `{text, note, cost, label, enabled, action, pulse}`, with `kind` for these two.
- **Tests:** `--rows` (`autotest_g2_def.gd`), `--campg` (`autotest_g2_camp.gd`), `--cards` (`autotest_g2_cards.gd`,
  screenshots; run at 480x1040 with `--safe-top=73 --safe-bottom=42`), and `--fightf`, updated for squads.
- **Results on the PC:** `--smoke` OK, `--fightf` 55 pass, `--homegoals` 45, `--rows` 46, `--campg` 45, `--enemyf` 22,
  `--cards` 55; no failures.
- **Backup** before G2: `D:\DevCache\backup\pre_phase_g2_20261120_1429`.

### Phase G3: the Bow Shop (New, 21 Nov 2026, G3)

The design is `docs/PHASE_G_PLAN.md` (step G3). The numbers are in `balance.json`.

- **Data.**
  - `stations.bench.name` is "Bow Shop" (the station id is still `bench`).
  - The shop uses `bows` for Twig, Sunwood, Ember and Frost. Thorn Volley and Foxfire have data and assets and
    are hidden in the shop. `Data.bow_burn` reads Ember's 3 s burn at 25% of the hit's damage per second.
  - `Data.craft_cost` takes leaves and timber.
- **Code.**
  - `stations.gd`: `_card_bench` (the card), `_bow_tile` and `_bow_note` (the tiles and their badges), `_craft` (buy),
    `_equip`, `_upgrade_bow`, `_locked`.
  - `player.gd`: `apply_bow` swaps the bow model into the cat's `SK_CatBow` (`_bow_parts`, a named-bind skin). Glowing
    parts use a second material `M_Glow` that keeps its glow (`Props.apply_vc_glow` / `Props.vc_surfaces`).
  - `arrow.gd` picks the arrow model and applies the shot's effects. `enemy.gd` handles burn, slow and freeze.
    `fx.gd` draws the release bursts, trails, hit effects and Frost's ice. A tile row may carry a `picture` (`ui/hud/shop_tiles.gd`).
  - `CatRanger.glb` has revised Idle, Walk and Run carry poses and no bow spin after release in Shoot.
    `bow_face.gd` rolls the paw in place to turn the string toward the chest when carrying, using
    `cat.bow_face_max_deg`. During draw the animation already points the string at the cat.
- **Files.**
  - Bows `game/assets/cat/bows/bow_<id>.glb`, arrows `game/assets/cat/arrows/arrow_<id>.glb`, tile pictures
    `game/assets/ui/bows/bow_<id>.png`.
  - A bow or arrow without a file falls back to the cat's own bow tinted, and the plain CatRanger arrow.
  - Claude made bow and arrow models in Blender under the owner's exception. The owner approved the first
    set on 21 Nov 2026. Bows are skinned to two bow bones (`weapon.L` for the grip and `bowstring`), so drawing still
    pulls the string. The limb tips bend about 2.5 cm at full draw.
  - Blender pipeline `art/scripts/bows/` (`run_all.sh`), exports in `art/export/bows/`, pictures in
    `art/previews/bows/`. These art folders stay local (not in git).
- **Tests:** `--bowshop` (`game/scripts/autotest_g3_bow.gd`); see the test modes table.
- **Results on the PC:** `--bowshop` passed 61 checks after the new balance and effects. `--smoke` completed.
- **Backup** before G3: `D:\DevCache\backup\pre_g3_20261121`.

### Phase G4: the Saddlery (New, 21 Nov 2026, G4)

The design is `docs/PHASE_G_PLAN.md` (step G4). The numbers are in `balance.json`. What the player sees is in part 5
("The Saddlery").

- **Data.**
  - `stations.saddlery` (the building), `saddlery` (its levels and prices), `mount_skills` (the four skills),
    `mount_attachments` (the three attachments), `building_hp.saddlery`.
  - The old `mount.thump_*` keys are kept but no longer used.
  - Helpers in `data.gd`: `saddle_items`, `saddle_price`, `saddle_block`, `skill_damage`, `mount_hp_mult`, `leaf_bonus`,
    `saddlebag_leaves`.
- **Code.**
  - `stations.gd`: `_card_saddlery` (the card with its sections Skills, Attachments, Upgrade), `_saddle_tile`, `_saddle_buy`.
  - `mount.gd`: the skills and their timers, `try_move`, the Fire-spitter, the Pounce and Ram movement.
  - `save.gd`: `Save.saddlery` holds `skills`, `attach` and `worn`. The worn attachment alone shows and
    works. `migrate_saddlery()` handles old saves (see part 5).
  - `fireball.gd`: flame-ball flight, swept collision, splash damage and burn. `player.attack_interval` supplies its pace.
    `Data.cat_range` supplies its range. The attachment's `fire_aim` node rotates the firing unit; `marker_nozzle` is
    its +Z firing axis. `mount.gd` keeps the target lock and smooth aim independently of the mount's heading.
  - `enemy.gd`: `stun`, `shove`, `bellowed`. `fx.gd`: `fireball`, `fireball_hit`, `bellow`. `ui_icons.gd`: icons stomp, ram, pounce,
    bellow, saddlebags. `marker.gd`: the saddle badge. `world.gd`: the Saddlery spot (5, 0, 8).
- **Riding and models.**
  - `ride_motion.gd` makes the cat move with the saddle, lifts and tilts the carried bow, and eases her
    away from sampled mount head and ear points. The mount follows joystick travel using its original forward gait.
    `mount.aim_cone_deg` sets the half-arc, and `aim_cone_keep_deg` adds edge tolerance to an existing lock.
    `assets/cat/mounted/shooting.res` supplies five upper-body loops, blended by mount-relative bearing in `player.gd`.
    The character root follows the mount; the animation layer is filtered from the spine upward. The procedural seat
    remains active while shooting. The loops share the Shoot draw/release clock. Movement and clearance use `mount.ride_*`.
  - `lifebar.gd` draws the amber mount bar. Mounts' GLBs and clip lists are under `assets/companions/`,
    with Claude's six gear models in `attachments/` (three for each mount). The Blender scripts
    and previews are in the local `art/` folders.
- **Tests:** `--saddlery` (`game/scripts/autotest_g4_saddle.gd`); see the test modes table.
- **Results on the PC:** `--saddlery` passed 94 checks, including flame balls, splash, firing cadence, arrow range and tracking while steering. Add `--rideclear` to measure rider clearance.
  The `--topup` and `--raidloss` failures listed in `docs/CHANGES.md` are gone since H1: both pass on 25 Nov 2026.
- **Backup** before G4: `D:\DevCache\backup\pre_g4_20261121` (scripts, data, both mounts' files and `.blend`).

### Loop fixes (22 Nov 2026) (New, 22 Nov 2026, loop fixes)

A loop check on 21 Nov 2026 found three loops: a camp fall ate the savings needed for the Hearthtree (the owner's save
was stuck that way), each act's last raid had to be won before the Hearthtree could grow, and two repair prices
drained leaves. Five fixes, each approved by the owner:

1. **A camp fall takes only the lost chapter's leaves.** The Gloom takes `raid.leaves_share` (30%) of the leaves gained
   since the chapter began, never more than the cat holds. Code: `Save.leaves` has a setter that adds every rise to
   `Save.mission_run["gain"]` while `Save.count_gain` is on (from a raid wave start to the chapter break, fall or end);
   `fight.chapter_gain()`, `fight.last_fall_lost`. It survives a saved run and an app restart. Raids still take nothing.
2. **Hearthtree goals one raid earlier:** `stations.camp.levels[1..4].goals`. Hearthtree 2 needs raid 1, 3 raid 5,
   4 raid 9, 5 raid 12. Hearthtree 6 (raid 15), the Gloomwood and 7-8 are unchanged.
3. **The Hearthtree's repair is capped:** 10% of its cost, at least `ruin_min`, at most 900 leaves and 30 timber, in the
   raids too. Code: `gloom_raids.repair`. Other buildings keep the 30% price.
4. **A knocked-down tower's repair badge costs what "Mend the defences" costs for that tower** (leaves only). Code:
   `defences.gd` `mend_price(p)`. `defences.tower.repair_share` is no longer read.
5. **The Saddlery needs Hearthtree level 2** (and 8 raids won). At Hearthtree 1 its tile says "Needs the Hearthtree at
   level 2".

- **Tests (PC):** `--smoke` OK, `--homegoals` 46, `--rows` 48, `--campg` 47, `--saddlery` 46, `--fightf` 64 (new fall-gain
  checks), `--laststand` 1 (it runs again with `fight.skip_gate`), `--raidloss` 12 pass and 2 old failures (it tries to
  replay a won raid, which is refused since Phase F).
- **Backup** before the fixes: `D:\DevCache\backup\pre_loopfix_20261121`.

### Bow and Hearthtree balance (22 Nov 2026) (New, 22 Nov 2026)

The owner approved these balance changes, and Claude built them. The numbers are in part 3 (the Hearthtree prices and
the bow table) and in `balance.json`.

- **Data.**
  - `stations.camp.levels`: the leaves and timber prices of Hearthtree levels 2 to 8, and the Frost Bow goal on level 6.
  - `bows`: each shop bow has `draw_mult` (Twig 1.0, Sunwood 1.1, Ember 1.0, Frost 1.25; higher = longer draw time).
  - `cat.min_range_m` (2.0 m): the floor for the cat's range.
- **Code.**
  - `Data.bow_draw_mult(id)`. `Data.cat_range()` applies the 2.0 m floor.
    - `Data.bow_level_mult(id, level)` applies `bow_upgrade_curve` to existing and newly purchased bow levels.
  - `player.gd`: the draw speed is `Data.cat_draw() / Data.bow_draw_mult(Save.bow)`.
  - `stations.gd` `_bow_note` builds each bow tile's pro and con.
- **Tests (PC).** `--bowshop` 61 pass, `--homegoals` 48 pass, `--smoke` OK.

### Barricades and the Well (22 Nov 2026) (New, 22 Nov 2026)

Three changes and four review fixes, built and tested on the PC.

- **Repairs any time.** A built row's marker stays visible and tappable in a wave, and its card's Repair is enabled.
  Before, three checks blocked it in a wave: the markers were hidden, the tap card showed "A wave is on!", and
  `repair_row` refused. Building rows and repairing towers stay between waves only. The price per piece is in part 4
  (Defences).
  - Code: `defences.gd` `_marks_state`, `repair_row`, `repair_row_cost` (the cracked-piece floor of 0.5 is new); `ui/hud/card.gd`
    `_spec` (the card).
- **Pads follow each road.** `world.gd` uses `balance.json` `defences.barricade.pad_rule` to place the gate 2.4 m from
  the firelight along the road and the far pad near the woods' edge. Fernwood and Bandit Thicket use `patches[].far_pad`
  to bring the far pad toward camp and unlock it at Hearthtree 4. Their `even_barricade_spacing` setting puts the middle
  pad halfway between the other two along the road. The left roads use the sharpest outer bend. Rows keep their saved
  `[lane, index]`. When the Hearthtree grows, `main.on_camp_grown()`
  rebuilds the roads and then calls `defences.rebuild()` to move the rows, collisions and markers with their pads.
- **The Well mends to full.** Everything damaged but not broken goes back to full health by itself: the campfire, the
  Hearthtree and buildings, barricade pieces and towers. `balance.json` `well.passive`: `between_by_level` (3%, 6%,
  10% a second) and `regen_by_level` (0.5%, 1%, 2% a second in waves). The old `cap_by_level` (60/75/90%) and
  `between_per_s` are gone. Code: `defences.gd` `well_mend`; `stations.gd` `well_between`; `ui/hud/card.gd` for the card text.
  A tower the Well mends to full loses its dark "wrecked" look (review fix 1).
- **Review fixes (Opus code review):**
  1. A tower the Well mends to full loses its dark "wrecked" look.
  2. The cracked-piece price (see the first item).
  3. `bow_face.gd` (turns the string toward the cat) now rolls the paw in place, so the wrist stays on the arm. It eases
     its turn, keeps its direction near 180 degrees, and is off while fishing.
  4. While riding, the cat's lean away from the mount's head is applied last, as one turn at the spine, so aiming no
     longer undoes it.
- **Riding overlap after fix 4** (negative = into the cat):

  | Thistle move | Before | After |
  |---|---|---|
  | Stomp | -4.8 cm | +0.6 cm (clear) |
  | Pounce | -8.2 cm | -2.2 cm |
  | Bellow | -13.6 cm | -7.1 cm |

  Bramblewool is clear in every move except Stomp at -0.1 cm. **Still open:** Thistle's Bellow overlaps the cat by
  7.1 cm. A toned-down head throw in that mount animation would fix it (not done).
- **Tests (PC):** `--rows` 57, `--campg` 49, `--layout` 118, `--saddlery` 52, `--smoke` OK.

**Pads open by ring (New, 22 Nov 2026).** The owner chose this. The old row limit (2, 3, 5, 7, 9, 12 by home level) was
replaced because the owner's save had 8 rows at Hearthtree 4, where the limit was 7, so every empty pad refused to build
without saying why. Now `balance.json` `defences.barricade.rings_by_home` = [0, 1, 1, 2, 2, 3, 3, 3, 3] sets how many rings are open.
The indices are 2 for the gate, 1 for the middle and 0 for the far pad. A road can open its far pad before the far ring.
`rows_by_home` is no longer used. Code: `defences.gd` `rings_open()`, `pad_open(lane, idx)`, `pads_open_count()`,
`build_row`, `_marks_state`, `_refresh_marks`, `_card_spot` and `_price_words()` (the plain reasons on the card);
`row_cap()` and `row_room()` are removed; `main.gd` has the barricade tip. Old saves keep rows on closed pads.
- **Final placement tests on PC.** `--rows` passed 94 checks, including the right-hand unlocks at Hearthtree 4 and
  pad spacing and positions at every Hearthtree level.
  `--layout` passed 118 checks through the game's own Hearthtree growth path. `--smoke` completed cleanly.

### The Market, the pets, the Saddlery and the Tailor's Nook (New, H5, 27 Nov 2026)

Step H5. The game side is parts 3 and 5. The owner's answers are in `docs/PHASE_H_PLAN.md`, H5. The change list is in
`docs/CHANGES.md`.

- **Content kinds** (`content/`, listed in `content/index.json`, read through `Data.shop_entries`, `Data.item`,
  `Data.owned_level`, `Data.companion_model`, `Data.shop_picture`): `mounts` (thistle, bramblewool), `pets` (sprig,
  lumi), `outfits` (original, dusk_ranger, nightfall_ranger) and `attachments` (fire_spitter, saddle, saddlebags,
  mount_shoes, pet_lantern, pet_charm, pet_bell). The rules are in `scripts/shop_data.gd` (static functions, preloaded
  by `data.gd`). `content/README.md` says how to add one.
- **Buying:** one **Buy** command (`commands/buy.gd`: `Buy.new(kind, id, amount, expected_level, look_id)`, `can_run`,
  `run`) is used by every shop window. `expected_level` is the level the button showed, so a stale tap buys nothing.
  `scripts/market_trade.gd` holds Bramble's offers and prices (`offers`, `quote`, `sell`) and `scripts/companion_shop.gd`
  the looks and the circles (`choose`, `assign_skill`). The command never saves; `stations.gd` saves and shows the
  receipt (`market_trade(side, id, bundles)`, `_buy_companion`, `_train_pet`, `_saddle_buy`, `_buy_skin`, ...).
- **Windows** (`ui/windows/`): `market_window.gd` with `market_trade_tab.gd`, `market_companions.gd` and
  `market_words.gd`; `saddlery_window.gd` with `saddlery_skills.gd` and `attachment_inspect.gd`; `tailor_window.gd`
  with `outfit_preview.gd`. Kit: `ui/kit/item_popup.gd` (the amount popup) and `skill_triangle.gd`. Tests reach them as
  `hud.windows["stall"]` (`select(t)`, `tab_ids()`, `tab_spec(t)`, `entries(t)`, `inspect(id)`, `back()`, `open_on(t)`,
  `.trade`), `hud.windows["saddlery"]` and `hud.windows["tailor"]` (`entries()`, `try_on(id)`, `selected_id()`).
- **The save is version 5** (`core/save_upgrade_v5.gd`, frozen numbers in `balance.json save_upgrades.to_v5`). What a
  player owns is `owned[kind][id] = {"level": n}`. New fields: `owned`, `pet_level`, `market_hp_floor`;
  `saddlery` is `{skills, skill_slots, worn, mount_credit}`; `attach` is `{mount, pet}` (the worn ones). The 4 to 5 step:
  the Cottage's level becomes `pet_level` and Sprig and Lumi are owned; the Market becomes level 1, its old level is
  the mount's `mount_credit` and its earned health is `market_hp_floor`; outfits and both attachment families move into
  `owned`; the learned skills fill `skill_slots` as Stomp, Ram, Pounce.
- **Levels now come from other places:** `Data.pet_level()` (the shared pet level), `Data.mount_level()` = the highest
  of 1, the Saddlery's level and `mount_credit`, or 0 while no mount is owned. A new home goal type is `pet_level`.
  `mount.speed_by_level` and `hp_by_level` have six entries (0 to 5). `raids.camp_score` counts the pet's level and the
  mount's level (capped by `camp_score.mount_level_cap`), so an old save's raid strength stays the same.
- **Gone:** the Cottage's window, entry, marker badge and `Raids.trade_shards` (and `gloom_raids.shard_trade`); the old
  balance blocks `looks.mount`, `looks.pet`, `cat_skins`, `attachments` and `mount_attachments` (only `looks.guardian`
  is left in `looks`). The Cottage's asset and its prop stay in `assets/`. `Data.word` reads the new words
  (`pet_joins`, `head_outfits`, and the Market's in `balance.json windows`).
- **Camp:** `world.gd` keeps the Cottage only in the legacy hide-spot map (`OLD_VILLAGE`, `OLD_DOOR`, `_legacy_built`),
  so an old player's tall grass stays where it was. `main.refresh_companions` brings the pet out when `pet_level() > 0`,
  the mount when one is owned, and Bramble when the Market is built.
- **Tests:** `--campg`, `--saddlery`, `--tailor`, `--cards`, `--content` and `--saves` were rewritten or extended, and
  `--layout`, `--hudcheck`, `--taps`, `--bag`, `--topup`, `--homegoals`, `--buildmenu`, `--village`, `--wear` and
  `--shards` were moved to the new windows. New `--h5found`. Results are in `docs/STATUS.md`.

### Tailor's Nook and cat outfits (23 Nov 2026)

- `balance.json` holds the building price and unlock in `stations.tailor` and the outfit prices in `cat_skins`.
  The outfit IDs are `original`, `dusk_ranger` and `nightfall_ranger`.
  The last ID now displays **Ember Ranger**; it stays unchanged internally to preserve old saves and purchases.
- (Before H5. Since H5 the card is `tailor_window.gd` with `outfit_preview.gd`, see "The Market, the pets, the
  Saddlery and the Tailor's Nook" above, and `balance.json cat_skins` is gone: the outfits are `content/outfits/`.)
  `stations.gd` builds the outfit card with `_card_tailor` and `_skin_tile` and handles buying and wearing with
  `_buy_skin` and `_wear_skin`. `data.gd` has the `cat_skin_*` helpers. `save.gd` stores `cat_skin` and
  `cat_skins_owned`. `settle_cat_skin` defaults older saves to Original Ranger and resets an invalid choice.
- `player.gd` picks and checks the model with `hero_base` and `_hero_ok` and swaps it with `apply_skin`. A missing
  or broken outfit model falls back to the original look. The outfits reuse the Cat Ranger's skeleton and animation
  clips, so riding, bows, cloth and attachments keep working. Each outfit adds four cloth bones for its cloak
  (`cloak.L.1`/`.2`, `cloak.R.1`/`.2`, on the hips; built by `art/scripts/cat_skins/cloak_bones.py`): `cloth.gd`
  swings them (FEEL `cloak_top`/`cloak_hem`, thigh and shin capsules), and `cloth_fit.gd` keeps them off the legs
  and tail and tucks the tunic's back flaps under the cloak. The original cat has no cloak bones and is unchanged.
- The outfits follow the owner's Meshy designs. The cloaks and the Nook were rebuilt as clean geometry to match the
  designs because the Meshy pieces were too broken to clean up. Sources are in `art/source/meshy/`, build scripts in
  `art/scripts/cat_skins/` and exports in `art/export/cat_skins/`.
- Outfit models and clips go at `res://assets/cat/skins/<id>.glb` and `res://assets/cat/skins/<id>_clips.json`.
  Original Ranger uses the base hero model. Shop pictures go at `res://assets/ui/cat_skins/<id>.png`. The Nook
  model is `res://assets/props/tailors_nook.glb`, and its spot in `world.gd` is `(8.9, 0, 5.2)`.
- **Codex review fixes.** The Nook collision radius is 1.35 m (`stations.gd`) and its interaction ring is
  1.95 m out on the camera's side (`world.gd`). An active fight gives newly built attackable stations their
  full health. `Data.cat_skin_buyable` blocks purchases without a model file. `hero_clips()` follows the
  model that actually loaded, including an Original Ranger fallback.
- `--tailor` (`game/scripts/autotest_cat_skins.gd`) passed 63 checks. `--layout` passed 132 checks with the Nook.

### The new core (New, H1, 25 Nov 2026)

The first pieces of `docs/ARCHITECTURE.md` (the target structure). Step H1 only.

- **`game/core/`:**
  - `events.gd`: the event board, with 14 signals (enemy_died, damage_dealt, currency_changed, item_gained,
    bag_changed, wave_started, wave_ended, raid_started, raid_ended, mission_won, building_upgraded, timer_finished,
    quality_changed, save_loaded). Code sends them; later steps make the HUD listen.
  - `pools.gd`: pooled arrows, damage numbers and text pop-ups, hit bursts and sprays, and leaf and timber pickups.
    Pool sizes are in `balance.json` `pools`, per graphics level. A pool that runs out makes more.
  - Shockwave, swipe, flower_ring and bellow now share one mesh and one material per colour (`fx.gd`).
  - `save_upgrades.gd`: versioned save upgrades. Its one step so far, 2→3 (H1 part 3), turns old amber, glowstone, heartwood and Hollow keys into leaves (`balance.json` `save_upgrades.to_v3`).
- **`game/content/`:** `index.json` was empty in H1 (H2 added `settings`, H3 `crops` and `recipes`). `Data.catalog()`
  and `Data.item()` read it.
- **`game/tests/`:** sample saves for `--saves` (`v2_sample.json` and `v3_sample.json`; H3 added `v4_sample.json`). The folder is left out of the phone build.
- **Balance blocks:** `kill_leaf_bonus` (1.3, see part 9), `save_upgrades` (`to_v3`: the frozen rates for the 2→3 step), `burrows.amber` (the amber drops) and `pools` (arrows, numbers, hit_fx, pickups: three numbers
  each, for Low, Medium and High).
- **Save notes:** under "Saving".
- **Raids:** `raids.gd` holds a Random Raid until every raider is defeated. The leader no longer routs the others.
  Stragglers walk to the campfire after `flee_after`.
- **Home goals check:** `--homegoals` also checks that no Hearthtree goal asks for a station that is not open yet.
- **Text:** "Burrow" became "expedition" in player-facing text. Code names (`burrow.gd`, `burrow_run.gd`) are
  unchanged. The Gloomwood and the Old Hollow keep their names; the Gloomwood's grub holes are "The Grubling holes".

### The new HUD and Settings (New, H2, 26 Nov 2026)

Step H2. The screen is described under "The screen" in part 2.

- **`game/ui/hud/`:** `hud.gd` is the facade (every public name kept, so old callers still work). Its parts:
  `hud_style.gd`, `hud_layout.gd` (the screen rectangles), `top_bar.gd` (currencies, gear), `fight_bar.gd` (raid bar,
  campfire bar, words line, boss bar), `messages.gd` (banners, toasts, status), `action_buttons.gd`, `card.gd` and
  `card_signpost.gd` (the cards), `shop_tiles.gd`, `hud_icons.gd`, `lifebar.gd`, `threat_arrows.gd`, `health_bars.gd`
  (the Bag's health bars, with `scripts/inventory.gd`), `settings_window.gd` and `slide.gd` (the 0.2 s slide and fade).
- **The HUD listens to Events:** `currency_changed`, `fight_progress(done, total)`, `riding_changed`,
  `mount_down_changed`, `placing_changed`, `area_changed`, `boss_changed`, `campfire_hit`, `wave_ended`, `raid_ended`.
- **Commands:** the Ride/Walk button sends the Ride command (`game/commands/command.gd`, `game/commands/ride.gd`).
- **Settings:** `game/core/settings_file.gd` reads and writes the settings file (atomic write, like `save.gd`).
  `Quality.set_level` and `Quality.set_auto` change the graphics; `Sfx.set_sound` turns sound on or off.
- `fight.wave_total()` counts boss summons, so the raid bar's total is right.
- **Layout check:** every visible HUD edge control is in the group `hud_edge`. The layout test checks that none enters
  the middle third and no two overlap.
- **Persistent buttons** leave `ui_block` and stop taking touches when they start to fade out, and `build_buttons()`
  skips hidden ones, so the joystick and the tests do not misread them.

### Food, potions and the Bag (New, H3, 26 Nov 2026)

Step H3. The game side is part 6. The owner's answers and the defaults that were built are in `docs/PHASE_H_PLAN.md`,
H3.

- **New files:**
  - `core/timers.gd` (autoload `Timers`, right after `Save`): real-time jobs. A job is `"<kind>:<key>"` (`crop:0` …
    `crop:5`, `cook:pot`); its kind must be in `balance.json timers.jobs`. API: `now`, `start`, `has`, `done`, `left`,
    `progress`, `job_data`, `set_job_data`, `shorten`, `remove`, `ids`, `check`, `use_real_clock`. `now()` never goes
    below `seen`, so a clock set back makes jobs wait. `check()` runs every `timers.check_every_s` (1 s), on resume and
    focus, and 1 s after a save loads; each job that ended sends `Events.timer_finished(id)` once. Timers never changes
    the game itself (no Bag, no Gloom meter, no leaves), and raising `seen` alone never marks the save dirty.
  - `core/bag.gd` (`class_name Bag`, static): the only writer of the counts. Food, fish and potions in `Save.bag`,
    towers and spikes in `Save.items`, amber in `Save.mats`. The kinds come from data (`ingredients`, `content/recipes`,
    `Data.MATS`, `defences.<id>.from_bag`). `add(id, n, force)` puts in only what fits unless `force` (a thing already
    paid for). It sends `item_gained` and `bag_changed`. The `Data.has_items`, `take_items` and `add_items` wrappers
    stay (fishing uses them); the Market and the pot call Bag directly.
  - `core/effects.gd` (`class_name Effects`): the effects list, types `heal`, `heal_over_time`, `stat_mult` and
    `revive`, with `known`, `reason`, `apply` and `hud_potion`. `parts/effects_holder.gd` (the child "Effects" of the
    cat and of the mount) runs the timed ones on frame time; the cat's hands Data the full map of running stats
    (`Data.set_effect_mults`, read by `Data.effect_mult` in `cat_speed()` and `arrow_damage()`).
  - `commands/use_potion.gd`: `UsePotion.new(id).can_run(main)` ("" or the reason) and `.run(main)`. The HUD's potion
    buttons, the Bag's Use and the tests send it. It never calls the HUD and never saves.
  - `ui/windows/garden_window.gd` and `ui/windows/cooking_window.gd`: the two windows, shown in their card as a row
    `{"kind": "window", "window": hud.garden_window}` (card.gd). The window API: `content()` (safe to call again on any
    rebuild), `tick(delta)`, `opened()` (once per visit) and `closed()` (when the card closes or another replaces it,
    never on a rebuild or a wave blank). The cards have a stable `view_id`, so a leaf pickup does not rebuild them
    under a drag. The windows hold no rules: those are in `garden.gd` and `cooking.gd`.
  - `ui/kit/drag_source.gd` and `ui/kit/drop_slot.gd`: the game's first drag-and-drop (seeds onto plots, ingredients
    into the pot). Payloads `{"kind": "seed" | "food", "id"}`. A press that moves less than 12 px is a tap.
  - `content/crops/<id>/entry.json` (sunberry, fernmint, honeybell, emberpepper, swiftroot: `gives`, `yield`, `grow_s`,
    `price`, `unlock`, `model`, `icon`) and `content/recipes/<id>/entry.json` (health_potion, mount_potion,
    cooked_fish, damage_potion, speed_potion: `needs`, `cook_s`, `limit`, `unlock`, `effects`, `color`, `icon`). A
    recipe is its result's type: its id is the Bag item's id. `icon` is a `ui_icons.gd` id and `model` the base of
    the Props ids (`<model>_growing`, `<model>_ripe`) until the art moves into the folders. `Data.unlocked(rule)` knows
    `{}` and `{"building": [id, level]}`.
- **Rewritten:** `garden.gd` (plots are `{"crop": id}`, growth is the job `crop:<i>`; `plant`, `water`, `pick`,
  `wants_pulse`, `window_opened`), `cooking.gd` (the job `cook:pot`; `known`, `match_recipe`, `can_cook`, `cook`,
  `collect`, `wants_pulse`), `scripts/inventory.gd` (the Bag window), `defences.gd` (counts through Bag, the drop-in,
  the ghost's rule shared with the start-up check), `ui/hud/action_buttons.gd` (`potion_button`,
  `mount_potion_button`, `tick_potions`), `ui/hud/top_bar.gd` (the running potions line, `hud._meal_l`), and
  `ui_icons.gd` (stand-in icons `peppers`, `roots` and the five potions).
- **Gone:** the dish lifecycle (eating at a chapter start, `Data.set_meal`, `meal_boost`), the snacks
  (`snack_pick`, `eat_snack`, the snack button), Feed (`feed_mount`, the Feed button, `mount.revive_food`), growth by
  waves (`grow_wave`), the pantry strip on the cards and the legacy balance keys (`garden.crops`, `cooking.recipes`,
  `burrows.lunch` and the others).
- **The handlers:** `garden.gd` and `cooking.gd` listen to `Events.timer_finished`. They refresh the look and the
  stations (a ring pulses only after `stations.refresh()`) and show one toast for everything that ended in that check
  (the garden's toast also takes the pot's line). What changes the game (pay, pick, collect, the Gloom bumps
  `harvest` and `dish`) happens only on the player's taps. A handler can miss an event, so each also reads the state
  (the garden checks its stages every 2 s).
- **Save version 4** (`core/save_upgrades.gd` step 3→4, frozen numbers in `balance.json save_upgrades.to_v4`):
  `Save.bag` (`{id: count}`) and `Save.timers` (`{"seen": Unix s, "jobs": {id: {"start", "len", "data", "told"}}}`).
  The step moves the pantry into the Bag, turns old dishes into Health Potions, keeps a half-grown crop's share as a
  job, and erases `pantry`, `snack_choice`, `meal_ready`, `meal_on` and a run's `meal`. The step reads its "now" from
  `Timers.clock`, so a test that holds the clock still holds the upgrade too.
- **Data:** `balance.json` `timers`, `bag` (`slots` 24, `stack` 20, `use` for fish and the Golden Carp, `desc`),
  `potions.hud` (which potion each HUD button uses), `garden.water_s_by_level` [0, 300, 360, 420] and `water_speed` 2,
  `cooking.pot_slots` 3, `ingredients` peppers and roots, `defences.tower/spikes.from_bag`, and `market.buys` the
  Golden Carp.
- **Tests:** see "Test modes" below. A test that moves the clock sets `Timers.clock` to a method of its own node (not
  a lambda) and calls `Timers.use_real_clock()` on every way out.

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
| `settings.json` | The graphics level and sound (H2) |
| `test_args.txt` | One-shot arguments for a debug build on the phone; deleted after reading |

On the phone `user://` is the app's `files/` folder (package `com.projectleaf.game`; reach it with
`adb shell run-as com.projectleaf.game`). The game saves after every purchase, every wave cleared, every chapter break
(`Save.mission_run`) and every raid end. Raids save quietly (`Save.save_game(true)`) every 10 meter points, at stir,
at full, at each wave held, and on pause, focus-out or close (`main._notification` calls `raids.persist()` and
`burrows.persist()`). A Burrows run saves at checkpoints, when hurt (throttled) and on pause. Old saves load field by
field with defaults (`d.get`); `save_v` is 5 (H5, 27 Nov 2026: the 4 to 5 step is in "The Market, the pets, the
Saddlery and the Tailor's Nook" above); before it, 4 (the 2 to 3 step turns old amber, glowstone, heartwood and keys into
leaves; the 3 to 4 step, H3, moves the pantry into the Bag, turns old dishes into Health Potions and old crop growth
into Timers jobs). Since H3 the save holds `bag` (the Bag's food, fish and potions) and `timers` (the real-time jobs:
the crops and the pot); there is no `pantry`, dish or snack field any more.

**New (H1, 25 Nov 2026):**
- `Save.mark_dirty()` and `Save.flush()`: while the save is dirty it is flushed every 10 s, and on pause, background
  or close.
- `Save.hold_flush`: no flush during a Raid Mission wave, and one flush at the wave's end. This stops leaf farming
  by force-closing the game.
- Writes are atomic, through a `.tmp` file. If the main save cannot be read, the `.bak` copy is loaded. A backup is
  written before an upgrade.
- `Save.loaded_v` holds the version the file had. `save_upgrades.gd` runs the versioned steps (2→3, 3→4 since H3, and 4→5 since H5).
- Currency changes send `Events.currency_changed`. `Events.save_loaded` is sent after a load.

### The debug endgame start

Debug builds only. `--endgame` opens a **separate save** as if all 15 raids were won: home level 5, a grown cat
(Training Target and Bow Shop at 5; Well and Garden at 3; the Market built, the pet at level 3 and the Saddlery at 5, so the mount rides at level 5 (H5); Guardian Stone at 0), 8,000 leaves, 300 timber, 60 shards, no Hollow keys, food in the Bag (8 Sunberries, 4 Fernmint, 2 honey, 3 fish; H3), an empty garden, the Gloomwood open (the Warden still to be found). The HUD
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
| Raids and camp | `autotest.gd` | default (all 15 waves of raid 1), `--smoke`, `--resume=1` then `=2`, `--village`, `--siege`, `--laststand`, `--bars`, `--skins`, `--levels`, `--grow`, `--gallery`, `--patch=N`, `--grasswalk`, `--lake`, `--perf`, `--perfdiag` |
| Warden, fishing | `autotest.gd` | `--guardian`, `--guardianab`, `--fishing` (H3: the catch goes into the Bag), `--camplife`. `--garden`, `--cook` and `--feed` moved to the H3 row |
| Gloom / Random Raids | `autotest.gd`, `autotest_assault.gd` | `--assault` / `--raidsave` (29 continuous-assault checks); `--raid` (with `--raid-small`, `--with-warden`), `--raidloss`, `--meter`, `--raidresume=1/2/3`, `--raidtypes`, `--wear`, `--shards`, `--raidintro`, `--raidshots`, `--raidperf`; flags `--raid-type=`, `--raid-warn=`, `--raid-meter=` |
| The Gloomwood | `autotest_e.gd` | `--dungeon`, `--dungeonshots`, `--dungeonfall`, `--dungeonresume=1` then `=2`, `--boss`, `--dungeonperf`, `--dungeontreasure`, `--dungeonlevels`, `--dungeonstand` (`=god`, `=items`), `--dungeoncareful`, `--floormaps=<dir>`; kept from Phase E: `--burrowsave`, `--hollow`, `--dash`, `--traps`, `--burrowfoes`, `--topup`, `--burrowhooks` |
| Layout and HUD | `autotest_layout.gd` | `--layout`, `--layoutsave=1` then `=2`, `--hudcheck` (121 checks since H2: real taps on Ride, the gear, a graphics row, the Bag and the build icon; a mission wave, the Last Stand and a raid's attack; the raid bar fills. 128 since H3: also the potion buttons, the potions line and the garden and pot windows fitting), `--taps`, `--arrows` |
| Phase F | `autotest_f_home.gd`, `autotest_f_fight.gd`, `autotest_f_enemy.gd` | `--homegoals` (goals and raid access), `--fightf` (90 passes: manual waves, rewards, save/resume, losses, legacy saves, squads and Gloom Raids), `--enemyf` (boars, support enemies, grub and totem) |
| G1b and G2 | `autotest_g2_def.gd`, `autotest_towers.gd`, `autotest_g2_camp.gd`, `autotest_g2_cards.gd` | `--rows` (168 checks: pads, repair, the Well, five tower levels, full-circle arrows and loading cycles), `--campg` (the Hearthtree camp), `--cards` (shop cards; screenshots at 480x1040 with `--safe-top=73 --safe-bottom=42`) |
| G3 | `autotest_g3_bow.gd` | `--bowshop` (buying, late damage and leaf budgets, upgrades, equipping, pierce, burn, frost, models and shot effects; 78 passes, 25 Nov 2026) |
| G4 | `autotest_g4_saddle.gd` | `--saddlery` (skills, attachments, riding and Fire-spitter flame balls/splash/cadence/range/tracking; flame and ground-fire lifecycle/quality checks; 111 passes, 25 Nov 2026); add `--rideclear` for the clearance sweep |
| Tailor's Nook and cat outfits | `autotest_cat_skins.gd` | `--tailor` (building, buying, wearing, saving, models, fallback and cloth; 63 passes; since H5 also the window's try-on, grey cards, one button and Back; 76 passes) |
| H4 (New, 26 Nov 2026) | `autotest_build_menu.gd`, `autotest_g3_bow_windows.gd`, `autotest_g2_cards_kit.gd` | `--buildmenu` (47 checks: the menu, its Build buttons, the dot, the camera shot and the rise); the window checks of `--bowshop` and `--cards` |
| H5 (New, 27 Nov 2026) | `autotest_g2_market.gd` (from `autotest_g2_camp.gd`), `autotest_saddle_window.gd` (from `autotest_g4_saddle.gd`), `autotest_h5_found.gd` | `--campg` (110: the Market's tabs by real taps, trades, Sprig and Lumi, training, the pet goals, a real v4 save upgraded), `--saddlery` (156: the tabs, the triangle, a real drag), `--h5found` (60: the content kinds, the Buy command, the 4 to 5 save step) |
| H1 (New, 25 Nov 2026) | `autotest_pools.gd`, `autotest_saves.gd` | `--pools` (the object pools and the event board), `--saves` (the sample saves in `game/tests/saves/`, `v2_sample.json`, `v3_sample.json` and since H3 `v4_sample.json`, load, upgrade and save, with the clock held still) |
| H2 (New, 26 Nov 2026) | `autotest_settings.gd` | `--settings` (40 checks: the settings file, Graphics Auto/Low/Medium/High, sound on/off, the gear window, nothing written during autotests) |
| H3 (New, 26 Nov 2026) | `autotest_timers.gd`, `autotest_content.gd`, `autotest_bag.gd`, `autotest_potions.gd`, `autotest_garden.gd`, `autotest_cook.gd`, `autotest_saves.gd` | `--timers` (jobs with a pretend clock: they follow it, end "while the game is closed", wait when the clock is set back; resume checks; `seen` alone never marks the save dirty), `--content` (the crop and recipe folders and `index.json`), `--bag` (also `--inventory`, the old name; `autotest_inventory.gd` is now `autotest_bag.gd`: the Bag window, stacks, "Bag full", Use and Place, the drop-in, the Golden Carp sale; at its end it runs the potions checks of `autotest_potions.gd`), `--feed` (the potions checks only: every effect, the HUD potion buttons, the mount), `--garden` (the window, a real drag, real-time growth, watering, "grows while closed", picking, the Gloom bump per visit, the ring), `--cook` (the window, a real drag, Cook, the timer, Collect, a full Bag, the fire out), and `--saves --startup=1` (with `--fresh`) then `--saves --startup=2` (without `--fresh`): a real first launch with a v3 save on disk |
| Mounted target lock | `autotest_mounted_aim.gd` | `--mountedaim` (69 checks: strict 280-degree arc boundaries, rear blind spot, both mounts, real arrows and hits, torso aiming above a forward-facing root, hips and feet, outfits and different bows, left/right steering and forward gait, target reacquisition, Ram direction and dismounting mid-shot) |

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
adb is not on PATH: the Android SDK puts it in `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`. The adb daemon often restarts after an
export, so run `adb wait-for-device` first, then `adb -s <serial> install -r game\build\ProjectLEAF.apk` (the S24's
serial is in `docs/STATUS.md`). Before installing over the owner's game, copy the phone's save to
`D:\DevCache\backup\phone_save_<date>.json` (for example `adb exec-out run-as com.projectleaf.game cat
files/leaf_save.json > ...`). If the phone is on the endgame save and the owner wants the real one, put
`--endgame-off` in `files/test_args.txt`.

**Set up again after the Windows reinstall (21 Nov 2026).** The Android SDK is in `%LOCALAPPDATA%\Android\Sdk`
(build-tools 36.0.0), Java is Android Studio's own (`jbr`), the Godot 4.7.2 export templates are installed, and the
Samsung USB Driver 1.9.5.0 lets adb reach the S24. Builds are signed with the owner's saved Godot debug keystore, the
same key as every earlier phone build. The local `tools/build_apk.ps1` fills blank Java and SDK paths in Godot's editor
settings and passes keystore settings through environment variables. With `-Install`, it backs up via ADB `run-as`,
installs and compares the save hashes. Routine ADB stderr messages no longer stop it.

### Backups

Copies before each big change are in `D:\DevCache\backup\pre_*` (the latest: `pre_h3_2026-11-26`, `pre_g4_20261121`, `pre_g3_20261121`, `pre_phase_g2_20261120_1429`, `pre_phase_g1_20261120_1359`, `pre_phase_f_20261119_1209`, `pre_homefix_20261119_0023`,
`pre_markers_dungeon2_20261119_0052`, `pre_dungeon2_20261119_0053`); phone saves in `D:\DevCache\backup\phone_save_*`
and `game\build\phone_save_backup\`; per-step copies in `D:\DevCache\tmp\<work>\`. Back up what you touch first.

### Work in progress

- Phase F and Phase G1 through G4 are on the phone in the 23 Nov build. G5 is tuning by the owner's play.
- The Golden Grub, Gloom Totem and later Training Target and Bow Shop levels use the stand-ins listed above.
- The Gloomwood's road and difficulty are in the live project; only `--dungeon` has been run since, so the full
  regression is still to do.
- **H3** (food, potions and the Bag) is built on `feature/h3-food-bag` and waits for the owner's phone test. Known:
  `--dungeoncareful` loses at the boss in about 2 runs of 3 (part 8); the garden's card scrolls about 150 px at
  540x960 to reach its Upgrade row (the window fits; nothing scrolls at the phone's shape).

### Rules

- **Disks** (since 21 Nov 2026): C: has room again, so tools may keep their caches and temp files in their default
  places on C:. The project, builds, backups and work files stay on D:. Old caches are in `D:\DevCache`, and the test
  runners still set TEMP and TMP to `D:\DevCache\tmp`.
- **Blender:** headless (`D:\Blender\blender.exe -b`), or live in the Blender that `tools/start_blender_mcp.ps1` opens,
  through the local bridge on port 9876. `py -3.15-32 tools/blender_mcp.py` runs scripts in that window. Leave the
  owner's own Blender alone. Agents working side by side stay headless.
- **3D models** (`CLAUDE.md`): the owner makes models in Meshy. Claude may design bows, arrows and mount attachments
  in Blender. Claude finishes the owner's meshes and can rebuild broken parts to match the design, as with the
  outfit cloaks and the Nook. Concept images (`tools/gen_concepts.ps1`, Codex CLI) are made at the owner's request.
- **Agents and review** (updated 25 Nov 2026): who does what is in `CLAUDE.md` and `docs/PHASE_H_PLAN.md` Part F.
  Opus reviews all work by Sonnet, Haiku and Codex; Codex works read-only and supplies patches.
- **Architecture** (agreed 25 Nov 2026): `docs/ARCHITECTURE.md` is the target structure (one folder per thing, eight
  singletons, the patterns and the house rules). Phase H moves the game over to it step by step; read it before
  writing game code.
- **Godot MCP** uses the local `.mcp.json` and `tools/mcp/` to connect to the Godot 4.7.2 console.
- Keep the design rules (updated by the owner, 25 Nov 2026): only timers keep running while the game is closed (built
  in H3: the crops and the pot); camp, not village; looks-only selling, with purple shards the paid currency for looks only and Bramble never
  buying shards; nothing tall between the camera and where the cat can walk; nothing of the HUD in the middle third of
  the screen. Numbers live in data (`game/data/`, and `game/content/` as Phase H moves content there).
- **Phase H removed the Mushroom Cottage** (H5, built 27 Nov 2026): the pet's upgrades are on the Market's Pets tab.
- The owner tests on the phone: build complete and playable, keep testing light, and back up first.

---

## 12. Where to read more

- `docs/STATUS.md`: where things stand, what is next, tools and paths. Read it first when work starts again.
- `docs/CHANGES.md`: changes and checks for each merged branch.
- `GAME_PLAN.md`: the whole design. Section 0 (Draft 7) holds the direction and the owner's decisions; it wins over
  the older sections below it.
- `docs/PHASE_A_PROGRESS.md`: build notes for every phase, the choices made, and the test results.
- `docs/PHASE_C_SPEC.md`: the Moss Warden, the garden, cooking and fishing (as specified; the build notes win).
- `docs/PHASE_D_SPEC.md`: the Gloom Raids and keeping the camp up.
- `docs/PHASE_E_SPEC.md`: the Burrows. Only the decisions at the top still hold; its rooms are gone.
- `docs/DUNGEON_SPEC.md`: dungeons as paths; the Gloomwood.
- `docs/DUNGEON_EXPEDITIONS_PLAN.md`: agreed future expedition/discovery/recruitment direction, prototype suggestions
  and open decisions (23 Nov 2026; not implemented).
- `docs/RAID_MISSIONS_AND_RANDOM_RAIDS_PLAN.md`: built Raid Mission catalogue/replays and the separate future Random Raid assault/menu direction.
- `docs/PERFORMANCE.md`: graphics levels and measurements on the PC and the S24.
- `docs/ASSET_RULES.md`: the rules every 3D model follows.
- `docs/AGENT_BRIEF_MESHY.md`: the brief for turning a Meshy mesh into a game model.
- `game/README.md`: how to run the game, every test mode, and what each script does.
- `docs/screens/`: older screenshots of the camp, the lake, the cards and the enemies.
