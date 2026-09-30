from __future__ import annotations

import io
import json
import hashlib
import logging
import os
import platform
import re
import secrets
import shutil
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, Response
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from pydantic import BaseModel, Field
import websocket


logger = logging.getLogger("character_workshop")
if not logger.handlers:
    _handler = logging.StreamHandler()
    _handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s character_workshop: %(message)s"))
    logger.addHandler(_handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False

_JOB_PROGRESS_LOCK = threading.Lock()
_JOB_PROGRESS: dict[str, dict] = {}

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW_BINDINGS_PATH = Path(__file__).with_name("workflow_bindings.json")
COMFYUI_URL = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188").rstrip("/")
COMFYUI_ROOT = Path(os.environ.get("COMFYUI_ROOT", r"C:\Users\mrsza\tools\ComfyUI-directml"))
CONTROLNET_MODEL = os.environ.get("CONTROLNET_MODEL", "control_v11p_sd15_canny.pth")
TILE_CONTROLNET_MODEL = os.environ.get("TILE_CONTROLNET_MODEL", "control_v11f1e_sd15_tile.pth")
IPADAPTER_MODEL = "ip-adapter-plus_sd15.safetensors"
IPADAPTER_CLIP_VISION = "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
IPADAPTER_WEIGHT = 0.7
TILE_CONTROL_STRENGTH = 0.25
# Characters are authored at 64x64 and supersampled down to the 32x32 sprite the game
# renders 1:1. SD 1.5 is also far more stable on a 64x64 latent than on a 32x32 one.
CHARACTER_CANVAS_SIZE = 64
GAME_CANVAS_SIZE = 32
GAME_DOWNSCALE = CHARACTER_CANVAS_SIZE // GAME_CANVAS_SIZE
PALETTE_LOCK_COLORS = 32
MAX_GENERATION_SEED = 4294967295
SAMPLER_SETTINGS = {
    "sampler_name": "euler",
    "scheduler": "normal",
    "steps": 20,
    "cfg": 8.0,
}
CONCEPT_DENOISE = 1.0
ANIMATION_DENOISE = 0.38
POSE_SEQUENCE = [
    {"name": "idle_right", "kind": "idle", "phase": 0, "facing": "right"},
    {"name": "walk_right_1", "kind": "walk", "phase": 1, "facing": "right"},
    {"name": "walk_right_2", "kind": "walk", "phase": -1, "facing": "right"},
    {"name": "run_right_1", "kind": "run", "phase": 1, "facing": "right"},
    {"name": "run_right_2", "kind": "run", "phase": -1, "facing": "right"},
    {"name": "turn_front_1", "kind": "turn", "phase": 1, "facing": "front"},
    {"name": "front", "kind": "front", "phase": 0, "facing": "front"},
    {"name": "turn_left_1", "kind": "turn", "phase": -1, "facing": "left"},
    {"name": "run_left_1", "kind": "run", "phase": -1, "facing": "left"},
    {"name": "run_left_2", "kind": "run", "phase": 1, "facing": "left"},
    {"name": "walk_left_1", "kind": "walk", "phase": -1, "facing": "left"},
    {"name": "walk_left_2", "kind": "walk", "phase": 1, "facing": "left"},
    {"name": "idle_left", "kind": "idle", "phase": 0, "facing": "left"},
]
ANIMATION_BATCH_GROUPS = [
    {
        "name": "right",
        "start": 0,
        "length": 5,
        "view": "side view, facing right, moving toward image right",
        "motion": "consistent right-facing profile, walking and running toward image right with alternating strides",
    },
    {
        "name": "turn",
        "start": 5,
        "length": 3,
        "view": "turn from right-facing side profile through a front-facing pose to a left-facing side profile",
        "motion": "three sequential turning poses; rotate the same character smoothly through front view without changing identity",
    },
    {
        "name": "left",
        "start": 8,
        "length": 5,
        "view": "side view, facing left, moving toward image left",
        "motion": "consistent left-facing profile, running and walking toward image left with alternating strides",
    },
]
ANIMATION_GROUPS = {
    "idle_right": {"frames": [0], "loop": True},
    "walk_right": {"frames": [1, 2], "loop": True},
    "run_right": {"frames": [3, 4], "loop": True},
    "turn": {"frames": [5, 6, 7], "loop": False},
    "run_left": {"frames": [8, 9], "loop": True},
    "walk_left": {"frames": [10, 11], "loop": True},
    "idle_left": {"frames": [12], "loop": True},
    # Seamless demo cycle over the same 13 poses: front idle -> turn right -> walk
    # right -> turn back through front -> walk left -> turn back to the front idle.
    # Turn frames 5 and 7 are replayed in reverse, so no extra poses are needed.
    "showcase_loop": {
        "frames": [6, 5, 0, 1, 2, 1, 2, 0, 5, 6, 7, 12, 11, 10, 11, 10, 12, 7],
        "loop": True,
    },
}
DEFAULT_PARTS = [
    {"name": "head", "role": "head", "x": 26, "y": 2, "width": 12, "height": 12, "color": "#F2C078"},
    {"name": "torso", "role": "torso", "x": 22, "y": 18, "width": 20, "height": 14, "color": "#3366FF"},
    {"name": "arm_left", "role": "arm_left", "x": 16, "y": 20, "width": 4, "height": 12, "color": "#F2C078"},
    {"name": "arm_right", "role": "arm_right", "x": 44, "y": 20, "width": 4, "height": 12, "color": "#F2C078"},
    {"name": "leg_left", "role": "leg_left", "x": 22, "y": 36, "width": 6, "height": 28, "color": "#30384A"},
    {"name": "leg_right", "role": "leg_right", "x": 36, "y": 36, "width": 6, "height": 28, "color": "#30384A"},
]

# Alternate body proportions per height class. Every rig below was validated to stay
# within the 64x64 canvas, keep both feet on row 63, and never let any of the 13
# walk/run/turn/front pose transforms make two parts overlap.
HEIGHT_RIGS: dict[str, list[dict]] = {
    "average": DEFAULT_PARTS,
    "short": [
        {"name": "head", "role": "head", "x": 24, "y": 10, "width": 16, "height": 14, "color": "#F2C078"},
        {"name": "torso", "role": "torso", "x": 18, "y": 26, "width": 28, "height": 16, "color": "#3366FF"},
        {"name": "arm_left", "role": "arm_left", "x": 12, "y": 28, "width": 4, "height": 14, "color": "#F2C078"},
        {"name": "arm_right", "role": "arm_right", "x": 48, "y": 28, "width": 4, "height": 14, "color": "#F2C078"},
        {"name": "leg_left", "role": "leg_left", "x": 20, "y": 44, "width": 8, "height": 20, "color": "#30384A"},
        {"name": "leg_right", "role": "leg_right", "x": 36, "y": 44, "width": 8, "height": 20, "color": "#30384A"},
    ],
    "tall": [
        {"name": "head", "role": "head", "x": 28, "y": 0, "width": 8, "height": 10, "color": "#F2C078"},
        {"name": "torso", "role": "torso", "x": 24, "y": 14, "width": 16, "height": 16, "color": "#3366FF"},
        {"name": "arm_left", "role": "arm_left", "x": 18, "y": 16, "width": 4, "height": 14, "color": "#F2C078"},
        {"name": "arm_right", "role": "arm_right", "x": 42, "y": 16, "width": 4, "height": 14, "color": "#F2C078"},
        {"name": "leg_left", "role": "leg_left", "x": 22, "y": 34, "width": 6, "height": 30, "color": "#30384A"},
        {"name": "leg_right", "role": "leg_right", "x": 36, "y": 34, "width": 6, "height": 30, "color": "#30384A"},
    ],
}

HEIGHT_PHRASES: dict[str, str] = {
    "short": "short and stocky build, dwarf-like proportions",
    "average": "average human proportions",
    "tall": "tall and slender build, elf-like proportions",
}

# Reinforces IP-Adapter/Canny identity anchoring in every animation branch prompt;
# text alone cannot guarantee this, but it measurably reduces drift in practice.
ANIMATION_IDENTITY_LOCK = (
    "(identical character in every frame, same face, same hair, same outfit, "
    "same proportions, same colors, do not change identity between poses:1.3)"
)

# The concept render always uses a flat, single-color background so it can be
# key-flattened deterministically in _flatten_background(); the animation
# frames are already forced transparent by the Aseprite alpha mask regardless.
# "reference sheet" wording is deliberately avoided: many pixel-art/anime
# checkpoints associate it with multi-panel character-sheet compositions
# (palette swatches, stat blocks, turnarounds), which is exactly the kind of
# hallucinated clutter this workshop must not produce.
BACKGROUND_PHRASES: dict[str, str] = {
    "transparent": "flat solid magenta background, empty background, no other objects",
    "white": "flat solid white background, empty background, no other objects",
    "black": "flat solid black background, empty background, no other objects",
}
BACKGROUND_NEGATIVE_TERMS = (
    "cluttered background, detailed background, background scenery, landscape, room, "
    "gradient background, background pattern, drop shadow, animals, pets, companions, "
    "magical creatures, objects, furniture, reference sheet, character sheet, model sheet, "
    "turnaround, multiple views, split screen, collage, color palette swatches, palette chart, "
    "stat block, user interface, icons, grid, borders, panels, multiple characters, text, numbers"
)


def _data_root() -> Path:
    configured = os.environ.get("CHARACTER_WORKSHOP_DATA_DIR")
    if configured:
        return Path(configured).expanduser().resolve()
    if platform.system().lower() == "windows":
        return Path(os.environ.get("LOCALAPPDATA", Path.home())) / "BuildsAndBosses" / "CharacterWorkshop"
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "builds-and-bosses" / "character-workshop"


DATA_ROOT = _data_root()
PROJECTS_ROOT = DATA_ROOT / "projects"


class Part(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    role: Literal["head", "torso", "arm_left", "arm_right", "leg_left", "leg_right", "static"]
    x: int = Field(ge=0, le=CHARACTER_CANVAS_SIZE - 1)
    y: int = Field(ge=0, le=CHARACTER_CANVAS_SIZE - 1)
    width: int = Field(ge=1, le=CHARACTER_CANVAS_SIZE)
    height: int = Field(ge=1, le=CHARACTER_CANVAS_SIZE)
    color: str = Field(pattern=r"^#[0-9A-Fa-f]{6}$")


class ProjectCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    subject: str = Field(min_length=1, max_length=240)
    height_class: Literal["short", "average", "tall"] = Field(default="average")
    background: Literal["transparent"] = Field(default="transparent")
    view: str = Field(
        default="side view, facing right, full body, centered on a plain background",
        max_length=200,
    )
    head: str = Field(default="", max_length=300)
    hairstyle: str = Field(default="", max_length=200)
    has_beard: bool = Field(default=False)
    has_helmet: bool = Field(default=False)
    upper_body: str = Field(default="", max_length=300)
    lower_body: str = Field(default="", max_length=300)
    left_hand: str = Field(default="empty", max_length=200)
    right_hand: str = Field(default="empty", max_length=200)
    held_item: str = Field(default="", max_length=200)
    palette: str = Field(default="", max_length=200)
    style_tags: str = Field(default="2D pixel", max_length=200)
    positive_prompt: str = Field(default="", max_length=2000)
    negative_prompt: str = Field(default="", max_length=2000)
    character_lora: str = Field(
        default="", max_length=200,
        pattern=r"^(?:|[A-Za-z0-9 _./-]+\.(?:safetensors|pt))$",
    )
    seed: int | None = Field(default=None, ge=0, le=4294967295)


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=64)
    subject: str | None = Field(default=None, min_length=1, max_length=240)
    height_class: Literal["short", "average", "tall"] | None = Field(default=None)
    background: Literal["transparent"] | None = Field(default=None)
    view: str | None = Field(default=None, max_length=200)
    head: str | None = Field(default=None, max_length=300)
    hairstyle: str | None = Field(default=None, max_length=200)
    has_beard: bool | None = Field(default=None)
    has_helmet: bool | None = Field(default=None)
    upper_body: str | None = Field(default=None, max_length=300)
    lower_body: str | None = Field(default=None, max_length=300)
    left_hand: str | None = Field(default=None, max_length=200)
    right_hand: str | None = Field(default=None, max_length=200)
    held_item: str | None = Field(default=None, max_length=200)
    palette: str | None = Field(default=None, max_length=200)
    style_tags: str | None = Field(default=None, max_length=200)
    positive_prompt: str | None = Field(default=None, max_length=2000)
    negative_prompt: str | None = Field(default=None, max_length=2000)
    character_lora: str | None = Field(
        default=None, max_length=200,
        pattern=r"^(?:|[A-Za-z0-9 _./-]+\.(?:safetensors|pt))$",
    )
    seed: int | None = Field(default=None, ge=0, le=4294967295)
    parts: list[Part] | None = None


class GenerateRequest(BaseModel):
    seed: int | None = Field(default=None, ge=0, le=4294967295)


class AnimateRequest(BaseModel):
    parts: list[Part] | None = None


app = FastAPI(title="Builds & Bosses Character Workshop", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_methods=["GET", "POST", "PUT", "OPTIONS"],
    allow_headers=["Content-Type"],
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ensure_project_seed(project: dict) -> int:
    seed = project.get("seed")
    if type(seed) is not int or not 0 <= seed <= MAX_GENERATION_SEED:
        seed = secrets.randbits(32)
        project["seed"] = seed
        logger.warning("Replaced invalid/missing project seed with %s for project %s", seed, project.get("id"))
    return seed


def _sampler_inputs(seed: int, denoise: float) -> dict:
    return {"seed": seed, **SAMPLER_SETTINGS, "denoise": denoise}


def _animation_branch_seeds(seed: int) -> dict[str, int]:
    return {
        group["name"]: (seed + group["start"]) % (MAX_GENERATION_SEED + 1)
        for group in ANIMATION_BATCH_GROUPS
    }


def _workflow_model_name(workflow: dict) -> str | None:
    for node in workflow.values():
        if node.get("class_type") == "CheckpointLoaderSimple":
            return node.get("inputs", {}).get("ckpt_name")
    return None


def _invalidate_accepted_outputs(project: dict) -> None:
    project["approved_image"] = None
    project["approved_prompt_id"] = None
    project["animation"] = None


def _project_directory(project_id: str) -> Path:
    try:
        safe_id = str(uuid.UUID(project_id))
    except ValueError as exc:
        raise HTTPException(status_code=404, detail="Project not found") from exc
    return PROJECTS_ROOT / safe_id


def _save_project(project: dict) -> None:
    directory = _project_directory(project["id"])
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / "project.json"
    temporary = target.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(project, indent=2), encoding="utf-8")
    temporary.replace(target)


def _load_project(project_id: str) -> dict:
    path = _project_directory(project_id) / "project.json"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Project not found")
    try:
        project = json.loads(path.read_text(encoding="utf-8"))
        project["background"] = "transparent"
        if not isinstance(project.get("character_lora"), str):
            project["character_lora"] = ""
        return project
    except (OSError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=500, detail="Project data is unreadable") from exc


def _request_json(url: str, payload: dict | None = None) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"} if data is not None else {},
        method="POST" if data is not None else "GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise HTTPException(status_code=502, detail=f"ComfyUI returned {exc.code}: {detail}") from exc
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=502, detail=f"ComfyUI request failed: {exc}") from exc


