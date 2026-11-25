# Game content

Each kind groups entries by ID under `<kind>/<id>/`. An entry lives in
`entry.json` beside its model, icon, and any other assets for that entry.
Keep folder IDs lowercase with underscores and stable after release.

`index.json` lists the IDs for each kind. Data reads the index at startup,
including in Android exports.

See [Architecture, part 5](../../docs/ARCHITECTURE.md#5-content-one-folder-per-thing)
for the entry format and index workflow.
