#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(CDPATH= cd -- "$PROJECT_ROOT/../.." && pwd)
SCENE_PATH="${1:-$REPO_ROOT/other-examples/vegas.json}"
TOOLS_MANIFEST="$REPO_ROOT/tools/Cargo.toml"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vegas-reference.XXXXXX")
CHAIR_PREFIX='Workspace:Workspace[1]/Folder:Games[1]/Folder:Tables[1]/Folder:Roulette[1]/Model:Roulette[1]/Folder:Functional[1]/Folder:Stools[1]/Model:Player3[1]/Model:SofaChair[1]'
CHAIR_ORIGIN='-78.13532,4.1533,-19.07567'

cleanup() {
  rm -f "$TEMP_DIR/map.json" "$TEMP_DIR/tables.json" "$TEMP_DIR/slots.json"
  rmdir "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

cargo run --manifest-path "$TOOLS_MANIFEST" --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Workspace:Workspace[1]/Folder:Map[1]' \
  --scale 1 --output "$PROJECT_ROOT/assets/models/vegas_map.glb" \
  --bounds-output "$PROJECT_ROOT/assets/models/vegas_map.bounds.json" \
  --collision-output "$TEMP_DIR/map.json"

cargo run --manifest-path "$TOOLS_MANIFEST" --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Workspace:Workspace[1]/Folder:Games[1]/Folder:Tables[1]' \
  --exclude-path "$CHAIR_PREFIX" \
  --scale 1 --output "$PROJECT_ROOT/assets/models/vegas_tables.glb" \
  --bounds-output "$PROJECT_ROOT/assets/models/vegas_tables.bounds.json" \
  --collision-output "$TEMP_DIR/tables.json"

cargo run --manifest-path "$TOOLS_MANIFEST" --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Workspace:Workspace[1]/Folder:Games[1]/Folder:Slots[1]' \
  --scale 1 --output "$PROJECT_ROOT/assets/models/vegas_slots.glb" \
  --bounds-output "$PROJECT_ROOT/assets/models/vegas_slots.bounds.json" \
  --collision-output "$TEMP_DIR/slots.json"

cargo run --manifest-path "$TOOLS_MANIFEST" --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix "$CHAIR_PREFIX" --origin "$CHAIR_ORIGIN" \
  --scale 1 --output "$PROJECT_ROOT/assets/models/vegas_chair.glb" \
  --bounds-output "$PROJECT_ROOT/assets/models/vegas_chair.bounds.json"

jq -c -n \
  --slurpfile map "$TEMP_DIR/map.json" \
  --slurpfile tables "$TEMP_DIR/tables.json" \
  --slurpfile slots "$TEMP_DIR/slots.json" \
  '{formatVersion: 1, triangles: ($map[0].triangles + $tables[0].triangles + $slots[0].triangles)}' \
  > "$PROJECT_ROOT/reference/vegas-collision.json"
