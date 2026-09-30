from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import server


SIZE = server.CHARACTER_CANVAS_SIZE
SHEET_NAME = "motion_stickman_13.png"
CONTACT_NAME = "motion_stickman_contact.png"
GIF_NAME = "motion_stickman_13.gif"
MANIFEST_NAME = "motion_stickman_13.json"
FRAME_DIR_NAME = "motion_stickman_frames"

INK = (226, 239, 255, 255)
JOINT = (255, 201, 111, 255)

MID_X = 16
HEAD_Y = 5
NECK_Y = 9
SHOULDER_Y = 10
HIP_Y = 18
FOOT_Y = 31

# Fix, pixelpontos eltolások a különböző sétáló és mozgási fázisokhoz oldalnézetben
# [váll_bal_X, könyök_bal_X, kéz_bal_X, láb_bal_X, térd_bal_X, lábfej_bal_X, ...]
def _side_pose(kind: str, phase: int, facing: str) -> dict[str, tuple[int, int]]:
    # Alapértelmezett (idle) koordináták
    dx_arm_l, dx_hand_l = -1, -2
    dx_arm_r, dx_hand_r = 1, 2
    dx_leg_l, dx_foot_l = -1, 0
    dx_leg_r, dx_foot_r = 1, 0
    dy_knee_l, dy_knee_r = 6, 6

    if kind in {"walk", "run"}:
        if phase > 0:
            # Előre lépő fázis
            dx_arm_l, dx_hand_l = -3, -5
            dx_arm_r, dx_hand_r = 3, 5
            dx_leg_l, dx_foot_l = 2, 4
            dx_leg_r, dx_foot_r = -2, -4
            dy_knee_l, dy_knee_r = 5, 7
        else:
            # Hátraslépő fázis
            dx_arm_l, dx_hand_l = 3, 5
            dx_arm_r, dx_hand_r = -3, -5
            dx_leg_l, dx_foot_l = -2, -4
            dx_leg_r, dx_foot_r = 2, 4
            dy_knee_l, dy_knee_r = 7, 5
    elif kind == "turn":
        dx_arm_l, dx_hand_l = -2, -3
        dx_arm_r, dx_hand_r = 2, 3

    points = {
        "head": (MID_X, HEAD_Y),
        "nose": (MID_X + 2, HEAD_Y),
        "neck": (MID_X, NECK_Y),
        "shoulder": (MID_X, SHOULDER_Y),
        "hip": (MID_X, HIP_Y),
        "left_shoulder": (MID_X - 1, SHOULDER_Y),
        "right_shoulder": (MID_X + 1, SHOULDER_Y),
        "left_elbow": (MID_X - 1 + dx_arm_l, SHOULDER_Y + 4),
        "left_hand": (MID_X - 1 + dx_hand_l, SHOULDER_Y + 8),
        "right_elbow": (MID_X + 1 + dx_arm_r, SHOULDER_Y + 4),
        "right_hand": (MID_X + 1 + dx_hand_r, SHOULDER_Y + 8),
        "left_hip": (MID_X - 1, HIP_Y),
        "right_hip": (MID_X + 1, HIP_Y),
        "left_knee": (MID_X - 1 + dx_leg_l, HIP_Y + dy_knee_l),
        "left_foot": (MID_X - 1 + dx_foot_l, FOOT_Y),
        "right_knee": (MID_X + 1 + dx_leg_r, HIP_Y + dy_knee_r),
        "right_foot": (MID_X + 1 + dx_foot_r, FOOT_Y),
    }

    if facing == "left":
        points = {
            name: (SIZE - 1 - x, y) if "shoulder" not in name and "hip" not in name and "elbow" not in name and "hand" not in name and "knee" not in name and "foot" not in name
            else (SIZE - 1 - x, y) # Helyes tükrözés balra nézéshez
            for name, (x, y) in points.items()
        }
        # Bal és jobb oldali címkék felcserélése tükrözésnél
        swapped = {}
        for name, coords in points.items():
            if "left" in name:
                swapped[name.replace("left", "right")] = coords
            elif "right" in name:
                swapped[name.replace("right", "left")] = coords
            else:
                swapped[name] = coords
        points = swapped
        # Orr igazítása balra nézve
        points["nose"] = (points["head"][0] - 2, points["head"][1])

    return points


