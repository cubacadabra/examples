# Source artwork

Files under `raw-assets/` are editable/source artwork for this example. They are
not game-package assets and are not copied into the built game. Runtime-ready
files belong under `assets/` and must use a format supported by the game
package and engine.

## Rocks

`blender/rocks.blend` is the upstream Blender source for three rock models in
the Maze World repository. `assets/models/rock_01.glb` is the first runtime
export, produced from the upstream `rock_01.fbx` with Blender. The package
builder validates and ships this GLB. It remains available as the first source
rock variant for later package-owned dressing; the generic maze expansion does
not place it automatically. The runtime uploads indexed geometry once for
instanced mesh decorations. The first runtime slice is intentionally
flat-shaded: GLB textures, mesh collision, and prefab behavior are separate
follow-ups.

Source: [MayGo/maze-world, `raw-assets/blender/rocks.blend`](https://github.com/MayGo/maze-world/blob/2dba386/raw-assets/blender/rocks.blend)

The source repository is licensed under MIT; its license notice is included in
this directory. See [LICENSE](LICENSE).

## Authored island shell

`generate_island_shell.py` produces `assets/models/island_shell.glb`, a small
deterministic low-poly shell with an irregular authored outline and tapered
underside. It is visual-only; the generated maze floor remains the playable
terrain and collision surface. Regenerate it from this directory after source
changes.
