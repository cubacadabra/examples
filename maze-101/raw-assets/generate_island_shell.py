"""Build the authored Maze 101 island shell without external dependencies.

The runtime mesh is intentionally visual-only. Maze terrain remains the
playable collision surface; this shell supplies the authored silhouette below
it and is exported as an embedded, position-only GLB for the world-mesh path.
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "models" / "island_shell.glb"
RING_COUNT = 24


def ring_points(y: float, scale: float, phase: float) -> list[tuple[float, float, float]]:
    points = []
    for index in range(RING_COUNT):
        angle = math.tau * index / RING_COUNT
        irregular = 1.0 + 0.07 * math.sin(index * 2.3 + phase) + 0.035 * math.cos(index * 5.1)
        points.append(
            (
                math.cos(angle) * 46.0 * scale * irregular,
                y,
                math.sin(angle) * 44.0 * scale * (1.0 + 0.04 * math.sin(index * 3.7)),
            )
        )
    return points


def make_mesh() -> tuple[list[tuple[float, float, float]], list[int]]:
    vertices: list[tuple[float, float, float]] = [(0.0, -0.49, 0.0)]
    rings = [
        ring_points(-0.49, 1.0, 0.2),
        ring_points(-1.5, 1.02, 1.1),
        ring_points(-7.0, 0.77, 2.3),
        ring_points(-13.4, 0.49, 3.6),
    ]
    ring_indices: list[list[int]] = []
    for ring in rings:
        ring_indices.append(list(range(len(vertices), len(vertices) + RING_COUNT)))
        vertices.extend(ring)

    bottom_center = len(vertices)
    vertices.append((1.8, -15.2, -2.2))
    indices: list[int] = []

    # The top is hidden under the generated sand floor, but closes the mesh so
    # the shell still reads correctly when viewed from a low review angle.
    top = ring_indices[0]
    for index in range(RING_COUNT):
        next_index = (index + 1) % RING_COUNT
        indices.extend((0, top[next_index], top[index]))

    for upper, lower in zip(ring_indices, ring_indices[1:]):
        for index in range(RING_COUNT):
            next_index = (index + 1) % RING_COUNT
            indices.extend((upper[index], lower[next_index], lower[index]))
            indices.extend((upper[index], upper[next_index], lower[next_index]))

    bottom = ring_indices[-1]
    for index in range(RING_COUNT):
        next_index = (index + 1) % RING_COUNT
        indices.extend((bottom[index], bottom[next_index], bottom_center))

    return vertices, indices


def aligned_json(value: object) -> bytes:
    encoded = json.dumps(value, separators=(",", ":")).encode("utf-8")
    return encoded + b" " * ((4 - len(encoded) % 4) % 4)


def write_glb(vertices: list[tuple[float, float, float]], indices: list[int]) -> None:
    position_bytes = b"".join(struct.pack("<3f", *vertex) for vertex in vertices)
    index_offset = len(position_bytes)
    index_bytes = b"".join(struct.pack("<I", index) for index in indices)
    binary = position_bytes + index_bytes
    binary += b"\0" * ((4 - len(binary) % 4) % 4)

    minimum = [min(vertex[axis] for vertex in vertices) for axis in range(3)]
    maximum = [max(vertex[axis] for vertex in vertices) for axis in range(3)]
    document = {
        "asset": {"version": "2.0", "generator": "maze-101 island shell generator"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "Maze 101 authored island shell"}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1, "mode": 4}]}],
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(position_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": index_offset, "byteLength": len(index_bytes), "target": 34963},
        ],
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": len(vertices),
                "type": "VEC3",
                "min": minimum,
                "max": maximum,
            },
            {"bufferView": 1, "componentType": 5125, "count": len(indices), "type": "SCALAR"},
        ],
    }
    json_bytes = aligned_json(document)
    header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(json_bytes) + 8 + len(binary))
    glb = header + struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes
    glb += struct.pack("<I4s", len(binary), b"BIN\0") + binary
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(glb)


if __name__ == "__main__":
    write_glb(*make_mesh())