def _front_pose(kind: str, phase: int, facing: str) -> dict[str, tuple[int, int]]:
    turn_offset = -2 if facing == "front" and phase > 0 else 2
    if kind == "front":
        turn_offset = 0
    center_x = MID_X + turn_offset
    return {
        "head": (center_x, HEAD_Y),
        "nose": (center_x + (1 if turn_offset <= 0 else -1), HEAD_Y),
        "neck": (center_x, NECK_Y),
        "shoulder": (center_x, SHOULDER_Y),
        "hip": (MID_X, HIP_Y),
        "left_shoulder": (center_x - 3, SHOULDER_Y),
        "right_shoulder": (center_x + 3, SHOULDER_Y),
        "left_hip": (MID_X - 2, HIP_Y),
        "right_hip": (MID_X + 2, HIP_Y),
        "left_elbow": (center_x - 4 - phase, SHOULDER_Y + 4),
        "left_hand": (center_x - 4 - phase, SHOULDER_Y + 8),
        "right_elbow": (center_x + 4 + phase, SHOULDER_Y + 4),
        "right_hand": (center_x + 4 + phase, SHOULDER_Y + 8),
        "left_knee": (MID_X - 2, HIP_Y + 6),
        "left_foot": (MID_X - 2, FOOT_Y),
        "right_knee": (MID_X + 2, HIP_Y + 6),
        "right_foot": (MID_X + 2, FOOT_Y),
    }


def _draw_pose(pose: dict) -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    points = (
        _front_pose(pose["kind"], pose.get("phase", 0), pose["facing"])
        if pose["facing"] == "front"
        else _side_pose(pose["kind"], pose.get("phase", 0), pose["facing"])
    )

    segments = (
        ("head", "neck"),
        ("neck", "shoulder"),
        ("shoulder", "hip"),
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_hand"),
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_hand"),
        ("left_hip", "left_knee"),
        ("left_knee", "left_foot"),
        ("right_hip", "right_knee"),
        ("right_knee", "right_foot"),
    )
    for start, end in segments:
        draw.line((points[start], points[end]), fill=INK, width=1)

    head_x, head_y = points["head"]
    draw.ellipse((head_x - 2, head_y - 2, head_x + 2, head_y + 2), outline=JOINT)
    draw.line((points["head"], points["nose"]), fill=INK, width=1)
    for name in (
        "shoulder", "hip", "left_elbow", "right_elbow", "left_knee", "right_knee"
    ):
        x, y = points[name]
        draw.point((x, y), fill=JOINT)
    return image


