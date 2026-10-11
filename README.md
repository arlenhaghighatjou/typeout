# typeout
cool game

## Layout

- `src/` — scripts (`shared`, `server`, `client`)
- `workspace/` — everything in here syncs into `Workspace`
  - `Name.model.json` → one instance (a Part, Model, etc.) named `Name`
  - a subfolder → a `Folder` (add `init.meta.json` with `"className": "Model"` to make it a Model)

The arena map is generated straight into `workspace/` as one folder per area (`DesertIsland/`,
`Mainland/`, `Cave/`, `Pool/`, `Bridge/`, `Forest/`, `Meadow/`, plus `Spawns.model.json`), so don't
edit those files by hand:

- `python tools/build_map.py` rebuilds it (layout, colours and props all live in that script)
- `python tools/preview_map.py` renders `tools/preview.png` for a quick look without Studio (needs numpy)

Run `rojo serve` and connect from the Rojo plugin in Studio. Things built by hand in
Studio's Workspace are left alone; they just aren't saved to this repo.
