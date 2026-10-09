#!/usr/bin/env python3
"""Generate a blocky, Roblox-style pig as OBJ + MTL.

Original design (not based on any existing character).
Units are Roblox studs (1 stud ~= 0.28 m). Y is up, origin at the centre
of the feet, pig faces +Z.

Usage:
    python3 tools/make_pig.py [output_dir]

Writes <output_dir>/pig.obj and <output_dir>/pig.mtl
(default output_dir: models/).
"""

import os
import sys

# Each part: name, material, centre (x, y, z), size (sx, sy, sz)
PARTS = [
    # Body
    ("Body",        "PigGreen",   (0.0, 2.2, 0.0),   (3.0, 2.2, 3.6)),
    # Head (overlaps the front of the body)
    ("Head",        "PigGreen",   (0.0, 3.1, 2.3),   (2.6, 2.4, 2.2)),
    # Snout and nostrils
    ("Snout",       "PigSnout",   (0.0, 2.9, 3.55),  (1.3, 1.0, 0.5)),
    ("NostrilL",    "PigDark",    (-0.3, 2.9, 3.83), (0.25, 0.3, 0.1)),
    ("NostrilR",    "PigDark",    (0.3, 2.9, 3.83),  (0.25, 0.3, 0.1)),
    # Eyes: white sclera + black pupil
    ("EyeWhiteL",   "PigWhite",   (-0.65, 3.8, 3.4), (0.6, 0.6, 0.1)),
    ("EyeWhiteR",   "PigWhite",   (0.65, 3.8, 3.4),  (0.6, 0.6, 0.1)),
    ("PupilL",      "PigDark",    (-0.65, 3.8, 3.47), (0.3, 0.3, 0.05)),
    ("PupilR",      "PigDark",    (0.65, 3.8, 3.47),  (0.3, 0.3, 0.05)),
    # Ears
    ("EarL",        "PigGreen",   (-1.1, 4.5, 2.1),  (0.8, 0.8, 0.3)),
    ("EarR",        "PigGreen",   (1.1, 4.5, 2.1),   (0.8, 0.8, 0.3)),
    # Legs with small dark hooves
    ("LegFL",       "PigGreen",   (-0.85, 0.55, 1.2),  (0.8, 1.1, 0.8)),
    ("LegFR",       "PigGreen",   (0.85, 0.55, 1.2),   (0.8, 1.1, 0.8)),
    ("LegBL",       "PigGreen",   (-0.85, 0.55, -1.2), (0.8, 1.1, 0.8)),
    ("LegBR",       "PigGreen",   (0.85, 0.55, -1.2),  (0.8, 1.1, 0.8)),
    ("HoofFL",      "PigDark",    (-0.85, 0.08, 1.2),  (0.84, 0.16, 0.84)),
    ("HoofFR",      "PigDark",    (0.85, 0.08, 1.2),   (0.84, 0.16, 0.84)),
    ("HoofBL",      "PigDark",    (-0.85, 0.08, -1.2), (0.84, 0.16, 0.84)),
    ("HoofBR",      "PigDark",    (0.85, 0.08, -1.2),  (0.84, 0.16, 0.84)),
    # Tail
    ("Tail",        "PigGreen",   (0.0, 2.5, -2.0),  (0.35, 0.35, 0.35)),
]

MATERIALS = {
    "PigGreen": (0.42, 0.78, 0.22),
    "PigSnout": (0.60, 0.88, 0.40),
    "PigWhite": (0.96, 0.96, 0.96),
    "PigDark":  (0.08, 0.08, 0.08),
}

# Box faces as quads of vertex indices (0..7), wound counter-clockwise
# when viewed from outside. Vertex index bits: x=bit0, y=bit1, z=bit2
# (0 = minimum, 1 = maximum on that axis).
FACES = [
    (0, 2, 3, 1),  # -Z
    (4, 5, 7, 6),  # +Z
    (0, 1, 5, 4),  # -Y
    (2, 6, 7, 3),  # +Y
    (0, 4, 6, 2),  # -X
    (1, 3, 7, 5),  # +X
]


def box_vertices(c, s):
    cx, cy, cz = c
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    verts = []
    for i in range(8):
        x = cx + (hx if i & 1 else -hx)
        y = cy + (hy if i & 2 else -hy)
        z = cz + (hz if i & 4 else -hz)
        verts.append((x, y, z))
    return verts


def write_mtl(path):
    with open(path, "w", encoding="utf-8") as f:
        f.write("# Materials for pig.obj\n")
        for name, (r, g, b) in MATERIALS.items():
            f.write(f"newmtl {name}\n")
            f.write(f"Kd {r:.4f} {g:.4f} {b:.4f}\n")
            f.write("Ka 0.0 0.0 0.0\n")
            f.write("Ks 0.0 0.0 0.0\n")
            f.write("d 1.0\n\n")


def write_obj(path, mtl_name):
    lines = [
        "# Blocky Roblox-style pig (original design)",
        "# Units: studs, Y up, feet at origin",
        f"mtllib {mtl_name}",
    ]
    v_offset = 0
    tri_count = 0
    for name, mat, centre, size in PARTS:
        lines.append(f"o {name}")
        lines.append(f"usemtl {mat}")
        for x, y, z in box_vertices(centre, size):
            lines.append(f"v {x:.4f} {y:.4f} {z:.4f}")
        for a, b, c, d in FACES:
            lines.append(f"f {a + 1 + v_offset} {b + 1 + v_offset} "
                         f"{c + 1 + v_offset} {d + 1 + v_offset}")
            tri_count += 2
        v_offset += 8
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return tri_count


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "models"
    os.makedirs(out_dir, exist_ok=True)
    obj_path = os.path.join(out_dir, "pig.obj")
    mtl_path = os.path.join(out_dir, "pig.mtl")
    write_mtl(mtl_path)
    tris = write_obj(obj_path, os.path.basename(mtl_path))
    print(f"Wrote {obj_path} and {mtl_path}")
    print(f"Parts: {len(PARTS)}, triangles: {tris}")


if __name__ == "__main__":
    main()
