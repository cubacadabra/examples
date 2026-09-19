# Vegas 101

Vegas 101 is a playable Cubacadabra port built from the imported Roblox
reference scene at `../../other-examples/vegas.json`. The source map, table bank,
and slot bank are exported as ordinary package meshes; the authored Luau layer
adds a compact credits/tickets HUD and deterministic local rounds for the
source table locations.

The imported spawn is preserved. Walk with WASD/arrows, run with Shift, jump
with Space, and orbit/zoom with drag and wheel. Walk into a marked table zone to
play Texas Hold'em, blackjack, baccarat, roulette, slots, Plinko, or Cash Wheel.
The build starts with 46,248 credits and 3,504 tickets to match the supplied
reference screenshot. Bets and wins last for the current session.

## Build

```sh
cargo run --manifest-path ../../tools/Cargo.toml --bin cubacadabra -- \
  build-game --source . --output build/package
```

The checked-in meshes and collision file were generated from the reference
scene with `scripts/export_reference.sh`. The original Roblox XML is not
required to build or run this package.

## Source fidelity

`vegas_map.glb` contains the imported `Workspace/Map` hierarchy,
`vegas_tables.glb` contains the imported table games, and `vegas_slots.glb`
contains the imported slot bank. Textures referenced by the source export were
not available in the local reference JSON, so unknown mesh assets use the
importer's primitive approximation while all source transforms, colors,
materials, collision flags, and visible geometry are retained.
