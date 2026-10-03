# Cuboom

Cuboom is the featured Cubacadabra game and the best place to help us improve
the platform. Walk over loose letter strokes to restore a wall of pushable
cubes. Finish a layer together and another layer grows above it, up to 31
layers. Push the cubes and their restored letters follow.

This is a playable pre-launch example. We want feedback from Roblox creators
on the game, the editor, and the path from source to a portable package.

## Run it locally

Check out `rust`, `tools`, `studio`, and `examples` as sibling repositories and
install stable Rust. From their parent directory:

```sh
cargo run --manifest-path tools/Cargo.toml --bin cubacadabra -- \
  build-game examples/cuboom --output examples/cuboom/build/package
cargo run --manifest-path studio/Cargo.toml -- --path examples/cuboom
```

Press **Play** in Studio. WASD or arrows move, Space jumps, and Shift runs.
Walk over dark strokes on the ground to collect them. The game also provides
touch movement, Jump, and Run controls for Player hosts.

Studio's Play menu starts 3, 6, or 9 local preview clients. Shared state and
presence require a reachable backend; see the
[local backend setup](https://github.com/cubacadabra/backend#readme).
Local pickups and animations run without that service. The compact HUD labels
this as a local preview; synchronized progression and advancing to the next
layer need a connected session. The first row can be explored without signing in.

## Find the code

| File | Purpose |
| --- | --- |
| [scene.json](scene.json) | Stable scene nodes, pushable cubes, letter strokes, and interaction zones |
| [manifest.json](manifest.json) | Package identity, SDK version, world configuration, and effects |
| [src/main.luau](src/main.luau) | Collection, animation, layer progression, cooperative state, controls, and test-player behavior |

The authoring folder is `cuboom`; the existing package ID remains **`heavy2`**
for session and URL compatibility. Browser packages are served at
`/games/heavy2/`, and the browser launch query is `?game=heavy2`.
The game uses SDK `0.6.0` and the canonical native builder.

The `@cubacadabra/shared-state` helper coordinates cooperative clients. It
does not provide trusted game authority or durable progression. Do not use
this example's retained state as a security boundary for rewards.

## Help wanted

- Improve the first minute: make the goal and collected-stroke feedback easy
  to understand on a phone and a desktop.
- Reproduce simultaneous pickups, cube pushes, reconnects, and layer changes
  with several players. Include steps and the package revision in reports.
- Improve camera behavior, collision, readability, and performance as the
  tower grows. Keep game-specific rules here and reusable fixes in the owner
  repository.
- Help finish the Studio workflows this game exposes: scene editing,
  properties, undo, and useful multiplayer diagnostics.

[Open an examples issue](https://github.com/cubacadabra/examples/issues) or
read the [contribution guide](https://github.com/cubacadabra/docs/blob/main/CONTRIBUTING.md).
Source and project-owned artwork use [GPL-3.0-or-later](../LICENSE).
