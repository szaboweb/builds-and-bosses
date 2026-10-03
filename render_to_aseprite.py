import bpy
import os
import subprocess

# --- SETTINGS ---
ASEPRITE_PATH = r"C:\Program Files\Aseprite\Aseprite.exe"
# Get the home directory in a cross-platform way
HOME_DIR = os.path.expanduser("~")
OUTPUT_DIR = os.path.join(HOME_DIR, "Downloads", "render_frames")
ASEPRITE_FILE = os.path.join(HOME_DIR, "Downloads", "fighter_walk.aseprite")
RES = 64
START_FRAME = 1
END_FRAME = 12

if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

# --- BLENDER RENDER ---
scene = bpy.context.scene
scene.render.resolution_x = RES
scene.render.resolution_y = RES
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'

print(f"Starting render of {END_FRAME - START_FRAME + 1} frames...")

for f in range(START_FRAME, END_FRAME + 1):
    scene.frame_set(f)
    frame_path = os.path.join(OUTPUT_DIR, f"frame_{f:02d}.png")
    scene.render.filepath = frame_path
    bpy.ops.render.render(write_still=True)
    print(f"Rendered: {frame_path}")

# --- ASEPRITE PACKING ---
print("Packing frames into Aseprite...")
try:
    # Use the full path for Aseprite and frames
    # The glob pattern frame_*.png works best when passed as a single string to the shell
    command = f'"{ASEPRITE_PATH}" -b "{OUTPUT_DIR}\\frame_*.png" --save-as "{ASEPRITE_FILE}"'
    subprocess.run(command, shell=True, check=True)
    print(f"Successfully created: {ASEPRITE_FILE}")
except Exception as e:
    print(f"Error calling Aseprite: {e}")