def _set_job_progress(prompt_id: str, **updates) -> dict:
    with _JOB_PROGRESS_LOCK:
        progress = _JOB_PROGRESS.setdefault(prompt_id, {"status": "queued", "step": 0, "total": None})
        progress.update(updates)
        progress["updated_at"] = _now()
        if len(_JOB_PROGRESS) > 256:
            oldest_prompt_id = next(iter(_JOB_PROGRESS))
            if oldest_prompt_id != prompt_id:
                _JOB_PROGRESS.pop(oldest_prompt_id, None)
        return dict(progress)


def _get_job_progress(prompt_id: str) -> dict | None:
    with _JOB_PROGRESS_LOCK:
        progress = _JOB_PROGRESS.get(prompt_id)
        return None if progress is None else dict(progress)


def _watch_comfy_job(connection, prompt_id: str) -> None:
    deadline = time.monotonic() + 600
    try:
        while time.monotonic() < deadline:
            try:
                message = connection.recv()
            except websocket.WebSocketTimeoutException:
                continue
            if not isinstance(message, str):
                continue
            try:
                event = json.loads(message)
            except json.JSONDecodeError:
                continue

            event_type = event.get("type")
            data = event.get("data", {})
            event_prompt_id = data.get("prompt_id")
            if event_prompt_id and event_prompt_id != prompt_id:
                continue

            if event_type == "progress":
                current = int(data.get("value", 0))
                total = int(data.get("max", 0)) or None
                _set_job_progress(
                    prompt_id,
                    status="running",
                    step=current,
                    total=total,
                    fraction=(current / total) if total else None,
                )
            elif event_type == "executing":
                node_id = data.get("node")
                if node_id is None:
                    _set_job_progress(prompt_id, status="completed", step=None, fraction=1.0)
                    return
                _set_job_progress(prompt_id, status="running", node_id=str(node_id))
            elif event_type == "execution_error":
                _set_job_progress(
                    prompt_id,
                    status="error",
                    error=data.get("exception_message", "ComfyUI execution failed"),
                )
                return
            elif event_type == "execution_success":
                _set_job_progress(prompt_id, status="completed", step=None, fraction=1.0)
                return
    except (websocket.WebSocketException, OSError, TimeoutError) as exc:
        logger.info("ComfyUI WebSocket tracking ended for job %s; REST polling remains available: %s", prompt_id, exc)
    finally:
        try:
            connection.close()
        except websocket.WebSocketException:
            pass


def _queue_comfy_workflow(workflow: dict) -> dict:
    client_id = str(uuid.uuid4())
    parsed_url = urllib.parse.urlsplit(COMFYUI_URL)
    websocket_scheme = "wss" if parsed_url.scheme == "https" else "ws"
    websocket_url = f"{websocket_scheme}://{parsed_url.netloc}/ws?{urllib.parse.urlencode({'clientId': client_id})}"
    connection = None
    try:
        connection = websocket.create_connection(websocket_url, timeout=5)
        connection.settimeout(1)
    except (websocket.WebSocketException, OSError, TimeoutError) as exc:
        logger.info("ComfyUI WebSocket unavailable; falling back to REST/history polling: %s", exc)

    try:
        result = _request_json(
            f"{COMFYUI_URL}/prompt",
            {"prompt": workflow, "client_id": client_id},
        )
    except HTTPException:
        if connection is not None:
            connection.close()
        raise

    prompt_id = result.get("prompt_id")
    if prompt_id:
        _set_job_progress(str(prompt_id), status="queued", step=0, total=None, fraction=0.0)
        if connection is not None:
            threading.Thread(
                target=_watch_comfy_job,
                args=(connection, str(prompt_id)),
                daemon=True,
                name=f"comfy-progress-{str(prompt_id)[:8]}",
            ).start()
    elif connection is not None:
        connection.close()
    return result


