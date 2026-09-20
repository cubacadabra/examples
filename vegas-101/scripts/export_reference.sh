#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(CDPATH= cd -- "$PROJECT_ROOT/../.." && pwd)
SCENE_PATH="${1:-$REPO_ROOT/other-examples/vegas.json}"
TOOLS_MANIFEST="$REPO_ROOT/tools/Cargo.toml"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vegas-reference.XXXXXX")
TABLES_PREFIX='Workspace:Workspace[1]/Folder:Games[1]/Folder:Tables[1]'

cleanup() {
  rm -f "$TEMP_DIR/map.json" "$TEMP_DIR/tables.json" "$TEMP_DIR/slots.json" "$TEMP_DIR/chairs.json" "$TEMP_DIR/manifest.json"
  rmdir "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

cargo run --manifest-path "$TOOLS_MANIFEST" --bin cubacadabra -- \
  export-reference-instances --scene "$SCENE_PATH" \
  --path-prefix "$TABLES_PREFIX" --instance-name SofaChair \
  --asset-prefix vegas-chair --asset-directory "$PROJECT_ROOT/assets/models" \
  --asset-path-prefix assets/models --mapping-output "$TEMP_DIR/chairs.json"

cargo run --manifest-path "$TOOLS_MANIFEST" --bin cubacadabra -- \
  import-roblox-scene --reference "$SCENE_PATH" \
  --base-scene "$PROJECT_ROOT/scene.json" --output "$PROJECT_ROOT/scene.json" \
  --source-index "$PROJECT_ROOT/imports/roblox/vegas/index.json" \
  --promotion-report-output "$PROJECT_ROOT/reference/vegas-promotion-report.json" \
  --compact-output \
  --tree-depth 4 --reset-generated-source-tree \
  --editable-instance-map "$TEMP_DIR/chairs.json" \
  --editable-parent-id imported-environment \
  --editable-id-prefix vegas-chair --editable-display-prefix 'Vegas Chair'

cargo run --manifest-path "$TOOLS_MANIFEST" --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Workspace:Workspace[1]/Folder:Map[1]' \
  --exclude-authoring-scene "$PROJECT_ROOT/scene.json" \
  --scale 1 --output "$PROJECT_ROOT/assets/models/vegas_map.glb" \
  --bounds-output "$PROJECT_ROOT/assets/models/vegas_map.bounds.json" \
  --collision-output "$TEMP_DIR/map.json"

cargo run --manifest-path "$TOOLS_MANIFEST" --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix "$TABLES_PREFIX" \
  --exclude-path '/Model:SofaChair[1]' \
  --exclude-authoring-scene "$PROJECT_ROOT/scene.json" \
  --scale 1 --output "$PROJECT_ROOT/assets/models/vegas_tables.glb" \
  --bounds-output "$PROJECT_ROOT/assets/models/vegas_tables.bounds.json" \
  --collision-output "$TEMP_DIR/tables.json"

cargo run --manifest-path "$TOOLS_MANIFEST" --bin cubacadabra -- \
  export-reference-mesh --scene "$SCENE_PATH" \
  --path-prefix 'Workspace:Workspace[1]/Folder:Games[1]/Folder:Slots[1]' \
  --exclude-authoring-scene "$PROJECT_ROOT/scene.json" \
  --scale 1 --output "$PROJECT_ROOT/assets/models/vegas_slots.glb" \
  --bounds-output "$PROJECT_ROOT/assets/models/vegas_slots.bounds.json" \
  --collision-output "$TEMP_DIR/slots.json"

jq --slurpfile chairs "$TEMP_DIR/chairs.json" \
  '.assets.models = ((.assets.models // {}) + (reduce $chairs[0].assets[] as $asset ({}; .[$asset.id] = {path: $asset.path, bounds: $asset.bounds, collision: $asset.collision})))' \
  "$PROJECT_ROOT/manifest.json" > "$TEMP_DIR/manifest.json"
mv "$TEMP_DIR/manifest.json" "$PROJECT_ROOT/manifest.json"

jq -c -n \
  --slurpfile map "$TEMP_DIR/map.json" \
  --slurpfile tables "$TEMP_DIR/tables.json" \
  --slurpfile slots "$TEMP_DIR/slots.json" \
  '{formatVersion: 1, triangles: ($map[0].triangles + $tables[0].triangles + $slots[0].triangles)} | .triangles |= map(map(map((. * 1000 | round) / 1000)))' \
  > "$PROJECT_ROOT/reference/vegas-collision.json"

printf 'Vegas baked collision triangles: '
jq '.triangles | length' "$PROJECT_ROOT/reference/vegas-collision.json"
