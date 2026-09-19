#!/usr/bin/env python3
"""Generate Maze 101's source hub and bounded maze-world manifest data.

The room markers are read from the exported Roblox reference scene so the
authoring contract cannot drift from the source hub mesh.  Run from this
example directory after refreshing the reference export.
"""

from __future__ import annotations

import json
import argparse
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCENE = Path("/Users/aa/Downloads/reference-scene.json")
SCALE = 0.6

ROOM_TIERS = {
    "VeryEasyRoom": {
        "label": "VERY EASY",
        "difficulty": "very-easy",
        "size": (5, 5),
        "time": 60,
        "base_reward": 50,
        "solo_reward": 25,
        "cost": 0,
        "worlds": [("maze-very-easy-1", 101), ("maze-very-easy-2", 102)],
    },
    "EasyRoom": {
        "label": "EASY",
        "difficulty": "easy",
        "size": (10, 10),
        "time": 180,
        "base_reward": 250,
        "solo_reward": 125,
        "cost": 500,
        "worlds": [("easy-room", 201), ("maze-easy-2", 202)],
    },
    "NormalRoom": {
        "label": "NORMAL",
        "difficulty": "normal",
        "size": (15, 15),
        "time": 300,
        "base_reward": 2000,
        "solo_reward": 1000,
        "cost": 2000,
        "worlds": [("maze-normal-1", 301)],
    },
    "HardRoom": {
        "label": "HARD",
        "difficulty": "hard",
        "size": (20, 20),
        "time": 600,
        "base_reward": 10000,
        "solo_reward": 5000,
        "cost": 10000,
        "worlds": [("maze-hard-1", 401)],
    },
}
ADVANCED_ROOMS = ("CrazyRoom", "ExtremeRoom", "InsaneRoom", "ImpossibleRoom", "HorrorMaze")
FINISH_BY_SEED = {
    101: (2, 1),
    102: (4, 4),
    201: (8, 2),
    202: (1, 5),
    301: (13, 6),
    401: (2, 7),
}

SOURCE_WORLD_VISUAL = {
    # The source place runs a clear, saturated 06:30 morning. These are
    # portable SDK 0.5 scene controls, not copied Roblox sky assets.
    "colorCorrection": {"brightness": 0.12, "contrast": 0.20, "saturation": 0.60},
    "daylight": {
        "timeOfDay": 6.5,
        "geographicLatitude": 45,
        "brightness": 2,
        "outdoorAmbient": [0.5, 0.5, 0.5],
        "shadowSoftness": 0.5,
    },
    "sunRays": {"intensity": 0.058, "spread": 0.463},
    "fogStart": 180,
    "fogEnd": 650,
}


def source_room_positions(scene: dict[str, object]) -> dict[str, list[float]]:
    positions: dict[str, list[float]] = {}
    for geometry in scene["geometry"]:
        if geometry.get("name") != "RoomPlaceholder":
            continue
        path = geometry.get("path", "")
        room = next((name for name in (*ROOM_TIERS, *ADVANCED_ROOMS) if f"Folder:{name}[1]/" in path), None)
        if room is None:
            continue
        raw = geometry["transform"]["position"]
        positions[room] = [round(float(value) * SCALE, 4) for value in raw]
    missing = set(ROOM_TIERS) - set(positions)
    if missing:
        raise SystemExit(f"reference scene is missing RoomPlaceholder markers: {sorted(missing)}")
    return positions


def source_signs(
    positions: dict[str, list[float]], labels: dict[str, dict]
) -> list[dict[str, object]]:
    signs = []
    for room, tier in ROOM_TIERS.items():
        x, y, z = positions[room]
        signs.append({
            "text": f"{tier['label']}  {tier['size'][0]}x{tier['size'][1]}",
            "position": [x, y + 5.0, z],
            "maxWidth": 8,
            "color": "paper",
        })
        board = labels[room]
        label_x, label_y, label_z = [v * SCALE for v in board["transform"]["position"]]
        rotation = board["transform"]["rotation"]
        yaw = math.atan2(rotation[0][2], rotation[2][2])
        offset = board["size"][2] * SCALE / 2 + 0.05
        entry_cost = tier["cost"]
        entry_label = "FREE" if entry_cost == 0 else f"{entry_cost} COINS"
        # Place lettering on the two faces, not inside the imported board.
        # Keep source rotation so diagonal bridge signs remain readable.
        for side in (1, -1):
            for text, dy in ((tier["label"], 0.35), (entry_label, -0.35)):
                signs.append({
                    "text": text,
                    "position": [label_x + side * math.sin(yaw) * offset,
                                 label_y + dy, label_z + side * math.cos(yaw) * offset],
                    "yaw": yaw if side == 1 else yaw + math.pi,
                    "maxWidth": board["size"][0] * SCALE * 0.9,
                    "color": "paper",
                })
    for name in ADVANCED_ROOMS:
        x, y, z = positions[name]
        signs.append({
            "text": f"{name.replace('Room', '').upper()}  NOT PORTED",
            "position": [x, y + 5.0, z],
            "maxWidth": 9,
            "color": "hot",
        })
    return signs


