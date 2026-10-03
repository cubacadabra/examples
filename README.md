# Cubacadabra examples

Start with **[Cuboom](cuboom/README.md)**, our featured game. Restore loose
letter strokes to pushable cubes and build a tower together. We want help from
game developers with its playability, multiplayer behavior, and the Studio
workflows used to build it.

Cubacadabra is pre-launch. These are editable game sources, not promises of a
stable platform. Games own their rules in Luau and native scene data; the
shared runtime and hosts stay game-independent.

## Build and preview Cuboom

Keep `rust`, `tools`, `studio`, and `examples` as siblings and install stable
Rust. From this repository:

```sh
sh ../tools/scripts/cubacadabra.sh build-game cuboom --output cuboom/build/package
cargo run --manifest-path ../studio/Cargo.toml -- --path cuboom
```

Studio opens the project stopped; press **Play**. Local multiplayer presence
and shared state need the [backend](https://github.com/cubacadabra/backend#readme).
The [contribution guide](https://github.com/cubacadabra/docs/blob/main/CONTRIBUTING.md)
explains setup and ownership. Cuboom's existing package ID is `heavy2`; source
folder names and package identities need not match.

## Other examples

| Source | What to study |
| --- | --- |
| [Spellbound Schoolyard](first-game/README.md) | Cooperative charm discovery, rounds, effects, audio, and HUD |
| [Signal Run](second-game/README.md) | Cooperative relay capture and round-scoped state |
| [Capability Probe](third-game/README.md) | Small reproducible probes for UI, network, audio, images, and SDK helpers |
| [Maze 101](maze-101/README.md) | Deterministic procedural rooms, imported static geometry, collision, and progression; partial port |
| [Lemonade 101](lemonade-101/README.md) | Experimental native actors and a recipe/service loop |
| [Vegas 101](vegas-101/README.md) | Experimental imported scene and physics interactions |
| `adventure-101` | Exploration, discovery trail, and landmarks |
| `survival-101` | Cooperative resource gathering, day/night, rescue, and hazards |
| `the-wild-west` | Platforming, checkpoints, falls, and completion |
| `scratch` | Minimal source project |

The former `first-game`, `second-game`, and `third-game` repositories are now
directories here. Their package IDs and hosted `/games/<id>/` URLs are
unchanged. All examples use the same native builder. Never edit built
packages in place; change source, build, and verify the resulting artifact.

## Verify

From the sibling checkout root:

```sh
python3 -m unittest discover -s tools/tests -p test_preview_conformance.py
python3 tools/scripts/check_workspace_compatibility.py
```

The first command builds every example and checks package identity, assets,
and hashes. The full compatibility check also loads them through native Rust,
built browser WASM, and Studio, then compares a scripted behavior trace. Build
the browser renderer first as described in the tools README. Device behavior
still requires actual iOS and Android verification.

### Licensing

Copyright (C) 2026 Andrew Arrow

Licensed under the GNU General Public License v3.0 or later.
See [LICENSE](LICENSE).

Keep third-party asset notices, including the MIT-licensed Maze reference
artwork, with their source files.
