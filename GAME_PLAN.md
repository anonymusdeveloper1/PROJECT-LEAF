# Project LEAF: game plan

Draft 7, 17 November 2026. Draft 2 added the camp as a safe home base with no menus. Draft 3 added the progression
(section 6). Draft 4 added stations that gate the upgrades (section 4). Draft 5 replaced the round-fenced village
with the tree home, its shop, the firelight and fences you place yourself (section 3). Draft 6 (section 0) brought
missions, enemies that wreck buildings, barricades instead of fences, and looks-only sales. Draft 7 (section 0) makes
each mission 15–20 waves long, adds a camp guardian, and adds the game after the missions: Gloom Raids, the Burrows
(dungeons), and things to do in the camp besides fighting. One cat protecting its campfire camp: no villagers.

**Built so far (16 November 2026):** the playable game in `game/` (see `game/README.md`). That covers:
- the camp, the shop, the stations and the free-placed defences
- all 4 patches with their waves, and Gloom Night
- the progression and saving
- the five enemies from the user's Meshy models, coloured, rigged and animated in Blender, with spring bones
- 47 Blender-made props, plus the tree home modelled live through the Blender MCP
- the later woods: Moonmoth Hollow, Crystal Ridge and the Owl Witch's Spire (stages 5–7, coming back down claimed
  trails) with the Gloom Moth (flies over barricades), Frog Shaman (heals, Gloom bolts), Beetle Knight (front shield,
  bash), Crystal Snail (slime, crystal burst) and the Owl Witch boss (blink, homing orbs, hex circle, calls moths)
- the buildings round the campfire (target and bench east; cottage and stall south-east; the well on the lake's near shore): Wishing Well (mends the campfire between waves), Mushroom Cottage (Sprig the
  leaf-dragon pet fights beside the cat) and Market Stall (ride Thistle the giant hare; it thumps enemies; sells
  timber). Enemies, Sprig and Thistle are from Meshy 6 Lite, coloured/rigged/animated in Blender; the buildings are
  modelled in Blender
- losing: when the campfire goes out it is the Last Stand (the fire stays out, the camp is not safe, every enemy hunts
  the cat, no respawn; winning the remaining waves still claims the patch). If the cat falls then, the camp falls: the
  Gloom takes 30% of the unspent leaves, crusts one building with crystals until cleared, and wrecks defences until mended in the
  shop. Nothing built is lost and the stage is fought again
- tall moving grass, the lighting, the living campfire and placeholder sounds
- a debug APK in `game/build/`

Balance numbers are first guesses.

## 0. The direction from here (Draft 7, 17 November 2026)

