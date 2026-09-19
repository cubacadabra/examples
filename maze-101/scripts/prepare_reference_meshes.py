"""Run with Blender --background --python scripts/prepare_reference_meshes.py.

Uses the original local rock FBXs. Protected Roblox palms, grass, and ropes
are explicit procedural substitutes, NOT recovered source meshes. Overrides
are normalized; the exporter applies authored size, transform and Color3.
"""
import json
import math
from pathlib import Path
import bpy

PROJECT = Path(__file__).resolve().parents[1]
ORIGINAL = PROJECT.parents[1] / "other-examples" / "maze-world"

def mesh():
    return {"vertices": [], "triangles": []}

def triangle(out, a, b, c):
    start = len(out["vertices"])
    out["vertices"].extend([a, b, c])
    out["triangles"].append([start, start + 1, start + 2])

def quad(out, a, b, c, d):
    triangle(out, a, b, c)
    triangle(out, a, c, d)

def cylinder(bent=False):
    out = mesh()
    rings = 7 if bent else 1
    def point(ring, side):
        t = ring / rings
        angle = side * math.tau / 10
        radius = (0.34 - 0.14 * t) if bent else 0.5
        bend = 0.16 * math.sin(t * math.pi) if bent else 0
        return [bend + radius * math.cos(angle), t - 0.5, radius * math.sin(angle)]
    for ring in range(rings):
        for side in range(10):
            quad(out, point(ring, side), point(ring + 1, side),
                 point(ring + 1, side + 1), point(ring, side + 1))
    for side in range(10):
        triangle(out, [0, -0.5, 0], point(0, side), point(0, side + 1))
        triangle(out, [0, 0.5, 0], point(rings, side + 1), point(rings, side))
    return out

def palm_leaves():
    out = mesh()
    for leaf in range(9):
        angle = leaf * math.tau / 9
        lengths = [0, 0.15, 0.30, 0.43, 0.5]
        heights = [0.15, 0.30, 0.20, -0.08, -0.40]
        widths = [0.015, 0.065, 0.052, 0.03, 0]
        def point(i, side):
            r, w = lengths[i], widths[i] * side
            return [r * math.cos(angle) - w * math.sin(angle), heights[i],
                    r * math.sin(angle) + w * math.cos(angle)]
        for i in range(4):
            left, middle, right = point(i, -1), point(i, 0), point(i, 1)
            nl, nm, nr = point(i + 1, -1), point(i + 1, 0), point(i + 1, 1)
            middle[1] += 0.025
            nm[1] += 0.025
            quad(out, left, nl, nm, middle)
            quad(out, middle, nm, nr, right)
    return out

def grass():
    out = mesh()
    for i in range(11):
        angle = i * 2.39996
        radius = 0.11 + (i % 3) * 0.10
        x, z = radius * math.cos(angle), radius * math.sin(angle)
        triangle(out, [x - 0.028, -0.5, z],
                 [x + 0.07 * math.cos(angle), -0.10 + (i % 4) * 0.055,
                  z + 0.10 * math.sin(angle)], [x + 0.028, -0.5, z])
    return out

def source_rock(filename):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.fbx(filepath=str(ORIGINAL / "raw-assets/blender" / filename))
    out = mesh()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        obj.data.calc_loop_triangles()
        offset = len(out["vertices"])
        for vertex in obj.data.vertices:
            p = obj.matrix_world @ vertex.co
            out["vertices"].append([p.x, p.z, -p.y])
        out["triangles"].extend([[offset + i for i in face.vertices]
                                 for face in obj.data.loop_triangles])
    low = [min(v[i] for v in out["vertices"]) for i in range(3)]
    high = [max(v[i] for v in out["vertices"]) for i in range(3)]
    out["vertices"] = [[(v[i] - (low[i] + high[i]) / 2) / (high[i] - low[i])
                        for i in range(3)] for v in out["vertices"]]
    return out

meshes = {
    "rbxassetid://5459061824": palm_leaves(),
    "rbxassetid://5459046563": cylinder(bent=True),
    "rbxassetid://516875678": grass(),
    "rbxassetid://3573287966": cylinder(),
    "rbxassetid://3583604671": cylinder(),
}
for asset, name in [("5498135840", "rock_01.fbx"), ("5498140079", "rock_02.fbx"),
                    ("5498143396", "rock_03.fbx")]:
    meshes["rbxassetid://" + asset] = source_rock(name)
destination = PROJECT / "reference/mesh-overrides.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps({"formatVersion": 1, "meshes": meshes}, separators=(",", ":")) + "\n")
print("Wrote", destination)
