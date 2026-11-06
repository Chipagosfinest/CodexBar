#!/usr/bin/env python3
"""Read original native fixture pixels; do not transform or rewrite images."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("images", type=Path)
parser.add_argument("--reference", type=Path)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
observations = []
zero_comparisons = []
hashes = {}
accepted = True
for theme in ["light", "dark"]:
    path = args.images / ("vertical-adjustment-" + theme + ".png")
    hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    image = Image.open(path).convert("RGB")
    scale = image.width / 700
    assert image.height == 290 * scale
    background = image.getpixel((image.width - 1, image.height - 1))
    reference = None
    if args.reference:
        reference = Image.open(args.reference / path.name).convert("RGB")
        assert reference.size == image.size
    for row, name in enumerate(["normal calm", "normal warning", "HC calm", "HC warning"]):
        centers = []
        capsules = []
        masses = []
        for column in range(3):
            points = []
            red = []
            for y in range(int((98 + 42 * row) * scale), int((120 + 42 * row) * scale)):
                for x in range(int((190 + 160 * column) * scale), int((335 + 160 * column) * scale)):
                    color = image.getpixel((x, y))
                    if max(abs(color[channel] - background[channel]) for channel in range(3)) > 30:
                        points.append((y + 0.5) / scale)
                    if color[0] > 150 and color[1] < 80 and color[2] < 80:
                        red.append((y + 0.5) / scale)
            assert points
            centers.append(sum(points) / len(points))
            capsules.append(sum(red) / len(red) if red else None)
            masses.append(len(red))
        delta = [value - centers[0] for value in centers]
        red_delta = [value - capsules[0] if value is not None else None for value in capsules]
        row_passed = all(abs(actual - expected) < 0.25 for actual, expected in zip(delta, [0, 3, -3]))
        if row in [1, 3]:
            row_passed = row_passed and all(value is not None and abs(value - expected) < 0.25
                                           for value, expected in zip(red_delta, [0, 3, -3]))
        accepted = accepted and row_passed
        observations.append({"theme": theme, "row": name, "foreground_delta_points": delta,
                             "capsule_delta_points": red_delta, "capsule_mask_pixels": masses,
                             "physical_motion_passed": row_passed})
        if reference:
            box = tuple(int(value * scale) for value in (190, 98 + row * 42, 335, 120 + row * 42))
            old_pixels = list(reference.crop(box).getdata())
            new_pixels = list(image.crop(box).getdata())
            changed = sum(before != after for before, after in zip(old_pixels, new_pixels))
            zero_comparisons.append({"theme": theme, "row": name, "changed_rgb_pixels": changed,
                                     "zero_offset_pixel_identical": changed == 0})
result = {"physical_motion_accepted": accepted, "image_sha256": hashes,
          "boundary": "Read-only analysis of native component images; not installed-app proof",
          "canvas_points": [700, 290], "button_frame_height_points": 22,
          "foreground_mask": "max RGB distance from background >30", "capsule_mask": "R>150 G<80 B<80",
          "expected_delta_for_offsets_0_minus3_plus3": [0, 3, -3], "observations": observations,
          "zero_offset_reference_comparisons": zero_comparisons}
args.output.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
