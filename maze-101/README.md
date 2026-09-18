# Maze 101 visual and reference milestones

The current visual-regression target is the daytime interior maze frame from
[MayGo/maze-world](https://github.com/MayGo/maze-world). The launch target stays
on the generated `easy-room` while the restored `archipelago` hub and historical
`island-1`, `island-2`, and `island-3` worlds remain available for later work.

Studio uses `studio.json` to launch the playable `easy-room` with its Gameplay
camera. WASD/arrows move, Space jumps, drag orbits, and the wheel zooms.
The separate `maze-world-reference` world contains the source-derived Main
Island mesh and remains visual-only; it has no mesh collision.

The gameplay visual-regression target is `screenshots/maze-world-6.png` in the
original `other-examples/maze-world` checkout. The maze's presentation bound is
`[-62, -2, -62]` to `[62, 14, 62]`. Its 15-unit corridors, 12-unit green walls,
and open starting corridor provide the playable comparison. Keep it focused on camera/FOV, player-to-wall
scale, grass wall and sand floor response, daylight, sky, and shadow shape.
For island inspection, temporarily set `previewWorld` to
`maze-world-reference` and `reviewCamera` to `showcase`. Left-drag orbits,
right/middle-drag pans, and wheel/pinch zooms. Click the preset again to reframe.
This view exposes remaining renderer/import gaps against the original island
screenshots; it is not a gameplay level.

The exit is at the farthest dead end, cell `[3, 7]`, so collecting all eight
coins never requires passing through the finish trigger first. Coins are
optional, the timer is 150 seconds, and the exit remains open after time expires.
Studio's Restart begins a fresh run.

Build the package with:

```sh
cargo run --release --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  build-game --source . --output build/package
```

Regenerate the reference mesh from a local importer artifact with:

```sh
cargo run --release --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  export-reference-mesh \
  --scene /Users/aa/Downloads/reference-scene.json \
  --output assets/models/maze_world_reference.glb \
  --path-prefix 'Folder:Place[1]/Folder:Main[1]/Model:MainIsland[1]'
```

The 27 MB JSON remains an uncommitted development artifact. The generated GLB
is the compact package asset consumed by the normal shared renderer. The export
preserves source colors without an invented tint, uses explicit `builtin:`
material names, and follows the source wedge orientation. Real MeshPart assets,
source sky/post-processing, and imported-mesh collision are still missing.

The generated package is disposable output. If a build leaves removed asset
files in `build/package`, delete only those stale files before reviewing it.

Verify the built package's collision, all eight coins, and the exit with real
movement inputs (plus a separate debug-skip check):

```sh
CUBACADABRA_TEST_MAZE_PACKAGE_DIR="$PWD/build/package" \
  cargo test --manifest-path ../../rust/Cargo.toml --lib --no-default-features \
  --features headless maze_tests -- --ignored --nocapture
```