Agreed with the user on 17 November 2026: Draft 6 in the morning, Draft 7 (the user's mission length and endgame, with
Claude's suggestions for what else to add) in the evening. Where this disagrees with the older sections below, this
wins. Anything marked *(proposal)* is Claude's suggestion and not yet confirmed by the user.

**One cat protecting its campfire camp** (the user, 17 November 2026). Not a Clash of Clans-style base builder: the
home base is a camp round a campfire, not a village, and nobody lives there. No villagers, no workers, no production
timers. What helps the cat defend it are companions: the pet, the mount and a camp guardian (below).

**Not open world.** The camp stays the home base and the enemies come to it. Going out happens in separate small
places reached from the camp: the Burrows (dungeons, after the missions) and islands by boat (later).

### Missions: long, wave by wave (Draft 7)

The user's rule: **a mission is 15–20 waves, each harder than the last, and the waves pay enough that the camp and
the cat keep growing during the mission.** A player can spend about 20 minutes and still be on mission 1. This
replaced Draft 6's 3-phase missions of 2–4 minutes. **Built (A2, 17 November 2026)**: fight.gd, balance.json
"mission" (the rules) and "missions" (per mission: waves, count, chapters, elite, boss).

- **Chapters of 5 waves**, so a long mission fits a phone: every 5th wave is an elite wave (the mission's signature
  tough enemy, more each chapter), and the last wave of the mission brings its boss or a big finale pack. After each
  chapter the camp rests until the player goes on from the signpost ("Go"). **Progress is saved at every chapter
  break** (Save.mission_run): closing the game mid-mission comes back to the start of that chapter, and the
  signpost offers "Go on" or "Give up this mission".
- **Between waves**: a 15 s breather (the signpost's "Go" skips it). The shops and stations only open between waves;
  in a wave their cards say so. Ruins can be repaired between waves, or are mended free when the mission is won. The
  camp is safe again between waves, so the cat heals there.
- **Chapter break**: the campfire is fed back to full and a chest pays out.
- **Pay**: kills drop 65% of their leaves; each cleared wave pays a small bonus; each chapter ends with a chest
  (leaves and a little timber); the win pays the mission's reward. All of it grows 20% per mission. Estimate: about
  35,000 leaves over the 15 missions against about 24,000 for everything sold today, so most things can be bought
  through the missions and home levels 4–6 (Phase B) still have room.
- **Difficulty**: every wave is 5% stronger than the last, on top of 8% per mission, with more enemies each wave
  (6–17 in mission 1, up to 26 later; at most 28 on the field).
- **Length**: missions 1–5 have 15 waves (3 chapters), 6–15 have 20 (4 chapters: Scouts, Main assault, Onslaught,
  Finale). The test cat clears mission 1 in about 8 minutes of fighting; with the breathers and shopping a player
  takes about 12–15 minutes. Bigger waves or slower spawns are the lever if it should be longer.
- **The camp falls** (see below): the current chapter starts over, not the whole mission.
- **Replays** of won missions stay; their reward is half (wave bonuses and chests are paid in full), to grind when
  stuck.

The 15 missions in the game now keep their names, new enemies and gifts: 1 First Embers (thornlings, tutorial) ·
2 Bramble Pack (boars; **Thistle the mount**) · 3 Toadstool March (brutes; **Sprig the pet**) · 4 Stumps at Dusk
(stump golems) · 5 Bandit Night (raccoons) · 6 Mossback Wakes (bear boss) · 7 Moth Swarm (fliers skip barricades) ·
8 Spitting Thicket (pitcher spitters) · 9 Croaking Choir (frogs heal, crow drummers) · 10 Shield Wall (beetles, mole
sappers) · 11 Crystal Creep (snails, puffball bombers) · 12 Two Fronts (every trail) · 13 The Owl Witch (boss) ·
14 Gloom Tide (long mix) · 15 The Elder Thornstag (island boss).
The mount and the pet come early and stay part of the whole game. Gloom Night is removed.

**Later: 2–3 more bosses** (the user, 17 November 2026). Only missions 6 (Mossback), 13 (the Owl Witch) and 15 (the
Elder Thornstag) end in a real boss; mission 1 has the Thornling Chief, a mini-boss, and the rest end in a big pack of
elites. Make 2–3 new bosses (Meshy models, rigged and animated in Blender) for missions that end without one, for
example 4 Stumps at Dusk, 9 Croaking Choir and 12 Two Fronts. Not now.

### Health bars over the cat and the mount (Draft 7, the user, 17 November 2026)

- The cat's health is a **bar over its head**, not the row of circles at the top of the screen. Flat and simple:
  just red, a little see-through so it does not hide anything when there are many enemies.
- When the cat is hit the red drains, and the part just lost shows grey for a moment before it goes.
- **The mount takes hits too.** While the cat rides, a second bar sits right under the cat's: the same width, thinner,
  for the mount's health. *(proposal)* Hits land on the mount while the cat rides it. When the mount's health runs
  out it throws the cat off and runs back to the Market Stall, and it can be ridden again once it has rested (after
  the wave, or about 20 s in the camp). Its health grows with the Market Stall's level.

### Helpers: the pet, the mount and the camp guardian (Draft 7)

The cat defends the camp with companions, not residents. The pet (Sprig) and the mount (Thistle) stay as they are.

**The camp guardian** (the user's idea: like the iron golem that guards a Minecraft village). One big, slow, strong
creature that lives at the camp and fights for it. *(proposal for the details)*:
- Working name **the Moss Warden**: a golem of mossy stone and old roots, woken at a guardian stone in the camp. Its
  model comes from the user's Meshy like every character; coloured, rigged and animated in Blender.
- It stays in and round the camp and goes for whatever is attacking a building, a barricade or the campfire, so the
  camp is not empty while the cat is away. Heavy fist hits and a ground slam that knocks small enemies
  back. Slow, so fast enemies and fliers can get past it.
- It has health. Knocked down, it crumbles and pulls itself back together after about 30 s (or at the next breather).
- **When and how you get them (the user, 18 November 2026):** not during the missions. Guardians come after every
  mission is won, because from then on the cat is away in the Burrows and the camp needs someone to defend it.
  **Guardians are never sold and there is no shop for them: you find them** by playing the Burrows. The game awards
  the first one for sure, so every player has a guardian before they need it. The code for the Moss Warden is built
  (Phase C) but stays hidden until then.
- *(proposal, for the user to confirm: "the Sleeping Warden")*
  1. During the missions the old guardian stone already stands east of the camp, dark and mossy, with no ring:
     Bramble mentions that "a guardian of the forest sleeps under the roots". A hint, nothing to do yet.
  2. The last mission is won and the Burrows open. The first Burrow (the Gloomwood) ends in the boss's arena: the Moss Warden lies
     trapped in a cage of violet Gloom crystals at its edge, and the Burrow's boss guards it.
  3. Beat the boss and break the seal (stand on it a few seconds, like rebuilding the campfire). The Warden wakes,
     follows the cat home and takes its place at the stone: "The Moss Warden is free! It guards the camp while you
     are away." So the first run always gives it: the player rescues it rather than getting a gift.
  4. While the cat is in a Burrow, a raid can still come (only while the game is played). The Warden, the towers and
     the barricades defend without the cat, and the cat sees what happened when it comes back ("The Warden held the
     camp" or "the well was damaged").
  5. **Later** *(the user, 18 November 2026, while Phase E was built: for now the game has one guardian, the Moss
     Warden, found sealed behind the Old Hollow's first boss; everything in this item is for later)*. **Guardians are
     collected (the user, 18 November 2026): not one guardian, but every guardian the player finds
     in the Burrows joins the camp and helps protect it.** The more the player explores, the safer the camp. They
     are found the same way as the first: sealed at a Burrow's end, behind a boss, or in rare hidden places
     on its path. They are earned, never sold. The user's rules for them:
     - **they fight in different ways** (each its own technique);
     - **some help with other things** besides fighting;
     - **none of them ever goes into a Burrow**: in the Burrows it is only the cat, its pet and its mount. The
       guardians stay home and look after the camp; that is how they help the player.
     *(proposals for kinds)* Fighters: the Moss Warden (big and slow, punches and slams by the fire); a Bramble Boar
     (charges down a trail and knocks a pack back); a Crystal Golem (stands at a trail mouth, its crystal pulses hurt
     everything near it); a Root Treant (plants itself on a road and blocks it like a living barricade). Helpers
     (they never produce resources, so the camp stays a camp, not a village of workers): a Lantern Owl (watches the
     woods, so raids are seen earlier and the warning is longer; it also swoops at fliers); a Moss Tortoise (slowly
     mends damaged buildings and barricades between raids, only while the game is played); an Ember Salamander
     (keeps the campfire going: once per raid it brings the fire back if it goes out); a Dew Sprite (heals the cat,
     the pet and the mount when they come back from a Burrow); a Hedgehog Sentry (keeps thieves and pests off the
     garden and the pantry).
     **Guardian spots follow the camp's level (the user, 18 November 2026):** when the missions end (home level 4 or
     5) the camp holds at most 2 guardians; every home level after that adds 1, up to 5. The camp keeps growing as the
     player plays the Burrows, so home levels go on past 6: spots = home level - 3, at least 2, at most 5 (levels 4-5:
     2, level 6: 3, level 7: 4, level 8: 5). Home levels 7 and 8 come after the missions and are paid mostly with
     what the Burrows bring back (they need new home and campfire models). Each spot is a post round the camp; with
     more guardians than spots, the player chooses at the stone.
  6. Guardians are upgraded at the stone with leaves (the user, 18 November 2026: "leaves is fine"), and they eat:
     food keeps them strong and mends them after a raid.

### After the missions (Draft 7)

The user's rule: **when every mission is won, random waves of attacks keep coming and the camp must be kept in good
condition at all times; the Burrows (dungeons) open, to earn resources for the camp and its defences.**

The user, 18 November 2026: **after the missions, the Burrows are most of the gameplay.** The camp needs resources to
keep going (food for the campfire and the like): the cat goes into the Burrows, brings back what the camp needs,
upgrades the camp, gets stronger, and goes deeper. There will be several Burrows, more over time. Raids keep coming
meanwhile, so the camp must stay in good shape. (Nothing drains or happens while the game is closed.)

**The late game and what is sold (the user, 18 November 2026).** After the missions the player is rich, so there
must be things worth earning, and the camp keeps growing through a lot of Burrow runs.
- **New pets and new mounts are looks only**: whatever they look like, they do exactly what the first ones do. They
  are sold (and some can be earned).
- **Cosmetics** (styles, skins) are sold.
- **Attachments for the pet and the mount** (saddles, armour, charms, lanterns...) are the part that **helps in the
  Burrows**. They can be bought with real money, or earned with in-game money through a lot of playing. This is how
  the game makes money: pets, mounts, cosmetics, and these attachments.
- When the player has everything and cannot grow any more, the game is done, and the Burrows are there just for fun.

**Food, from the start (the user, 18 November 2026).** Food is not a late-game thing: it matters from the first
missions. **The mount can be knocked out, and food is how you bring it back** (the pet does not die; it is just
there). Food also feeds the Moss Warden. So the garden (or another early food source) has to come early, by the time
the mount arrives in mission 2. More uses *(proposals)*, all happening only while playing:
- befriending creatures in the Burrows with their favourite food (new pet and mount looks to win by playing);
- a packed lunch for a Burrow run: a snack that heals the cat inside a run, or a rest between floors to go deeper;
- feeding the fire: rebuilding the campfire in the Last Stand, or stoking it before a raid for a brighter firelight
  that heals the cat faster;
- treats for the pet, the mount and the Warden raise their bond, which unlocks small tricks (Phase F bonds);
- a feast before a big raid: everyone (cat, pet, mount, Warden) gets a short boost;
- trading food with Bramble the trader for rare seeds, special arrows and cosmetic bits;
- bait: a special food at the fishing spot or a Burrow's mouth draws out a rare fish or a treasure creature.

- **Gloom Raids** (Phase D, see docs/PHASE_D_SPEC.md). A Gloom meter (the Watch: a horn and a crystal on the
  signpost) fills only while the game is being played: time in the camp with no fight on (not while idle), plus
  things the cat does (replays, garden, cooking, fishing, Burrows runs). **Nothing happens while the game is closed**:
  the meter does not fill, no raid is fought, nothing is lost. A raid that was coming, or being fought, when the game
  closed comes back at its warning (at least 30 s) when the player returns. When the meter is full the horn sounds
  and a raid arrives after a warning (45 s; 60 s for the first raid and for elite raids; never more than 60), and the
  player can meet it early from the signpost. Kinds: siege (bruisers for buildings), sneak (the least-guarded trail,
  hidden until 15 s before), sky (moths over the barricades), and a rare elite raid led by a boss. A raid is 3 waves;
  its last wave is led by the Gloom Herald (or the boss): topple the leader and the raid breaks. Repelling pays Gloom
  shards, leaves and timber; a perfect defence (no building lost, the fire never out) pays 50% more shards, and a
  camp that was whole when the raid began pays 20% more. A lost raid leaves only damage to repair, nothing else, and
  the next raid is a little gentler. The raid level grows with the camp (home, stations, towers, defence levels,
  guardian) and with raids won, never with the cat's own upgrades.
- **Keeping the camp up.** Ruins, wrecked defences and building wear carry over between raids and are saved as they
  happen. Repair at each building, mend defences in the shop, or tap "Mend all" at the signpost. Endgame repairs are
  capped in price. Raids knock the guardian down; it gets up again by itself.
- **Gloom shards** are earned only by playing and are never sold. They buy defence level 4 (Shardstone), the Watch's
  Lookout and Tracker, earned-only looks (Gloomlit colours, Shardfire), or leaves from Bramble.
- **The Burrows (dungeons): the main loop after the missions** *(Phase E, built 18 November 2026: docs/PHASE_E_SPEC.md;
  dungeons as paths since the same evening: docs/DUNGEON_SPEC.md; notes in docs/PHASE_A_PROGRESS.md)*. The Old Hollow at
  the south edge of the woods stands sealed from the first mission won and opens when the last mission is won. **Entry
  is free and unlimited**; the Burrows are built as a list, each with its map as data (data/dungeons/<id>.json), so more
  Burrows are data plus models. **The cat goes in with its pet and its mount**; the Moss Warden stays home and guards
  the camp. **A dungeon is one continuous map, a path the cat walks to a boss** (as in World of Warcraft): the first,
  the Gloomwood, is a wood at night, about 150 m from the way in past six fights (packs asleep that wake together,
  Grublings bursting out of holes, moths flying in from the dark), a Gloom-bound chest, rolling logs, the Moonwell (heal
  once, a boon, a root lift home) and a bridge, to Mossback in a big arena whose roots close behind the cat. Not every
  dungeon needs a boss: a map can end in a treasure clearing. Replays are **levels** of the same map (level N beaten
  opens N+1: stronger, other monsters, more pay). Every trap and big attack glows on the ground before it lands, and the
  cat moves, dashes with a flick of the thumb (the Leaf Dash, Burrows only) and baits charges into standing stones.
  Food matters there too: a knocked-out mount is fed back with the same Feed button as in missions, a packed lunch (a
  snack from the pantry) heals the cat, and a dish waiting in the pot goes down with the cat. Materials (amber,
  glowstone, heartwood) go into a satchel: a root lift home keeps all of them, a knock-out keeps half; leaves, timber
  and shards are always kept. **Hollow keys are only a bonus** (entering with one starts the run with a boon): they come
  from playing (a Gloom Raid held, a mission replay won, a new level beaten), at most 3 are held, and nothing refills
  while the game is closed. A run in progress is saved at its checkpoints and waits at the Hollow when the game is
  closed. **The first clear of the Gloomwood frees the Moss Warden**: it lies sealed in Gloom crystals behind the boss,
  and the cat stands on the seal to break it. Materials pay for mastery (levels 11-12
  of damage, draw speed, health, speed and every bow), the Foxfire Bow, the level-5 Heartwood Gate, Amber Tower and
  Amber Thorns, **home levels 7 and 8** (paid mostly with materials; their models are level 6's until new ones are
  made), and **attachments** for the mount and the pet that help only in the Burrows (3 each: more health, a stronger
  Thump or sparks, more loot, earlier trap warnings, more health for the cat), bought on the Stable and Nest cards. The
  Warden's level 4 costs leaves, like all its upgrades. Keys and materials are never sold.

### Things to do besides fighting (Draft 7, proposals)

What keeps the game moving when the player is not fighting. Everything here is something the cat does itself, with
its companions; nothing works for it while the game is closed. (Dropped on 17 November 2026, at the user's word:
rescued villagers, expeditions run by villagers, and production buildings that fill on a timer.)

1. **The garden**: the cat plants seeds (from the trader and the Burrows), waters them, and picks berries, herbs and
   flowers when they are ripe. They go into cooking.
2. **Cooking at the campfire**: berries, herbs, fish and honey make dishes that give a short boost for the next
   mission chapter or raid (more health, faster shots, a stronger pet).
3. **Fishing at the lake**: a calm little game; fish for cooking, now and then a rare find.
4. **Fletching special arrows** at the Bow Bench from Burrows materials.
5. **Bonds** with the pet, the mount and the guardian: time spent together (feeding, riding, playing) unlocks small
   upgrades and new tricks for them.
6. **Decorating the camp**: decorations, lights and paths the player places. The natural home for sold looks, in line
   with the looks-only rule.
7. **Daily and weekly tasks** ("defeat 30 thornlings", "survive a raid without a ruin") and a weekly boss.
8. **Endless mode**: how many waves can the finished camp survive, with a leaderboard. Later.
9. Ranger ranks from Draft 6, still a candidate.

### Kept from Draft 6 (built in Phase A)

**Enemies attack buildings.** Every structure has health. Enemies go for the nearest of: barricades, then acorn towers,
then buildings, then the campfire. A destroyed building is a ruin and does nothing until repaired.

**The campfire is the heart.** When it is destroyed the cat is alone in the dark (the Last Stand). The cat can rebuild
it once per chapter (Draft 7; once per mission in Draft 6): stand on the ashes 4 s (a hit cancels it) and pay 10
timber; it comes back at 30%.

**The camp falls** when the cat dies while the campfire is down, or the fire falls a second time. A setback, not a
reset and not "back where you were": lose 30% of unspent leaves, ruined buildings stay ruins (repair = about 30% of
what they cost), the campfire must be rebuilt, the current chapter starts over (Draft 7; in Draft 6 the whole
mission). No levels are ever lost.

**Defences.** No fences at all (owned fences are refunded as leaves). Barricades only on the roads, at 2–3 fixed spots
per trail (log, stone wall, thorn gate). Acorn towers on a limited number of spots set by the home level (2/3/4/5/6),
with health; enemies target them right after barricades. Spikes stay as a cheap road trap.

**More levels (Phase B, built 17 November 2026).** Home levels 4–6: a Big Treehouse, a Great Tree Home and a
Tree Hall, each with its own campfire (a stone hearth, a great bonfire, a crystal brazier), modelled in Blender.
- Growing costs 3,000 leaves + 120 timber (after 9 missions), 6,000 + 200 (after 12) and 10,000 + 300 (after all 15).
- Each level: a wider firelight (6.5 / 7 / 7.5 m), a tougher campfire (900 / 1,300 / 1,800 health), a tougher home,
  and one more acorn tower spot (5 / 6 / 7). The stations stay at level 3 for now; the home itself grows.
- Ruined buildings keep the violet crystal crust they have now; broken-down models are for later.
- (The barricade models, log, stone wall and thorn gate, are done.)

**Skins (Phase B).** Every mount and pet look has colour skins: Natural, Snow, Midnight, Autumn and Golden for the
mounts; Frost, Ember, Golden and Midnight for Sprig; Snow, Midnight, Golden and Ember for Lumi. A skin recolours the
look's main fur or scale colour in the shared shader and keeps the cream parts, so no new models are needed. Pick
them on the Stable and Nest cards ("Colours"). All free while testing; sold later as looks. Accessories (saddles,
flower crowns, lanterns on bones) are later.

**The trader** at the Market Stall (Bramble) sells pet and mount gear, seeds, bait, special arrows and cosmetics. He
is the camp's one visitor, a shopkeeper, not a resident.

### Making money (Draft 7, 18 November 2026)

The user: **ads are wanted; skins, mounts and pets are sold; Burrow attachments are sold or earned; and maybe an
in-game currency that can be bought with real money.** The rest of this section is Claude's proposal, for the user to
pick from. The fairness lines stay: the missions are never pay-to-win, guardians are never sold, and every paid
thing that helps (the attachments) only helps in the Burrows and can also be earned by playing.

**1. A premium currency: Moonpetals** *(name is a proposal)*. Bought with real money in packs; a few are also earned
by playing (a Burrow boss beaten for the first time, a mission won for the first time, collection milestones), so a
free player can save up for a look. Moonpetals buy everything in the shop below. Leaves and timber are never sold for
money (that would buy mission power).

**2. What can be bought** (with Moonpetals, or straight with money for bundles):
- **Looks:** new pets and mounts (same strength), colour skins and special skins for them, outfits for the cat
  (hoods, cloaks, hats), bow skins and arrow trails (glowing, petals, sparks), campfire flame colours, the cat's emotes
  (a wave, a dance, a nap by the fire).
- **Camp decorations:** lanterns, banners, flower beds, paths, a hammock, fairy lights: the camp is the player's home,
  and making it pretty is a good thing to sell.
- **Burrow attachments** for the pet and the mount (saddles, armour, charms, lanterns): bought with Moonpetals, or
  earned with what the Burrows pay (the user's rule).
- **A starter pack** (once, cheap): a mount look, a pet look and some Moonpetals.
- (No "No Ads" purchase is needed: there are no forced ads. A "skip the ad" pass could later give the rewarded ads
  gifts without watching, as a convenience.)
- **A Forest Pass (a season):** a free track and a paid track of rewards (looks, decorations, Moonpetals, a few
  attachments) filled by playing missions and Burrows. It never fills while the game is closed; the season just has
  an end date.
- **Supporter bundles** now and then (a themed set: a mount, its saddle, a cat outfit).

**3. Ads: rewarded ads only (the user, 18 November 2026: "nobody wants a game like this to get interrupted"). No
between-screen ads and no banners, ever; an ad only plays when the player taps a button that offers a gift:**
- **Rewarded ads, always the player's choice** (a button that says what you get):
  - double the chest at a chapter break;
  - when the camp falls: keep your leaves (the 30% the Gloom takes);
  - one extra chance: bring the cat back once in the Last Stand;
  - in a Burrow: reroll the boss chest, or bring the mount back without food;
  - a small food bundle at the pot (a few berries) when the pantry is empty;
  - at most a few rewarded ads per play session, so they never feel like the main way to play.
- **No banner ads:** on a portrait phone the screen is full of play and cards, and a banner would spoil the look.

**4. Never sold:** mission progress, stats, the guardians, leaves and timber, raid wins, and anything that skips the
missions. A player who never pays can still get every gameplay thing by playing.

**5. Building it later:** Google Play Billing for purchases and an ad network (AdMob, or AppLovin MAX for more fill)
through a Godot Android plugin; the shop as a card at Bramble's stall or a "Moonpetal" button on the HUD; nothing of
this is built yet.

*(Updated 18 November 2026: besides looks, attachments for the pet and the mount that help in the Burrows are sold
too, or earned by playing; see "The late game and what is sold" above.)*
**Mounts, pets and what is sold (agreed 17 November 2026).** One gameplay mount slot (Thistle) and one pet slot
(Sprig): they get stronger only by playing (bonds, upgrades, their buildings). Everything sold for money changes looks
only, never power:
- skins: palette swaps of the same model and animations (snow, midnight, autumn, golden...) and accessory models
  attached to the saddle or head bones (saddles, flower crowns, armour, lanterns), made in Blender
- extra mounts and pets (Bramblewool the ram, Lumi the fox kit, later others) are premium looks for the same slot;
  each needs one Meshy model plus rig and clips
- **the rule: every mount has one signature ability, and every look plays it its own way, but what it does never
  changes.** Thistle stamps a Thump shockwave, Bramblewool lowers its horns and rams; the damage, range, cooldown,
  speed and upgrades are exactly the same. The same goes for pets: Sprig spits seed sparks, Lumi flicks lantern
  sparks, with the same damage and rate. Only the model, animation, effect colours and sounds differ
- choosing a look: a Stable card at the Market Stall (mount looks and their skins) and a Nest card at the Mushroom
  Cottage (pet looks and their skins); owned looks are kept in the save
- hats and cloaks for the cat, the same way
- some skins come in a season pass and some can be earned with Gloom shards, so free players get some too

**Models.** Characters (enemies, bosses, pets, mounts, NPCs, the cat) come from the user's Meshy; Claude writes their
concept images with Codex CLI, then colours, rigs and animates the meshes in Blender. Buildings, props, barricades,
arrows and other small items Claude models in Blender. The batch of 10 (5 enemies and a boss for the building-attack
design, a remade Cat Ranger, a trader, a second pet and a second mount) is done and in the game (17 November 2026);
the remade cat was tried on the phone and the user kept the original Cat Ranger.

**Build order** *(Draft 7 proposal)*:
- A) core rework: missions, building attacks, rebuild the campfire, the camp falls, barricades and tower spots, mount
  and pet early. **Done** (docs/PHASE_A_PROGRESS.md), together with the looks (Stable and Nest cards, Bramblewool,
  Lumi), the 10 new Meshy models and graphics levels for low-end phones.
- A2) **missions wave by wave**: chapters, breathers, per-wave pay, chapter chests, saving at chapter breaks, the camp
  falls restarts the chapter, a rebalance of the pay. **Done** (17 November 2026); balance still to be tuned by play.
- A3) health bars over the cat and the mount, and the mount taking hits. **Done** (17 November 2026).
- B) home levels 4–6 and new Blender models (campfires, bigger tree homes); skins (colour skins now, accessories
  later). **Done** (17 November 2026).
- C) the camp guardian (Meshy model, guardian stone, behaviour, upgrades), then the garden, cooking and fishing.
  **Built** (18 November 2026, docs/PHASE_C_SPEC.md, notes in docs/PHASE_A_PROGRESS.md). Gifts: the garden and its
  cooking pot come with the first win of mission 1 (with 4 Sunberries), the Fishing Spot with mission 6. The Moss
  Warden is built and tested but no mission gives it: Phase E frees it in the first Burrow (`stations.free_guardian()`).
  A knocked-out mount stays out in a mission until it is fed (2 Sunberries, the HUD's Feed button) or the next chapter
  break. Nothing in Phase C moves on while the game is closed (plants grow per wave held, a dish lasts one chapter).
- D) the game after the missions: Gloom Raids and keeping the camp up. **Built** (18 November 2026,
  docs/PHASE_D_SPEC.md, notes in docs/PHASE_A_PROGRESS.md): the meter, the Watch, four raid kinds, the Gloom Herald
  (the Crow Drummer at 1.25x until its Meshy model comes) and the rout, shards and what they buy, wear, Mend all.
  Left: the Herald's model (D10) and a balance pass on the phone; the optional Moth Lantern and Bramble Snare (D12).
