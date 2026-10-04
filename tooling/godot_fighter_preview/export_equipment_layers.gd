extends SceneTree


func _initialize() -> void:
	call_deferred("_export")


func _render_frame(preview: Control) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = preview.viewport.get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	return frame


func _export() -> void:
	var scene: PackedScene = load("res://preview.tscn")
	var preview: Control = scene.instantiate()
	root.add_child(preview)
	await process_frame
	if not preview.ready_ok:
		push_error("Cannot export equipment layers: " + preview.error_message)
		quit(1)
		return
	preview.set_paused(true)
	preview.set_process(false)
	preview.set_resolution(64)
	preview.set_angle(270)
	preview.camera.position = Vector3(-5, 0.95, 0)
	preview.camera.look_at(Vector3(0, 0.95, 0))
	preview.viewport.transparent_bg = true
	for child: Node in preview.viewport.get_children():
		if child is WorldEnvironment:
			child.environment.background_mode = Environment.BG_CLEAR_COLOR
	var base_path := ProjectSettings.globalize_path("res://../../app/assets/images/characters/fighter_godot/walk13_fighter.png")
	var base := Image.load_from_file(base_path)
	if base == null or base.get_size() != Vector2i(832, 64):
		push_error("Export the fighter atlas first: " + base_path)
		quit(1)
		return
	base.convert(Image.FORMAT_RGBA8)
	var names := {"Helmet": "helmet", "Chest": "chest", "Weapon": "sword"}
	var layers: Dictionary = {}
	for slot: String in names:
		layers[slot] = Image.create(832, 64, false, Image.FORMAT_RGBA8)
		preview.set_equipment(slot, false)
	for index: int in range(13):
		if index == 0:
			preview.animation.stop()
			preview.skeleton.reset_bone_poses()
		else:
			preview.animation.play(preview.walk_name)
			preview.animation.seek(float(index - 1) / 12.0, true)
			preview.animation.advance(0)
		preview.skeleton.force_update_all_bone_transforms()
		var bare: Image = await _render_frame(preview)
		var frame_layers: Dictionary = {}
		var expected := base.get_region(Rect2i(index * 64, 0, 64, 64))
		if bare.get_data() != expected.get_data():
			push_error("Fighter frame differs from bundled atlas at index " + str(index))
			quit(1)
			return
		for slot: String in names:
			preview.set_equipment(slot, true)
			var equipped: Image = await _render_frame(preview)
			var layer := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			# The body remains in the depth test, so hidden gear stays hidden.
			for y: int in range(64):
				for x: int in range(64):
					if equipped.get_pixel(x, y) != bare.get_pixel(x, y):
						layer.set_pixel(x, y, equipped.get_pixel(x, y))
			if layer.get_used_rect().size == Vector2i.ZERO:
				push_error("Empty equipment layer: " + slot + " frame " + str(index))
				quit(1)
				return
			var reconstructed := bare.duplicate()
			reconstructed.blend_rect(layer, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
			if reconstructed.get_data() != equipped.get_data():
				push_error("Layer composition differs from Godot render: " + slot)
				quit(1)
				return
			layers[slot].blit_rect(layer, Rect2i(0, 0, 64, 64), Vector2i(index * 64, 0))
			frame_layers[slot] = layer
			preview.set_equipment(slot, false)
		var order: Array[String] = ["Chest", "Helmet", "Weapon"]
		for mask: int in range(8):
			var combined := bare.duplicate()
			for bit: int in range(3):
				var enabled := (mask & (1 << bit)) != 0
				preview.set_equipment(order[bit], enabled)
				if enabled:
					combined.blend_rect(frame_layers[order[bit]], Rect2i(0, 0, 64, 64), Vector2i.ZERO)
			var rendered: Image = await _render_frame(preview)
			if combined.get_data() != rendered.get_data():
				push_error("Combined layers differ from Godot: frame " + str(index) + " mask " + str(mask))
				quit(1)
				return
		for slot: String in names:
			preview.set_equipment(slot, false)
	var output := ProjectSettings.globalize_path("res://../../app/assets/images/equipment/godot_sample")
	var result := DirAccess.make_dir_recursive_absolute(output)
	if result != OK:
		push_error("Cannot create equipment folder: " + str(result))
		quit(1)
		return
	for slot: String in names:
		result = layers[slot].save_png(output.path_join(names[slot] + "_walk13.png"))
		if result != OK:
			push_error("Cannot save equipment layer: " + str(result))
			quit(1)
			return
		print("EXPORTED LAYER: ", slot, " (13 x 64px; exact base match and all 8 combinations verified)")
	quit(0)
