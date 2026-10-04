extends SceneTree


func _initialize() -> void:
	call_deferred("_export")


func _export() -> void:
	var scene: PackedScene = load("res://preview.tscn")
	var preview: Control = scene.instantiate()
	root.add_child(preview)
	await process_frame
	if not preview.ready_ok:
		push_error("Cannot export fighter: " + preview.error_message)
		quit(1)
		return
	preview.set_paused(true)
	preview.set_process(false)
	preview.set_resolution(64)
	preview.set_angle(270)
	# A strictly horizontal side view gives the ground a constant pixel baseline.
	preview.camera.position = Vector3(-5, 0.95, 0)
	preview.camera.look_at(Vector3(0, 0.95, 0))
	preview.viewport.transparent_bg = true
	var environment: WorldEnvironment
	for child: Node in preview.viewport.get_children():
		if child is WorldEnvironment:
			environment = child
			break
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	for slot: String in preview.SLOT_BONES:
		preview.set_equipment(slot, false)
	var sheet := Image.create(64 * 13, 64, false, Image.FORMAT_RGBA8)
	var walk_hashes: Dictionary = {}
	for index: int in range(13):
		if index == 0:
			preview.animation.stop()
			preview.skeleton.reset_bone_poses()
		else:
			preview.animation.play(preview.walk_name)
			preview.animation.seek(float(index - 1) / 12.0, true)
			preview.animation.advance(0)
		preview.skeleton.force_update_all_bone_transforms()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = preview.viewport.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		if frame.get_pixel(0, 0).a != 0.0 or frame.get_used_rect().size == Vector2i.ZERO:
			push_error("Expected visible fighter on a transparent background.")
			quit(1)
			return
		if index > 0:
			walk_hashes[hash(frame.get_data())] = true
		sheet.blit_rect(frame, Rect2i(0, 0, 64, 64), Vector2i(index * 64, 0))
		if index == 0 or index == 4:
			DirAccess.make_dir_recursive_absolute("res://captures")
			frame.resize(512, 512, Image.INTERPOLATE_NEAREST)
			frame.save_png("res://captures/flutter_frame_%d.png" % index)
	if walk_hashes.size() < 8:
		push_error("Walk export has too few distinct poses: " + str(walk_hashes.size()))
		quit(1)
		return
	var output := ProjectSettings.globalize_path("res://../../app/assets/images/characters/fighter_godot/walk13_fighter.png")
	var result := DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if result != OK:
		push_error("Cannot create export folder: " + str(result))
		quit(1)
		return
	result = sheet.save_png(output)
	if result != OK:
		push_error("Cannot save fighter sheet: " + str(result))
		quit(1)
		return
	print("EXPORTED: ", output, " (13 x 64px cells, rest + 12 walk phases; baseline 54)")
	quit(0)
