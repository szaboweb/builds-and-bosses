# Character Workshop

## Local setup

The workshop runs as three local processes:

1. ComfyUI at `http://127.0.0.1:8188`.
2. The FastAPI workshop service at `http://127.0.0.1:8765`.
3. The Flutter app, which opens the workshop from the sparkle button below the game HUD.

Start `Start ComfyUI (AMD DirectML)` and `Start Character Workshop API` from the VS Code task picker. The API task installs its Python dependencies into the Windows `.venv-2` environment and keeps the service bound to localhost. The WSL `.venv` is not used by this Windows task.

## Required animation model

The repository now contains a separate API-format animation workflow at `assets/ComfyUI_Animation_API.json`. It uses the installed core `ControlNetLoader`, `ControlNetApplyAdvanced`, `ImageBatch`, `ImageFromBatch`, `LatentFromBatch`, `LatentBatch`, `RepeatImageBatch`, `ImageScale`, `VAEEncode`, and `RepeatLatentBatch` nodes plus `ComfyUI_IPAdapter_plus` for reference appearance conditioning. One queue request runs three prompt-conditioned branches (5 right-facing, 3 turning/front, 5 left-facing frames), then merges them back into the original order. AnimateDiff is not required. Both workflows use the non-ancestral `euler` sampler and `normal` scheduler. Node IDs are bound in `tooling/character_workshop/workflow_bindings.json`; startup capability checks remove unavailable optional IP-Adapter/Tile stages and retain the Canny fallback.

Install the SD 1.5 Canny ControlNet checkpoint:

- File: `control_v11p_sd15_canny.pth`
- Download: <https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth?download=true>
- Approximate size: 1.45 GB
- Destination: `C:\Users\mrsza\tools\ComfyUI-directml\models\controlnet\control_v11p_sd15_canny.pth`

Create the `controlnet` directory if needed. Restart ComfyUI after copying the file so its model list refreshes. To use a different compatible SD 1.5 Canny model or another ComfyUI install root, set `CONTROLNET_MODEL` or `COMFYUI_ROOT` in the environment used to start the Character Workshop API.

The installed animation workflow also uses the following SD 1.5 consistency weights:

- IP-Adapter Plus: `models/ipadapter/ip-adapter-plus_sd15.safetensors` (~94 MB), from <https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors?download=true>.
- Matching CLIP-Vision ViT-H: `models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` (~2.35 GB), from <https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors?download=true>.
- Tile ControlNet: `models/controlnet/control_v11f1e_sd15_tile.pth` (~1.34 GB), from <https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1e_sd15_tile.pth?download=true>.

Install the custom nodes into the ComfyUI environment's `custom_nodes` directory: `git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git`. Restart ComfyUI after cloning or adding weights so `/object_info` refreshes. The API activates IP-Adapter only when its node classes and both model files are present; it activates Tile only when the Tile weight and core nodes are available. Either optional stage falls back cleanly to Canny pose control. The IP-Adapter Plus repository is in maintenance mode; this setup was verified with the installed ComfyUI 0.3.27 build.

There is currently about 2 GB of free system RAM reported by Windows. Before the first batch render, close memory-heavy apps and check that the RX 6600 is selected in the ComfyUI startup log. The DirectML ComfyUI VRAM display is hard-coded to 1 GB in this installed build; it is not a physical-memory reading. The animation batch renders at 32x32 pixels (13 images at once) to match the game's authoritative character canvas (see `docs/MOVEMENT_AND_TUI_GUIDE.md`); this was verified against the installed SD 1.5 checkpoint with a live smoke test and completed without shape/latent errors.

## Reproducibility

The Windows ComfyUI launcher uses `--disable-xformers --deterministic`. These reduce known sources of variation but do not promise bit-identical output across GPU drivers, PyTorch/DirectML versions, or hardware; the project's versioned workflow, model name, integer seed, and sampler settings are also stored with each generation.

