# Source artwork

Files under `raw-assets/` are editable/source artwork for this example. They are
not game-package assets and are not copied into the built game. Runtime-ready
files belong under `assets/` and must use a format supported by the game
package and engine.

## Rocks

`blender/rocks.blend` is the upstream Blender source for three rock models in
the Maze World repository. `assets/models/rock_01.glb` is the first runtime
export, produced from the upstream `rock_01.fbx` with Blender. The package
builder validates and ships this GLB. Maze 101's generated world now references
it as an instanced mesh decoration; the runtime uploads the indexed geometry
once and draws the generated placements from that shared asset. The first
runtime slice is intentionally flat-shaded: GLB textures, mesh collision, and
prefab behavior are separate follow-ups.

Source: [MayGo/maze-world, `raw-assets/blender/rocks.blend`](https://github.com/MayGo/maze-world/blob/2dba386/raw-assets/blender/rocks.blend)

The source repository is licensed under MIT; its license notice is included in
this directory. See [LICENSE](LICENSE).
