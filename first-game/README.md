# Spellbound Schoolyard

A cooperative charm-discovery example. Find Spark, Splash, and Sprout, then
cast them in the Wand Circle for a shared celebration. A solo player can
finish the round; several players can split up and celebrate together.

This source moved from the standalone `first-game` repository into `examples`.
Its package ID remains `first-game`. It uses SDK `0.3.0` and the same native
builder as Cuboom.

## Build and preview

From this directory, with `tools`, `rust`, and `studio` alongside `examples`:

```sh
sh ../../tools/scripts/cubacadabra.sh build-game . --output build/package
cargo run --manifest-path ../../studio/Cargo.toml -- --path .
```

Press Play in Studio. Shared state needs a reachable backend.
`src/main.luau` owns lifecycle hooks, `src/round.luau` owns round rules, and
`src/ui/` owns the HUD. `manifest.json` describes the world; `effects.json`
defines visuals. Rust knows about generic interactions, not spells.

The shared-state helper coordinates cooperative clients. It does not enforce
trusted game rules or persist rewards. Use [Cuboom](../cuboom/README.md) for
the featured game and the [creator contracts](https://github.com/cubacadabra/docs/tree/main/contracts)
for API behavior.

Licensed [GPL-3.0-or-later](LICENSE); preserve the copyright notice.