- The project gets one unsigned 32-bit seed when created if the user leaves the seed blank. It is persisted before the concept request, and animation reuses that same seed. A seed of `-1`, `null`, or an out-of-range value is never sent to a KSampler.
- If the seed is changed, existing approved image and animation outputs are invalidated so they cannot be mistaken for products of the new seed.
- Backend-enforced settings: `sampler_name=euler`, `scheduler=normal`, `steps=20`, `cfg=8`; concept `denoise=1.0`, animation `denoise=0.38`.
- The 13 masks are packed into one image batch and sliced into ordered 5/3/5 groups. `RepeatLatentBatch` repeats the approved reference latent; it has no seed input. The three KSamplers use deterministic seeds derived from the project seed plus each group's starting frame index; all are recorded in generation metadata.
- A live repeat-run smoke test on the installed RX 6600 DirectML stack rendered a synthetic 13-frame batch twice with identical inputs/settings/seed; all 13 decoded RGBA frames matched pixel-for-pixel. This is a verified baseline for this exact local stack, not a cross-version or cross-hardware guarantee.
- Exact pixel equality is only expected when model/checkpoint, workflow, prompt, settings, software versions, device, and deterministic-kernel behavior match. DirectML may still use nondeterministic kernels, so across stack changes this is reproducible configuration, not a mathematical guarantee of identical pixels.

## Job Progress and Sprite QC

Prompt submission opens a ComfyUI WebSocket with a per-job `client_id`. Sampler `progress`, node execution and terminal events feed the existing `/api/projects/{id}/jobs/{prompt_id}` response, which the Flutter workshop polls to show sampling progress. REST `/history` remains authoritative for final outputs; if the WebSocket is unavailable, submission continues and the client falls back to status polling.

The named 13-pose sequence includes alternating walk and run strides, right-to-front/left turns, and left/right idle poses. Aseprite shifts the arms and legs visibly and folds the leading run leg while preserving opaque pixel mass; the front pose changes torso proportions without changing area. The 13 composited frames are quantized against one 32-color palette sampled from the approved concept. Their geometry alpha masks are reapplied after quantization, so palette locking cannot change the silhouette. QC requires at least eight distinct silhouettes, alternating walk/run silhouettes, distinct facing/turn poses, 32x32 dimensions, exact alpha-mask equality, row-31 foot anchoring, and the shared palette limit. `walk13_quality.json` records each named pose's bounds, opaque-pixel count, palette size and pixel hash, plus palette coverage and duplicate-frame diagnostics. `walk13_contact_sheet.png` labels poses in a nearest-neighbor 4x4 review sheet.

`walk13_sprite_manifest.json` exposes the runtime atlas layout (`cols`, `rows`, `cell_w`, `cell_h`), 100 ms frame duration, alpha flag, per-frame `[x, y, width, height]` rectangles, and separate `animations` groups for idle, walk, run and the one-shot turn. Each group lists zero-based frame indices and its own loop flag, so a loader does not play the mixed atlas as one long animation. The left/right variants are pre-rendered in this atlas. The manifest is available at `/api/projects/{id}/animation/manifest`; the contact sheet and QC report are at `/api/projects/{id}/animation/contact-sheet` and `/api/projects/{id}/animation/quality`.

The workshop exports these runtime-ready assets into the local project folder only. The current game `PlayerComponent` still loads the bundled `fighter_32.png` first frame and does not yet consume a workshop manifest; publishing a generated character into gameplay remains an explicit integration step.

## Consistency Controls

The Windows ComfyUI install uses core `LoraLoader` and `ConditioningSetArea`, IP-Adapter Plus, SD 1.5 Canny, and SD 1.5 Tile controls.

- IP-Adapter Plus conditions the animation model on the approved concept image. It improves appearance similarity, but is not a pixel lock; the direct 32x32 output and reference scaling limit how much face detail it can preserve.
- A project may select a trained SD 1.5 character LoRA filename in the workshop. It must already exist in ComfyUI's `models/loras` folder. No generic LoRA is bundled: character-specific training requires a curated image set, and the selected LoRA name is recorded with the seed/settings.
- The concept workflow uses core `ConditioningSetArea` to keep positive character prompting within a centered canvas region. The separate Regional Prompter custom pack is not installed; it is unnecessary for this single centered concept region. The core node has a 64-pixel minimum region, so it cannot divide the 32x32 animation canvas into meaningful prompt zones. Neither this conditioning nor Regional Prompter would physically guarantee an empty background; the Aseprite alpha-mask composite is the hard silhouette/empty-background constraint.
- Tile ControlNet receives the approved image slice for each 5/3/5 branch at low strength, after that branch's per-pose Canny ControlNet. Canny control images include a small facing-direction marker outside the character mask. Tile can stabilize local texture cues but may also resist pose changes; separate prompts and markers still do not synchronize adjacent frames or remove temporal flicker.

