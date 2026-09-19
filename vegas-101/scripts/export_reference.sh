#!/bin/sh
set -eu

SCENE_PATH="${1:-/Users/aa/cubacadabra/other-examples/vegas.json}"

cargo run --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Workspace:Workspace[1]/Folder:Map[1]' \
  --scale 1 --output assets/models/vegas_map.glb \
  --collision-output /tmp/vegas-map-collision.json

cargo run --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Workspace:Workspace[1]/Folder:Games[1]/Folder:Tables[1]' \
  --scale 1 --output assets/models/vegas_tables.glb \
  --collision-output /tmp/vegas-tables-collision.json

cargo run --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Workspace:Workspace[1]/Folder:Games[1]/Folder:Slots[1]' \
  --scale 1 --output assets/models/vegas_slots.glb \
  --collision-output /tmp/vegas-slots-collision.json

jq -n \
  --slurpfile map /tmp/vegas-map-collision.json \
  --slurpfile tables /tmp/vegas-tables-collision.json \
  --slurpfile slots /tmp/vegas-slots-collision.json \
  '{formatVersion: 1, triangles: ($map[0].triangles + $tables[0].triangles + $slots[0].triangles)}' \
  > reference/vegas-collision.json

rm -f /tmp/vegas-map-collision.json /tmp/vegas-tables-collision.json /tmp/vegas-slots-collision.json
