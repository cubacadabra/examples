# Maze 101 visual milestone

This example is currently a single visual-regression target: the daytime
interior maze frame from [MayGo/maze-world](https://github.com/MayGo/maze-world).
The scene is intentionally limited to one generated `easy-room`; do not add a
hub, named islands, bridges, or decorative scenery until the maze frame itself
converges.

The fixed review subject is the `easy-room` presentation bound
`[-36, -1, -36]` to `[36, 22, 36]`. Keep the comparison focused on camera/FOV,
player-to-wall scale, grass wall and sand floor response, daylight, sky, and
shadow shape. Capture the same Studio review camera after substantial visual
changes and compare it side by side with the reference before iterating on
content.

Build the package with:

```sh
cargo run --release --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  build-game --source . --output build/package
```

The generated package is disposable output. If a build leaves removed asset
files in `build/package`, delete only those stale files before reviewing it.
