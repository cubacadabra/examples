# Maze 101 visual milestone

The current visual-regression target is the daytime interior maze frame from
[MayGo/maze-world](https://github.com/MayGo/maze-world). The launch target stays
on the generated `easy-room` while the restored `archipelago` hub and historical
`island-1`, `island-2`, and `island-3` worlds remain available for later work.

The fixed review subject is the `easy-room` presentation bound
`[-36, -1, -36]` to `[36, 9, 36]`. Keep the comparison focused on camera/FOV,
player-to-wall scale, grass wall and sand floor response, daylight, sky, and
shadow shape. Capture the same Studio review camera after substantial visual
changes and compare it side by side with the reference before iterating on
content. The hub and island environments are preserved, but are not part of
this visual-regression pass.

Build the package with:

```sh
cargo run --release --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  build-game --source . --output build/package
```

The generated package is disposable output. If a build leaves removed asset
files in `build/package`, delete only those stale files before reviewing it.
