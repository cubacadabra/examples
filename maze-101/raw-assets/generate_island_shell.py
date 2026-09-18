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
SHELL_OUTPUT = ROOT / "assets" / "models" / "island_shell.glb"
OPEN_SHELL_OUTPUT = ROOT / "assets" / "models" / "island_shell_open.glb"
CAP_OUTPUT = ROOT / "assets" / "models" / "island_cap.glb"
BRIDGE_OUTPUT = ROOT / "assets" / "models" / "rope_bridge.glb"
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


def make_shell(close_top: bool = True) -> tuple[list[tuple[float, float, float]], list[int]]:
    vertices: list[tuple[float, float, float]] = [(0.0, -0.49, 0.0)] if close_top else []
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
    if close_top:
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


def make_cap() -> tuple[list[tuple[float, float, float]], list[int]]:
    vertices = [(0.0, -0.43, 0.0), *ring_points(-0.43, 1.0, 0.2)]
    indices: list[int] = []
    for index in range(RING_COUNT):
        current = index + 1
        next_index = (index + 1) % RING_COUNT + 1
        indices.extend((0, next_index, current))
    return vertices, indices


def append_box(
    vertices: list[tuple[float, float, float]],
    indices: list[int],
    center: tuple[float, float, float],
    size: tuple[float, float, float],
) -> None:
    cx, cy, cz = center
    hx, hy, hz = (axis * 0.5 for axis in size)
    corners = [
        (cx - hx, cy - hy, cz - hz),
        (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz),
        (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz),
        (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz),
        (cx - hx, cy + hy, cz + hz),
    ]
    offset = len(vertices)
    vertices.extend(corners)
    for triangle in (
        (0, 2, 1), (0, 3, 2),
        (4, 5, 6), (4, 6, 7),
        (0, 1, 5), (0, 5, 4),
        (3, 7, 6), (3, 6, 2),
        (0, 4, 7), (0, 7, 3),
        (1, 2, 6), (1, 6, 5),
    ):
        indices.extend(offset + value for value in triangle)


def append_beam(
    vertices: list[tuple[float, float, float]],
    indices: list[int],
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    thickness: float,
) -> None:
    direction = tuple(end[axis] - start[axis] for axis in range(3))
    length = math.sqrt(sum(value * value for value in direction))
    z_axis = tuple(value / length for value in direction)
    x_axis = (1.0, 0.0, 0.0)
    y_axis = (0.0, z_axis[2], -z_axis[1])
    center = tuple((start[axis] + end[axis]) * 0.5 for axis in range(3))
    hx = thickness * 0.5
    hy = thickness * 0.5
    hz = length * 0.5
    corners: list[tuple[float, float, float]] = []
    for local_x, local_y, local_z in (
        (-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
        (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz),
    ):
        corners.append(tuple(
            center[axis]
            + x_axis[axis] * local_x
            + y_axis[axis] * local_y
            + z_axis[axis] * local_z
            for axis in range(3)
        ))
    offset = len(vertices)
    vertices.extend(corners)
    for triangle in (
        (0, 2, 1), (0, 3, 2),
        (4, 5, 6), (4, 6, 7),
        (0, 1, 5), (0, 5, 4),
        (3, 7, 6), (3, 6, 2),
        (0, 4, 7), (0, 7, 3),
        (1, 2, 6), (1, 6, 5),
    ):
        indices.extend(offset + value for value in triangle)


def bridge_height(z: float) -> float:
    normalized = min(1.0, abs(z) / 16.0)
    return -1.15 * (1.0 - normalized * normalized)


def make_bridge() -> tuple[list[tuple[float, float, float]], list[int]]:
    vertices: list[tuple[float, float, float]] = []
    indices: list[int] = []
    for index in range(17):
        z = -16.0 + index * 2.0
        deck_y = bridge_height(z) * 0.55
        append_box(vertices, indices, (0.0, deck_y, z), (5.7, 0.34, 1.62))

    post_zs = (-16.0, -8.0, 0.0, 8.0, 16.0)
    for side in (-1.0, 1.0):
        rope_points: list[tuple[float, float, float]] = []
        for z in post_zs:
            deck_y = bridge_height(z) * 0.55
            append_box(vertices, indices, (side * 3.0, deck_y + 1.55, z), (0.28, 3.1, 0.28))
            rope_points.append((side * 3.0, deck_y + 2.75, z))
        for start, end in zip(rope_points, rope_points[1:]):
            append_beam(vertices, indices, start, end, 0.16)
            lower_start = (start[0], start[1] - 1.0, start[2])
            lower_end = (end[0], end[1] - 1.0, end[2])
            append_beam(vertices, indices, lower_start, lower_end, 0.12)
    return vertices, indices


def aligned_json(value: object) -> bytes:
    encoded = json.dumps(value, separators=(",", ":")).encode("utf-8")
    return encoded + b" " * ((4 - len(encoded) % 4) % 4)


def write_glb(
    output: Path,
    name: str,
    vertices: list[tuple[float, float, float]],
    indices: list[int],
) -> None:
    position_bytes = b"".join(struct.pack("<3f", *vertex) for vertex in vertices)
    index_offset = len(position_bytes)
    index_bytes = b"".join(struct.pack("<I", index) for index in indices)
    binary = position_bytes + index_bytes
    binary += b"\0" * ((4 - len(binary) % 4) % 4)

    minimum = [min(vertex[axis] for vertex in vertices) for axis in range(3)]
    maximum = [max(vertex[axis] for vertex in vertices) for axis in range(3)]
    document = {
        "asset": {"version": "2.0", "generator": "maze-101 archipelago generator"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
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
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(glb)


if __name__ == "__main__":
    write_glb(SHELL_OUTPUT, "Maze 101 island shell", *make_shell())
    write_glb(OPEN_SHELL_OUTPUT, "Maze 101 open island cliff shell", *make_shell(False))
    write_glb(CAP_OUTPUT, "Maze 101 island grass cap", *make_cap())
    write_glb(BRIDGE_OUTPUT, "Maze 101 rope bridge", *make_bridge())