The IP-Adapter and Tile stages are capability-checked through ComfyUI's `/object_info` API and model folders. Missing optional nodes or weights are omitted from the submitted graph, preserving the existing Canny-only path.

## Workflow

1. Create a character project and write the subject, view/orientation, height class (short/average/tall), fixed transparent background, head/hairstyle/beard/helmet, upper body, lower body, left-hand item, right-hand item, palette, style tags, and negative prompt. Each hand accepts an item description or `empty`; an empty hand receives an explicit positive constraint plus a matching negative-prompt exclusion. The model is told which item belongs to the character's anatomical left/right hand, independently of image orientation. All structured fields are combined into the final prompt by `_compose_prompt()` in `tooling/character_workshop/server.py`. Legacy projects using `held_item` only are mapped to the right hand when reopened.
2. Height class also selects the starting Aseprite rig geometry from `server.HEIGHT_RIGS` (`short` = dwarf-like stocky proportions, `average` = human proportions, `tall` = elf-like slender proportions). Each rig is validated to stay inside the 32x32 canvas, keep both feet on row 31, and avoid part overlaps across all 13 walk/run/turn/front poses.
3. Generate a concept. The project stores its generation seed and ComfyUI job history. The concept prompt always requests a flat magenta key background (never a scene, animal, prop, or piece of furniture; see `BACKGROUND_NEGATIVE_TERMS`); the service then force-flattens the corner-connected background to transparent alpha with `_flatten_background()`. Background color is not user-configurable: every character concept is delivered with a transparent background for in-game compositing.
4. Review and explicitly approve a candidate. The approved image (with background alpha already removed) is kept as the character reference.
5. Edit the Aseprite rig JSON if desired for further fine-tuning. The rig defines six non-overlapping rectangles on a 32x32 canvas; both legs must touch canvas row 31, matching the game's character sprite baseline.
6. Render the animation. Aseprite generates the named 13-pose idle/walk/run/turn/front sequence. The service extracts their alpha masks, uploads the approved reference and 13 control images to ComfyUI, then submits one graph with separate right/turn/left prompts, controls and KSamplers for the 5/3/5 frame groups. The outputs are merged in sequence order. IP-Adapter and low-strength Tile ControlNet are applied per group when their required nodes/models are available; otherwise all groups fall back to Canny pose control. A selected character LoRA is applied to both concept and animation. The workflow uses placeholders in `assets/ComfyUI_Animation_API.json` bound by `tooling/character_workshop/workflow_bindings.json`.
7. The generated images are composited through the original Aseprite alpha masks, quantized to the approved reference's shared 32-color palette, and checked by the QC gate. The editable geometric `.aseprite` source, rendered sheet, contact sheet, quality report, and runtime frame manifest are saved under the local character project directory.

Projects are stored under `%LOCALAPPDATA%\BuildsAndBosses\CharacterWorkshop\projects\<project-id>`. They are not automatically published into the game's bundled runtime assets, but the rendered 32x32 sprite sheet now matches `app/assets/images/characters/fighter_32.png` in frame size, so publishing no longer requires a resize step.

## Current limits

The approved concept, IP-Adapter, Tile ControlNet, optional character LoRA, fixed seed and common palette improve consistency but none guarantees bit-identical textures or eliminates flicker. Palette locking can simplify fine shading to the selected 32 colors. ControlNet constrains pose images; it is not a temporal diffusion model. DirectML has about 2 GB free system RAM in the current environment, so the additional 2.35 GB CLIP-Vision and 1.34 GB Tile weights may increase paging or render time. The final Aseprite alpha composite still guarantees the exact silhouette and transparent pixels. The current Aseprite rig is a block-in and is not automatically inferred from the concept image.
