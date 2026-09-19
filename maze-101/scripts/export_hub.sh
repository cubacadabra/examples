#!/bin/sh
set -eu
# Run from maze-101. The visual hub is split along the source hierarchy so no
# package asset approaches the runtime's 16 MiB per-asset ceiling. Collision
# remains one joined source export because the character can traverse between
# those hierarchies in the same world.
SCENE_PATH="${1:-/Users/aa/Downloads/reference-scene.json}"

export_mesh() {
  cargo run --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
    export-reference-mesh --scene "$SCENE_PATH" \
    --path-prefix "$1" \
    --exclude-path '/Model:LockPlaceholder[1]' \
    --scale 0.6 \
    --mesh-overrides reference/mesh-overrides.json \
    --output "$2"
}

export_mesh 'Folder:Place[1]/Folder:Main[1]' assets/models/maze_world_main.glb
export_mesh 'Folder:Place[1]/Folder:Rooms[1]' assets/models/maze_world_rooms.glb
export_mesh 'Folder:Place[1]/Folder:Leaderboards[1]' assets/models/maze_world_leaderboards.glb

collision_dir=$(mktemp -d "${TMPDIR:-/tmp}/maze-101-collision.XXXXXX")
trap 'rm -f "$collision_dir/hub.glb"; rmdir "$collision_dir"' EXIT
cargo run --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Folder:Place[1]/Folder:Main[1]' \
  --path-prefix 'Folder:Place[1]/Folder:Rooms[1]' \
  --path-prefix 'Folder:Place[1]/Folder:Leaderboards[1]' \
  --exclude-path '/Model:LockPlaceholder[1]' \
  --scale 0.6 \
  --mesh-overrides reference/mesh-overrides.json \
  --output "$collision_dir/hub.glb" \
  --collision-output reference/hub-collision.json
