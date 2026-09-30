from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import server


SIZE = server.CHARACTER_CANVAS_SIZE
# Poses are authored in a 32-unit design space and scaled onto the current canvas,
# so the skeleton tables stay readable when the authoring resolution changes.
DESIGN_SIZE = 32
SCALE = max(1, SIZE // DESIGN_SIZE)
SHEET_NAME = "motion_stickman_13.png"
GAME_SHEET_NAME = "walk13_rendered.png"
GAME_MANIFEST_NAME = "walk13_sprite_manifest.json"
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
NOSE_REACH = 3
SIDE_HALF_WIDTH = 1
FRONT_HALF_WIDTH = 3

UPPER_ARM_LENGTH = 4
LOWER_ARM_LENGTH = 4
UPPER_LEG_LENGTH = 7
LOWER_LEG_LENGTH = 6

# Hand/foot targets as (x offset from the body centre, absolute y). The torso stays
# at a fixed height in every pose and the knees/elbows are solved by IK, so the
# sprite never bobs vertically between frames; only the limbs move.
SIDE_LIMB_TARGETS: dict[tuple[str, int], dict[str, tuple[int, int]]] = {
    ("idle", 0): {
        "arm_left": (-2, 18), "arm_right": (2, 18),
        "leg_left": (-1, FOOT_Y), "leg_right": (1, FOOT_Y),
    },
    ("walk", 1): {
        "arm_left": (-3, 19), "arm_right": (3, 19),
        "leg_left": (3, FOOT_Y), "leg_right": (-3, FOOT_Y),
    },
    ("walk", -1): {
        "arm_left": (3, 19), "arm_right": (-3, 19),
        "leg_left": (-3, FOOT_Y), "leg_right": (3, FOOT_Y),
    },
    ("run", 1): {
        "arm_left": (-5, 16), "arm_right": (5, 16),
        "leg_left": (5, 28), "leg_right": (-4, 26),
    },
    ("run", -1): {
        "arm_left": (5, 16), "arm_right": (-5, 16),
        "leg_left": (-4, 26), "leg_right": (5, 28),
    },
    ("turn", 0): {
        "arm_left": (-3, 17), "arm_right": (3, 19),
        "leg_left": (-2, FOOT_Y), "leg_right": (2, FOOT_Y),
    },
}
FRONT_LIMB_TARGETS: dict[str, tuple[int, int]] = {
    "arm_left": (-4, 18), "arm_right": (4, 18),
    "leg_left": (-3, FOOT_Y), "leg_right": (3, FOOT_Y),
}
# Knees bend toward the facing direction, elbows away from it.
LEG_BEND = -1
ARM_BEND = 1


def _two_bone_ik(
    origin: tuple[float, float],
    target: tuple[float, float],
    upper_length: int,
    lower_length: int,
    bend: int,
) -> tuple[tuple[float, float], tuple[float, float]]:
    origin_x, origin_y = origin
    delta_x, delta_y = target[0] - origin_x, target[1] - origin_y
    distance = math.hypot(delta_x, delta_y) or 1e-6
    reach = upper_length + lower_length - 1e-6
    if distance > reach:
        scale = reach / distance
        delta_x, delta_y, distance = delta_x * scale, delta_y * scale, reach
    unit_x, unit_y = delta_x / distance, delta_y / distance
    projection = (upper_length**2 - lower_length**2 + distance**2) / (2 * distance)
    offset = math.sqrt(max(upper_length**2 - projection**2, 0.0))
    joint = (
        origin_x + projection * unit_x - bend * offset * unit_y,
        origin_y + projection * unit_y + bend * offset * unit_x,
    )
    return joint, (origin_x + delta_x, origin_y + delta_y)


def _build_limbs(
    points: dict[str, tuple[float, float]],
    targets: dict[str, tuple[int, int]],
    centre_x: float,
) -> None:
    for side in ("left", "right"):
        arm_offset, arm_y = targets[f"arm_{side}"]
        leg_offset, leg_y = targets[f"leg_{side}"]
        elbow, hand = _two_bone_ik(
            points[f"{side}_shoulder"],
            (centre_x + arm_offset, arm_y),
            UPPER_ARM_LENGTH,
            LOWER_ARM_LENGTH,
            ARM_BEND,
        )
        knee, foot = _two_bone_ik(
            points[f"{side}_hip"],
            (centre_x + leg_offset, leg_y),
            UPPER_LEG_LENGTH,
            LOWER_LEG_LENGTH,
            LEG_BEND,
        )
        points[f"{side}_elbow"] = elbow
        points[f"{side}_hand"] = hand
        points[f"{side}_knee"] = knee
        points[f"{side}_foot"] = foot


def _side_pose(kind: str, phase: int, facing: str) -> dict[str, tuple[int, int]]:
    lead = (1 if phase > 0 else -1) if kind in {"walk", "run"} else 0
    targets = SIDE_LIMB_TARGETS.get((kind, lead), SIDE_LIMB_TARGETS[("idle", 0)])
    points: dict[str, tuple[float, float]] = {
        "head": (MID_X, HEAD_Y),
        "nose": (MID_X + NOSE_REACH, HEAD_Y),
        "neck": (MID_X, NECK_Y),
        "shoulder": (MID_X, SHOULDER_Y),
        "hip": (MID_X, HIP_Y),
        "left_shoulder": (MID_X - SIDE_HALF_WIDTH, SHOULDER_Y),
        "right_shoulder": (MID_X + SIDE_HALF_WIDTH, SHOULDER_Y),
        "left_hip": (MID_X - SIDE_HALF_WIDTH, HIP_Y),
        "right_hip": (MID_X + SIDE_HALF_WIDTH, HIP_Y),
    }
    _build_limbs(points, targets, MID_X)
    rounded = {name: (round(x), round(y)) for name, (x, y) in points.items()}
    if facing == "left":
        rounded = {name: (DESIGN_SIZE - 1 - x, y) for name, (x, y) in rounded.items()}
    return {name: (x * SCALE, y * SCALE) for name, (x, y) in rounded.items()}


def _front_pose(kind: str, phase: int, facing: str) -> dict[str, tuple[int, int]]:
    turn_offset = -2 if facing == "front" and phase > 0 else 2
    if kind == "front":
        turn_offset = 0
    center_x = MID_X + turn_offset
    swing = phase if kind == "turn" else 0
    targets = {
        name: (offset - swing if name.endswith("left") else offset + swing, target_y)
        if name.startswith("arm")
        else (offset, target_y)
        for name, (offset, target_y) in FRONT_LIMB_TARGETS.items()
    }
    points: dict[str, tuple[float, float]] = {
        "head": (center_x, HEAD_Y),
        "nose": (center_x + (1 if turn_offset <= 0 else -1), HEAD_Y),
        "neck": (center_x, NECK_Y),
        "shoulder": (center_x, SHOULDER_Y),
        "hip": (MID_X, HIP_Y),
        "left_shoulder": (center_x - FRONT_HALF_WIDTH, SHOULDER_Y),
        "right_shoulder": (center_x + FRONT_HALF_WIDTH, SHOULDER_Y),
        "left_hip": (MID_X - FRONT_HALF_WIDTH, HIP_Y),
        "right_hip": (MID_X + FRONT_HALF_WIDTH, HIP_Y),
    }
    _build_limbs(points, targets, center_x)
    return {name: (round(x) * SCALE, round(y) * SCALE) for name, (x, y) in points.items()}



def _draw_pose(pose: dict) -> Image.Image:
    return _draw_pose_at(pose, SIZE, SCALE)


def _draw_pose_at(pose: dict, canvas_size: int, scale: int) -> Image.Image:
    image = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    points = (
        _front_pose(pose["kind"], pose.get("phase", 0), pose["facing"])
        if pose["facing"] == "front"
        else _side_pose(pose["kind"], pose.get("phase", 0), pose["facing"])
    )
    if scale != SCALE:
        points = {name: (x // SCALE * scale, y // SCALE * scale) for name, (x, y) in points.items()}

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
        draw.line((points[start], points[end]), fill=INK, width=scale)

    head_x, head_y = points["head"]
    head_radius = 2 * scale
    draw.ellipse(
        (head_x - head_radius, head_y - head_radius, head_x + head_radius, head_y + head_radius),
        outline=JOINT,
        width=scale,
    )
    draw.line((points["head"], points["nose"]), fill=INK, width=scale)
    for name in (
        "shoulder", "hip", "left_elbow", "right_elbow", "left_knee", "right_knee"
    ):
        x, y = points[name]
        draw.rectangle((x, y, x + scale - 1, y + scale - 1), fill=JOINT)
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


def _write_game_sheet(poses: list[dict], output_dir: Path) -> Path:
    # Redrawn at game resolution instead of downscaled: thin stick-figure strokes
    # turn into grey mush under any resampling filter.
    game_size = server.GAME_CANVAS_SIZE
    game_scale = max(1, game_size // DESIGN_SIZE)
    frames = [_draw_pose_at(pose, game_size, game_scale) for pose in poses]
    sheet = Image.new("RGBA", (game_size * len(frames), game_size), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * game_size, 0))
    sheet_path = output_dir / GAME_SHEET_NAME
    sheet.save(sheet_path)

    manifest = {
        "type": "character_animations",
        "schema_version": 2,
        "sheet": GAME_SHEET_NAME,
        "cols": len(frames),
        "rows": 1,
        "cell_w": game_size,
        "cell_h": game_size,
        "frame_ms": 100,
        "alpha": True,
        "direction_mode": "pre_rendered",
        "animations": server.ANIMATION_GROUPS,
        "frames": [
            {
                "name": f"frame_{index + 1:02d}",
                "index": index,
                "pose": pose["name"],
                "kind": pose["kind"],
                "facing": pose["facing"],
                "phase": pose.get("phase", 0),
                "file": GAME_SHEET_NAME,
                "rect": [index * game_size, 0, game_size, game_size],
            }
            for index, pose in enumerate(poses)
        ],
    }
    (output_dir / GAME_MANIFEST_NAME).write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return sheet_path


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
    scale = max(1, 256 // SIZE)
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
    _write_game_sheet(poses, output_dir)
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