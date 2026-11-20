# Map preview tool

Runs the game's real map, gun and car code outside Roblox, using a tiny mocked Roblox API in Luau. It exports every part to JSON and renders the result with three.js.

```bash
cargo build --release                       # builds the Luau runner (mlua)
./target/release/rbxmock bootstrap.lua ../.. ../../src/server/Maps/Downtown.lua out/Downtown.json
npm i three@0.160.0
python3 make.py local out/*.json            # -> preview_local.html (serve with any static server)
python3 make.py cdn out/*.json              # -> preview.html (self-contained, loads three.js from a CDN)
```

Terrain is drawn as 4-stud voxels. In Roblox it renders smooth.
