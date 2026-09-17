# Source artwork

Files under `raw-assets/` are editable/source artwork for this example. They are
not game-package assets and are not copied into the built game. Runtime-ready
files belong under `assets/` and must use a format supported by the game
package and engine.

## Rocks

`blender/rocks.blend` is the upstream Blender source for three rock models in
the Maze World repository. `assets/models/rock_01.glb` is the first runtime
export, produced from the upstream `rock_01.fbx` with Blender. The package
builder validates and ships this GLB; the general world-mesh renderer is still
being wired into the runtime, so the current visual dressing uses the engine's
procedural rock prefab until that registration path is complete.

Source: [MayGo/maze-world, `raw-assets/blender/rocks.blend`](https://github.com/MayGo/maze-world/blob/2dba386/raw-assets/blender/rocks.blend)

The source repository is licensed under MIT; its license notice is included in
this directory. See [LICENSE](LICENSE).
