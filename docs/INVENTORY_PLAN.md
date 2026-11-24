# Supplies inventory plan

23 November 2026. Approved and implemented in this session, including the owner's revised layout. Gameplay continues while the Bag is open. One view contains a square supplies grid, a currency strip, and a preview of the current cat, with her mount while riding. PC verification passed `--smoke` and 53 checks in `--inventory` at the S24 screen shape with simulated safe areas.

## Purpose

Help the player answer three questions wherever they are in the game.

- What food, money, and materials do I have?
- What can I use, and what will it do?
- What did I just gain or spend?

The inventory's scope is food, consumable supplies, and the existing economy. The Market handles trade, the cooking pot makes dishes, the garden handles crops, and the other buildings handle their services. The bag gives the player a view of their supplies and access to dungeon food use.

## What the game already does

- `Save.pantry` holds Sunberries, Fernmint, honey, fish, and Golden Carp. The configured capacity is 20 of each.
- Garden picking, fishing, and Market purchases add food. Recipes, mount feeding, and dungeon snacks spend it.
- The pot already prints pantry totals and recipe requirements as text. Those amounts need a clearer visual presentation and visibility beyond the pot card.
- `Save.meal_ready` holds the dish waiting in the pot. `Save.meal_on` holds the dish whose boost is active. The next chapter or dungeon run activates the waiting dish.
- `main.snack_pick()` chooses the first available food from `burrows.lunch`. The order is fish, honey, Golden Carp, Fernmint, then Sunberries.
- `main.eat_snack()` heals in a dungeon and consumes one food, with `burrows.snack_every_s` between uses.
- The garden shows the amount gained in floating text. The player needs the resulting owned total as well.
- Currency and material totals live in `Save` and are read through `Data.have()`. Materials collected during a dungeon run also have their own satchel counts.

These existing values and actions are the basis of the feature.

## 1. A compact Bag panel

Add a small Bag button in a bottom corner, clear of the joystick, dash gesture, and existing action buttons. Its position must fit the S24 safe area and the game's supported portrait sizes.

Open one compact panel using the existing parchment, wood, icons, and close controls. Leaves, timber, and shards appear as icons with counts at the top. Square item slots hold food, keys, materials, unplaced defences, and waiting or active dishes together. Empty slots complete the rows. Android Back, the X, and a tap outside close it. The panel scrolls on shorter screens. Opening a building card and opening the bag are mutually exclusive.

Show the actual cat beside the selected item's details. While riding, show the cat seated on the current mount. The preview uses the live models and bone poses, including the worn outfit, equipped bow, mount look and attachments. It renders in a small isolated viewport while the Bag is open. This uses the existing game assets.

### Food

- Display each known food in a square slot with its icon and count. Selecting it shows its name and capacity, such as `Sunberries 8/20`, beside the cat.
- Show known foods at zero so the player can see what has run out. Food already owned always appears, including after loading an older save.
- Selecting a food shows its dungeon healing amount, its cooking uses, and any mount-feeding use.
- Provide Eat during a dungeon run and Use for quick heal as distinct actions.
- Show the cat's current and maximum health beside the food actions.
- Give waiting and active dishes their own slots with a state label. Selecting one shows its effect and when it activates or ends.

Food descriptions explain every relevant use. For example, Sunberries restore 2 health in a dungeon, are used in recipes, and two revive a knocked-out mount. The actual values come from the existing balance data.

### Resources

- Show golden leaves, timber, Gloom shards, Hollow keys, Root Amber, Glowstone, and Heartwood as their systems become available. Always show an owned resource.
- Give each item its icon and count in the shared grid. Selecting a resource shows its name, purpose and relevant limit beside the cat.
- During a dungeon, material slots show their current run counts. Selecting one shows amounts labelled At camp and This run, read from the stored stock and current satchel.
- Explain the lift-home and knock-out outcomes in the selected material's details. Use the game's existing settlement calculation for the keep amount.
- Give owned, unplaced towers and thorn spikes individual slots. Their details explain how to place them through the camp build controls.

## 2. Make dungeon healing visible and deliberate

The Bag's Eat action lets the player consume the selected food. The bottom quick-heal button lets them use it during action with one tap.

- Start with Auto selected for older saves. Auto follows the existing configured snack order.
- Let the player choose a particular food in the bag before or during a dungeon run.
- Label the quick button with the food, its quantity, and its healing amount, such as `Fish x3` and `Heal 4`.
- When a deliberately chosen food runs out, show its zero count and a Choose food action. Consuming a different food requires a new choice or selecting Auto.
- Show Full health, No food, or the remaining cooldown as appropriate. At full health, consuming food spends nothing.
- The Bag action and quick button use one consumption operation and one cooldown. Recheck quantity, health, run state, and cooldown when the action executes.
- Save the remaining food and healed run health together. Closing or resuming a run must retain both changes.
- Show the health actually restored in feedback, including when only part of the food's healing was needed.

### Reading behavior chosen by the owner

Gameplay continues while the Bag is open. Enemies, attacks, traps, raid warnings, and cooldowns keep running. The panel blocks touches behind it and closes through the X, an outside tap, or Android Back. A successful Eat closes it. The quick-heal button works directly during live play.

