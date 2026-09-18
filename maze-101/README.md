# Maze 101 visual and reference milestones

The current visual-regression target is the daytime interior maze frame from
[MayGo/maze-world](https://github.com/MayGo/maze-world). The launch target stays
on the generated `easy-room` while the restored `archipelago` hub and historical
`island-1`, `island-2`, and `island-3` worlds remain available for later work.

Studio uses `studio.json` to preview the separate `maze-world-reference` world
with its Showcase camera. That world contains the source-derived Main Island
mesh and is intentionally visual-only; the shipping manifest still launches
`easy-room`, and the historical progression worlds remain unchanged.

For the gameplay visual-regression pass, set `previewWorld` to `easy-room` in
`studio.json`. Its fixed presentation bound is `[-36, -1, -36]` to
`[36, 9, 36]`. Keep that comparison focused on camera/FOV, player-to-wall
scale, grass wall and sand floor response, daylight, sky, and shadow shape.
The default `maze-world-reference` preview instead exists to expose renderer
gaps against the source-authored island; it is not a gameplay level.

Build the package with:

```sh
cargo run --release --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  build-game --source . --output build/package
```

Regenerate the reference mesh from a local importer artifact with:

```sh
cargo run --release --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  export-reference-mesh \
  --scene /tmp/reference-scene.json \
  --output assets/models/maze_world_reference.glb \
  --path-prefix 'Folder:Place[1]/Folder:Main[1]/Model:MainIsland[1]'
```

The 27 MB JSON remains an uncommitted development artifact. The generated GLB
is the compact package asset consumed by the normal shared renderer.

The generated package is disposable output. If a build leaves removed asset
files in `build/package`, delete only those stale files before reviewing it.