def _load_workflow_config() -> tuple[dict, dict]:
    try:
        bindings = json.loads(WORKFLOW_BINDINGS_PATH.read_text(encoding="utf-8"))
        workflow_path = (REPO_ROOT / bindings["workflow_path"]).resolve()
        workflow_path.relative_to(REPO_ROOT)
        workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
    except (OSError, KeyError, ValueError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=500, detail=f"Cannot load ComfyUI workflow: {exc}") from exc
    return workflow, bindings["nodes"]


def _load_animation_workflow_config() -> tuple[dict, dict]:
    try:
        bindings = json.loads(WORKFLOW_BINDINGS_PATH.read_text(encoding="utf-8"))
        workflow_path = (REPO_ROOT / bindings["animation_workflow_path"]).resolve()
        workflow_path.relative_to(REPO_ROOT)
        workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
    except (OSError, KeyError, ValueError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=500, detail=f"Cannot load animation workflow: {exc}") from exc
    return workflow, bindings["animation_nodes"]


def _apply_character_lora(
    workflow: dict,
    project: dict,
    loader_id: str,
    model_target_ids: str | list[str],
) -> str | None:
    lora_name = project.get("character_lora", "").strip()
    if not lora_name:
        return None

    lora_info = _request_json(f"{COMFYUI_URL}/object_info/LoraLoader").get("LoraLoader", {})
    lora_names = lora_info.get("input", {}).get("required", {}).get("lora_name", [[]])[0]
    if lora_name not in lora_names:
        raise HTTPException(
            status_code=422,
            detail=f"Character LoRA '{lora_name}' is not installed in ComfyUI's models/loras folder",
        )

    checkpoint_id = next(
        node_id for node_id, node in workflow.items()
        if node.get("class_type") == "CheckpointLoaderSimple"
    )
    workflow[loader_id] = {
        "inputs": {
            "model": [checkpoint_id, 0],
            "clip": [checkpoint_id, 1],
            "lora_name": lora_name,
            "strength_model": 0.8,
            "strength_clip": 0.8,
        },
        "class_type": "LoraLoader",
        "_meta": {"title": "Load Character Consistency LoRA"},
    }
    for node in workflow.values():
        if node.get("class_type") == "CLIPTextEncode" and node.get("inputs", {}).get("clip") == [checkpoint_id, 1]:
            node["inputs"]["clip"] = [loader_id, 1]
    target_ids = [model_target_ids] if isinstance(model_target_ids, str) else model_target_ids
    for model_target_id in target_ids:
        workflow[model_target_id]["inputs"]["model"] = [loader_id, 0]
    return lora_name


def _compose_prompt(project: dict) -> str:
    segments = [
        "pixel art, 2D retro game character, single full-body character",
        "solo, exactly one character, one pose only, no other objects or props besides the specified hand items",
    ]
    segments.append(BACKGROUND_PHRASES["transparent"])
    view_text = (project.get("view") or "").strip() or "side view, facing right, centered on a plain background"
    # Left/right facing is notoriously unreliable for diffusion models; emphasis
    # weighting (native ComfyUI CLIPTextEncode syntax) biases it but cannot fully
    # guarantee it. Reordering it to the front and up-weighting it helps in practice.
    segments.append(f"({view_text}:1.3)")
    height_class = project.get("height_class") or "average"
    segments.append(HEIGHT_PHRASES.get(height_class, HEIGHT_PHRASES["average"]))
    subject = (project.get("subject") or "").strip()
    if subject:
        segments.append(subject)
    head = (project.get("head") or "").strip()
    if head:
        segments.append(head)
    hairstyle = (project.get("hairstyle") or "").strip()
    if hairstyle:
        segments.append(hairstyle)
    segments.append("with a beard" if project.get("has_beard") else "clean-shaven, no beard")
    segments.append("wearing a helmet" if project.get("has_helmet") else "no helmet, bare head")
    for key in ("upper_body", "lower_body"):
        value = (project.get(key) or "").strip()
        if value:
            segments.append(value)
    left_hand = project.get("left_hand")
    right_hand = project.get("right_hand")
    if left_hand is None and right_hand is None and project.get("held_item"):
        right_hand = project["held_item"]
        left_hand = "empty"
    for side, hand_item in (("left", left_hand), ("right", right_hand)):
        item = (hand_item or "empty").strip()
        if item.lower() in {"", "empty", "none", "nothing"}:
            segments.append(
                f"(character's own {side} hand is empty, visibly unoccupied, fingers relaxed:1.4)"
            )
        else:
            segments.append(f"(character holds exactly {item} in their own {side} hand:1.4)")
    palette = (project.get("palette") or "").strip()
    if palette:
        segments.append(f"{palette} color palette")
    style_tags = (project.get("style_tags") or "").strip()
    if style_tags:
        segments.append(style_tags)
    else:
        segments.append("2D pixel")
    extra = (project.get("positive_prompt") or "").strip()
    if extra:
        segments.append(extra)
    return ", ".join(segments)


def _compose_negative_prompt(project: dict) -> str:
    extra = (project.get("negative_prompt") or "").strip()
    segments = [BACKGROUND_NEGATIVE_TERMS, "extra held objects, duplicate props, extra weapons"]
    left_hand = project.get("left_hand")
    right_hand = project.get("right_hand")
    if left_hand is None and right_hand is None and project.get("held_item"):
        right_hand = project["held_item"]
        left_hand = "empty"
    for side, hand_item in (("left", left_hand), ("right", right_hand)):
        item = (hand_item or "empty").strip()
        if item.lower() in {"", "empty", "none", "nothing"}:
            segments.append(
                f"item in the character's empty {side} hand, object in the character's empty {side} hand"
            )
    if extra:
        segments.append(extra)
    return ", ".join(segments)


def _apply_background_mode(image_bytes: bytes) -> bytes:
    return _flatten_background(image_bytes, "transparent")


def _flatten_background(image_bytes: bytes, mode: str) -> bytes:
    """Force the generated background to real transparency or a flat solid
    color, regardless of what the diffusion model actually painted there."""
    image = Image.open(io.BytesIO(image_bytes)).convert("RGBA")
    probe = image.convert("RGB")
    width, height = probe.size
    sentinel = (1, 254, 3)
    for point in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        if probe.getpixel(point) != sentinel:
            ImageDraw.floodfill(probe, point, sentinel, thresh=40)
    mask = Image.new("L", probe.size, 0)
    probe_pixels = probe.load()
    mask_pixels = mask.load()
    for y in range(height):
        for x in range(width):
            if probe_pixels[x, y] == sentinel:
                mask_pixels[x, y] = 255

    if mode == "transparent":
        alpha = image.getchannel("A")
        image.putalpha(ImageChops.multiply(alpha, ImageChops.invert(mask)))
    else:
        flat_color = (255, 255, 255, 255) if mode == "white" else (0, 0, 0, 255)
        flat = Image.new("RGBA", image.size, flat_color)
        image = Image.composite(flat, image, mask)

    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def _history_entry(prompt_id: str) -> dict | None:
    history = _request_json(f"{COMFYUI_URL}/history/{urllib.parse.quote(prompt_id)}")
    return history.get(prompt_id)


def _candidate_images(entry: dict, save_node_id: str) -> list[dict]:
    return entry.get("outputs", {}).get(str(save_node_id), {}).get("images", [])


def _get_candidate(project: dict, prompt_id: str) -> dict:
    for candidate in project["candidates"]:
        if candidate["prompt_id"] == prompt_id:
            return candidate
    raise HTTPException(status_code=404, detail="Generation job not found")


def _comfy_image_bytes(image: dict) -> bytes:
    query = urllib.parse.urlencode({
        "filename": image["filename"],
        "subfolder": image.get("subfolder", ""),
        "type": image.get("type", "output"),
    })
    try:
        with urllib.request.urlopen(f"{COMFYUI_URL}/view?{query}", timeout=60) as response:
            return response.read()
    except (urllib.error.URLError, KeyError, TimeoutError) as exc:
        raise HTTPException(status_code=502, detail=f"Could not retrieve ComfyUI image: {exc}") from exc


