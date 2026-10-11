"""Headless Blender script to render 3D character/boss animation actions into 2D sprites.

Automatically:
- Configures transparent background and disables reference platform meshes.
- Auto-detects character forward/right orientation and animation frame range.
- Sets up an orthographic side-view camera with customizable elevation.
- Creates 3-point studio lighting (Key, colored Rim, Fill) for high contrast and read.
- Renders individual frame PNGs without clipping.
- Optionally bundles them with Aseprite into .aseprite, horizontal .png sheet, .json, and .gif.

Usage via Blender CLI:
    blender -b <model.blend> -P tooling/render_blend_to_sprites.py -- [options]

Options:
    --out-dir <path>        Output directory for rendered assets (required).
    --action <name>         Action name to render (default: active/first action).
    --name <name>           Base asset name (default: blend filename or action name).
    --res-x <int>           Frame width in pixels (default: 160).
    --res-y <int>           Frame height in pixels (default: 64).
    --elev-deg <float>      Camera elevation in degrees (default: 12.0).
    --start-frame <int>     Start frame (default: auto).
    --end-frame <int>       End frame (default: auto).
    --aseprite              Bundle rendered frames using Aseprite CLI.
    --aseprite-path <path>  Explicit path to Aseprite.exe.
"""

from __future__ import annotations

import argparse
import math
import os
from pathlib import Path
import subprocess
import sys


def parse_args():
    # Only parse arguments after the '--' delimiter
    raw_args = sys.argv
    if "--" in raw_args:
        args_to_parse = raw_args[raw_args.index("--") + 1 :]
    else:
        args_to_parse = []

    parser = argparse.ArgumentParser(description="Render Blender action to 2D sprites")
    parser.add_argument("--out-dir", required=True, help="Output directory")
    parser.add_argument("--action", default="", help="Action name to render")
    parser.add_argument("--name", default="", help="Asset base name")
    parser.add_argument("--res-x", type=int, default=160, help="Frame width in pixels")
    parser.add_argument("--res-y", type=int, default=64, help="Frame height in pixels")
    parser.add_argument(
        "--elev-deg", type=float, default=12.0, help="Camera elevation angle"
    )
    parser.add_argument("--start-frame", type=int, default=None, help="Start frame")
    parser.add_argument("--end-frame", type=int, default=None, help="End frame")
    parser.add_argument(
        "--aseprite", action="store_true", help="Bundle with Aseprite"
    )
    parser.add_argument("--aseprite-path", default="", help="Path to Aseprite.exe")

    return parser.parse_args(args_to_parse)


