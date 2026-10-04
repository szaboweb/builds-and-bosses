extends SceneTree


func _initialize() -> void:
	call_deferred("_export")


func _export() -> void:
	var scene: PackedScene = load("res://preview.tscn")
	var preview: Control = scene.instantiate()
	root.add_child(preview)
	await process_frame
	if not preview.ready_ok:
		push_error("Cannot export equipment: " + preview.error_message)
		quit(1)
		return
	preview.set_paused(true)
	preview.set_process(false)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.1
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true
	var output := ProjectSettings.globalize_path("res://../../app/assets/images/equipment/godot_sample")
	var result := DirAccess.make_dir_recursive_absolute(output)
	if result != OK:
		push_error("Cannot create icon folder: " + str(result))
		quit(1)
		return
	var filenames := {"Helmet": "helmet", "Chest": "chest", "Weapon": "sword"}
	for slot: String in preview.SLOT_BONES:
		var group := Node3D.new()
		viewport.add_child(group)
		var bone: int = preview.skeleton.find_bone(preview.SLOT_BONES[slot])
		var bounds := AABB()
		var first := true
		for original: MeshInstance3D in preview.slots[slot].get_children():
			var piece := MeshInstance3D.new()
			piece.mesh = original.mesh
			piece.material_override = original.material_override
			group.add_child(piece)
			piece.transform = preview.skeleton.get_bone_global_rest(bone) * original.transform
			var piece_bounds: AABB = piece.transform * piece.get_aabb()
			bounds = piece_bounds if first else bounds.merge(piece_bounds)
			first = false
		if first:
			push_error("No meshes for equipment slot: " + slot)
			quit(1)
			return
		var center := bounds.get_center()
		camera.size = bounds.size.length() * 1.35
		camera.position = center + Vector3(3, 2, 5)
		camera.look_at(center)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var icon := viewport.get_texture().get_image()
		icon.convert(Image.FORMAT_RGBA8)
		var used := icon.get_used_rect()
		if used.size == Vector2i.ZERO or icon.get_pixel(0, 0).a != 0.0 or used.position.x <= 0 or used.position.y <= 0 or used.end.x >= 64 or used.end.y >= 64:
			push_error("Expected nonempty, unclipped transparent equipment icon: " + slot)
			quit(1)
			return
		result = icon.save_png(output.path_join(filenames[slot] + ".png"))
		if result != OK:
			push_error("Cannot save equipment icon: " + str(result))
			quit(1)
			return
		print("EXPORTED EQUIPMENT: ", slot, " bounds=", used)
		group.free()
	quit(0)
