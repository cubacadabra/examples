# Signal Run

A cooperative relay example. Capture signal nodes around the yard, then
activate the uplink together. Luau owns round-scoped actions and state;
the shared engine supplies interactions, effects, audio, and network APIs.

This source moved from the standalone `second-game` repository into `examples`.
Its package ID remains `second-game` and its SDK is `0.3.0`.

## Build and preview

From this directory, with `tools`, `rust`, and `studio` alongside `examples`:

```sh
sh ../../tools/scripts/cubacadabra.sh build-game . --output build/package
cargo run --manifest-path ../../studio/Cargo.toml -- --path .
```

Press Play in Studio. Shared state needs a reachable backend.
`src/relay.luau` contains the game rules; `src/main.luau` binds lifecycle hooks.
The shared-state helper provides cooperative coordination, not trusted game
validation or durable progression.

Start with [Cuboom](../cuboom/README.md) for the featured game. See the
[creator contracts](https://github.com/cubacadabra/docs/tree/main/contracts)
for API behavior. Licensed [GPL-3.0-or-later](LICENSE).