- E) the Burrows (dungeons). **Built** (18 November 2026, docs/PHASE_E_SPEC.md, notes in docs/PHASE_A_PROGRESS.md):
  the Old Hollow with five tiers of depth, traps, the Leaf Dash, the new monsters on stand-ins,
  the satchel and the top upgrades, home levels 7-8, attachments, and the Moss Warden freed in the first clear. The room runs
  were replaced on 18-19 Nov by the Gloomwood path dungeon (docs/DUNGEON_SPEC.md; Old Grubber deleted). Left:
  the Meshy models of the new monsters, and a balance pass by play on the phone.
- F) bonds, fletching, decorating, daily and weekly tasks, endless mode. Islands later.

## 1. The game in one line

A cat ranger defends her forest camp from gloom-touched creatures that come out of the woods. She grows the camp into
a fortress, collects better bows, and takes the forest back one patch at a time.

- **Platform:** Android phone, **portrait only** (never landscape), played with one thumb. The controls are the Cat
  Ranger prototype's: press anywhere and drag, a joystick appears under your finger, and the cat walks or runs that way.
- **No menus:** opening the game drops you straight into the camp, with the cat standing in it. Everything is done by
  walking somewhere (see section 3).
- **Engine:** Godot 4.7.2, mobile renderer.
- **Hero:** the Cat Ranger from `D:\3D Modeling Test\CatRangerGame` (model, clips, cloth, hood, ears, auto-aim), copied
  in as it is.