def _save_gif(
    frames: list[Image.Image],
    path: Path,
    duration_ms: int,
    *,
    loop: bool | None,
) -> None:
    opaque_pixels = [
        pixel[:3]
        for frame in frames
        for pixel in frame.getdata()
        if pixel[3] > 0
    ]
    if not opaque_pixels:
        raise RuntimeError("Cannot create a GIF from fully transparent stickman frames")

    palette_samples = Image.new("RGB", (len(opaque_pixels), 1))
    palette_samples.putdata(opaque_pixels)
    palette = palette_samples.quantize(
        colors=255,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    palette_data = palette.getpalette()
    palette_data[765:768] = [0, 0, 0]

    indexed_frames = []
    for frame in frames:
        indexed = frame.convert("RGB").quantize(
            palette=palette,
            dither=Image.Dither.NONE,
        )
        indices = list(indexed.getdata())
        alpha = list(frame.getchannel("A").getdata())
        indexed.putdata([
            255 if opacity == 0 else color_index
            for color_index, opacity in zip(indices, alpha, strict=True)
        ])
        indexed.putpalette(palette_data)
        indexed.info["transparency"] = 255
        indexed_frames.append(indexed)

    save_options = {
        "format": "GIF",
        "save_all": True,
        "append_images": indexed_frames[1:],
        "duration": duration_ms,
        "disposal": 2,
        "transparency": 255,
        "optimize": False,
    }
    if loop is not None:
        if loop:
            save_options["loop"] = 0
    indexed_frames[0].save(path, **save_options)


def generate(output_dir: Path) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    frame_dir = output_dir / FRAME_DIR_NAME
    frame_dir.mkdir(parents=True, exist_ok=True)
    poses = server.POSE_SEQUENCE
    frames = [_draw_pose(pose) for pose in poses]
    hashes = [hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames]

    if len(frames) != 13 or len(set(hashes)) < 8:
        raise RuntimeError("Stickman sequence must contain 13 frames and at least 8 distinct poses")

    sheet = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    contact_columns = 4
    scale = 8
    label_height = 18
    contact_rows = (len(frames) + contact_columns - 1) // contact_columns
    contact = Image.new(
        "RGBA",
        (contact_columns * SIZE * scale, contact_rows * (SIZE * scale + label_height)),
        (24, 26, 34, 255),
    )
    contact_draw = ImageDraw.Draw(contact)
    manifest_frames = []
    for index, (frame, pose) in enumerate(zip(frames, poses, strict=True)):
        filename = f"frame_{index + 1:02d}.png"
        frame.save(frame_dir / filename)
        sheet.alpha_composite(frame, (index * SIZE, 0))
        x = (index % contact_columns) * SIZE * scale
        y = (index // contact_columns) * (SIZE * scale + label_height)
        contact.alpha_composite(frame.resize((SIZE * scale, SIZE * scale), Image.Resampling.NEAREST), (x, y))
        contact_draw.text((x + 3, y + SIZE * scale + 2), pose["name"].replace("_", " "), fill=INK)
        manifest_frames.append({
            "name": pose["name"],
            "index": index,
            "kind": pose["kind"],
            "facing": pose["facing"],
            "phase": pose.get("phase", 0),
            "file": f"{FRAME_DIR_NAME}/{filename}",
            "rect": [index * SIZE, 0, SIZE, SIZE],
            "pixel_sha256": hashes[index],
        })

    groups = {}
    for index, pose in enumerate(poses):
        if pose["kind"] == "idle":
            key = f"idle_{pose['facing']}"
        elif pose["kind"] in {"walk", "run"}:
            key = f"{pose['kind']}_{pose['facing']}"
        else:
            key = "turn"
        group = groups.setdefault(key, {"frames": [], "loop": key != "turn"})
        group["frames"].append(index)
    groups["showcase_loop"] = dict(server.ANIMATION_GROUPS["showcase_loop"])

    sheet.save(output_dir / SHEET_NAME)
    contact.save(output_dir / CONTACT_NAME)
    _save_gif(frames, output_dir / GIF_NAME, duration_ms=100, loop=None)
    group_gifs = {}
    for animation_name, animation in groups.items():
        group_gif_name = f"motion_stickman_{animation_name}.gif"
        group_frames = [frames[index] for index in animation["frames"]]
        _save_gif(
            group_frames,
            output_dir / group_gif_name,
            duration_ms=100,
            loop=animation["loop"],
        )
        group_gifs[animation_name] = group_gif_name
    manifest = {
        "type": "motion_stickman_reference",
        "schema_version": 1,
        "frame_size": [SIZE, SIZE],
        "frame_ms": 100,
        "sheet": SHEET_NAME,
        "contact_sheet": CONTACT_NAME,
        "gif": GIF_NAME,
        "group_gifs": group_gifs,
        "animations": groups,
        "frames": manifest_frames,
    }
    (output_dir / MANIFEST_NAME).write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: generate_stickman13.py <output-directory>")
    result = generate(Path(sys.argv[1]))
    print(json.dumps({
        "sheet": result["sheet"],
        "contact_sheet": result["contact_sheet"],
        "gif": result["gif"],
        "frames": len(result["frames"]),
        "output_dir": str(Path(sys.argv[1]).resolve()),
    }, indent=2))