def hub_world(positions: dict[str, list[float]], labels: dict[str, dict]) -> dict[str, object]:
    interactions = []
    for room, tier in ROOM_TIERS.items():
        x, y, z = positions[room]
        interactions.append({
            "id": f"room-{tier['difficulty']}",
            "kind": "zone",
            "label": f"ENTER {tier['label']}",
            "position": [x, y, z],
            "radius": 9.5,
            "color": "signal",
            "visual": "checkpoint",
        })
    for name in ADVANCED_ROOMS:
        x, y, z = positions[name]
        interactions.append({
            "id": f"room-{name[:-4].lower()}",
            "kind": "zone",
            "label": f"{name[:-4].upper()}  NOT PORTED",
            "position": [x, y, z],
            "radius": 9.5,
            "color": "hot",
            "visual": "checkpoint",
        })
    return {
        "collision": {"source": "reference/hub-collision.json"},
        "terrain": {"cellSize": 1.5, "hideDefaultGround": True, "operations": []},
        "palette": {
            "sky": "#76D6EC", "ground": "#B08A55", "groundEdge": "#365E29",
            "signal": "#F4C84A", "hot": "#E34A45", "coral": "#D77B3F",
            "butter": "#F4C84A", "periwinkle": "#7895D8", "ink": "#172A24",
            "paper": "#F4F0D8",
        },
        "world": {
            "groundSize": 1,
            "gridSize": 1,
            "gridDivisions": 1,
            "showGrid": False,
            "spawn": [13.2, 4.1, 10.8],
            "showSpawnPad": False,
            "camera": {"yaw": 0.35, "pitch": 0.48, "distance": 32},
            "presentationBounds": {"minimum": [-135, -40, -145], "maximum": [150, 30, 100]},
            "physics": {
                "groundCollision": False,
                "deathY": -70,
                "horizontalBounds": {"minimum": [-620, -180], "maximum": [330, 410]},
                "respawnDelay": 0.7,
            },
            "visual": SOURCE_WORLD_VISUAL,
        },
        "decorations": [
            {"kind": "mesh", "asset": "maze-world-main", "position": [0, 0, 0], "scale": 1, "color": "#FFFFFF"},
            {"kind": "mesh", "asset": "maze-world-rooms", "position": [0, 0, 0], "scale": 1, "color": "#FFFFFF"},
            {"kind": "mesh", "asset": "maze-world-leaderboards", "position": [0, 0, 0], "scale": 1, "color": "#FFFFFF"},
        ],
        "blocks": [],
        "signs": source_signs(positions, labels),
        "interactions": interactions,
        "hazards": [],
        "safeZones": [],
    }


def maze_cell_position(width: int, height: int, cell: tuple[int, int], offset: tuple[float, float]) -> list[float]:
    """Return a visual-only prop position tucked into a maze-cell corner."""
    return [
        (cell[0] - (width - 1) / 2) * 15 + offset[0],
        0,
        (cell[1] - (height - 1) / 2) * 15 + offset[1],
    ]


def maze_dressing(width: int, height: int, finish: tuple[int, int], seed: int) -> list[dict[str, object]]:
    """Use source-like dense, foliage-only maze dressing.

    The original generator makes per-cell decoration decisions.  These grass
    clumps intentionally remain visual-only: unlike crates, rocks, or palms,
    they do not imply a solid obstacle that the player expects to collide
    with. The generated terrain remains the single authority for route tests.
    Positions and variants depend only on baked maze metadata.
    """
    target_counts = {5: 10, 10: 25, 15: 42, 20: 62}
    target = target_counts.get(max(width, height), max(8, round(width * height * 0.16)))
    candidates = [
        (x, z)
        for z in range(height)
        for x in range(width)
        if (x, z) not in {(0, 0), finish}
    ]
    # Integer ranking avoids a runtime RNG while distributing the retained
    # cells across each baked layout rather than filling row by row.
    candidates.sort(key=lambda cell: ((cell[0] * 73 + cell[1] * 151 + seed * 37) % 997, cell))
    decorations: list[dict[str, object]] = []
    corners = [(-4.4, -4.1), (4.2, -4.0), (-4.0, 4.3), (4.1, 4.2)]
    for index, cell in enumerate(candidates[:min(target, len(candidates))]):
        decorations.append({
            "kind": "grass-clump",
            "position": maze_cell_position(width, height, cell, corners[(seed + index) % len(corners)]),
            "scale": 0.85 + ((seed + index * 7) % 5) * 0.10,
            "yaw": ((seed * 0.19 + index * 1.7) % math.tau),
            "color": "groundEdge",
            "variant": (seed + index) % 3,
        })
    return decorations