- **Art:** low-poly with visible facets and bright fantasy colours, the same style as the cat.

## 2. World and look

- **Setting:** a sunny clearing in a jungle-like forest: giant friendly trees, ferns, flowers, glowing mushrooms,
  fireflies and a stream. The cat's camp is in the middle.
- **The Gloom:** a violet haze hangs in the woods around the clearing. Woods under the Gloom are darker and tinted
  violet, and every enemy walks out of it. When you claim a patch of woods, the Gloom bursts away in a splash of light
  and petals and the colour comes back, so progress is visible on the map.
- **What makes it recognisable** (someone should know a screenshot is LEAF):
  - The faceted low-poly look in saturated colours.
  - Splashes everywhere. A hit pops a burst of leaves. A kill bursts into leaf confetti and drops golden leaves. Level
    ups and new buildings throw a ring of flowers.
  - Squash and stretch on enemies, pickups and buildings as they upgrade.
  - Lush meadow grass in darker and lighter patches, full of tiny flowers, that bends away from the cat and the
    enemies as they walk through it. Tall grass patches and bushes to hide in. Trees sway; some canopies are
    coral-pink.
  - A lake beside the tree home: turquoise shallows and a deep blue middle with gentle ripples and glints, a sandy
    pebbly shore with mossy rocks, cattails, lily pads with pink flowers, a little plank dock, fireflies, and a fish
    that jumps now and then.
  - Winding cobblestone roads with ragged grassy edges, pebbles, rocks, ferns and flowers along the sides, and a
    lantern on each trail. Soft rays of sunlight slant through the trees.
  - Cloth and fur that move: the cat's hood, capelet and skirt (already working), plus enemy bandanas, capes, tails,
    leaves and fur.
  - Violet glowing eyes and violet crystals on every enemy: the mark of the Gloom.
