# Lemonade 101

Lemonade 101 is the first behavior-first Cubacadabra example. It is a tiny
native park with ingredient stations, four customer interaction zones, a
three-minute shift, and a Luau-owned recipe loop.

This first slice deliberately has no imported content and no walking NPCs.
The native scene is authored in `scene.json`, so the stand, stations,
customers, and their hierarchy are visible to Studio instead of being
duplicated only in manifest arrays. Maya, Jun, Priya, and Theo are now
stationary authored actors rendered through the shared character renderer.
They have identity and appearance but no AI or movement. The next Studio gate
is tracked in the canonical
[Lemonade 101 plan](../../docs/reference/lemonade-101.md).

## Build

From the `tools` repository:

```sh
cargo run --release --manifest-path ../tools/Cargo.toml --bin cubacadabra -- \
  build-game --source . --output build/package --zip build/lemonade-101.zip
```

The package remains intentionally asset-free. `scene.json` owns the authored
park hierarchy and visual/interactable objects; `src/main.luau` owns the shift,
orders, ingredients, cash, feedback, and results.
