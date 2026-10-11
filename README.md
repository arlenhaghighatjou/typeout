# typeout
cool game

## Layout

- `src/` — scripts (`shared`, `server`, `client`)
- `serverstorage/` — syncs into `ServerStorage` (templates the server clones, e.g. `WordSign`)
- `src/shared/Guis/` — syncs into `ReplicatedStorage.Shared.Guis` (screen GUIs; the client copies them into PlayerGui on join)
- `workspace/` — everything in here syncs into `Workspace`
  - `Name.model.json` → one instance (a Part, Model, etc.) named `Name`
  - a subfolder → a `Folder` (add `init.meta.json` with `"className": "Model"` to make it a Model)

Game flow: public servers are the lobby (party menu over a view of the map). Starting a game reserves a
private server of the same place and teleports the party there; public games are listed through
MemoryStore. Teleports do not work in Studio, so in a Studio test "start game" runs the match in the same
server instead.

To run matches in a separate place, add a second place to the experience, publish this same project to it,
and put its place id in `ServerStorage.GamePlaceId` (`serverstorage/GamePlaceId.model.json`). While that is 0,
matches use a private server of the lobby's own place.

There are three maps and each round uses the next one. The first is spread over the top-level folders
listed below; `workspace/Frostpeak/` and `workspace/Harvest/` each hold a whole map, 4000 and 8000 studs
along X. Any top-level folder with a `Spawns` folder inside counts as a map.

The arena map lives in `workspace/` as one folder per area (`DesertIsland/`, `Mainland/`, `Cave/`,
`Pool/`, `Bridge/`, `Bridges/`, `Forest/`, `Meadow/`, `Grove/`, `Buildings/`, plus `Spawns.model.json`).

Run `rojo serve` and connect from the Rojo plugin in Studio. Things built by hand in
Studio's Workspace are left alone; they just aren't saved to this repo.