def maze_world(tier: dict[str, object], seed: int) -> dict[str, object]:
    width, height = tier["size"]
    half = max(width, height) * 15 / 2
    finish = FINISH_BY_SEED[seed]
    # Checked against each baked layout: face its open first corridor, not the
    # north boundary wall. This is authoring data, not another maze algorithm.
    entrance_yaw = -math.pi / 2 if seed in (101, 102, 201) else math.pi
    return {
        "maze": {
            "width": width,
            "height": height,
            "cellSize": 15,
            "wallHeight": 12,
            "wallThickness": 1.8,
            "seed": seed,
            "wallColor": "groundEdge",
            "finishColor": "signal",
            "terrain": {"cellSize": 1.5, "wallMaterial": "builtin:leafygrass", "floorMaterial": "builtin:sand"},
            "start": [0, 0],
            "finish": list(finish),
            "landmarks": False,
            "checkpointEvery": max(1, (width * height) // 8),
            "collectibles": {"count": min(8, width * height - 2), "color": "butter"},
        },
        "world": {
            "groundSize": 1,
            "gridSize": 1,
            "gridDivisions": max(width, height) * 2,
            "showGrid": False,
            "showSpawnPad": False,
            "camera": {"yaw": entrance_yaw, "pitch": 0.20, "distance": 12},
            "presentationBounds": {"minimum": [-half - 4, -4, -half - 4], "maximum": [half + 4, 30, half + 4]},
            "physics": {
                "groundCollision": False,
                "deathY": -70,
                "horizontalBounds": {"minimum": [-half - 4, -half - 4], "maximum": [half + 4, half + 4]},
                "respawnDelay": 0.7,
            },
            "visual": SOURCE_WORLD_VISUAL,
        },
        "palette": {
            "sky": "#76D6EC", "ground": "#B08A55", "groundEdge": "#365E29",
            "signal": "#F4C84A", "hot": "#E34A45", "butter": "#F4C84A",
            "ink": "#172A24", "paper": "#F4F0D8",
        },
        "terrain": {"cellSize": 1.5, "hideDefaultGround": True, "operations": []},
        "decorations": maze_dressing(width, height, finish, seed),
        "blocks": [], "signs": [], "interactions": [], "hazards": [], "safeZones": [],
    }


def rooms_module() -> str:
    entries = []
    for tier in ROOM_TIERS.values():
        for index, (world_id, seed) in enumerate(tier["worlds"], 1):
            finish_x, finish_z = FINISH_BY_SEED[seed]
            half_x = tier["size"][0] * 15 / 2
            half_z = tier["size"][1] * 15 / 2
            finish_position = (finish_x * 15 - half_x + 7.5, 1.5, finish_z * 15 - half_z + 7.5)
            entries.append(
                f'    ["{world_id}"] = {{ id = "{world_id}", tier = "{tier["difficulty"]}", '
                f'name = "{tier["label"]}", time_limit = {tier["time"]}, coin_count = {min(8, tier["size"][0] * tier["size"][1] - 2)}, '
                f'base_reward = {tier["base_reward"]}, solo_reward = {tier["solo_reward"]}, cost = {tier["cost"]}, seed = {seed}, variant = {index}, '
                f'finish_position = {{{finish_position[0]}, {finish_position[1]}, {finish_position[2]}}} }},'
            )
    return "return {\n" + "\n".join(entries) + "\n}\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scene", type=Path, default=SCENE)
    args = parser.parse_args()
    scene = json.loads(args.scene.read_text(encoding="utf-8"))
    positions = source_room_positions(scene)
    labels = {
        room: geometry
        for geometry in scene["geometry"]
        if geometry.get("name") == "RoomLabel"
        for room in ROOM_TIERS
        if f"Folder:{room}[1]/" in geometry.get("path", "")
    }
    if set(labels) != set(ROOM_TIERS):
        raise SystemExit(f"reference scene is missing RoomLabel markers: {sorted(set(ROOM_TIERS) - set(labels))}")
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    manifest.update({
        "version": "0.6.2",
        "sdkVersion": "0.5.0",
        "startWorld": "maze-world",
        "launch": {"destinationWorld": "maze-world", "authoritative": True},
        "scene": {
            **manifest.get("scene", {}),
            "description": "Explore the source hub, unlock baked maze variants, and find each checked exit.",
        },
        "worlds": {"maze-world": hub_world(positions, labels)},
    })
    manifest["assets"]["models"].pop("maze-world-hub", None)
    manifest["assets"]["models"].pop("maze-world-reference", None)
    manifest["assets"]["models"].update({
        "maze-world-main": {"path": "assets/models/maze_world_main.glb"},
        "maze-world-rooms": {"path": "assets/models/maze_world_rooms.glb"},
        "maze-world-leaderboards": {"path": "assets/models/maze_world_leaderboards.glb"},
    })
    for tier in ROOM_TIERS.values():
        for world_id, seed in tier["worlds"]:
            manifest["worlds"][world_id] = maze_world(tier, seed)
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (ROOT / "src/rooms.luau").write_text(rooms_module(), encoding="utf-8")
    print("generated", ", ".join(manifest["worlds"]))
    print("room positions", json.dumps(positions, sort_keys=True))


if __name__ == "__main__":
    main()
