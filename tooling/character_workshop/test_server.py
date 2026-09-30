import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from io import BytesIO
from unittest.mock import patch

from fastapi import HTTPException
from PIL import Image, ImageDraw
from pydantic import ValidationError

import server

CANVAS = server.CHARACTER_CANVAS_SIZE
import generate_stickman13


def _find_aseprite() -> str | None:
    candidate = shutil.which("aseprite") or r"C:\Program Files\Aseprite\Aseprite.exe"
    return candidate if Path(candidate).is_file() else None


class AnimationWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(__file__).resolve().parents[2]
        self.bindings = json.loads(
            (self.root / "tooling/character_workshop/workflow_bindings.json").read_text()
        )
        self.base_workflow = json.loads(
            (self.root / self.bindings["animation_workflow_path"]).read_text()
        )

    def test_checked_in_workflows_use_non_ancestral_sampler_and_fixed_settings(self):
        for workflow_path in (self.bindings["workflow_path"], self.bindings["animation_workflow_path"]):
            workflow = json.loads((self.root / workflow_path).read_text())
            samplers = [node["inputs"] for node in workflow.values() if node["class_type"] == "KSampler"]
            self.assertTrue(samplers, workflow_path)
            for inputs in samplers:
                self.assertEqual(inputs["sampler_name"], "euler")
                self.assertEqual(inputs["scheduler"], "normal")
                self.assertEqual(inputs["steps"], 20)
                self.assertEqual(inputs["cfg"], 8)

            concept = json.loads((self.root / self.bindings["workflow_path"]).read_text())
            self.assertEqual(concept["5"]["inputs"]["positive"], ["8", 0])
            self.assertEqual(concept["8"]["class_type"], "ConditioningSetArea")

            animation = json.loads((self.root / self.bindings["animation_workflow_path"]).read_text())
            self.assertEqual(animation["5"]["inputs"]["model"], ["41", 0])
            self.assertEqual(animation["39"]["class_type"], "IPAdapterModelLoader")
            self.assertEqual(animation["41"]["class_type"], "IPAdapterAdvanced")
            self.assertEqual(animation["42"]["inputs"]["amount"], 13)
            self.assertEqual(animation["43"]["inputs"]["control_net_name"], server.TILE_CONTROLNET_MODEL)
            self.assertEqual(animation["45"]["class_type"], "CLIPTextEncode")
            self.assertEqual(animation["46"]["class_type"], "CLIPTextEncode")
            self.assertEqual(animation["47"]["class_type"], "CLIPTextEncode")
            self.assertEqual(animation["48"]["inputs"]["length"], 5)
            self.assertEqual(animation["49"]["inputs"]["length"], 3)
            self.assertEqual(animation["50"]["inputs"]["length"], 5)
            for node_id in self.bindings["animation_nodes"]["samplers"]:
                self.assertEqual(animation[node_id]["class_type"], "KSampler")
            self.assertEqual(animation["66"]["class_type"], "LatentBatch")
            self.assertEqual(animation["67"]["class_type"], "LatentBatch")
            self.assertEqual(animation["48"]["inputs"]["batch_index"], 0)
            self.assertEqual(animation["49"]["inputs"]["batch_index"], 5)
            self.assertEqual(animation["50"]["inputs"]["batch_index"], 8)
            self.assertEqual(animation["66"]["inputs"]["samples1"], ["5", 0])
            self.assertEqual(animation["66"]["inputs"]["samples2"], ["64", 0])
            self.assertEqual(animation["67"]["inputs"]["samples1"], ["66", 0])
            self.assertEqual(animation["67"]["inputs"]["samples2"], ["65", 0])
            self.assertEqual(animation["6"]["inputs"]["samples"], ["67", 0])
            node_ids = set(animation)
            for node in animation.values():
                for value in node.get("inputs", {}).values():
                    if isinstance(value, list) and len(value) == 2 and isinstance(value[0], str):
                        self.assertIn(value[0], node_ids)

    def test_stickman_generator_outputs_thirteen_frame_transparent_gif(self):
        with tempfile.TemporaryDirectory() as temporary:
            output_dir = Path(temporary)
            manifest = generate_stickman13.generate(output_dir)
            gif_path = output_dir / manifest["gif"]

            with Image.open(gif_path) as animation:
                self.assertEqual(animation.size, (server.CHARACTER_CANVAS_SIZE, server.CHARACTER_CANVAS_SIZE))
                self.assertEqual(animation.n_frames, 13)
                self.assertEqual(animation.info.get("duration"), 100)
                self.assertNotIn("loop", animation.info)
                self.assertIsNotNone(animation.info.get("transparency"))

            walk_gif = output_dir / manifest["group_gifs"]["walk_right"]
            with Image.open(walk_gif) as animation:
                self.assertEqual(animation.n_frames, 2)
                self.assertEqual(animation.info.get("loop"), 0)

            self.assertEqual(len(list((output_dir / "motion_stickman_frames").glob("frame_*.png"))), 13)

    def test_stickman_gait_pairs_keep_facing_direction_visible(self):
        poses = server.POSE_SEQUENCE
        for index in (1, 2, 3, 4):
            pose = poses[index]
            self.assertEqual(pose["facing"], "right")
            points = generate_stickman13._side_pose(
                pose["kind"], pose["phase"], pose["facing"]
            )
            self.assertGreater(points["nose"][0], points["head"][0])
            if pose["phase"] > 0:
                self.assertGreater(points["left_foot"][0], points["right_foot"][0])
            else:
                self.assertLess(points["left_foot"][0], points["right_foot"][0])
            image = generate_stickman13._draw_pose(pose)
            self.assertEqual(image.getpixel(points["nose"]), generate_stickman13.INK)

        for index in (8, 9, 10, 11, 12):
            pose = poses[index]
            self.assertEqual(pose["facing"], "left")
            points = generate_stickman13._side_pose(
                pose["kind"], pose["phase"], pose["facing"]
            )
            self.assertLess(points["nose"][0], points["head"][0])
            if pose["kind"] in {"walk", "run"}:
                if pose["phase"] > 0:
                    self.assertLess(points["left_foot"][0], points["right_foot"][0])
                else:
                    self.assertGreater(points["left_foot"][0], points["right_foot"][0])
            image = generate_stickman13._draw_pose(pose)
            self.assertEqual(image.getpixel(points["nose"]), generate_stickman13.INK)

    def test_generate_request_rejects_minus_one_seed(self):
        with self.assertRaises(ValidationError):
            server.GenerateRequest(seed=-1)

    def test_compose_prompt_includes_structured_body_fields(self):
        prompt = server._compose_prompt({
            "subject": "dwarven knight",
            "view": "side view, facing right",
            "head": "horned steel helmet",
            "upper_body": "riveted breastplate",
            "lower_body": "leather greaves",
            "held_item": "a warhammer",
            "palette": "steel and crimson",
            "style_tags": "16-bit JRPG sprite",
            "positive_prompt": "battle scars",
        })
        self.assertIn("dwarven knight", prompt)
        self.assertIn("side view, facing right", prompt)
        self.assertIn("horned steel helmet", prompt)
        self.assertIn("riveted breastplate", prompt)
        self.assertIn("leather greaves", prompt)
        self.assertIn("character holds exactly a warhammer in their own right hand", prompt)
        self.assertIn("steel and crimson color palette", prompt)
        self.assertIn("16-bit JRPG sprite", prompt)
        self.assertIn("battle scars", prompt)

    def test_compose_prompt_assigns_each_hand_independently(self):
        prompt = server._compose_prompt({
            "subject": "wizard",
            "left_hand": "magic wand",
            "right_hand": "empty",
        })
        self.assertIn("character holds exactly magic wand in their own left hand", prompt)
        self.assertIn("character's own right hand is empty, visibly unoccupied", prompt)
        self.assertNotIn("holding magic wand in their own right hand", prompt)

    def test_negative_prompt_forbids_objects_in_explicitly_empty_hand(self):
        negative = server._compose_negative_prompt({
            "left_hand": "magic wand",
            "right_hand": "empty",
        })
        self.assertIn("object in the character's empty right hand", negative)
        self.assertNotIn("object in the character's empty left hand", negative)

    def test_legacy_held_item_maps_to_right_hand(self):
        prompt = server._compose_prompt({"subject": "wizard", "held_item": "magic wand"})
        self.assertIn("character holds exactly magic wand in their own right hand", prompt)
        self.assertIn("character's own left hand is empty", prompt)

    def test_project_creation_persists_both_hand_assignments(self):
        request = server.ProjectCreate(
            name="wizard",
            subject="wizard",
            left_hand="empty",
            right_hand="magic wand",
        )
        with patch.object(server, "_save_project") as save_project:
            project = server.create_project(request)

        self.assertEqual(project["left_hand"], "empty")
        self.assertEqual(project["right_hand"], "magic wand")
        self.assertIs(type(project["seed"]), int)
        self.assertGreaterEqual(project["seed"], 0)
        self.assertLessEqual(project["seed"], server.MAX_GENERATION_SEED)
        save_project.assert_called_once_with(project)

    def test_project_creation_migrates_legacy_held_item_to_right_hand(self):
        request = server.ProjectCreate(
            name="legacy wizard",
            subject="wizard",
            held_item="magic wand",
        )
        with patch.object(server, "_save_project"):
            project = server.create_project(request)

        self.assertEqual(project["left_hand"], "empty")
        self.assertEqual(project["right_hand"], "magic wand")

    def test_compose_prompt_never_hints_at_a_reference_sheet(self):
        prompt = server._compose_prompt({"subject": "hero"})
        self.assertNotIn("reference sheet", prompt)
        negative = server._compose_negative_prompt({})
        self.assertIn("reference sheet", negative)
        self.assertIn("character sheet", negative)
        self.assertIn("multiple views", negative)
        self.assertIn("color palette swatches", negative)

    def test_compose_prompt_always_states_solo_single_pose(self):
        prompt = server._compose_prompt({"subject": "hero"})
        self.assertIn("solo, exactly one character, one pose only", prompt)

    def test_compose_prompt_weights_the_view_instruction(self):
        prompt = server._compose_prompt({"subject": "hero", "view": "facing right"})
        self.assertIn("(facing right:1.3)", prompt)

    def test_compose_prompt_falls_back_to_default_view_when_blank(self):
        prompt = server._compose_prompt({"subject": "villager", "view": ""})
        self.assertIn("side view, facing right, centered on a plain background", prompt)
        self.assertIn("villager", prompt)

    def test_compose_prompt_includes_height_class_phrase(self):
        for height_class, expected in server.HEIGHT_PHRASES.items():
            prompt = server._compose_prompt({"subject": "hero", "height_class": height_class})
            self.assertIn(expected, prompt)

    def test_compose_prompt_defaults_to_average_height_when_missing(self):
        prompt = server._compose_prompt({"subject": "hero"})
        self.assertIn(server.HEIGHT_PHRASES["average"], prompt)

    def test_compose_prompt_includes_hairstyle_beard_and_helmet(self):
        with_all = server._compose_prompt({
            "subject": "hero",
            "hairstyle": "long silver braid",
            "has_beard": True,
            "has_helmet": True,
        })
        self.assertIn("long silver braid", with_all)
        self.assertIn("with a beard", with_all)
        self.assertIn("wearing a helmet", with_all)

        without_any = server._compose_prompt({"subject": "hero"})
        self.assertIn("clean-shaven, no beard", without_any)
        self.assertIn("no helmet, bare head", without_any)

    def test_compose_prompt_always_uses_transparent_background(self):
        for background in ("transparent", "white", "black", "", None):
            prompt = server._compose_prompt({"subject": "hero", "background": background})
            self.assertIn(server.BACKGROUND_PHRASES["transparent"], prompt)
            self.assertNotIn(server.BACKGROUND_PHRASES["white"], prompt)
            self.assertNotIn(server.BACKGROUND_PHRASES["black"], prompt)

    def test_compose_prompt_defaults_to_transparent_background_when_missing(self):
        prompt = server._compose_prompt({"subject": "hero"})
        self.assertIn(server.BACKGROUND_PHRASES["transparent"], prompt)

    def test_compose_negative_prompt_always_includes_background_terms(self):
        negative = server._compose_negative_prompt({"negative_prompt": "extra fingers"})
        self.assertIn(server.BACKGROUND_NEGATIVE_TERMS, negative)
        self.assertIn("extra fingers", negative)

    def test_compose_negative_prompt_excludes_creatures_props_and_furniture(self):
        negative = server._compose_negative_prompt({})
        for term in ("animals", "pets", "companions", "magical creatures", "objects", "furniture"):
            self.assertIn(term, negative)

    def test_compose_negative_prompt_works_without_user_negative(self):
        negative = server._compose_negative_prompt({})
        self.assertIn(server.BACKGROUND_NEGATIVE_TERMS, negative)
        self.assertIn("object in the character's empty left hand", negative)
        self.assertIn("object in the character's empty right hand", negative)

    def test_background_schema_rejects_nontransparent_modes(self):
        with self.assertRaises(ValidationError):
            server.ProjectCreate(name="hero", subject="hero", background="white")
        with self.assertRaises(ValidationError):
            server.ProjectUpdate(background="black")

    def test_apply_background_mode_always_flattens_to_transparent(self):
        raw = self._make_magenta_square_png()
        result = server._apply_background_mode(raw)
        image = Image.open(BytesIO(result)).convert("RGBA")
        self.assertEqual(image.getpixel((0, 0))[3], 0)

    def test_flatten_background_makes_transparent(self):
        raw = self._make_magenta_square_png()
        flattened = server._flatten_background(raw, "transparent")
        image = Image.open(BytesIO(flattened)).convert("RGBA")
        self.assertEqual(image.getpixel((0, 0))[3], 0)
        self.assertEqual(image.getpixel((15, 15))[3], 255)
        self.assertEqual(image.getpixel((15, 15))[:3], (30, 60, 200))

    def test_flatten_background_flattens_to_solid_white(self):
        raw = self._make_magenta_square_png()
        flattened = server._flatten_background(raw, "white")
        image = Image.open(BytesIO(flattened)).convert("RGBA")
        self.assertEqual(image.getpixel((0, 0)), (255, 255, 255, 255))
        self.assertEqual(image.getpixel((15, 15))[:3], (30, 60, 200))

    def test_flatten_background_flattens_to_solid_black(self):
        raw = self._make_magenta_square_png()
        flattened = server._flatten_background(raw, "black")
        image = Image.open(BytesIO(flattened)).convert("RGBA")
        self.assertEqual(image.getpixel((0, 0)), (0, 0, 0, 255))
        self.assertEqual(image.getpixel((15, 15))[:3], (30, 60, 200))

    @staticmethod
    def _make_magenta_square_png() -> bytes:
        image = Image.new("RGB", (CANVAS, CANVAS), (255, 0, 255))
        draw = ImageDraw.Draw(image)
        draw.rectangle((10, 10, 20, 25), fill=(30, 60, 200))
        buffer = BytesIO()
        image.save(buffer, format="PNG")
        return buffer.getvalue()

    def test_control_direction_markers_stay_outside_alpha_masks(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            sheet = Image.new("RGBA", (CANVAS * 13, CANVAS), (0, 0, 0, 0))
            for index in range(13):
                frame = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
                ImageDraw.Draw(frame).rectangle((10, 10, 20, 25), fill=(30, 60, 200, 255))
                sheet.paste(frame, (index * CANVAS, 0))
            sheet_path = directory / "sheet.png"
            sheet.save(sheet_path)

            paths, alpha_masks = server._make_control_masks(sheet_path, directory)

            with Image.open(paths[0]) as right_control:
                self.assertEqual(right_control.getpixel((1, 2)), (255, 255, 255))
            with Image.open(paths[7]) as left_control:
                self.assertEqual(left_control.getpixel((30, 2)), (255, 255, 255))
            with Image.open(paths[6]) as front_control:
                self.assertEqual(front_control.getpixel((1, 1)), (255, 255, 255))
            self.assertEqual(alpha_masks[0].getpixel((1, 2)), 0)
            self.assertEqual(alpha_masks[7].getpixel((30, 2)), 0)
            self.assertEqual(alpha_masks[6].getpixel((1, 1)), 0)

    def test_builds_thirteen_pose_control_batch(self):
        workflow = server._build_animation_workflow(
            self.base_workflow,
            self.bindings["animation_nodes"],
            "control_v11p_sd15_canny.pth",
            server.TILE_CONTROLNET_MODEL,
            [f"poses/pose_{index:02d}.png" for index in range(1, 14)],
            "poses/approved.png",
            {
                "subject": "test hero",
                "positive_prompt": "blue pixel armor",
                "negative_prompt": "blur",
                "seed": 123,
            },
            "renders/frame",
        )

        self.assertEqual(
            sum(node["class_type"] == "ImageBatch" for node in workflow.values()),
            12,
        )
        self.assertEqual(workflow["4"]["inputs"]["batch_size"], 13)
        self.assertEqual(workflow["5"]["inputs"]["seed"], 123)
        self.assertEqual(workflow["64"]["inputs"]["seed"], 128)
        self.assertEqual(workflow["65"]["inputs"]["seed"], 131)
        for sampler_id in self.bindings["animation_nodes"]["samplers"]:
            sampler = workflow[sampler_id]["inputs"]
            self.assertEqual(sampler["sampler_name"], "euler")
            self.assertEqual(sampler["scheduler"], "normal")
            self.assertEqual(sampler["steps"], 20)
            self.assertEqual(sampler["cfg"], 8.0)
            self.assertEqual(sampler["denoise"], 0.38)
            self.assertEqual(sampler["model"], ["41", 0])
        self.assertEqual(workflow["5"]["inputs"]["positive"], ["60", 0])
        self.assertEqual(workflow["64"]["inputs"]["positive"], ["61", 0])
        self.assertEqual(workflow["65"]["inputs"]["positive"], ["62", 0])
        self.assertEqual(workflow["41"]["inputs"]["image"], ["34", 0])
        self.assertEqual(workflow["42"]["inputs"]["amount"], 13)
        self.assertEqual(workflow["45"]["inputs"]["text"].find("facing right") >= 0, True)
        self.assertIn("turn from right-facing", workflow["46"]["inputs"]["text"])
        self.assertIn("facing left", workflow["47"]["inputs"]["text"])
        self.assertEqual(workflow["60"]["inputs"]["strength"], server.TILE_CONTROL_STRENGTH)
        self.assertEqual(workflow["57"]["inputs"]["image"], ["51", 0])
        self.assertEqual(workflow["58"]["inputs"]["image"], ["52", 0])
        self.assertEqual(workflow["59"]["inputs"]["image"], ["53", 0])
        node_ids = set(workflow)
        links = (
            value
            for node in workflow.values()
            for value in node.get("inputs", {}).values()
            if isinstance(value, list)
            and len(value) == 2
            and isinstance(value[0], str)
        )
        self.assertTrue(all(target in node_ids for target, _ in links))

    def test_ensure_project_seed_preserves_valid_seed(self):
        project = {"seed": 0}
        self.assertEqual(server._ensure_project_seed(project), 0)
        self.assertEqual(project["seed"], 0)

    def test_animation_builder_removes_missing_optional_consistency_nodes(self):
        workflow = server._build_animation_workflow(
            self.base_workflow,
            self.bindings["animation_nodes"],
            server.CONTROLNET_MODEL,
            server.TILE_CONTROLNET_MODEL,
            [f"poses/pose_{index:02d}.png" for index in range(1, 14)],
            "poses/approved.png",
            {"subject": "test hero", "negative_prompt": "cat", "seed": 123},
            "renders/frame",
            use_ipadapter=False,
            use_tile=False,
        )

        for sampler_id, canny_id in zip(
            self.bindings["animation_nodes"]["samplers"],
            self.bindings["animation_nodes"]["canny_applies"],
            strict=True,
        ):
            self.assertEqual(workflow[sampler_id]["inputs"]["model"], ["1", 0])
            self.assertEqual(workflow[sampler_id]["inputs"]["positive"], [canny_id, 0])
            self.assertEqual(workflow[sampler_id]["inputs"]["negative"], [canny_id, 1])
        self.assertNotIn("39", workflow)
        self.assertNotIn("40", workflow)
        self.assertNotIn("41", workflow)
        for node_id in ("42", "43", "54", "55", "56", "60", "61", "62"):
            self.assertNotIn(node_id, workflow)
        for node in workflow.values():
            for value in node.get("inputs", {}).values():
                if isinstance(value, list) and len(value) == 2 and isinstance(value[0], str):
                    self.assertIn(value[0], workflow)

    def test_ensure_project_seed_replaces_null_and_negative(self):
        for invalid in (None, -1, 4294967296, "not-a-seed"):
            project = {"seed": invalid, "id": "seed-test"}
            with patch.object(server.secrets, "randbits", return_value=987654321):
                self.assertEqual(server._ensure_project_seed(project), 987654321)
            self.assertEqual(project["seed"], 987654321)

    def test_concept_generation_forces_fixed_sampler_settings(self):
        project = {
            "id": "concept-test",
            "subject": "wizard",
            "positive_prompt": "blue robe",
            "negative_prompt": "blur",
            "seed": 24680,
            "candidates": [],
            "background": "transparent",
        }
        workflow = json.loads((self.root / self.bindings["workflow_path"]).read_text())
        captured = {}
        def queue_workflow(graph):
            captured["prompt"] = graph
            return {"prompt_id": "job-1"}

        with (
            patch.object(server, "_load_project", return_value=project),
            patch.object(server, "_load_workflow_config", return_value=(workflow, self.bindings["nodes"])),
            patch.object(server, "_queue_comfy_workflow", side_effect=queue_workflow),
            patch.object(server, "_save_project"),
        ):
            result = server.generate_candidate("concept-test", server.GenerateRequest())

        sampler = captured["prompt"][self.bindings["nodes"]["sampler"]]["inputs"]
        self.assertEqual(result["seed"], 24680)
        self.assertEqual(sampler["seed"], 24680)
        self.assertEqual(sampler["sampler_name"], "euler")
        self.assertEqual(sampler["scheduler"], "normal")
        self.assertEqual(sampler["steps"], 20)
        self.assertEqual(sampler["cfg"], 8.0)
        self.assertEqual(sampler["denoise"], server.CONCEPT_DENOISE)

    def test_comfy_websocket_records_steps_then_completion(self):
        class FakeSocket:
            def __init__(self):
                self.messages = iter([
                    json.dumps({"type": "progress", "data": {
                        "prompt_id": "ws-progress-test", "value": 7, "max": 20,
                    }}),
                    json.dumps({"type": "executing", "data": {
                        "prompt_id": "ws-progress-test", "node": "5",
                    }}),
                    json.dumps({"type": "executing", "data": {
                        "prompt_id": "ws-progress-test", "node": None,
                    }}),
                ])
                self.closed = False

            def recv(self):
                return next(self.messages)

            def close(self):
                self.closed = True

        connection = FakeSocket()
        server._watch_comfy_job(connection, "ws-progress-test")
        progress = server._get_job_progress("ws-progress-test")

        self.assertEqual(progress["status"], "completed")
        self.assertEqual(progress["fraction"], 1.0)
        self.assertTrue(connection.closed)

    def test_queue_comfy_workflow_connects_client_id_and_starts_tracker(self):
        class FakeSocket:
            def settimeout(self, timeout):
                self.timeout = timeout

            def close(self):
                pass

        connection = FakeSocket()
        with (
            patch.object(server.websocket, "create_connection", return_value=connection) as connect,
            patch.object(server, "_request_json", return_value={"prompt_id": "queued-ws-test"}) as request,
            patch.object(server.threading, "Thread") as thread_factory,
        ):
            result = server._queue_comfy_workflow({"5": {"class_type": "KSampler"}})

        self.assertEqual(result["prompt_id"], "queued-ws-test")
        client_id = request.call_args.args[1]["client_id"]
        self.assertIn(client_id, connect.call_args.args[0])
        self.assertEqual(server._get_job_progress("queued-ws-test")["status"], "queued")
        thread_factory.return_value.start.assert_called_once()

    def test_queue_comfy_workflow_falls_back_when_websocket_is_unavailable(self):
        with (
            patch.object(
                server.websocket,
                "create_connection",
                side_effect=server.websocket.WebSocketException("socket unavailable"),
            ),
            patch.object(server, "_request_json", return_value={"prompt_id": "rest-fallback-test"}),
        ):
            result = server._queue_comfy_workflow({"5": {"class_type": "KSampler"}})

        self.assertEqual(result["prompt_id"], "rest-fallback-test")
        self.assertEqual(server._get_job_progress("rest-fallback-test")["status"], "queued")

    def test_job_status_exposes_live_websocket_progress(self):
        project = {
            "candidates": [{"prompt_id": "live-job", "status": "queued", "images": []}],
        }
        progress = {"status": "running", "step": 4, "total": 20, "fraction": 0.2}
        with (
            patch.object(server, "_load_project", return_value=project),
            patch.object(server, "_history_entry", return_value=None),
            patch.object(server, "_get_job_progress", return_value=progress),
        ):
            result = server.get_job("project-id", "live-job")

        self.assertEqual(result["status"], "running")
        self.assertEqual(result["progress"]["fraction"], 0.2)

    def test_animation_quality_report_checks_masks_and_writes_contact_sheet(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            frame_files = []
            alpha_masks = []
            for index in range(13):
                alpha = Image.new("L", (CANVAS, CANVAS), 0)
                ImageDraw.Draw(alpha).rectangle((5 + index % 5, 4 + index, 12 + index % 5, CANVAS - 1), fill=255)
                frame = Image.new("RGBA", (CANVAS, CANVAS), (60, 100, 180, 255))
                frame.putalpha(alpha)
                filename = f"rendered_{index + 1:02d}.png"
                frame.save(directory / filename)
                frame_files.append(filename)
                alpha_masks.append(alpha)

            report = server._write_animation_quality_report(frame_files, alpha_masks, directory)

            self.assertTrue(report["passed"])
            self.assertTrue(all(report["checks"].values()))
            self.assertEqual(report["palette"]["unique_colors"], 1)
            self.assertTrue((directory / report["contact_sheet"]).is_file())
            self.assertTrue((directory / report["manifest_file"]).is_file())
            sprite_manifest = json.loads(
                (directory / report["sprite_manifest_file"]).read_text()
            )
            self.assertEqual(sprite_manifest["type"], "character_animations")
            self.assertEqual(
                sprite_manifest["animations"],
                server.ANIMATION_GROUPS,
            )
            covered_indices = [
                frame_index
                for name, animation in sprite_manifest["animations"].items()
                if name != "showcase_loop"
                for frame_index in animation["frames"]
            ]
            self.assertEqual(sorted(covered_indices), list(range(13)))
            showcase_loop = sprite_manifest["animations"]["showcase_loop"]
            self.assertTrue(showcase_loop["loop"])
            self.assertTrue(set(showcase_loop["frames"]).issubset(set(range(13))))
            self.assertEqual(showcase_loop["frames"][0], showcase_loop["frames"][9])
            self.assertEqual(sprite_manifest["frame_ms"], 100)
            self.assertTrue(sprite_manifest["alpha"])
            self.assertEqual(
                sprite_manifest["frames"][12]["rect"],
                [12 * server.GAME_CANVAS_SIZE, 0, server.GAME_CANVAS_SIZE, server.GAME_CANVAS_SIZE],
            )
            self.assertEqual(sprite_manifest["frames"][1]["pose"], "walk_right_1")
            self.assertEqual(sprite_manifest["frames"][3]["kind"], "run")

    def test_animation_quality_gate_rejects_alpha_mask_drift(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            frame_files = []
            alpha_masks = []
            for index in range(13):
                mask = Image.new("L", (CANVAS, CANVAS), 0)
                ImageDraw.Draw(mask).rectangle((8, 8, 15, CANVAS - 1), fill=255)
                frame = Image.new("RGBA", (CANVAS, CANVAS), (60, 100, 180, 255))
                frame.putalpha(mask.copy())
                if index == 0:
                    frame.putpixel((4, 4), (60, 100, 180, 255))
                filename = f"rendered_{index + 1:02d}.png"
                frame.save(directory / filename)
                frame_files.append(filename)
                alpha_masks.append(mask)

            with self.assertRaises(HTTPException) as error:
                server._write_animation_quality_report(frame_files, alpha_masks, directory)

        self.assertEqual(error.exception.status_code, 502)
        self.assertIn("alpha_matches_geometry_masks", error.exception.detail)

    def test_animation_quality_gate_rejects_static_frames_without_movement(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            mask = Image.new("L", (CANVAS, CANVAS), 0)
            ImageDraw.Draw(mask).rectangle((8, 6, 15, CANVAS - 1), fill=255)
            frame = Image.new("RGBA", (CANVAS, CANVAS), (60, 100, 180, 255))
            frame.putalpha(mask)
            frame_files = []
            alpha_masks = []
            for index in range(13):
                filename = f"rendered_{index + 1:02d}.png"
                frame.save(directory / filename)
                frame_files.append(filename)
                alpha_masks.append(mask.copy())

            with self.assertRaises(HTTPException) as error:
                server._write_animation_quality_report(frame_files, alpha_masks, directory)

        self.assertEqual(error.exception.status_code, 502)
        self.assertIn("walk_cycle_has_visible_pose_changes", error.exception.detail)
        self.assertIn("run_cycle_has_visible_pose_changes", error.exception.detail)

    def test_motion_reference_contact_sheet_endpoint_returns_project_image(self):
        with tempfile.TemporaryDirectory() as temporary:
            project_directory = Path(temporary)
            motion_directory = project_directory / "motion_stickman"
            motion_directory.mkdir()
            contact_path = motion_directory / "motion_stickman_contact.png"
            Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0)).save(contact_path)
            with patch.object(server, "_project_directory", return_value=project_directory):
                response = server.get_motion_reference_contact_sheet("project-id")

            self.assertEqual(Path(response.path), contact_path)
            self.assertEqual(response.media_type, "image/png")

    def test_motion_reference_gif_endpoint_returns_project_animation(self):
        with tempfile.TemporaryDirectory() as temporary:
            project_directory = Path(temporary)
            motion_directory = project_directory / "motion_stickman"
            motion_directory.mkdir()
            gif_path = motion_directory / "motion_stickman_13.gif"
            Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0)).save(gif_path, format="GIF")
            with patch.object(server, "_project_directory", return_value=project_directory):
                response = server.get_motion_reference_gif("project-id")

            self.assertEqual(Path(response.path), gif_path)
            self.assertEqual(response.media_type, "image/gif")

    def test_motion_reference_player_page_uses_manifest_and_frame_controls(self):
        response = server.get_motion_reference_player("d722f508-166d-447d-b995-21daa519a329")

        self.assertIn("fetch(`${base}/manifest`)", response.body.decode())
        self.assertIn("${base}/frame/${index}", response.body.decode())
        self.assertIn("Previous", response.body.decode())
        self.assertIn("Next", response.body.decode())
        self.assertIn("Pause", response.body.decode())

    def test_project_seed_null_update_generates_seed_and_invalidates_old_outputs(self):
        project = {
            "id": "seed-update-test",
            "seed": 100,
            "revision": 1,
            "candidates": [{"prompt_id": "old-job"}],
            "approved_image": "approved.png",
            "approved_prompt_id": "old-job",
            "animation": {"sheet": "old.png"},
        }
        with (
            patch.object(server, "_load_project", return_value=project),
            patch.object(server, "_save_project"),
            patch.object(server.secrets, "randbits", return_value=456789),
        ):
            updated = server.update_project("seed-update-test", server.ProjectUpdate(seed=None))

        self.assertEqual(updated["seed"], 456789)
        self.assertEqual(updated["candidates"], [])
        self.assertIsNone(updated["approved_image"])
        self.assertIsNone(updated["animation"])

    def test_character_lora_is_applied_to_concept_model_and_clip(self):
        workflow = json.loads((self.root / self.bindings["workflow_path"]).read_text())
        lora_name = "trained/hero.safetensors"
        with patch.object(server, "_request_json", return_value={
            "LoraLoader": {"input": {"required": {"lora_name": [[lora_name]]}}},
        }):
            applied = server._apply_character_lora(
                workflow,
                {"character_lora": lora_name},
                self.bindings["nodes"]["lora_loader"],
                self.bindings["nodes"]["lora_model_target"],
            )

        self.assertEqual(applied, lora_name)
        self.assertEqual(workflow["9"]["class_type"], "LoraLoader")
        self.assertEqual(workflow["2"]["inputs"]["clip"], ["9", 1])
        self.assertEqual(workflow["3"]["inputs"]["clip"], ["9", 1])
        self.assertEqual(workflow["5"]["inputs"]["model"], ["9", 0])

    def test_uninstalled_character_lora_is_rejected(self):
        workflow = json.loads((self.root / self.bindings["workflow_path"]).read_text())
        with (
            patch.object(server, "_request_json", return_value={
                "LoraLoader": {"input": {"required": {"lora_name": [[]]}}},
            }),
            self.assertRaises(HTTPException) as error,
        ):
            server._apply_character_lora(
                workflow,
                {"character_lora": "missing.safetensors"},
                self.bindings["nodes"]["lora_loader"],
                self.bindings["nodes"]["lora_model_target"],
            )
        self.assertEqual(error.exception.status_code, 422)

    def test_character_lora_change_invalidates_previous_outputs(self):
        project = {
            "id": "lora-update-test",
            "character_lora": "old.safetensors",
            "revision": 1,
            "updated_at": "2026-09-26T00:00:00Z",
            "candidates": [{"prompt_id": "old-job"}],
            "approved_image": "approved.png",
            "approved_prompt_id": "old-job",
            "animation": {"sheet": "old.png"},
        }
        with (
            patch.object(server, "_load_project", return_value=project),
            patch.object(server, "_save_project"),
        ):
            updated = server.update_project(
                "lora-update-test", server.ProjectUpdate(character_lora="new.safetensors")
            )

        self.assertEqual(updated["character_lora"], "new.safetensors")
        self.assertEqual(updated["candidates"], [])
        self.assertIsNone(updated["approved_image"])
        self.assertIsNone(updated["animation"])

    def test_unrelated_update_preserves_character_lora(self):
        project = {
            "id": "lora-preserve-test",
            "name": "before",
            "character_lora": "trained/hero.safetensors",
            "revision": 1,
            "updated_at": "2026-09-26T00:00:00Z",
        }
        with (
            patch.object(server, "_load_project", return_value=project),
            patch.object(server, "_save_project"),
        ):
            updated = server.update_project(
                "lora-preserve-test", server.ProjectUpdate(name="after")
            )

        self.assertEqual(updated["name"], "after")
        self.assertEqual(updated["character_lora"], "trained/hero.safetensors")

    def test_extracts_thirteen_alpha_masks(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            sheet = Image.new("RGBA", (CANVAS * 13, CANVAS), (0, 0, 0, 0))
            draw = ImageDraw.Draw(sheet)
            for index in range(13):
                draw.rectangle((index * CANVAS + 8, 8, index * CANVAS + 15, 20), fill=(20, 80, 200, 255))
            sheet_path = directory / "walk13.png"
            sheet.save(sheet_path)

            paths, masks = server._make_control_masks(sheet_path, directory)

            self.assertEqual(len(paths), 13)
            self.assertEqual(len(masks), 13)
            self.assertEqual(masks[0].getbbox(), (8, 8, 16, 21))
            control = Image.open(paths[0]).convert("RGB")
            self.assertEqual(control.getpixel((8, 8)), (255, 255, 255))
            self.assertEqual(control.getpixel((0, 0)), (0, 0, 0))

            generated = BytesIO()
            Image.new("RGBA", (CANVAS, CANVAS), (220, 50, 60, 255)).save(generated, format="PNG")
            history_entry = {"outputs": {"7": {"images": [{} for _ in range(13)]}}}
            with patch.object(server, "_comfy_image_bytes", return_value=generated.getvalue()):
                rendered_sheet, frame_files = server._composite_rendered_frames(
                    history_entry,
                    "7",
                    masks,
                    directory,
                )

            result = Image.open(rendered_sheet).convert("RGBA")
            self.assertEqual(result.size, (CANVAS * 13, CANVAS))
            self.assertEqual(result.getpixel((8, 8))[3], 255)

            game_sheet = Image.open(directory / "walk13_game.png").convert("RGBA")
            self.assertEqual(
                game_sheet.size,
                (server.GAME_CANVAS_SIZE * 13, server.GAME_CANVAS_SIZE),
            )
            self.assertEqual(result.getpixel((0, 0))[3], 0)
            self.assertEqual(len(frame_files), 13)

    def test_animation_compositing_locks_frames_to_reference_palette(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            reference = Image.new("RGB", (4, 1))
            reference.putdata([(20, 40, 90), (40, 120, 130), (180, 150, 70), (80, 55, 105)])
            reference_path = directory / "approved.png"
            reference.save(reference_path)
            alpha_masks = []
            generated_bytes = []
            for index in range(13):
                mask = Image.new("L", (CANVAS, CANVAS), 0)
                ImageDraw.Draw(mask).rectangle((8, 5, 15, CANVAS - 1), fill=255)
                alpha_masks.append(mask)
                generated = Image.new("RGB", (CANVAS, CANVAS))
                generated.putdata([
                    ((x * 13 + index * 7) % 256, (y * 17 + index * 11) % 256, (x * y * 3 + index * 19) % 256)
                    for y in range(CANVAS)
                    for x in range(CANVAS)
                ])
                buffer = BytesIO()
                generated.save(buffer, format="PNG")
                generated_bytes.append(buffer.getvalue())

            entry = {"outputs": {"7": {"images": [{} for _ in range(13)]}}}
            with patch.object(server, "_comfy_image_bytes", side_effect=generated_bytes):
                server._composite_rendered_frames(
                    entry, "7", alpha_masks, directory, reference_path
                )

            shared_colors = set()
            for index in range(13):
                with Image.open(directory / f"rendered_{index + 1:02d}.png") as source:
                    frame = source.convert("RGBA")
                self.assertEqual(frame.getchannel("A").tobytes(), alpha_masks[index].tobytes())
                shared_colors.update(
                    pixel[:3] for pixel in frame.getdata() if pixel[3] > 0
                )

            self.assertLessEqual(len(shared_colors), 4)

    def test_aseprite_failure_reports_exit_code_and_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            fake_aseprite = [
                sys.executable,
                "-c",
                "import sys; print('partial progress'); print('boom', file=sys.stderr); sys.exit(3)",
            ]
            with self.assertRaises(HTTPException) as error:
                server._run_aseprite(fake_aseprite, cwd=directory)

        self.assertEqual(error.exception.status_code, 502)
        self.assertIn("exited with code 3", error.exception.detail)
        self.assertIn("partial progress", error.exception.detail)
        self.assertIn("boom", error.exception.detail)

    def test_aseprite_timeout_reports_command(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            fake_aseprite = [sys.executable, "-c", "import time; time.sleep(5)"]
            with patch.object(server.subprocess, "run", side_effect=server.subprocess.TimeoutExpired(fake_aseprite, 0.01)):
                with self.assertRaises(HTTPException) as error:
                    server._run_aseprite(fake_aseprite, cwd=directory)

        self.assertEqual(error.exception.status_code, 502)
        self.assertIn("timed out", error.exception.detail)

    def test_missing_controlnet_model_returns_install_path(self):
        with tempfile.TemporaryDirectory() as temporary:
            with (
                patch.object(server, "_load_project", return_value={"approved_image": "approved.png"}),
                patch.object(server, "COMFYUI_ROOT", Path(temporary)),
            ):
                with self.assertRaises(HTTPException) as error:
                    server.generate_animation("test-project", server.AnimateRequest())

        self.assertEqual(error.exception.status_code, 503)
        self.assertIn("models", error.exception.detail)
        self.assertIn(server.CONTROLNET_MODEL, error.exception.detail)

    @unittest.skipUnless(_find_aseprite(), "Aseprite CLI not installed on this machine")
    def test_height_class_rigs_render_thirteen_frames_without_mass_drift(self):
        aseprite = _find_aseprite()
        script_path = self.root / "tooling" / "generate_walk13.lua"
        for height_class, parts in server.HEIGHT_RIGS.items():
            with self.subTest(height_class=height_class), tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                config_path = directory / "walk13.json"
                config_path.write_text(json.dumps({
                    "projectName": "character",
                    "subjectDescription": f"{height_class} regression test hero",
                    "parts": parts,
                    "poses": server.POSE_SEQUENCE,
                }))
                generate = subprocess.run(
                    [aseprite, "-b", "--script-param", f"config={config_path}", "--script", str(script_path)],
                    cwd=directory, capture_output=True, text=True, timeout=120,
                )
                self.assertEqual(generate.returncode, 0, generate.stdout + generate.stderr)

                sheet_path = directory / "walk13.png"
                data_path = directory / "walk13.json"
                export = subprocess.run(
                    [aseprite, "-b", str(directory / "character_walk13.aseprite"), "--tag", "walk13",
                     "--sheet-type", "horizontal", "--sheet", str(sheet_path), "--data", str(data_path)],
                    cwd=directory, capture_output=True, text=True, timeout=120,
                )
                self.assertEqual(export.returncode, 0, export.stdout + export.stderr)
                sheet = Image.open(sheet_path)
                try:
                    self.assertEqual(sheet.size, (server.CHARACTER_CANVAS_SIZE * 13, server.CHARACTER_CANVAS_SIZE))
                    silhouettes = [
                        sheet.crop((index * CANVAS, 0, (index + 1) * CANVAS, CANVAS))
                        .convert("RGBA")
                        .getchannel("A")
                        .tobytes()
                        for index in range(13)
                    ]
                    self.assertGreaterEqual(len(set(silhouettes)), 8)
                    walk_silhouettes = {
                        silhouettes[index]
                        for index, pose in enumerate(server.POSE_SEQUENCE)
                        if pose["kind"] == "walk"
                    }
                    run_silhouettes = {
                        silhouettes[index]
                        for index, pose in enumerate(server.POSE_SEQUENCE)
                        if pose["kind"] == "run"
                    }
                    self.assertGreaterEqual(len(walk_silhouettes), 2)
                    self.assertGreaterEqual(len(run_silhouettes), 2)
                    self.assertNotEqual(silhouettes[0], silhouettes[-1])
                finally:
                    sheet.close()


class PublishTests(unittest.TestCase):
    def test_pubspec_registration_is_idempotent_and_keeps_existing_entries(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app_dir = root / "app"
            app_dir.mkdir()
            original = (
                "flutter:\n"
                "  uses-material-design: true\n"
                "\n"
                "  assets:\n"
                "    - assets/images/characters/\n"
                "    - assets/images/characters/wizard_13/\n"
                "\n"
                "  # trailing comment\n"
            )
            (app_dir / "pubspec.yaml").write_text(original, encoding="utf-8")

            with patch.object(server, "REPO_ROOT", root):
                self.assertTrue(server._register_pubspec_asset("hero_a"))
                self.assertFalse(server._register_pubspec_asset("hero_a"))

            updated = (app_dir / "pubspec.yaml").read_text(encoding="utf-8")
            self.assertEqual(
                updated.count("    - assets/images/characters/hero_a/"), 1
            )
            self.assertIn("    - assets/images/characters/wizard_13/", updated)
            self.assertIn("  # trailing comment", updated)


if __name__ == "__main__":
    unittest.main()
