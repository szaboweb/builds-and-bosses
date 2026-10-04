extends SceneTree

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _sample(preview: Control, seconds: float) -> void:
	preview.animation.seek(seconds, true)
	preview.animation.advance(0.0)
	preview.skeleton.force_update_all_bone_transforms()
	# Skeleton notifications update attachments at the end of the frame.
	await process_frame
	await process_frame


func _run() -> void:
	var controller: Script = load("res://preview.gd")
	if controller == null or not controller.can_instantiate():
		_check(false, "Preview script must compile")
		_finish()
		return
	var scene: PackedScene = load("res://preview.tscn")
	var preview: Control = scene.instantiate()
	root.add_child(preview)
	await process_frame
	_check(preview.ready_ok, "Preview initialization: " + preview.error_message)
	if not preview.ready_ok:
		_finish()
		return
	preview.set_paused(true)
	var capture := OS.get_cmdline_user_args().has("--capture")
	var walk: Animation = preview.animation.get_animation(preview.walk_name)
	print("Imported walk: ", preview.walk_name, " length=", walk.length, " bones=", preview.skeleton.get_bone_count())
	_check(absf(walk.length - 1.0) < 0.001, "Expected the full 24fps, 24-interval walk cycle")
	_check(walk.loop_mode == Animation.LOOP_LINEAR, "Walk must loop")
	var foot: int = preview.skeleton.find_bone("Foot.L")
	await _sample(preview, 0.0)
	var first: Transform3D = preview.skeleton.get_bone_global_pose(foot)
	await _sample(preview, 0.5)
	var half: Transform3D = preview.skeleton.get_bone_global_pose(foot)
	_check(first.origin.distance_to(half.origin) > 0.05, "Foot must move between opposite stride phases")
	await _sample(preview, walk.length - 0.00001)
	var last: Transform3D = preview.skeleton.get_bone_global_pose(foot)
	_check(first.origin.distance_to(last.origin) < 0.001, "Walk endpoint must meet the initial foot position")
	_check(first.basis.is_equal_approx(last.basis) or first.basis.get_rotation_quaternion().angle_to(last.basis.get_rotation_quaternion()) < 0.001, "Walk endpoint rotation must match")
	var phase_samples: Array[float] = [0.0, 0.25, 0.5, 0.75]
	var view_angles: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
	for resolution: int in preview.RESOLUTIONS:
		preview.set_resolution(resolution)
		_check(preview.viewport.size == Vector2i(resolution, resolution), "Viewport resolution")
		_check(int(preview.image.custom_minimum_size.x) % resolution == 0, "Integer texture scaling")
		for mask: int in range(8):
			for index: int in range(3):
				var slot: String = preview.SLOT_BONES.keys()[index]
				preview.set_equipment(slot, (mask & (1 << index)) != 0)
			for seconds: float in phase_samples:
				await _sample(preview, seconds)
				for slot: String in preview.SLOT_BONES:
					var equipment: Node3D = preview.slots[slot]
					var attachment: BoneAttachment3D = equipment.get_parent()
					var bone: int = preview.skeleton.find_bone(preview.SLOT_BONES[slot])
					var expected: Transform3D = preview.skeleton.global_transform * preview.skeleton.get_bone_global_pose(bone)
					_check(attachment.global_transform.is_equal_approx(expected), "Bone attachment alignment: " + slot)
				for angle: float in view_angles:
					preview.set_angle(angle)
					for slot: String in preview.SLOT_BONES:
						var equipment: Node3D = preview.slots[slot]
						if not equipment.visible:
							continue
						for child: Node in equipment.get_children():
							var piece := child as MeshInstance3D
							var bounds: AABB = piece.get_aabb()
							for corner: int in range(8):
								var point: Vector3 = piece.global_transform * bounds.get_endpoint(corner)
								var pixel: Vector2 = preview.camera.unproject_position(point)
								_check(not preview.camera.is_position_behind(point), "Equipment behind camera")
								_check(pixel.x >= 1 and pixel.y >= 1 and pixel.x < resolution - 1 and pixel.y < resolution - 1, "Equipment clipped: " + slot)
					if capture:
						await RenderingServer.frame_post_draw
						_check_render_bounds(preview, "resolution=%d mask=%d phase=%.2f angle=%.0f" % [resolution, mask, seconds, angle])
				var before: float = preview.animation.current_animation_position
				preview.set_equipment("Helmet", not preview.slots["Helmet"].visible)
				preview.set_equipment("Helmet", (mask & 1) != 0)
				_check(is_equal_approx(before, preview.animation.current_animation_position), "Equipment change reset animation")
	_check(preview.image.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Nearest-neighbor display")
	_check(preview.viewport.msaa_3d == Viewport.MSAA_DISABLED, "MSAA must be disabled")
	_check(preview.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Orthographic camera")
	for slot: String in preview.SLOT_BONES:
		preview.set_equipment(slot, false)
	for slot: String in preview.SLOT_BONES:
		var option: OptionButton = preview.slot_options[slot]
		option.item_selected.emit(1)
		for other: String in preview.SLOT_BONES:
			_check(preview.slots[other].visible == (other == slot), "Independent UI selector: " + slot + "/" + other)
		option.item_selected.emit(0)
	preview.resolution_option.item_selected.emit(0)
	_check(preview.viewport.size == Vector2i(64, 64), "Resolution UI selector")
	preview.angle_slider.value = 90
	_check(is_equal_approx(preview.camera.position.x, 5.0), "Direction UI slider")
	preview.posterize_material.set_shader_parameter("enabled", true)
	_check(preview.posterize_material.get_shader_parameter("enabled") == true, "Posterization toggle")
	preview.posterize_material.set_shader_parameter("enabled", false)
	preview.pause_button.pressed.emit()
	_check(not preview.paused, "Resume UI button")
	preview.pause_button.pressed.emit()
	_check(preview.paused, "Pause UI button")
	preview.set_paused(false)
	var moving_before: float = preview.animation.current_animation_position
	await create_timer(0.15).timeout
	_check(not is_equal_approx(moving_before, preview.animation.current_animation_position), "Realtime playback must advance")
	preview.set_paused(true)
	var paused_before: float = preview.animation.current_animation_position
	await create_timer(0.05).timeout
	_check(is_equal_approx(paused_before, preview.animation.current_animation_position), "Pause must hold the pose")
	if capture:
		await _capture(preview)
	print("RESULT: ", checks, " checks; ", failures.size(), " failures")
	_finish()


func _check_render_bounds(preview: Control, context: String) -> void:
	var frame: Image = preview.viewport.get_texture().get_image()
	_check(not frame.is_empty(), "Render exists: " + context)
	if frame.is_empty():
		return
	var background := frame.get_pixel(0, 0)
	var foreground: int = 0
	var clipped: bool = false
	for y: int in range(frame.get_height()):
		for x: int in range(frame.get_width()):
			if not frame.get_pixel(x, y).is_equal_approx(background):
				foreground += 1
				if x == 0 or y == 0 or x == frame.get_width() - 1 or y == frame.get_height() - 1:
					clipped = true
	_check(foreground > 100, "Visible rendered character: " + context)
	_check(not clipped, "Character/equipment pixels touch viewport edge: " + context)


func _capture(preview: Control) -> void:
	DirAccess.make_dir_recursive_absolute("res://captures")
	for slot: String in preview.SLOT_BONES:
		preview.set_equipment(slot, true)
	for resolution: int in preview.RESOLUTIONS:
		preview.set_resolution(resolution)
		for angle: int in [0, 90, 180, 270]:
			preview.set_angle(angle)
			await _sample(preview, 0.25)
			await process_frame
			await RenderingServer.frame_post_draw
			var frame: Image = preview.viewport.get_texture().get_image()
			_check(not frame.is_empty(), "Rendered capture must contain pixels")
			var path := "res://captures/fighter_%d_%d.png" % [resolution, angle]
			_check(frame.save_png(path) == OK, "Save capture: " + path)
			frame.resize(512, 512, Image.INTERPOLATE_NEAREST)
			_check(frame.save_png(path.replace(".png", "_x.png")) == OK, "Save enlarged capture")
	preview.set_resolution(128)
	preview.set_angle(45)
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	_check(screenshot.save_png("res://captures/viewer.png") == OK, "Save viewer screenshot")
	preview.set_paused(false)
	var started := Time.get_ticks_usec()
	for frame: int in range(120):
		await process_frame
	var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
	print("LOCAL VIEWER SAMPLE: 120 frames in %.3fs (%.1f frames/s); not a full-game benchmark" % [elapsed, 120.0 / elapsed])


func _finish() -> void:
	quit(0 if failures.is_empty() else 1)