- **Camera:** the same high camera as the prototype, looking down at about 50 degrees, following the cat. In the camp
  it pulls back a little so you can see more of your home. It moves in to the normal fighting distance when you leave
  the firelight.

## 3. How a game plays

### The camp: the safe home base

The camp starts small and wild: **the cat's tree home and a campfire next to it**, nothing else. The warm firelight
round the campfire is the safe area: nothing can hurt the cat inside it and no enemy can step into it. There is no
ready-made fence. The camp grows from here as you play (the look: mossy, lush, warm lights, like the reference images
the user shared; the tree home was modelled live in Blender, `art/blender/props/home_tree.blend`).

**Using things without menus.** (Updated 19 Nov 2026: Tap to open; there are no ground rings.) Every usable thing has a
leaf-pin marker floating over it. Tap the marker, or the thing, and a card opens as a dialog in the middle of the
screen, showing what it does and what the next thing costs; out of reach the cat walks there first. Tap the card's
button to buy it. The X, a tap outside or the back button closes it. Walking near something opens nothing.

**The camp's layout** (the user, 18 November 2026): the campfire is the centre of everything, with open ground all
round it, and the home stands beside it (stepping back to the north-west as it grows). The other buildings live round
the fire and the home, near them but a little apart and not in a ring, each on its own path from the fire: the Training
Target and the Bow Bench east of the fire, the Mushroom Cottage and the Market Stall further round to the south-east,
and the Wishing Well on the near shore of the lake, which lies beside the camp to the south-west, not in it. The camera
looks north from the south, so nothing tall stands just south of where the cat walks, every marker's spot is on the camera's
side of its building, and the ground straight south of the fire stays open. The north is the four trails and the
battle; the south the garden and the path to the Burrows.