Counts, health, and action states update in place so live changes cannot replace a button during a tap. Opening the Bag keeps the shared snack cooldown running.

## 3. Show owned food where the player works with it

### Garden

- Put a small food-count strip near the top of the garden card.
- Before picking, show how much will be added and the resulting total.
- After picking, show feedback such as `+3 Sunberries - now 8/20`. Group several harvested foods into a readable receipt.
- When a harvest cannot fit, show its capacity reason clearly. The existing ripe crop stays available for a later pick.

### Cooking pot

- Put the same food-count strip above the recipes.
- Give each recipe ingredient a clear Have and Need count. For example, `Sunberries - Have 8, Need 3`.
- Show the dish's effect and activation time beside its Cook action. Missing ingredients are named directly.
- After cooking, update the ingredient totals and Waiting dish row immediately.
- If a dish is already waiting, label the replacement action and identify the dish that will be used up, along with the ingredients the new recipe costs.
- Keep all unlocked recipes reachable in a scrolling list. The current More recipes text can name dishes without giving them an actionable recipe row.

### Fishing and the Market

- Fishing feedback reports the amount accepted and the new total, including a partial or full pantry result.
- Market food and material tiles show owned counts clearly beside the offer.
- After a trade, update the resource and food totals and show the actual amounts bought or sold.
- Bag totals, building cards, and the HUD all refresh from the completed transaction.

## 4. Data and implementation approach

Use `Save.pantry`, `Save.meal_ready`, `Save.meal_on`, currency fields, `Save.mats`, and the active run's satchel as the sources of truth. The Bag reads those values directly.

Add one saved preference for quick-heal selection, with Auto as its default. Loading an unknown preference falls back to Auto. Reuse `burrows.lunch` for healing values, `mount.revive_food` for feeding costs, recipe requirements for cooking uses, and the existing balance values for capacities and cooldowns.

Keep the panel in a dedicated script and reuse the HUD's established visual controls. Integrate the Bag with dialog ownership, input blocking, safe areas, and Android Back. Refresh the selected item, its counts, and action availability in place. The preview script copies the existing models into an isolated world, strips their gameplay drivers, and follows their live bone poses.

| Area | Likely files |
|---|---|
| Bag panel and HUD integration | New `game/scripts/inventory.gd`, `game/scripts/hud.gd` |
| Cat and ridden-mount preview | New `game/scripts/inventory_preview.gd` |
| Food choice and shared healing action | `game/scripts/main.gd`, `game/scripts/data.gd` |
| Saved quick-heal preference | `game/scripts/save.gd` |
| Garden, pot, and Market presentation | `game/scripts/stations.gd`, `game/scripts/cooking.gd` |
| Fishing and shard-trade receipts | `game/scripts/fishing.gd`, `game/scripts/raids.gd` |
| Existing values and any approved tuning | `game/data/balance.json` |
| Verification | New `game/scripts/autotest_inventory.gd`, dispatched by `autotest.gd` |
| Game documentation after implementation | `docs/GAME_GUIDE.md`, `docs/STATUS.md`, `docs/CHANGES.md` |

## 5. Build order

1. Build the compact Bag with a shared square grid, currency counts, cat and ridden-mount preview, and selected-item details. Verify counts against an existing save and a fresh save.
2. Connect the garden, pot, fishing, and Market feedback to the same displayed totals. Verify the harvest-to-cooking flow on the phone.
3. Add explicit food selection, the labelled quick-heal button, and the shared consumption checks. Keep gameplay running during Bag interaction.
4. Verify saving, run resuming, item capacity, satchel settlement, and input behavior. Build the complete APK and check it on the owner's phone with the usual save backup.

## Acceptance checks

- The player can find every owned food and resource, its amount, and its purpose from the Bag.
- The supplies share one grid of square slots. Currency counts fit on one line. Riding and dismounting update the cat and mount preview.
- Picking crops shows the amount gained and the new total. Capacity-blocked crops remain ripe.
- Cooking shows owned and required amounts, spends the ingredients once, and displays the waiting dish and its effect.
- A waiting dish and an active dish can both be understood when both exist.
- The player can select a food and heal in a dungeon through either action. Food is consumed once, and health stays within its maximum.
- Full health, zero stock, cooldown, defeat, and dungeon transitions are handled visibly and consistently.
- Feeding the mount and healing the cat draw from the same displayed food counts.
- Restarting preserves both consumed food and restored dungeon health. Older saves use the Auto default.
- At camp materials and current run materials stay accurate through checkpoints, a return home, a knock-out, and run abandonment.
- Back, outside taps, overlapping dialogs, thumb gestures, and safe areas work at the supported portrait sizes.
- Gameplay continues during Bag interaction, including enemy movement and shared healing cooldowns. Dungeon transitions close the Bag.

Run `--smoke` and the focused `--inventory` mode sequentially, using the separate test save and `--disable-vsync`. Check the full harvest, cooking, and dungeon-healing flow on the phone before further polish.
