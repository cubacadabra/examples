#!/bin/sh
set -eu
# Run from maze-101. Geometry and collision are regenerated together.
SCENE_PATH="${1:-/Users/aa/Downloads/reference-scene.json}"
cargo run --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Folder:Place[1]/Folder:Main[1]' \
  --path-prefix 'Folder:Place[1]/Folder:Rooms[1]' \
  --path-prefix 'Folder:Place[1]/Folder:Leaderboards[1]' \
  --exclude-path '/Model:LockPlaceholder[1]' \
  --scale 0.6 \
  --mesh-overrides reference/mesh-overrides.json \
  --output assets/models/maze_world_hub.glb \
  --collision-output reference/hub-collision.json
