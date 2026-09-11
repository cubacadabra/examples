# Cubacadabra examples

This repository contains example games for Cubacadabra, a user-generated gaming
platform for creators, children, and parents. Each example is a self-contained
game package that combines a `manifest.json` with Luau gameplay code and, where
needed, image assets.

The examples demonstrate different kinds of gameplay and platform features:

- **Adventure 101** (`adventure-101`) — an exploration game set in the
  Whispering Wilds. Players follow a discovery trail, find landmarks, climb a
  watchtower, and avoid wildlife.
- **Survival 101** (`survival-101`) — a cooperative survival loop set at
  Stormline Outpost. Players gather resources, manage a beacon through day and
  night, repair a rescue radio, and survive environmental hazards.
- **The Wild West** (`the-wild-west`) — a platforming course where players
  cross a canyon, use checkpoints, recover from falls, and reach the summit.

Each `manifest.json` defines the package metadata, scene, world, avatars, and
assets. The corresponding `src/main.luau` file implements the game-specific
logic, state, events, and in-game HUD.

### Licensing

Copyright (C) 2026 Andrew Arrow

Licensed under the GNU General Public License v3.0 or later.
See [LICENSE](LICENSE).