def find_aseprite(explicit_path: str = "") -> str:
    if explicit_path and os.path.exists(explicit_path):
        return explicit_path
    env_path = os.environ.get("ASEPRITE_PATH", "")
    if env_path and os.path.exists(env_path):
        return env_path
    candidates = [
        r"C:\Program Files\Aseprite\Aseprite.exe",
        r"C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return "aseprite"


def main():
    import bpy
    import mathutils

    args = parse_args()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    base_name = args.name
    if not base_name:
        blend_name = (
            Path(bpy.data.filepath).stem if bpy.data.filepath else "character"
        )
        base_name = f"{blend_name}_{args.action}" if args.action else blend_name

    # 1. Enable film transparent background and hide platform helpers
    bpy.context.scene.render.film_transparent = True
    for obj in bpy.data.objects:
        if obj.name.startswith("Platform") or obj.name.startswith("Helper"):
            obj.hide_render = True

    # 2. Select action
    armature = next(
        (o for o in bpy.data.objects if o.type == "ARMATURE"), None
    )
    action = None
    if args.action and args.action in bpy.data.actions:
        action = bpy.data.actions[args.action]
    elif armature and armature.animation_data and armature.animation_data.action:
        action = armature.animation_data.action
    elif len(bpy.data.actions) > 0:
        action = bpy.data.actions[0]

    if armature and action:
        if not armature.animation_data:
            armature.animation_data_create()
        armature.animation_data.action = action

    # 3. Determine frame range
    if args.start_frame is not None and args.end_frame is not None:
        start_frame = args.start_frame
        end_frame = args.end_frame
    elif bpy.context.scene.frame_start and bpy.context.scene.frame_end:
        start_frame = bpy.context.scene.frame_start
        end_frame = bpy.context.scene.frame_end
    else:
        start_frame = 1
        end_frame = 8

    # Check if end frame is an identical loop duplicate of start frame
    if armature and end_frame > start_frame:
        bpy.context.scene.frame_set(start_frame)
        dg = bpy.context.evaluated_depsgraph_get()
        eval_start = armature.evaluated_get(dg)
        p_start = {b.name: b.matrix.copy() for b in eval_start.pose.bones}

        bpy.context.scene.frame_set(end_frame)
        dg = bpy.context.evaluated_depsgraph_get()
        eval_end = armature.evaluated_get(dg)
        diff = max(
            (b.matrix - p_start[b.name]).translation.length
            for b in eval_end.pose.bones
            if b.name in p_start
        )
        if diff < 0.001:
            end_frame -= 1

    total_frames = end_frame - start_frame + 1
    print(f"[Render] Action: {action.name if action else 'default'}, frames: {start_frame}..{end_frame} ({total_frames} frames)")

    # 4. Measure envelope across all animation frames
    meshes = [
        o for o in bpy.data.objects
        if o.type == "MESH" and not o.name.startswith("Platform") and not o.hide_render
    ]

    all_corners = []
    for f in range(start_frame, end_frame + 1):
        bpy.context.scene.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        for m in meshes:
            me = m.evaluated_get(dg)
            mat = me.matrix_world
            for c in me.bound_box:
                all_corners.append(mat @ mathutils.Vector(c))

    # Determine orientation
    # Head / Tail orientation check
    head_obj = next((o for o in bpy.data.objects if "Head" in o.name and o.type == "MESH"), None)
    tail_obj = next((o for o in bpy.data.objects if "Tail" in o.name and o.type == "MESH"), None)
    if head_obj and tail_obj:
        forward = head_obj.matrix_world.translation - tail_obj.matrix_world.translation
        forward.z = 0
        forward.normalize()
    elif armature:
        forward = armature.matrix_world.to_3x3() @ mathutils.Vector((0, 1, 0))
        forward.z = 0
        forward.normalize()
    else:
        forward = mathutils.Vector((1, 0, 0))

    right = mathutils.Vector((forward.y, -forward.x, 0)).normalized()

    min_f = min(p.dot(forward) for p in all_corners)
    max_f = max(p.dot(forward) for p in all_corners)
    span_f = max_f - min_f
    mid_f = (min_f + max_f) / 2.0

    min_z = min(p.z for p in all_corners)
    max_z = max(p.z for p in all_corners)
    span_z = max_z - min_z
    mid_z = (min_z + max_z) / 2.0

    center = forward * mid_f + mathutils.Vector((0, 0, mid_z))

    # 5. Setup Camera
    cam = bpy.data.objects.get("Camera")
    if not cam:
        cam_data = bpy.data.cameras.new("Camera")
        cam = bpy.data.objects.new("Camera", cam_data)
        bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    cam.data.type = "ORTHO"
    aspect = args.res_x / float(args.res_y)
    scale_by_w = span_f / aspect
    scale_by_h = span_z
    cam.data.ortho_scale = max(scale_by_w, scale_by_h) * 1.12

    dist = 15.0
    elev_rad = math.radians(args.elev_deg)
    cam_pos = center + right * (dist * math.cos(elev_rad)) + mathutils.Vector((0, 0, dist * math.sin(elev_rad)))
    cam.location = cam_pos
    cam.rotation_euler = (center - cam_pos).to_track_quat("-Z", "Y").to_euler()

    # 6. Setup Lighting
    for o in list(bpy.data.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o, do_unlink=True)

    # Key light
    key_d = bpy.data.lights.new("KeyLight", "SUN")
    key_d.energy = 3.8
    key_d.color = (1.0, 0.97, 0.93)
    key_o = bpy.data.objects.new("KeyLight", key_d)
    bpy.context.collection.objects.link(key_o)
    key_o.rotation_euler = (center - (cam_pos + right * 2 + mathutils.Vector((0, 0, 4)))).to_track_quat("-Z", "Y").to_euler()

    # Rim light
    rim_d = bpy.data.lights.new("RimLight", "SUN")
    rim_d.energy = 2.8
    rim_d.color = (1.0, 0.35, 0.1)
    rim_o = bpy.data.objects.new("RimLight", rim_d)
    bpy.context.collection.objects.link(rim_o)
    rim_o.rotation_euler = (center - (center - right * 5 + mathutils.Vector((0, 0, 6)))).to_track_quat("-Z", "Y").to_euler()

    # Fill light
    fill_d = bpy.data.lights.new("FillLight", "SUN")
    fill_d.energy = 1.3
    fill_d.color = (0.65, 0.75, 1.0)
    fill_o = bpy.data.objects.new("FillLight", fill_d)
    bpy.context.collection.objects.link(fill_o)
    fill_o.rotation_euler = (center - (center + forward * 5 + mathutils.Vector((0, 0, 2)))).to_track_quat("-Z", "Y").to_euler()

    # 7. Render frames
    bpy.context.scene.render.resolution_x = args.res_x
    bpy.context.scene.render.resolution_y = args.res_y

    rendered_files = []
    for idx, f in enumerate(range(start_frame, end_frame + 1), start=1):
        bpy.context.scene.frame_set(f)
        frame_file = out_dir / f"frame_{idx:02d}.png"
        bpy.context.scene.render.filepath = str(frame_file)
        bpy.ops.render.render(write_still=True)
        rendered_files.append(frame_file)
        print(f"[Render] Saved {frame_file.name}")

    print(f"[Render] Completed {len(rendered_files)} frames in {out_dir}")

    # 8. Optional Aseprite packaging
    if args.aseprite:
        ase_exe = find_aseprite(args.aseprite_path)
        lua_script = out_dir / "_make_sheet.lua"
        ase_file = out_dir / f"{base_name}.aseprite"
        sheet_file = out_dir / f"{base_name}_sheet.png"
        json_file = out_dir / f"{base_name}.json"
        gif_file = out_dir / f"{base_name}.gif"

        lua_content = f"""local sprite = Sprite({args.res_x}, {args.res_y})
for i = 1, {len(rendered_files)} do
    local fn = string.format("{out_dir.as_posix()}/frame_%02d.png", i)
    local img = Image{{ fromFile = fn }}
    if i == 1 then
        sprite.cels[1].image = img
    else
        local frame = sprite:newFrame()
        sprite:newCel(sprite.layers[1], frame, img, Point(0, 0))
    end
end

for i, frame in ipairs(sprite.frames) do
    frame.duration = 0.12
end

sprite:saveAs("{ase_file.as_posix()}")
sprite:saveCopyAs("{gif_file.as_posix()}")
app.command.ExportSpriteSheet{{
    ui = false,
    askOverwrite = false,
    type = SpriteSheetType.HORIZONTAL,
    textureFilename = "{sheet_file.as_posix()}",
    dataFilename = "{json_file.as_posix()}",
    dataFormat = SpriteSheetDataFormat.JSON_HASH,
    openGenerated = false
}}
"""
        with open(lua_script, "w", encoding="utf-8") as f:
            f.write(lua_content)

        print(f"[Aseprite] Executing Aseprite bundle via {ase_exe}...")
        res = subprocess.run([ase_exe, "-b", "--script", str(lua_script)], capture_output=True, text=True)
        if res.returncode == 0:
            print(f"[Aseprite] Successfully exported {ase_file.name}, {sheet_file.name}, {json_file.name}, {gif_file.name}")
            if lua_script.exists():
                lua_script.unlink()
        else:
            print(f"[Aseprite Error] Code {res.returncode}: {res.stderr}")


if __name__ == "__main__":
    main()
