# Capability Probe

A development probe for the public game APIs: lifecycle hooks, UI events,
cooperative network state, disclosure, effects, audio, and image billboards.
Use it to reproduce a small platform behavior rather than a full game loop.

This source moved from the standalone `third-game` repository into `examples`.
Its package ID remains `third-game` and its SDK is `0.3.0`.

## Build and preview

From this directory, with `tools`, `rust`, and `studio` alongside `examples`:

```sh
sh ../../tools/scripts/cubacadabra.sh build-game . --output build/package
cargo run --manifest-path ../../studio/Cargo.toml -- --path .
```

Press Play in Studio. Network probes need a reachable backend.
`src/main.luau` and `manifest.json` are checked against the documented API by
`tools/tests/test_preview_conformance.py`. The generated package includes the
billboard image and audio, with hashes verified by the same test.

Start with [Cuboom](../cuboom/README.md) for the featured game. See the
[creator contracts](https://github.com/cubacadabra/docs/tree/main/contracts)
for normative API behavior. Licensed [GPL-3.0-or-later](LICENSE).