**The screen** (the user, 18 November 2026): the middle of the screen is the cat's; nothing of the HUD sits there but
the health bars over the cat and the pointer arrow. One slim bar across the top (on a soft dark strip, below the phone's
status bar) holds the leaves, timber and shards, the dish of the chapter, and on the right the fight's bar (the
campfire, the raid meter and its countdown, the Gloomwood's fight pips) with the status line. The boss bar, the banners (a
compact strip of about two seconds; a mission won or lost a little bigger) and short messages sit just under it. Tips
and the "drag to move" hint are one small line just above the buttons at the bottom. A card opens as a dialog in the
middle of the screen with an X (since 19 Nov 2026). Only the markers near the cat (and the one it is
walking to) show full size; the rest are small and dim. Pickup numbers are small and quick, and the same kind landing together
adds up.

| Spot | What you do there |
|---|---|
| **Tree home: the shop** (its counter, under a striped awning) | buy everything: the Training Target and the Bow Bench (once the first fights have shown them), the cat's own upgrades (health, move speed, leaf magnet), fence pieces, towers and spikes (once woods are claimed), defence upgrades, and growing the home |
| **Training Target** (built from the shop) | damage, draw speed and range. The cat shoots the target by itself while it stands there, so you see the upgrade at work |
| **Bow Bench** (built from the shop) | craft, swap and upgrade bows |
| **Signpost** (at the edge of the firelight) | pick the woods to fight in; between waves, call the next wave |

**Building.** Road barricades, acorn towers and thorn spikes bought in the shop go into your bag (fences were removed
in Draft 6). A build button appears; tap it and a ghost of the piece stands just in front of the cat (a barricade only
at the glowing road spots). Walk it where you want it and tap Place. Barricades stop enemies, who have to break
through them. Every piece of a kind shares one level, upgraded in the shop.

**How the home grows:** level 1 is the tree home (a hollow tree with a round door, a mossy roof and the shop counter);
level 2 is a bigger tree home; level 3 is the treehouse. Each level makes the firelight bigger, gives the campfire more
health and lets every station and defence go one level higher.

The first concept images in `concepts/camp/` show an earlier idea (a tent inside a round fence); the user replaced it
with the tree home and free-placed fences.

### Out in the meadow: the fight

**Going out.** Tap the signpost and pick the woods. The camera moves in and the first wave comes out of
the Gloom.

**A wave (about 1 minute).** Enemies come along their trail to the edge of the firelight and try to put out the
campfire. You drag to move. The cat shoots the nearest enemy in range by itself. Barricades hold them up, towers and spikes
hurt them. Enemies drop **golden leaves**; whatever is left on the field flies to the cat when the wave ends.

**Between waves (short, no timer).** Shop, build and place pieces, then tap the signpost for the next wave.

**Hiding.** Patches of tall grass and bushes in the meadow are hiding places. In one, the cat turns see-through and
enemies can't see it unless they walk right into it, so you can let a wave pass, slip away, or wait for the right
moment. While hidden the cat holds its fire until an enemy is within 3 m. After 1.5 seconds in hiding, its next shot
is an **Ambush** for double damage, and every shot gives it away for a moment. Bushes rustle and shed leaves when
anything pushes through them.

**A stage = 5 waves on one patch of woods.** Wave 5 has a big enemy or the boss. Clear it and that patch is yours.

**Losing.** The stage is lost when the campfire goes out. The enemies are pushed back into the woods and you are safe
in the camp again. If the cat is knocked out during a wave, it gets up by the campfire after 5 seconds. You keep every
leaf you collected, even in a lost stage, so every run counts toward the next upgrade.

**Long term.** Claimed woods grow the map and unlock new buildings and bows. The enemies get tougher with every patch,
and so do the cat and the camp.

## 4. Upgrades (the grind)

**Currencies (MVP).**
- **Golden Leaves:** dropped by every enemy, spent on almost everything.
- **Timber:** comes from claimed woods after each stage, spent on camp buildings and growing the camp.

### Stations gate the upgrades

Base-builder style, but LEAF's own game. Nothing can be upgraded at the very start: you play first, earn leaves, and
the stations appear and grow. **A station's level caps what you can buy there**, and **the camp level caps every
station**. So getting a better bow means playing, upgrading the Bow Bench (which needs a bigger camp, which needs
claimed woods), and then crafting and levelling the bow. There are no waiting timers: an upgrade is instant once you
can pay for it.

