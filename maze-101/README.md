# Maze 101

Start on Maze World's source-derived floating island, cross the **Very Easy**
bridge, and stand in the waiting area to enter a maze. Find the exit before the
timer expires to return to the island with a reward. Coins are optional.

Studio and the shipping manifest both start in `maze-world`, using the Gameplay
camera. This package requires the current SDK 0.5 runtime/Studio build; older
builds must reject it instead of ignoring its collision. WASD/arrows move, Shift
runs, Space jumps, drag orbits, and wheel/pinch
zooms. Overview and Showcase are inspection cameras; left-drag orbits,
right/middle-drag pans, and clicking the preset again reframes the scene.

## Implemented loop

The room positions, island/bridge layout, initial 100 coins, room sizes, timers,
unlock prices, countdowns, and solo completion rewards follow the original
`other-examples/maze-world` source. Queue countdown is 4 seconds in DEBUG and
20 seconds in RELEASE. Leaving cancels it. Finishing, timing out, or dying
returns to the island; rooms have a 10-second cooldown.

| Room | Maze | Time | Unlock | Solo reward |
| --- | --- | --- | --- | --- |
| Very Easy | 5×5 | 60 s | Free | 25 |
| Easy | 10×10 | 180 s | 500 coins | 125 |
| Normal | 15×15 | 300 s | 2,000 coins | 1,000 |
| Hard | 20×20 | 600 s | 10,000 coins | 5,000 |

Unlocks and wallet last for the current local session, not across Restart.
Very Easy and Easy alternate between two baked seeds; Normal and Hard each
have one. Exits are explicitly authored dead ends checked against the built
maze. These are not newly randomized mazes on every visit. Farther source
islands are visible and marked **NOT PORTED**. DEBUG exposes a maze-only
“Skip to Exit” testing control; ordinary play does not require it.

## Source geometry and remaining fidelity gaps

`maze_world_hub.glb` includes the source Main, Rooms, and Leaderboards
hierarchies, uniformly scaled by 0.6 to match the Cubacadabra character.
Source transforms, wedges, Color3, and semantic materials are retained.
Separate versioned triangles make the actual islands and bridges walkable;
there is no invisible ground plane between them. World-mesh materials use the
normal shared renderer, including terrain textures and shadows.

The original local rock FBXs are reused. Protected Roblox palm/grass/rope mesh
assets were unavailable anonymously, so `prepare_reference_meshes.py` creates
explicit geometric substitutes at their source placements. These are not
claimed to be recovered Roblox meshes. Static lock placeholders are omitted:
game Luau and the retained HUD handle unlocks instead of baking permanent red
screens or invisible lock volumes into the scenery.

This is a playable local port, not an exact recreation yet. Source decals,
full MeshPart/Union geometry, sky/post effects, dynamic voting/dark mazes,
multiplayer ranking, pets/shop, persistent economy, original maze props and
kill blocks remain unported. The reference screenshots under
`other-examples/maze-world/screenshots` remain the visual target.

## Build and regenerate

Build from this directory; Studio uses the same native builder automatically:

```sh
cargo run --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  build-game --source . --output build/package
```

Regenerate source assets and the authored room data:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python scripts/prepare_reference_meshes.py
sh scripts/export_hub.sh /Users/aa/Downloads/reference-scene.json
python3 scripts/generate_worlds.py --scene /Users/aa/Downloads/reference-scene.json
```

The extracted scene JSON is a local development input, not a package asset.
The generated GLB, mesh overrides, and collision JSON are checked-in source
artifacts. Rebuild packages after regenerating; do not hand-edit built output.

## Verification

Opt-in real-package tests cover walking the hub bridge, queue cancellation and
entry, all six layouts with ordinary movement, collectible visibility,
completion/rewards, timeout return, and DEBUG skip. A separate economy fixture
checks explicit unlock confirmation and that revisiting never charges twice:

```sh
CUBACADABRA_TEST_MAZE_PACKAGE_DIR="$PWD/build/package" \
  cargo test --manifest-path ../../rust/Cargo.toml --lib --no-default-features \
  --features headless maze_tests -- --ignored --nocapture
```

Studio's DEBUG `CUBA_STUDIO_PROBE_DIR` captures the app-owned GPU framebuffer
without OS screen-recording permission; see the Studio README. Compilation,
headless checks, and framebuffer captures are separate evidence, not substitutes
for verification on Web, mobile, or other desktop hosts.
