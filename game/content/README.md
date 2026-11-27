# Game content

Each kind groups entries by ID under `<kind>/<id>/`. An entry lives in
`entry.json` beside its model, icon, and any other assets for that entry.
Keep folder IDs lowercase with underscores and stable after release.

`index.json` lists the IDs for each kind. Data reads the index at startup,
including in Android exports.

See [Architecture, part 5](../../docs/ARCHITECTURE.md#5-content-one-folder-per-thing)
for the entry format and index workflow.

## The shop kinds (H5)

`mounts`, `pets`, `outfits` and `attachments` hold what the Market, the
Saddlery and the Tailor's Nook sell. `scripts/shop_data.gd` reads them, and
callers ask `Data` (`Data.shop_entries`, `Data.owned_level`, ...).

Every entry has the shared fields `id`, `name`, `desc`, `icon`, `price` and
`unlock`, and may have `hidden: true`.

- `price` is a currency dictionary, such as `{"leaves": 160}` or
  `{"leaves": 900, "timber": 30}`. `{}` means free, or included once its
  `unlock` rule holds (Thistle and Bramblewool come with the Market, the
  original outfit is always owned). A missing price, or one in a currency the
  shops cannot take (amber, or one the game does not know yet), is never sold.
- `icon` is a picture ID drawn in `scripts/ui_icons.gd`. It stands in when the
  optional `picture` file (a `res://` path, such as
  `res://content/mounts/thistle/icon.png`) is missing.
- `model` is a `res://` path. The shipped models stay where they are in
  `assets/`.

What each kind adds:

| Kind | Its own fields |
|---|---|
| `mounts` | `short` (the short name), `shop` (`stall`), `fur` and `skins` (the colours). Every mount has the same speed, health and skills. |
| `pets` | `short`, `shop` (`stall`), `flies`, `spark`, `fur`, `skins`. `looks_only: true` (Lumi) buys only the look, and only once the pet is owned. All pet looks share one pet level. |
| `outfits` | `picture` (the Tailor's card), `model` (a whole hero model; `""` for the original look, which uses the hero model). |
| `attachments` | `shop` (`saddlery` or `stall`), `slot` (`mount` or `pet`), `scope` (`all`: works everywhere; `expedition`: the Burrows only). A Saddlery attachment has `price` for level 1 and `upgrades` for levels 2 to 5 (`needs_burrows: true` is a gate, never a payment), its effect numbers, and `model` with `{mount}` standing for the mount look's ID. Expedition gear has one price and its `mods`. |

What the player owns is in the save (version 5): `owned[kind][id] = {"level": n}`
(1 for a look or an outfit, the bought level for a Saddlery attachment), read
through `Data.owned_level`. The pet has one shared level (`Save.pet_level`), and
an old save's Mushroom Cottage and Market became the pet, the mount looks and the
mount's carried tier (`core/save_upgrade_v5.gd`). The Cottage's building entry is
gone; its picture and model stay in `assets/`.

To add one: copy an entry of the same kind, give it a new folder ID, list the
ID in `index.json`, keep it `hidden` until the owner says it goes in, and run
`--content`.