| Station | Its level caps | Level 1 | Level 2 | Level 3 |
|---|---|---|---|---|
| **Home** (camp level, grown in the shop) | every other station's level, defence levels, the firelight's size, the campfire's health | tree home | bigger tree home (needs 1 claimed patch) | treehouse (needs 3 claimed patches) |
| **Training Target** | Damage, Draw speed, Range | stats up to level 4 | up to level 7, unlocks Range | up to level 10 |
| **Bow Bench** | bow levels and which bows can be crafted | Twig Bow up to level 4 | crafts the Sunwood Longbow, bows up to level 7 | crafts the Thorn Volley, bows up to level 10 |
| **Home** (the cat's own upgrades, sold in the shop) | Health, Move speed, Leaf magnet | up to level 4 | up to level 7 | up to level 10 |

The exact prices and caps are in `game/data/balance.json`.

### The cat

| Stat | What it does |
|---|---|
| Damage | arrow damage |
| Draw speed | shots per second |
| Range | how far it auto-aims (now 5.5 m) |
| Health | hits before it is knocked out |
| Move speed | run speed |
| Leaf magnet | how far away leaves fly to the cat |

### Bows

Each bow changes how the cat shoots, looks different in its paw, and levels up on its own.

| Bow | Shot | In MVP |
|---|---|---|
| Twig Bow | one arrow (the bow it has now) | yes |
| Sunwood Longbow | longer range, the arrow goes through 2 enemies | yes |
| Thorn Volley | 3 arrows in a fan, less damage each | yes |
| Ember Bow | fire arrows: small splash and burn | later |
| Frostpetal Bow | arrows slow enemies | later |
| Storm Seed Bow | lightning that jumps between enemies | later |

**Gear on the cat (later).** Hood, cape, quiver and charm slots. Each piece adds a stat and shows on the model, for
example a new hood colour or a bigger quiver.

### The camp

- **Home level** (grown in the shop): a bigger firelight, a stronger campfire, and higher levels for every station and
  defence. The tree home grows with it, up to the treehouse, and each step is a new model.
- **Defences** are bought in the shop and placed anywhere in the meadow; every piece of a kind shares one level (1 to 3):

| Defence | What it does | In MVP |
|---|---|---|
| Road barricade (fences were removed) | goes across a road at a fixed spot; enemies must break through it (the Boar smashes it) | yes |
| Acorn Tower | shoots acorns at enemies by itself | yes |
| Thorn Spikes | hurt whatever walks over them | yes |
| Spore Trap | a cloud that slows and poisons | later |
| Healing Totem | heals the cat near the camp | later |
| Firefly Lantern | hits flying enemies | later |

### The woods (territory)

The map is big but has an edge. The woods around the clearing are split into patches. MVP has **4 patches** (north,
east, south and west), each one a 5-wave stage. Patch 4 ends with the boss. Claiming a patch lifts the Gloom from it,
gives timber after every later stage, unlocks something (a bow, a defence or a home level), and makes the next
patch's enemies stronger.

## 5. The enemies (5)

The concept images are in `concepts/enemies/`, one image per enemy, ready for your 3D AI. The prompt behind each one is
in `concepts/enemies/prompts/`.

| # | Enemy | Role | Behaviour | Moving parts for rigging |
|---|---|---|---|---|
| 1 | **Thornling** | swarm | a small ball of bramble vines; quick, dies in 1 or 2 hits, comes in groups of 5 to 10. **Special: pounces** at the cat in a hop | the curled fern on top and the side leaves bounce, it waddles |
| 2 | **Toadstool Brute** | tank | slow with lots of health. **Special: spore burst** (a green ring warns first) that hurts and slows the cat | the big cap wobbles |
| 3 | **Raccoon Bandit** | thief | fast and fragile; grabs the golden leaves lying on the field before you pick them up and runs back to the woods. Catch it to get them back. **Special: vanishes in smoke** and sprints off after a theft or a hit | the bandana tails flutter, the fluffy tail swings |
| 4 | **Bramble Boar** | charger | stops and paws the ground (a red line shows the path), then charges in a straight line; smashes fences and knocks the cat back | the bristly mane moves, it runs on four legs |
| 5 | **Mossback, the Gloom Bear** | boss | huge health; a ground slam (a violet ring warns first); a roar that calls Thornlings; **Gloom Dash**: wind and leaves swirl round him, a line shows where he will go, then he rushes the cat and swipes for double damage | fur, the moss mantle and the torn cape |

<img src="concepts/enemies/01_thornling.png" width="19%"> <img src="concepts/enemies/02_toadstool_brute.png" width="19%"> <img src="concepts/enemies/03_raccoon_bandit.png" width="19%"> <img src="concepts/enemies/04_bramble_boar.png" width="19%"> <img src="concepts/enemies/05_mossback_bear_boss.png" width="19%">

Every attack flashes a swipe and throws up leaves and dust, and walkers lean into their stride and kick up dust.

**Getting harder.** Enemy health and damage go up about 15% for every patch claimed. New types appear one at a time:
patch 1 has Thornlings, patch 2 adds the Brute, patch 3 adds the Bandit and the Boar, and patch 4 brings Mossback.
Elite versions (bigger, with more crystals) come later.

## 6. Progression: from the first minute to the boss

The rhythm: at the start something new appears every minute or two, then every stage, then every session. Losing never
wastes your time.

### The first minutes

There are no tutorial screens. The game teaches by doing.

| Time | What happens |
|---|---|
| 0:00 | The game opens in a wild clearing: the cat, its tree home and the campfire. One hint: "Drag to move". A "!" marker shows over the signpost |
| 0:20 | The player taps the signpost and wave 1 of the first patch starts: 6 slow Thornlings. The cat shoots them by itself, which teaches the whole fight with no words. They drop golden leaves, and the leaf counter appears with the first one picked up |
| 1:00 | Wave over. An arrow points to the shop, which now sells a **Training Target** (15 leaves). Build it, then buy Damage there: the cat shoots the target and bigger numbers pop |
| After wave 2 | The shop sells the cat's own upgrades: Health, Move speed, Leaf magnet |
| After wave 3 | The shop sells the **Bow Bench**: upgrade the Twig Bow |
| Wave 5 | A big **Thornling Chief**, the first boss-like moment |
| About 6:00 | Patch 1 is claimed. The Gloom bursts away from that part of the woods, the first timber comes in, the shop sells **barricades** (3 come free) and growing the home |

Building is learnt by doing: the free pieces come with a build button and a tip.

### The path to the boss

| Patch | Enemies | You get when it starts | You get for claiming it | Expected |
|---|---|---|---|---|
| 1. Fernwood | Thornlings, Thornling Chief on wave 5 | the camp basics, one per wave (above) | Campfire upgrades, timber | first session, about 6 minutes, won first try |
| 2. Toadstool Dell | adds the Toadstool Brute | Acorn Tower; Range at the target | Sunwood Longbow (goes through enemies, good against Brutes in a line); the Hut (camp level 2) | first session, 1 or 2 tries |
| 3. Bandit Thicket | adds the Raccoon Bandit and the Bramble Boar | Thorn Spikes (they stop Boar charges); defences level 2 | Thorn Volley (3 arrows, good against swarms and fast Bandits); the Treehouse (camp level 3); defences level 3 | second session, 2 or 3 tries: the first real wall |
| 4. Mossback's Den | everything, and Mossback on wave 5 | nothing new: this is the test | the Gloom lifts from the whole map, and Gloom Night opens (below) | third session, 2 to 4 tries: the big wall |

Each new enemy arrives together with the thing that beats it, so a new problem always comes with a new tool.

Beating Mossback takes about 2 to 3 hours of play. That is long enough to show whether testers want to keep going.

### Grinding: what you do when you are stuck

- **Replay any claimed patch.** The signpost's card lets you pick the patch: the next new one or any you already claimed.
  Old patches are easier and still pay leaves, so they are where you farm for the next upgrade.
- **Losing keeps everything you picked up.** After a loss, the banner points at one useful upgrade you can already
  afford, for example: "Your arrows bounce off Brutes. Try Damage at the training target."
- **Timber grows with the map.** Every claimed patch adds 10 timber each time you finish a stage, so with 3 claimed
  patches you get 30 per stage. Timber pays for camp levels, so the camp grows as the map does.

### First numbers

These are a first guess. They all live in data files, so tuning them later needs no code changes.

- **Leaves per enemy:** Thornling 2, Bandit 5 (plus whatever it grabbed), Boar 6, Brute 8, Thornling Chief 30,
  Mossback 300.
- **Stage bonus:** 50 leaves × the patch number when you win. Nothing extra when you lose, but you keep what you picked
  up.
- **What one stage pays:** about 150 leaves in patch 1, 350 in patch 2, 650 in patch 3 and 1,100 in patch 4.
- **Upgrade prices:** each level costs about 35% more than the one before. Damage, for example, goes 15, 20, 27, 37,
  50, 67, 90, 122, 165, 222 (10 levels in the MVP).
- **Big buys:**

| Buy | Price |
|---|---|
| Hut | 300 leaves + 20 timber |
| Treehouse | 1,200 leaves + 60 timber |
| Sunwood Longbow | 250 leaves |
| Thorn Volley | 600 leaves |

- **Enemies** get about 15% stronger per patch. You keep up only by spending what each patch pays.
- **The target:** about 3 to 5 upgrades bought per stage. Fewer feels like a slog; more and the walls disappear.

### After the boss (still in the MVP)

**Gloom Night:** an endless mode you start from the signpost once Mossback is beaten. Waves come from all four patches at
once until the campfire goes out. It pays leaves and shows your best wave. This is what testers grind to max out their
upgrades, and it shows us whether the loop stays fun after the story ends.

### The long game (after the MVP)

- **The map grows outward.** Beating Mossback opens a trail to the next location, the next ring of woods around the
  camp: Mushroom Grove, then Crystal Lake, Old Ruins and Misty Swamp. Each has 4 patches, 2 new enemies, a boss, a new
  bow, a new defence and the next camp level (Tree Fort, then Great Tree). The camp stays the one home and keeps
  growing.
- **New systems, one per location** so there is always something new to learn: cat gear in location 2, perk cards
  between waves in location 3, helper cats in location 4, and leaves and timber earned while the game is closed.

## 7. MVP: the first version for testers

**In**
- One map: the camp clearing and 4 woods patches, with trails, trees and **grass that moves when the cat and enemies
  walk through it**.
- The Cat Ranger, copied in as it is now: moving, auto-shooting, cloth, ears.
- The 5 enemies, plus the Thornling Chief (a bigger Thornling). Placeholders until your models arrive, then the real
  rigged and animated models.
- The progression in section 6: the first-minutes flow, unlocks patch by patch, replaying claimed patches, and Gloom
  Night after the boss.
- The camp as the safe home base the game opens in: the tree home with its shop, the campfire and its firelight, the
  signpost, and the Training Target and Bow Bench built from the shop; 3 home levels; fences, towers and spikes placed
  anywhere.
- 3 bows, 6 cat stats, and 3 defences at 3 levels each.
- Golden Leaves and Timber, saved on the phone between sessions.
- The splashes: leaf bursts on hits, confetti on kills, the Gloom lifting from a claimed patch.
- No menus. The HUD shows leaves (and during a fight the wave number and the campfire's health) in a slim bar at the
  top. The upgrade cards dock at the bottom of the screen, and short banners under the top bar say when a stage is won
  or lost (section 3, "The screen").
- An APK for testers.

**Not yet:** gear and cosmetics, more bows, new locations, flying and ranged enemies, helper cats, quests, earnings
while the game is closed, music, and anything about money.

## 8. How it gets built

- **Project:** a new Godot project in `D:\Projects\Project LEAF\game`. The Cat Ranger files come over unchanged:
  `CatRanger.glb`, the arrow, `CatRanger_clips.json`, and `player.gd`, `body_twist.gd`, `cloth.gd`, `cloth_fit.gd`,
  `arrow.gd` and `joystick.gd`. The prototype's `main.gd` (the arena) is replaced by the real map, waves and camp.
- **Your 3D models to game-ready enemies:**
  1. You generate the model from its image in your 3D AI and send me the file (GLB, FBX or OBJ, with its texture).
  2. In Blender I fix the scale, which way it faces and its origin, cut it down to a phone-friendly size, and check the
     texture.
  3. I rig it: a body skeleton (2 legs, or 4 for the Boar) plus extra bone chains for the parts that should swing: the
     Thornling's fern and leaves, the mushroom cap, the bandana, tails, the mane and the cape.
  4. I animate it: Walk, Run, Attack, Hit and Die, plus Charge for the Boar, Steal for the Bandit, and Slam and Roar for
     Mossback.
  5. I export a GLB and a clips file to the game, the same way the cat was done.
  6. In the game, the swinging parts use the same spring-bone simulation as the cat's cloth, made general so any enemy
     can use it.
- **Size limits for phones** (up to about 40 enemies on screen):

| Model | Triangles | Texture |
|---|---|---|
| Thornling | up to 1,500 | 512 px |
| Brute, Bandit, Boar | up to 4,000 | 1024 px |
| Mossback | up to 10,000 | 1024 px |

- **Moving grass:** thousands of grass blades drawn in one batch (MultiMesh). A shader bends each blade in the wind and
  away from up to 16 nearby walkers (the cat and the closest enemies). This is cheap enough for phones.
- **Balance in data files:** enemy stats, waves, upgrade costs and bows live in data files, so tuning does not need
  code changes.

**Other models to make with your 3D AI** (I can write image prompts for these the same way):
- Camp: Campfire, Tent, Hut, Treehouse, bow bench and fletcher's workshop, training target, leaf basket and chest,
  twig fence and log palisade pieces, signpost.
- Defences: Bramble Fence, Acorn Tower, Thorn Spikes.
- Bows: Sunwood Longbow and Thorn Volley.
- Nature: 2 big trees, a gloom-covered tree, bush, fern, rock, flowers and decorative mushrooms.

## 9. Milestones

1. **Core loop:** new project with the cat; the game opens in the camp (safe in the firelight, rings that pop up
   cards); the signpost starts a wave; the meadow with moving grass and trails; waves from the woods; leaves to
   collect; the campfire's health with win and lose; saving. (Built.)
2. **Camp and woods:** the camp spots and camp levels, build spots and the 3 defences, claiming patches with the Gloom
   lifting, timber.
3. **Real enemies:** your 5 models rigged, animated and given swinging parts, with their behaviours (swarm, tank,
   thief, charger, boss).
4. **Polish and test build:** splashes, hit effects, placeholder sounds, a balance pass, and the APK for testers.

## 10. Ideas for after the MVP

- **New locations,** each with its own enemies and boss: Mushroom Grove, Crystal Lake, Old Ruins, Misty Swamp.
- **More enemies:** Gloom Moth (flies over walls), Frog Shaman (heals from far away), Beetle Knight (shield in front),
  Owl Witch (boss).
- **Helper cats** that guard towers: a sword cat and a mage cat.
- **Perk cards:** pick 1 of 3 between waves, for that stage only (split arrows, bouncing arrows, crits).
- **Day and night:** harder waves at night, with fireflies and lanterns.
- **Earnings while away:** claimed woods produce leaves and timber while the game is closed.
- Daily quests, achievements, cat cosmetics.

## 11. Questions for you

Answered: the game is portrait only, has no menu, opens in the camp, the camp is safe, and you use things by walking
up to them.

1. **Losing:** the stage is lost when the enemies put out the campfire, and the cat gets back up after being knocked
   out. Is that right?
2. **Length:** is about 5 minutes per stage (5 waves) right for phone sessions?
3. **3D AI:** which one will you use? It changes how much clean-up the models need.