def _upload_image(path: Path, subfolder: str) -> str:
    boundary = f"----CharacterWorkshop{uuid.uuid4().hex}"
    fields = {
        "type": "input",
        "subfolder": subfolder,
        "overwrite": "true",
    }
    chunks = []
    for name, value in fields.items():
        chunks.extend([
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
            value.encode(),
            b"\r\n",
        ])
    chunks.extend([
        f"--{boundary}\r\n".encode(),
        f'Content-Disposition: form-data; name="image"; filename="{path.name}"\r\n'.encode(),
        b"Content-Type: image/png\r\n\r\n",
        path.read_bytes(),
        b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    request = urllib.request.Request(
        f"{COMFYUI_URL}/upload/image",
        data=b"".join(chunks),
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            result = json.loads(response.read().decode("utf-8"))
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        logger.error("Upload to ComfyUI failed for %s: %s", path.name, exc)
        raise HTTPException(
            status_code=502, detail=f"Could not upload '{path.name}' to ComfyUI: {exc}"
        ) from exc
    return "/".join(part for part in (result.get("subfolder", subfolder), result["name"]) if part)


def _make_control_masks(sheet_path: Path, directory: Path) -> tuple[list[Path], list[Image.Image]]:
    try:
        sheet = Image.open(sheet_path).convert("RGBA")
    except OSError as exc:
        raise HTTPException(status_code=502, detail=f"Could not open Aseprite sprite sheet: {exc}") from exc
    if sheet.size != (CHARACTER_CANVAS_SIZE * 13, CHARACTER_CANVAS_SIZE):
        raise HTTPException(
            status_code=502,
            detail=f"Expected a {CHARACTER_CANVAS_SIZE * 13}x{CHARACTER_CANVAS_SIZE} animation sheet, got {sheet.width}x{sheet.height}",
        )

    control_paths = []
    alpha_masks = []
    mask_dir = directory / "control_masks"
    mask_dir.mkdir(parents=True, exist_ok=True)
    for frame_index in range(13):
        left = frame_index * CHARACTER_CANVAS_SIZE
        frame = sheet.crop((left, 0, left + CHARACTER_CANVAS_SIZE, CHARACTER_CANVAS_SIZE))
        alpha = frame.getchannel("A").point(lambda value: 255 if value > 0 else 0)
        control = Image.new("RGB", (CHARACTER_CANVAS_SIZE, CHARACTER_CANVAS_SIZE), "black")
        edge = alpha.filter(ImageFilter.FIND_EDGES).point(
            lambda value: 255 if value > 16 else 0
        )
        control.paste("white", mask=edge)
        marker = ImageDraw.Draw(control)
        facing = POSE_SEQUENCE[frame_index]["facing"]
        if facing == "right":
            marker.line(((1, 2), (6, 2)), fill="white", width=1)
            marker.line(((4, 0), (6, 2), (4, 4)), fill="white", width=1)
        elif facing == "left":
            marker.line(((30, 2), (25, 2)), fill="white", width=1)
            marker.line(((27, 0), (25, 2), (27, 4)), fill="white", width=1)
        else:
            marker.line(((1, 1), (4, 1), (4, 4), (1, 4), (1, 1)), fill="white", width=1)
        path = mask_dir / f"pose_{frame_index + 1:02d}.png"
        control.save(path)
        control_paths.append(path)
        alpha_masks.append(alpha)
    return control_paths, alpha_masks


def _compose_animation_prompt(project: dict, group: dict) -> str:
    animation_project = dict(project)
    animation_project["view"] = group["view"]
    existing_notes = (project.get("positive_prompt") or "").strip()
    animation_project["positive_prompt"] = ", ".join(
        note for note in (existing_notes, group["motion"], ANIMATION_IDENTITY_LOCK) if note
    )
    return _compose_prompt(animation_project)


def _build_animation_workflow(
    base_workflow: dict,
    bindings: dict,
    controlnet_name: str,
    tile_controlnet_name: str,
    mask_names: list[str],
    reference_name: str,
    project: dict,
    save_prefix: str,
    *,
    use_ipadapter: bool = True,
    use_tile: bool = True,
) -> dict:
    workflow = json.loads(json.dumps(base_workflow))
    negative_id = bindings["negative_prompt"]
    sampler_ids = bindings["samplers"]
    positive_ids = bindings["positive_prompts"]
    save_id = bindings["save_image"]
    pose_image_ids = bindings["pose_images"]
    if (
        len(pose_image_ids) != 13
        or len(mask_names) != 13
        or len(ANIMATION_BATCH_GROUPS) != len(sampler_ids)
        or len(positive_ids) != len(ANIMATION_BATCH_GROUPS)
    ):
        raise HTTPException(status_code=500, detail="Animation workflow must bind exactly 13 pose masks")

    workflow[negative_id]["inputs"]["text"] = project["negative_prompt"]
    workflow[save_id]["inputs"]["filename_prefix"] = save_prefix
    workflow[bindings["controlnet_loader"]]["inputs"]["control_net_name"] = controlnet_name
    for node_id, image_name in zip(pose_image_ids, mask_names, strict=True):
        workflow[node_id]["inputs"]["image"] = image_name
    workflow[bindings["approved_reference"]]["inputs"]["image"] = reference_name

    seed = _ensure_project_seed(project)
    branch_seeds = _animation_branch_seeds(seed)
    for group_index, group in enumerate(ANIMATION_BATCH_GROUPS):
        positive_id = positive_ids[group_index]
        latent_slice_id = bindings["latent_slices"][group_index]
        pose_slice_id = bindings["pose_slices"][group_index]
        reference_slice_id = bindings["reference_slices"][group_index]
        canny_apply_id = bindings["canny_applies"][group_index]
        tile_apply_id = bindings["tile_applies"][group_index]
        sampler_id = sampler_ids[group_index]
        start = group["start"]
        length = group["length"]

        workflow[positive_id]["inputs"]["text"] = _compose_animation_prompt(project, group)
        workflow[latent_slice_id]["inputs"].update({"batch_index": start, "length": length})
        workflow[pose_slice_id]["inputs"].update({"batch_index": start, "length": length})
        workflow[reference_slice_id]["inputs"].update({"batch_index": start, "length": length})
        workflow[canny_apply_id]["inputs"].update({
            "control_net": [bindings["controlnet_loader"], 0],
            "image": [pose_slice_id, 0],
        })
        workflow[tile_apply_id]["inputs"].update({
            "control_net": [bindings["tile_controlnet_loader"], 0],
            "image": [reference_slice_id, 0],
            "strength": TILE_CONTROL_STRENGTH,
        })

        branch_seed = branch_seeds[group["name"]]
        sampler_inputs = workflow[sampler_id]["inputs"]
        sampler_inputs.update(_sampler_inputs(branch_seed, ANIMATION_DENOISE))
        sampler_inputs["latent_image"] = [latent_slice_id, 0]
        sampler_inputs["positive"] = [tile_apply_id, 0]
        sampler_inputs["negative"] = [tile_apply_id, 1]

    if use_ipadapter:
        workflow[bindings["ipadapter_loader"]]["inputs"]["ipadapter_file"] = IPADAPTER_MODEL
        workflow[bindings["clip_vision_loader"]]["inputs"]["clip_name"] = IPADAPTER_CLIP_VISION
        workflow[bindings["ipadapter_apply"]]["inputs"]["weight"] = IPADAPTER_WEIGHT
    else:
        for sampler_id in sampler_ids:
            workflow[sampler_id]["inputs"]["model"] = ["1", 0]
        for node_key in ("ipadapter_loader", "clip_vision_loader", "ipadapter_apply"):
            workflow.pop(bindings[node_key], None)
    if use_tile:
        workflow[bindings["tile_controlnet_loader"]]["inputs"]["control_net_name"] = tile_controlnet_name
    else:
        for group_index, sampler_id in enumerate(sampler_ids):
            canny_apply_id = bindings["canny_applies"][group_index]
            workflow[sampler_id]["inputs"]["positive"] = [canny_apply_id, 0]
            workflow[sampler_id]["inputs"]["negative"] = [canny_apply_id, 1]
        for node_id in bindings["reference_slices"]:
            workflow.pop(node_id, None)
        workflow.pop(bindings["tile_reference_batch"], None)
        workflow.pop(bindings["tile_controlnet_loader"], None)
        for node_id in bindings["tile_applies"]:
            workflow.pop(node_id, None)
    _apply_character_lora(
        workflow,
        project,
        bindings["lora_loader"],
        bindings["lora_model_target"] if use_ipadapter else sampler_ids,
    )
    latent_batch_ids = bindings["latent_batch_nodes"]
    workflow[latent_batch_ids[0]]["inputs"].update({
        "samples1": [sampler_ids[0], 0],
        "samples2": [sampler_ids[1], 0],
    })
    workflow[latent_batch_ids[1]]["inputs"].update({
        "samples1": [latent_batch_ids[0], 0],
        "samples2": [sampler_ids[2], 0],
    })
    workflow[bindings["latent_batch_nodes"][1]]["_meta"]["title"] = (
        "Reassemble Right (5) + Turn (3) + Left (5)"
    )
    return workflow


def _wait_for_comfy_job(prompt_id: str, timeout_seconds: int = 600) -> dict:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        entry = _history_entry(prompt_id)
        if entry is not None:
            status = entry.get("status", {})
            if status.get("completed") or status.get("status_str") in {"success", "error"}:
                return entry
        time.sleep(1)
    raise HTTPException(status_code=504, detail="ComfyUI animation job timed out after 10 minutes")


def _composite_rendered_frames(
    entry: dict,
    save_node_id: str,
    alpha_masks: list[Image.Image],
    directory: Path,
    palette_reference: Path | None = None,
) -> tuple[Path, list[str]]:
    images = _candidate_images(entry, save_node_id)
    if len(images) != 13:
        raise HTTPException(status_code=502, detail=f"Expected 13 ComfyUI frame outputs, got {len(images)}")
    frame_paths = []
    rendered = []
    for index, image_ref in enumerate(images):
        frame_bytes = _comfy_image_bytes(image_ref)
        try:
            frame = Image.open(io.BytesIO(frame_bytes)).convert("RGBA")
        except OSError as exc:
            raise HTTPException(status_code=502, detail=f"Could not decode ComfyUI frame {index + 1}: {exc}") from exc
        if frame.size != (CHARACTER_CANVAS_SIZE, CHARACTER_CANVAS_SIZE):
            frame = frame.resize((CHARACTER_CANVAS_SIZE, CHARACTER_CANVAS_SIZE), Image.Resampling.NEAREST)
        frame.putalpha(ImageChops.multiply(frame.getchannel("A"), alpha_masks[index]))
        frame_paths.append(f"rendered_{index + 1:02d}.png")
        rendered.append(frame)

    palette_pixels = bytearray()
    palette_source = []
    if palette_reference is not None and palette_reference.is_file():
        with Image.open(palette_reference) as reference_image:
            palette_source.append(reference_image.convert("RGBA"))
    if not palette_source:
        palette_source = rendered
    for source in palette_source:
        for red, green, blue, alpha in source.getdata():
            if alpha > 0:
                palette_pixels.extend((red, green, blue))
    if not palette_pixels:
        raise HTTPException(status_code=502, detail="Cannot build a shared palette from transparent images")
    palette_samples = Image.frombytes("RGB", (len(palette_pixels) // 3, 1), bytes(palette_pixels))
    shared_palette = palette_samples.quantize(
        colors=PALETTE_LOCK_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )

    for index, frame in enumerate(rendered):
        locked = frame.convert("RGB").quantize(
            palette=shared_palette,
            dither=Image.Dither.NONE,
        ).convert("RGBA")
        locked.putalpha(alpha_masks[index])
        rendered[index] = locked
        locked.save(directory / frame_paths[index])

    sheet = Image.new("RGBA", (CHARACTER_CANVAS_SIZE * len(rendered), CHARACTER_CANVAS_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(rendered):
        sheet.alpha_composite(frame, (index * CHARACTER_CANVAS_SIZE, 0))
    sheet_path = directory / "walk13_rendered.png"
    sheet.save(sheet_path)
    _write_game_sheet(sheet, directory)
    return sheet_path, frame_paths


def _write_game_sheet(sheet: Image.Image, directory: Path) -> Path:
    # Box-filter supersampling: the game renders the 32x32 result 1:1, so the extra
    # authoring detail lands as cleaner edges instead of runtime rescaling blur.
    game_sheet = sheet.resize(
        (sheet.width // GAME_DOWNSCALE, sheet.height // GAME_DOWNSCALE),
        Image.Resampling.BOX,
    )
    alpha = game_sheet.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    flattened = game_sheet.convert("RGB").quantize(
        colors=PALETTE_LOCK_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    flattened.putalpha(alpha)
    game_path = directory / "walk13_game.png"
    flattened.save(game_path)
    return game_path


def _write_animation_quality_report(
    frame_files: list[str],
    alpha_masks: list[Image.Image],
    directory: Path,
    frame_duration_ms: int = 100,
) -> dict:
    if len(frame_files) != 13 or len(alpha_masks) != 13:
        raise HTTPException(status_code=502, detail="Sprite QC requires exactly 13 output frames and masks")

    contact_columns = 4
    scale = 3
    frame_display_size = CHARACTER_CANVAS_SIZE * scale
    label_height = 16
    contact_rows = (len(frame_files) + contact_columns - 1) // contact_columns
    contact_sheet = Image.new(
        "RGBA",
        (contact_columns * frame_display_size, contact_rows * (frame_display_size + label_height)),
        (24, 26, 34, 255),
    )
    contact_draw = ImageDraw.Draw(contact_sheet)
    frames = []
    total_palette = Counter()
    duplicate_frames: dict[str, int] = {}
    duplicate_pairs = []
    all_canvas_sizes_match = True
    all_alpha_masks_match = True
    all_frames_anchor_to_baseline = True
    total_opaque_pixels = 0
    silhouette_hashes = []

    for index, filename in enumerate(frame_files):
        frame_path = directory / filename
        try:
            with Image.open(frame_path) as source:
                frame = source.convert("RGBA")
        except OSError as exc:
            raise HTTPException(status_code=502, detail=f"Could not reopen rendered frame {index + 1}: {exc}") from exc
        size_matches = frame.size == (CHARACTER_CANVAS_SIZE, CHARACTER_CANVAS_SIZE)
        all_canvas_sizes_match = all_canvas_sizes_match and size_matches
        actual_alpha = frame.getchannel("A")
        expected_alpha = alpha_masks[index].convert("L").point(lambda value: 255 if value else 0)
        mask_matches = actual_alpha.tobytes() == expected_alpha.tobytes()
        all_alpha_masks_match = all_alpha_masks_match and mask_matches
        bbox = actual_alpha.getbbox()
        expected_bbox = expected_alpha.getbbox()
        anchored = expected_bbox is not None and expected_bbox[3] == CHARACTER_CANVAS_SIZE
        all_frames_anchor_to_baseline = all_frames_anchor_to_baseline and anchored

        colors = Counter(
            pixel[:3]
            for pixel in frame.getdata()
            if pixel[3] > 0
        )
        total_palette.update(colors)
        opaque_pixels = sum(colors.values())
        total_opaque_pixels += opaque_pixels
        frame_hash = hashlib.sha256(frame.tobytes()).hexdigest()
        silhouette_hash = hashlib.sha256(expected_alpha.tobytes()).hexdigest()
        silhouette_hashes.append(silhouette_hash)
        prior_index = duplicate_frames.get(frame_hash)
        if prior_index is not None:
            duplicate_pairs.append([prior_index, index + 1])
        else:
            duplicate_frames[frame_hash] = index + 1

        frames.append({
            "index": index + 1,
            "pose": POSE_SEQUENCE[index]["name"],
            "kind": POSE_SEQUENCE[index]["kind"],
            "facing": POSE_SEQUENCE[index]["facing"],
            "phase": POSE_SEQUENCE[index].get("phase", 0),
            "file": filename,
            "size": list(frame.size),
            "opaque_pixels": opaque_pixels,
            "bbox": list(bbox) if bbox else None,
            "palette_colors": len(colors),
            "alpha_matches_geometry": mask_matches,
            "feet_on_baseline": anchored,
            "pixel_sha256": frame_hash,
        })

        contact_x = (index % contact_columns) * frame_display_size
        contact_y = (index // contact_columns) * (frame_display_size + label_height)
        enlarged = frame.resize(
            (frame_display_size, frame_display_size),
            Image.Resampling.NEAREST,
        )
        contact_sheet.alpha_composite(enlarged, (contact_x, contact_y))
        contact_draw.text(
            (contact_x + 2, contact_y + frame_display_size + 1),
            POSE_SEQUENCE[index]["name"].replace("_", " "),
            fill=(235, 238, 245, 255),
        )

    walk_silhouettes = {
        silhouette_hashes[index]
        for index, pose in enumerate(POSE_SEQUENCE)
        if pose["kind"] == "walk"
    }
    run_silhouettes = {
        silhouette_hashes[index]
        for index, pose in enumerate(POSE_SEQUENCE)
        if pose["kind"] == "run"
    }
    turn_front_indices = [
        index for index, pose in enumerate(POSE_SEQUENCE)
        if pose["kind"] in {"turn", "front"}
    ]
    checks = {
        "frame_count_is_13": len(frames) == 13,
        "common_authoring_canvas": all_canvas_sizes_match,
        "alpha_matches_geometry_masks": all_alpha_masks_match,
        "feet_on_last_row": all_frames_anchor_to_baseline,
        "palette_locked_max_32_colors": len(total_palette) <= PALETTE_LOCK_COLORS,
        "walk_cycle_has_visible_pose_changes": len(walk_silhouettes) >= 2,
        "run_cycle_has_visible_pose_changes": len(run_silhouettes) >= 2,
        "left_and_right_idle_poses_differ": silhouette_hashes[0] != silhouette_hashes[-1],
        "turn_and_front_poses_are_distinct": len({silhouette_hashes[index] for index in turn_front_indices}) >= 3,
        "at_least_8_unique_pose_silhouettes": len(set(silhouette_hashes)) >= 8,
    }
    if not all(checks.values()):
        raise HTTPException(status_code=502, detail=f"Sprite quality gate failed: {checks}")

    top_palette = {color for color, _ in total_palette.most_common(16)}
    top_palette_pixels = sum(count for color, count in total_palette.items() if color in top_palette)
    report = {
        "schema_version": 1,
        "passed": True,
        "frame_count": len(frames),
        "frame_size": [CHARACTER_CANVAS_SIZE, CHARACTER_CANVAS_SIZE],
        "checks": checks,
        "palette": {
            "unique_colors": len(total_palette),
            "color_limit": PALETTE_LOCK_COLORS,
            "top_16_pixel_coverage": round(top_palette_pixels / total_opaque_pixels, 4)
            if total_opaque_pixels
            else 0,
        },
        "duplicate_frame_pairs": duplicate_pairs,
        "frames": frames,
        "contact_sheet": "walk13_contact_sheet.png",
    }
    sprite_manifest = {
        "type": "character_animations",
        "schema_version": 2,
        "sheet": "walk13_game.png",
        "authoring_sheet": "walk13_rendered.png",
        "cols": 13,
        "rows": 1,
        "cell_w": GAME_CANVAS_SIZE,
        "cell_h": GAME_CANVAS_SIZE,
        "authoring_cell_w": CHARACTER_CANVAS_SIZE,
        "authoring_cell_h": CHARACTER_CANVAS_SIZE,
        "frame_ms": frame_duration_ms,
        "alpha": True,
        "direction_mode": "pre_rendered",
        "palette_colors": len(total_palette),
        "animations": ANIMATION_GROUPS,
        "frames": [
            {
                "name": f"frame_{index + 1:02d}",
                "index": index,
                "pose": POSE_SEQUENCE[index]["name"],
                "kind": POSE_SEQUENCE[index]["kind"],
                "facing": POSE_SEQUENCE[index]["facing"],
                "phase": POSE_SEQUENCE[index].get("phase", 0),
                "file": filename,
                "rect": [index * GAME_CANVAS_SIZE, 0, GAME_CANVAS_SIZE, GAME_CANVAS_SIZE],
                "authoring_rect": [
                    index * CHARACTER_CANVAS_SIZE,
                    0,
                    CHARACTER_CANVAS_SIZE,
                    CHARACTER_CANVAS_SIZE,
                ],
            }
            for index, filename in enumerate(frame_files)
        ],
    }
    contact_sheet.save(directory / report["contact_sheet"])
    report_path = directory / "walk13_quality.json"
    sprite_manifest_path = directory / "walk13_sprite_manifest.json"
    report["manifest_file"] = report_path.name
    report["sprite_manifest_file"] = sprite_manifest_path.name
    sprite_manifest_path.write_text(json.dumps(sprite_manifest, indent=2), encoding="utf-8")
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def _aseprite_path() -> str:
    configured = os.environ.get("ASEPRITE_PATH")
    candidates = [configured, shutil.which("aseprite"), r"C:\Program Files\Aseprite\Aseprite.exe"]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    raise HTTPException(status_code=503, detail="Aseprite CLI not found; set ASEPRITE_PATH")


def _run_aseprite(command: list[str], cwd: Path) -> None:
    try:
        result = subprocess.run(
            command, cwd=cwd, capture_output=True, text=True, timeout=180,
        )
    except subprocess.TimeoutExpired as exc:
        logger.error("Aseprite command timed out: %s", command)
        raise HTTPException(
            status_code=502,
            detail=f"Aseprite timed out after 180s running: {' '.join(command)}",
        ) from exc
    if result.returncode != 0:
        logger.error(
            "Aseprite exited %s for %s\nstdout: %s\nstderr: %s",
            result.returncode, command, result.stdout, result.stderr,
        )
        raise HTTPException(
            status_code=502,
            detail=(
                f"Aseprite exited with code {result.returncode}. "
                f"stdout: {result.stdout.strip() or '(empty)'} "
                f"stderr: {result.stderr.strip() or '(empty)'}"
            ),
        )


@app.get("/api/health")
def health() -> dict:
    try:
        _request_json(f"{COMFYUI_URL}/system_stats")
        comfy_status = "online"
    except HTTPException:
        comfy_status = "offline"
    return {
        "status": "ok",
        "comfyui": comfy_status,
        "aseprite": shutil.which("aseprite") is not None or Path(r"C:\Program Files\Aseprite\Aseprite.exe").is_file(),
        "data_dir": str(DATA_ROOT),
    }


@app.get("/api/projects")
def list_projects() -> list[dict]:
    if not PROJECTS_ROOT.exists():
        return []
    projects = []
    for path in PROJECTS_ROOT.glob("*/project.json"):
        try:
            project = json.loads(path.read_text(encoding="utf-8"))
            project["background"] = "transparent"
            project.setdefault("character_lora", "")
            projects.append({key: project[key] for key in (
                "id", "name", "subject", "height_class", "background", "view", "head", "hairstyle",
                "has_beard", "has_helmet", "upper_body", "lower_body", "left_hand", "right_hand", "held_item",
                "palette", "style_tags", "positive_prompt", "negative_prompt", "character_lora", "seed",
                "revision", "created_at", "updated_at", "approved_image", "candidates", "animation", "parts",
            )})
        except (OSError, json.JSONDecodeError, KeyError):
            continue
    return sorted(projects, key=lambda item: item["updated_at"], reverse=True)


@app.post("/api/projects")
def create_project(request: ProjectCreate) -> dict:
    now = _now()
    project = {
        "schema_version": 1,
        "id": str(uuid.uuid4()),
        "name": request.name,
        "subject": request.subject,
        "height_class": request.height_class,
        "background": request.background,
        "view": request.view,
        "head": request.head,
        "hairstyle": request.hairstyle,
        "has_beard": request.has_beard,
        "has_helmet": request.has_helmet,
        "upper_body": request.upper_body,
        "lower_body": request.lower_body,
        "left_hand": request.left_hand,
        "right_hand": request.right_hand,
        "held_item": request.held_item,
        "palette": request.palette,
        "style_tags": request.style_tags,
        "positive_prompt": request.positive_prompt,
        "negative_prompt": request.negative_prompt,
        "character_lora": request.character_lora,
        "seed": request.seed if request.seed is not None else secrets.randbits(32),
        "revision": 1,
        "created_at": now,
        "updated_at": now,
        "approved_image": None,
        "candidates": [],
        "parts": HEIGHT_RIGS[request.height_class],
        "animation": None,
    }
    if request.left_hand == "empty" and request.right_hand == "empty" and request.held_item.strip():
        project["right_hand"] = request.held_item.strip()
    _save_project(project)
    return project


@app.get("/api/projects/{project_id}")
def get_project(project_id: str) -> dict:
    return _load_project(project_id)


@app.put("/api/projects/{project_id}")
def update_project(project_id: str, request: ProjectUpdate) -> dict:
    project = _load_project(project_id)
    changes = request.model_dump(exclude_unset=True)
    if "character_lora" in changes and changes["character_lora"] is None:
        changes["character_lora"] = ""
    if "seed" in changes and changes["seed"] is None:
        changes["seed"] = secrets.randbits(32)
    if "seed" in changes and changes["seed"] != project.get("seed"):
        project["candidates"] = []
        _invalidate_accepted_outputs(project)
    if "character_lora" in changes and changes["character_lora"] != project.get("character_lora", ""):
        project["candidates"] = []
        _invalidate_accepted_outputs(project)
    for key, value in changes.items():
        project[key] = [part.model_dump() for part in value] if key == "parts" and value is not None else value
    project["background"] = "transparent"
    if changes:
        project["revision"] += 1
        project["updated_at"] = _now()
        _save_project(project)
    return project


@app.post("/api/projects/{project_id}/generate")
def generate_candidate(project_id: str, request: GenerateRequest) -> dict:
    project = _load_project(project_id)
    workflow, nodes = _load_workflow_config()
    existing_seed = _ensure_project_seed(project)
    seed = request.seed if request.seed is not None else existing_seed
    if seed != existing_seed:
        _invalidate_accepted_outputs(project)
    character_lora = _apply_character_lora(
        workflow, project, nodes["lora_loader"], nodes["lora_model_target"]
    )
    project["seed"] = seed
    project["generation_settings"] = {
        "model": _workflow_model_name(workflow),
        **_sampler_inputs(seed, CONCEPT_DENOISE),
        "character_lora": character_lora,
    }
    project["updated_at"] = _now()
    _save_project(project)
    try:
        workflow[nodes["positive_prompt"]]["inputs"]["text"] = _compose_prompt(project)
        workflow[nodes["negative_prompt"]]["inputs"]["text"] = _compose_negative_prompt(project)
        sampler_inputs = workflow[nodes["sampler"]]["inputs"]
        sampler_inputs.update(_sampler_inputs(seed, CONCEPT_DENOISE))
        workflow[nodes["save_image"]]["inputs"]["filename_prefix"] = f"character_workshop/{project_id}/candidate"
    except (KeyError, TypeError) as exc:
        logger.error("Concept workflow binding mismatch for project %s: %s", project_id, exc)
        raise HTTPException(status_code=500, detail=f"Workflow node bindings do not match the API JSON: {exc}") from exc

    result = _queue_comfy_workflow(workflow)
    prompt_id = result.get("prompt_id")
    if not prompt_id:
        logger.error("ComfyUI rejected concept workflow for project %s: %s", project_id, result)
        raise HTTPException(status_code=502, detail=f"ComfyUI did not accept the workflow: {result}")
    logger.info("Queued concept job %s for project %s (seed=%s)", prompt_id, project_id, seed)
    candidate = {
        "prompt_id": prompt_id,
        "seed": seed,
        "settings": project["generation_settings"],
        "status": "queued",
        "images": [],
        "error": None,
    }
    project["candidates"].append(candidate)
    project["updated_at"] = _now()
    _save_project(project)
    return {"prompt_id": prompt_id, "seed": seed, "candidate": candidate}


@app.get("/api/projects/{project_id}/jobs/{prompt_id}")
def get_job(project_id: str, prompt_id: str) -> dict:
    project = _load_project(project_id)
    candidate = _get_candidate(project, prompt_id)
    entry = _history_entry(prompt_id)
    progress = _get_job_progress(prompt_id)
    if entry is None:
        result = dict(candidate)
        if progress is not None:
            result["progress"] = progress
            if progress["status"] in {"queued", "running"}:
                result["status"] = progress["status"]
            elif progress["status"] == "error":
                result["status"] = "error"
                result["error"] = progress.get("error")
        return result
    _, nodes = _load_workflow_config()
    images = _candidate_images(entry, nodes["save_image"])
    status = entry.get("status", {}).get("status_str", "completed")
    candidate["status"] = "completed" if images else ("error" if status == "error" else "running")
    candidate["images"] = images
    if candidate["status"] == "error":
        candidate["error"] = entry.get("status", {}).get("messages", "ComfyUI generation failed")
    project["updated_at"] = _now()
    _save_project(project)
    result = dict(candidate)
    if progress is not None:
        result["progress"] = progress
    return result


@app.get("/api/projects/{project_id}/jobs/{prompt_id}/images/{image_index}")
def get_candidate_image(project_id: str, prompt_id: str, image_index: int = 0) -> Response:
    project = _load_project(project_id)
    _get_candidate(project, prompt_id)
    job = get_job(project_id, prompt_id)
    if job["status"] != "completed":
        raise HTTPException(status_code=409, detail="Generation is not complete")
    images = job["images"]
    if image_index < 0 or image_index >= len(images):
        raise HTTPException(status_code=404, detail="Candidate image not found")
    image = images[image_index]
    flattened = _apply_background_mode(_comfy_image_bytes(image))
    return Response(content=flattened, media_type="image/png")


@app.post("/api/projects/{project_id}/approve/{prompt_id}")
def approve_candidate(project_id: str, prompt_id: str) -> dict:
    project = _load_project(project_id)
    candidate = _get_candidate(project, prompt_id)
    job = get_job(project_id, prompt_id)
    candidate["status"] = job["status"]
    candidate["images"] = job.get("images", [])
    if job["status"] != "completed" or not candidate["images"]:
        raise HTTPException(status_code=409, detail="Only a completed candidate can be approved")
    image = candidate["images"][0]
    directory = _project_directory(project_id)
    candidate_path = directory / f"approved_candidate_{len(project['candidates']):02d}.png"
    image_bytes = _apply_background_mode(_comfy_image_bytes(image))
    candidate_path.write_bytes(image_bytes)
    (directory / "approved.png").write_bytes(image_bytes)
    project["approved_image"] = candidate_path.name
    project["approved_prompt_id"] = prompt_id
    project["updated_at"] = _now()
    _save_project(project)
    logger.info("Approved candidate %s for project %s", prompt_id, project_id)
    return project


@app.get("/api/projects/{project_id}/approved.png")
def get_approved_image(project_id: str) -> FileResponse:
    path = _project_directory(project_id) / "approved.png"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="No approved image")
    return FileResponse(path, media_type="image/png")


@app.post("/api/projects/{project_id}/animate")
def generate_animation(project_id: str, request: AnimateRequest) -> dict:
    project = _load_project(project_id)
    logger.info("Starting animation render for project %s", project_id)
    if not project.get("approved_image"):
        raise HTTPException(status_code=409, detail="Approve a concept image before generating an animation")
    seed = _ensure_project_seed(project)
    project["seed"] = seed
    controlnet_path = COMFYUI_ROOT / "models" / "controlnet" / CONTROLNET_MODEL
    if not controlnet_path.is_file():
        raise HTTPException(
            status_code=503,
            detail=f"Missing SD 1.5 Canny ControlNet '{CONTROLNET_MODEL}' at {controlnet_path}.",
        )
    available_nodes = set(_request_json(f"{COMFYUI_URL}/object_info"))
    models_root = COMFYUI_ROOT / "models"
    use_ipadapter = (
        {"IPAdapterModelLoader", "IPAdapterAdvanced", "CLIPVisionLoader"} <= available_nodes
        and (models_root / "ipadapter" / IPADAPTER_MODEL).is_file()
        and (models_root / "clip_vision" / IPADAPTER_CLIP_VISION).is_file()
    )
    use_tile = (
        {"RepeatImageBatch", "ControlNetLoader", "ControlNetApplyAdvanced"} <= available_nodes
        and (models_root / "controlnet" / TILE_CONTROLNET_MODEL).is_file()
    )
    if not use_ipadapter:
        logger.warning("IP-Adapter node/model unavailable; using the Canny-only appearance fallback")
    if not use_tile:
        logger.warning("Tile ControlNet unavailable; using the Canny-only pose-control path")
    parts = request.parts or [Part.model_validate(part) for part in project["parts"]]
    project["parts"] = [part.model_dump() for part in parts]
    project["generation_settings"] = {
        "seed": seed,
        **_sampler_inputs(seed, ANIMATION_DENOISE),
    }
    project["updated_at"] = _now()
    _save_project(project)
    directory = _project_directory(project_id)
    config_path = directory / "walk13.json"
    config_path.write_text(json.dumps({
        "projectName": "character",
        "subjectDescription": project["subject"],
        "parts": project["parts"],
        "poses": POSE_SEQUENCE,
    }, indent=2), encoding="utf-8")
    script_path = REPO_ROOT / "tooling" / "generate_walk13.lua"
    aseprite = _aseprite_path()
    source_path = directory / "character_walk13.aseprite"
    sheet_path = directory / "walk13.png"
    metadata_path = directory / "walk13.json"
    try:
        logger.info("Running Aseprite pose generator for project %s", project_id)
        _run_aseprite(
            [aseprite, "-b", "--script-param", f"config={config_path}", "--script", str(script_path)],
            cwd=directory,
        )
        logger.info("Exporting Aseprite sprite sheet for project %s", project_id)
        _run_aseprite(
            [aseprite, "-b", str(source_path), "--tag", "walk13", "--sheet-type", "horizontal",
             "--sheet", str(sheet_path), "--data", str(metadata_path)],
            cwd=directory,
        )
    except HTTPException:
        logger.error("Aseprite step failed for project %s", project_id)
        raise
    if not sheet_path.is_file():
        logger.error("Aseprite reported success but no sprite sheet exists for project %s", project_id)
        raise HTTPException(status_code=502, detail="Aseprite did not create the expected sprite sheet")

    control_paths, alpha_masks = _make_control_masks(sheet_path, directory)
    comfy_subfolder = f"character_workshop/{project_id}"
    logger.info("Uploading %d pose masks and reference image to ComfyUI for project %s", len(control_paths), project_id)
    mask_names = [_upload_image(path, comfy_subfolder) for path in control_paths]
    approved_path = directory / "approved.png"
    reference_name = _upload_image(approved_path, comfy_subfolder)
    workflow, bindings = _load_animation_workflow_config()
    animation_workflow = _build_animation_workflow(
        workflow,
        bindings,
        CONTROLNET_MODEL,
        TILE_CONTROLNET_MODEL,
        mask_names,
        reference_name,
        project,
        f"character_workshop/{project_id}/rendered/frame",
        use_ipadapter=use_ipadapter,
        use_tile=use_tile,
    )
    project["generation_settings"]["model"] = _workflow_model_name(animation_workflow)
    project["generation_settings"].update(_sampler_inputs(seed, ANIMATION_DENOISE))
    project["generation_settings"].update({
        "character_lora": project.get("character_lora") or None,
        "ipadapter_model": IPADAPTER_MODEL if use_ipadapter else None,
        "clip_vision_model": IPADAPTER_CLIP_VISION if use_ipadapter else None,
        "ipadapter_weight": IPADAPTER_WEIGHT if use_ipadapter else None,
        "tile_controlnet_model": TILE_CONTROLNET_MODEL if use_tile else None,
        "tile_control_strength": TILE_CONTROL_STRENGTH if use_tile else None,
        "consistency_controls": {"ipadapter": use_ipadapter, "tile": use_tile},
        "palette_lock_colors": PALETTE_LOCK_COLORS,
        "animation_branch_seeds": _animation_branch_seeds(seed),
    })
    project["updated_at"] = _now()
    _save_project(project)
    queued = _queue_comfy_workflow(animation_workflow)
    prompt_id = queued.get("prompt_id")
    if not prompt_id:
        logger.error("ComfyUI rejected animation workflow for project %s: %s", project_id, queued)
        raise HTTPException(status_code=502, detail=f"ComfyUI rejected animation workflow: {queued}")
    logger.info("Queued animation job %s for project %s; waiting for completion", prompt_id, project_id)
    started_at = time.monotonic()
    entry = _wait_for_comfy_job(prompt_id)
    logger.info("Animation job %s finished in %.1fs", prompt_id, time.monotonic() - started_at)
    status = entry.get("status", {})
    if status.get("status_str") == "error":
        logger.error("ComfyUI animation job %s failed: %s", prompt_id, status.get("messages", status))
        raise HTTPException(status_code=502, detail=f"ComfyUI animation failed: {status.get('messages', status)}")
    rendered_sheet, rendered_frames = _composite_rendered_frames(
        entry,
        bindings["save_image"],
        alpha_masks,
        directory,
        approved_path,
    )
    quality_report = _write_animation_quality_report(
        rendered_frames,
        alpha_masks,
        directory,
        frame_duration_ms=100,
    )
    project["animation"] = {
        "kind": "controlnet_canny_batch",
        "frames": 13,
        "frame_width": CHARACTER_CANVAS_SIZE,
        "frame_height": CHARACTER_CANVAS_SIZE,
        "source": source_path.name,
        "geometry_sheet": sheet_path.name,
        "sheet": rendered_sheet.name,
        "frame_files": rendered_frames,
        "contact_sheet": quality_report["contact_sheet"],
        "quality_manifest": quality_report["manifest_file"],
        "sprite_manifest": quality_report["sprite_manifest_file"],
        "quality": quality_report,
        "metadata": metadata_path.name,
        "comfy_prompt_id": prompt_id,
        "controlnet_model": CONTROLNET_MODEL,
        "tile_controlnet_model": TILE_CONTROLNET_MODEL if use_tile else None,
        "ipadapter_model": IPADAPTER_MODEL if use_ipadapter else None,
        "generation_settings": {
            "model": _workflow_model_name(animation_workflow),
            **_sampler_inputs(seed, ANIMATION_DENOISE),
            "character_lora": project.get("character_lora") or None,
            "ipadapter_model": IPADAPTER_MODEL if use_ipadapter else None,
            "clip_vision_model": IPADAPTER_CLIP_VISION if use_ipadapter else None,
            "ipadapter_weight": IPADAPTER_WEIGHT if use_ipadapter else None,
            "tile_controlnet_model": TILE_CONTROLNET_MODEL if use_tile else None,
            "tile_control_strength": TILE_CONTROL_STRENGTH if use_tile else None,
            "consistency_controls": {"ipadapter": use_ipadapter, "tile": use_tile},
            "palette_lock_colors": PALETTE_LOCK_COLORS,
            "animation_branch_seeds": _animation_branch_seeds(seed),
        },
        "generated_at": _now(),
    }
    project["updated_at"] = _now()
    _save_project(project)
    logger.info("Animation render complete for project %s (prompt %s)", project_id, prompt_id)
    return project["animation"]


@app.get("/api/projects/{project_id}/animation/sheet")
def get_animation_sheet(project_id: str) -> FileResponse:
    project = _load_project(project_id)
    animation = project.get("animation")
    if not animation:
        raise HTTPException(status_code=404, detail="No animation generated")
    path = _project_directory(project_id) / animation["sheet"]
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Animation sheet is missing")
    return FileResponse(path, media_type="image/png")


@app.get("/api/projects/{project_id}/animation/contact-sheet")
def get_animation_contact_sheet(project_id: str) -> FileResponse:
    project = _load_project(project_id)
    animation = project.get("animation") or {}
    filename = animation.get("contact_sheet")
    if not filename or Path(filename).name != filename:
        raise HTTPException(status_code=404, detail="Animation contact sheet is missing")
    path = _project_directory(project_id) / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Animation contact sheet is missing")
    return FileResponse(path, media_type="image/png")


@app.get("/api/projects/{project_id}/animation/quality")
def get_animation_quality_report(project_id: str) -> FileResponse:
    project = _load_project(project_id)
    animation = project.get("animation") or {}
    filename = animation.get("quality_manifest")
    if not filename or Path(filename).name != filename:
        raise HTTPException(status_code=404, detail="Animation quality report is missing")
    path = _project_directory(project_id) / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Animation quality report is missing")
    return FileResponse(path, media_type="application/json")


@app.get("/api/projects/{project_id}/animation/manifest")
def get_animation_sprite_manifest(project_id: str) -> FileResponse:
    project = _load_project(project_id)
    animation = project.get("animation") or {}
    filename = animation.get("sprite_manifest")
    if not filename or Path(filename).name != filename:
        raise HTTPException(status_code=404, detail="Animation sprite manifest is missing")
    path = _project_directory(project_id) / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Animation sprite manifest is missing")
    return FileResponse(path, media_type="application/json")


def _register_pubspec_asset(slug: str) -> bool:
    """Adds the published folder to the Flutter asset list. Returns True if changed."""
    pubspec = REPO_ROOT / "app" / "pubspec.yaml"
    entry = f"    - assets/images/characters/{slug}/"
    lines = pubspec.read_text(encoding="utf-8").splitlines()
    if any(line.rstrip() == entry for line in lines):
        return False
    anchors = [
        index
        for index, line in enumerate(lines)
        if line.startswith("    - assets/images/characters/")
    ]
    if not anchors:
        raise HTTPException(status_code=500, detail="pubspec.yaml has no character asset list")
    lines.insert(anchors[-1] + 1, entry)
    pubspec.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return True


@app.post("/api/projects/{project_id}/publish")
def publish_animation_to_game(project_id: str) -> dict:
    project = _load_project(project_id)
    animation = project.get("animation")
    if not animation:
        raise HTTPException(status_code=409, detail="Render an animation before publishing")

    directory = _project_directory(project_id)
    game_sheet = directory / "walk13_game.png"
    manifest_name = animation.get("sprite_manifest")
    if not game_sheet.is_file() or not manifest_name or Path(manifest_name).name != manifest_name:
        raise HTTPException(status_code=409, detail="Re-render the animation to produce the game sheet")
    manifest_path = directory / manifest_name
    if not manifest_path.is_file():
        raise HTTPException(status_code=409, detail="Re-render the animation to produce the game sheet")

    slug = re.sub(r"[^a-z0-9_]+", "_", project["name"].lower()).strip("_") or "character"
    target = REPO_ROOT / "app" / "assets" / "images" / "characters" / slug
    target.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(game_sheet, target / "walk13_game.png")
    shutil.copyfile(manifest_path, target / "walk13_sprite_manifest.json")
    pubspec_updated = _register_pubspec_asset(slug)

    logger.info("Published animation for project %s into %s", project_id, target)
    return {
        "character_id": slug,
        "sheet_asset": f"characters/{slug}/walk13_game.png",
        "manifest_asset": f"assets/images/characters/{slug}/walk13_sprite_manifest.json",
        "pubspec_updated": pubspec_updated,
        "note": "Restart the game to pick up a newly registered asset folder."
        if pubspec_updated
        else "Asset folder was already registered.",
    }


@app.get("/api/projects/{project_id}/animation/game-sheet")
def get_animation_game_sheet(project_id: str) -> FileResponse:
    _load_project(project_id)
    path = _project_directory(project_id) / "walk13_game.png"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Game sheet is missing")
    return FileResponse(path, media_type="image/png")


@app.get("/api/projects/{project_id}/motion-reference/contact-sheet")
def get_motion_reference_contact_sheet(project_id: str) -> FileResponse:
    path = _project_directory(project_id) / "motion_stickman" / "motion_stickman_contact.png"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Motion reference contact sheet is missing")
    return FileResponse(path, media_type="image/png")


@app.get("/api/projects/{project_id}/motion-reference/animation.gif")
def get_motion_reference_gif(project_id: str) -> FileResponse:
    path = _project_directory(project_id) / "motion_stickman" / "motion_stickman_13.gif"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Motion reference GIF is missing")
    return FileResponse(path, media_type="image/gif")


@app.get("/api/projects/{project_id}/motion-reference/gif/{animation_name}.gif")
def get_motion_reference_state_gif(project_id: str, animation_name: str) -> FileResponse:
    if not re.fullmatch(r"(?:idle|walk|run)_(?:left|right)|turn", animation_name):
        raise HTTPException(status_code=404, detail="Unknown motion-reference animation")
    path = _project_directory(project_id) / "motion_stickman" / f"motion_stickman_{animation_name}.gif"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Motion-reference state GIF is missing")
    return FileResponse(path, media_type="image/gif")


@app.get("/api/projects/{project_id}/motion-reference/frame/{frame_index}")
def get_motion_reference_frame(project_id: str, frame_index: int) -> FileResponse:
    if not 0 <= frame_index < 13:
        raise HTTPException(status_code=404, detail="Motion-reference frame is out of range")
    filename = f"frame_{frame_index + 1:02d}.png"
    path = _project_directory(project_id) / "motion_stickman" / "motion_stickman_frames" / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Motion-reference frame is missing")
    return FileResponse(path, media_type="image/png")


@app.get("/api/projects/{project_id}/motion-reference/manifest")
def get_motion_reference_manifest(project_id: str) -> FileResponse:
    path = _project_directory(project_id) / "motion_stickman" / "motion_stickman_13.json"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Motion-reference manifest is missing")
    return FileResponse(path, media_type="application/json")


@app.get("/api/projects/{project_id}/motion-reference/player", response_class=HTMLResponse)
def get_motion_reference_player(project_id: str) -> HTMLResponse:
    safe_project_id = _project_directory(project_id).name
    base_url = f"/api/projects/{safe_project_id}/motion-reference"
    page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>13-pose stickman preview</title>
<style>
    :root {{ color-scheme: dark; font: 15px system-ui,sans-serif; background:#141923; color:#f0f3fa; }}
    body {{ margin:0; min-height:100vh; display:grid; place-items:center; }}
    main {{ width:min(680px,92vw); display:grid; gap:16px; }}
    header,nav,.controls {{ display:flex; align-items:center; gap:10px; flex-wrap:wrap; }}
    h1 {{ font-size:20px; margin:0 auto 0 0; }}
    select,button {{ color:inherit; background:#242d3c; border:1px solid #526078; border-radius:6px; padding:8px 12px; }}
    button {{ cursor:pointer; }}
    #stage {{ min-height:360px; display:grid; place-items:center; border:1px solid #394457; background:#0c1017; border-radius:8px; }}
    img {{ width:min(320px,72vw); height:min(320px,72vw); image-rendering:pixelated; object-fit:contain; }}
    #status {{ color:#b6c0d0; min-width:140px; }}
</style>
</head>
<body><main>
    <header><h1>13-pose stickman preview</h1><select id="animation" aria-label="Animation state"></select></header>
    <div id="stage"><img id="frame" alt="Stickman animation frame"></div>
    <nav>
        <button id="previous" type="button">Previous</button>
        <button id="play" type="button">Play</button>
        <button id="next" type="button">Next</button>
        <span id="status" aria-live="polite"></span>
    </nav>
</main>
<script>
const base={json.dumps(base_url)};
const frameImage=document.getElementById('frame');
const selector=document.getElementById('animation');
const status=document.getElementById('status');
let manifest=null, group=null, position=0, timer=null;
function showFrame() {{
    const index=group.frames[position];
    frameImage.src=`${{base}}/frame/${{index}}`;
    const metadata=manifest.frames[index];
    status.textContent=`${{metadata.name}} (${{index+1}}/13)`;
}}
function stop() {{ if(timer) clearInterval(timer); timer=null; document.getElementById('play').textContent='Play'; }}
function setAnimation(name) {{
    stop(); group=manifest.animations[name]; position=0; showFrame();
}}
selector.addEventListener('change',()=>setAnimation(selector.value));
document.getElementById('previous').addEventListener('click',()=>{{ stop(); position=(position+group.frames.length-1)%group.frames.length; showFrame(); }});
document.getElementById('next').addEventListener('click',()=>{{ stop(); position=(position+1)%group.frames.length; showFrame(); }});
document.getElementById('play').addEventListener('click',()=>{{
    if(timer) {{ stop(); return; }}
    document.getElementById('play').textContent='Pause';
    timer=setInterval(()=>{{
        if(position+1>=group.frames.length && !group.loop) {{ showFrame(); stop(); return; }}
        position=(position+1)%group.frames.length; showFrame();
    }},manifest.frame_ms);
}});
fetch(`${{base}}/manifest`).then(response=>{{ if(!response.ok) throw new Error('Manifest unavailable'); return response.json(); }}).then(data=>{{
    manifest=data;
    for(const name of Object.keys(data.animations)) {{ const option=document.createElement('option'); option.value=name; option.textContent=name.replaceAll('_',' '); selector.appendChild(option); }}
    setAnimation(selector.value);
}}).catch(error=>{{ status.textContent=error.message; }});
</script></body></html>"""
    return HTMLResponse(page)


@app.get("/api/projects/{project_id}/animation/geometry-sheet")
def get_geometry_animation_sheet(project_id: str) -> FileResponse:
    project = _load_project(project_id)
    animation = project.get("animation")
    if not animation:
        raise HTTPException(status_code=404, detail="No animation generated")
    path = _project_directory(project_id) / animation["geometry_sheet"]
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Geometry animation sheet is missing")
    return FileResponse(path, media_type="image/png")