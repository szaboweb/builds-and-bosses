extends Control

const FIGHTER: PackedScene = preload("res://assets/fighter.glb")
const POSTERIZE: Shader = preload("res://posterize.gdshader")
const SLOT_BONES: Dictionary = {
	"Helmet": "Head",
	"Chest": "Spine",
	"Weapon": "Hand.R",
}
const RESOLUTIONS: Array[int] = [64, 128]

var viewport: SubViewport
var camera: Camera3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var walk_name: StringName
var slots: Dictionary = {}
var slot_options: Dictionary = {}
var status: Label
var time_slider: HSlider
var pause_button: Button
var resolution_option: OptionButton
var angle_slider: HSlider
var image: TextureRect
var posterize_material: ShaderMaterial
var ready_ok: bool = false
var paused: bool = false
var error_message: String = ""


func _ready() -> void:
	get_window().min_size = Vector2i(1100, 740)
	_build_ui()
	_build_world()
	if not _load_fighter():
		return
	_build_equipment()
	if not error_message.is_empty():
		return
	animation.play(walk_name)
	animation.advance(0.0)
	ready_ok = true
	status.text = "Walk ready. Equipment follows bones; no sprite sheets."


func _process(_delta: float) -> void:
	if ready_ok:
		time_slider.set_value_no_signal(animation.current_animation_position)


func _fail(message: String) -> void:
	error_message = message
	status.text = "ERROR: " + message
	status.modulate = Color(1.0, 0.35, 0.3)
	push_error(message)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 28)
	margin.add_child(layout)
	var display := VBoxContainer.new()
	layout.add_child(display)
	var title := Label.new()
	title.text = "Runtime 3D -> low-resolution pixels"
	display.add_child(title)
	image = TextureRect.new()
	image.custom_minimum_size = Vector2(512, 512)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	posterize_material = ShaderMaterial.new()
	posterize_material.shader = POSTERIZE
	image.material = posterize_material
	display.add_child(image)
	var caption := Label.new()
	caption.text = "Fixed 512px display: 64px x8 / 128px x4.\nNo automatic per-frame cropping or camera fitting."
	display.add_child(caption)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 12)
	layout.add_child(controls)
	var heading := Label.new()
	heading.text = "Fighter equipment feasibility test"
	controls.add_child(heading)
	var note := Label.new()
	note.text = "Visual experiment only; not an engine migration.\nRigid sample armor is not production skinning."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(note)
	for slot: String in SLOT_BONES:
		var label := Label.new()
		label.text = slot + " (independent slot)"
		controls.add_child(label)
		var option := OptionButton.new()
		option.add_item("None")
		option.add_item("Sample " + slot.to_lower())
		option.item_selected.connect(func(index: int) -> void: set_equipment(slot, index == 1))
		slot_options[slot] = option
		controls.add_child(option)
	var resolution_label := Label.new()
	resolution_label.text = "Render resolution (same framing)"
	controls.add_child(resolution_label)
	resolution_option = OptionButton.new()
	for resolution: int in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [resolution, resolution])
	resolution_option.item_selected.connect(func(index: int) -> void: set_resolution(RESOLUTIONS[index]))
	controls.add_child(resolution_option)
	var palette := CheckBox.new()
	palette.text = "Experimental 5-level RGB posterization"
	palette.toggled.connect(func(enabled: bool) -> void: posterize_material.set_shader_parameter("enabled", enabled))
	controls.add_child(palette)
	var angle_label := Label.new()
	angle_label.text = "Viewing direction (degrees)"
	controls.add_child(angle_label)
	angle_slider = HSlider.new()
	angle_slider.min_value = 0
	angle_slider.max_value = 360
	angle_slider.step = 1
	angle_slider.value = 45
	angle_slider.value_changed.connect(set_angle)
	controls.add_child(angle_slider)
	pause_button = Button.new()
	pause_button.text = "Pause walk"
	pause_button.pressed.connect(func() -> void: set_paused(not paused))
	controls.add_child(pause_button)
	var restart := Button.new()
	restart.text = "Restart walk"
	restart.pressed.connect(func() -> void:
		if ready_ok:
			animation.seek(0.0, true)
	)
	controls.add_child(restart)
	time_slider = HSlider.new()
	time_slider.step = 0.001
	time_slider.max_value = 1.0
	time_slider.value_changed.connect(func(value: float) -> void:
		if ready_ok:
			set_paused(true)
			animation.seek(value, true)
	)
	controls.add_child(time_slider)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(status)


func _build_world() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	add_child(viewport)
	image.texture = viewport.get_texture()
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.075, 0.09, 0.12)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.1
	light.shadow_enabled = false
	viewport.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	camera.near = 0.01
	camera.far = 100.0
	viewport.add_child(camera)
	camera.current = true
	set_angle(45.0)


func _load_fighter() -> bool:
	var fighter := FIGHTER.instantiate()
	viewport.add_child(fighter)
	var skeletons := fighter.find_children("*", "Skeleton3D", true, false)
	var players := fighter.find_children("*", "AnimationPlayer", true, false)
	if skeletons.size() != 1 or players.size() != 1:
		_fail("Expected one skeleton and one animation player in fighter.glb.")
		return false
	skeleton = skeletons[0] as Skeleton3D
	animation = players[0] as AnimationPlayer
	for candidate: StringName in animation.get_animation_list():
		if String(candidate).contains("Fighter_Walk"):
			walk_name = candidate
			break
	if walk_name.is_empty():
		_fail("Fighter_Walk not found. Imported animations: " + str(animation.get_animation_list()))
		return false
	for bone: String in SLOT_BONES.values():
		if skeleton.find_bone(bone) < 0:
			_fail("Missing equipment bone: " + bone)
			return false
	var walk := animation.get_animation(walk_name)
	walk.loop_mode = Animation.LOOP_LINEAR
	time_slider.max_value = walk.length
	return true


func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.8
	return material


func _piece(parent: Node3D, mesh: Mesh, center: Vector3, material: Material, bone: int) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	parent.add_child(piece)
	# Author pieces in skeleton rest coordinates, then bind to the bone's space.
	piece.transform = skeleton.get_bone_global_rest(bone).affine_inverse() * Transform3D(Basis.IDENTITY, center)


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _build_equipment() -> void:
	var steel := _material(Color(0.45, 0.62, 0.78), 0.35)
	var gold := _material(Color(0.85, 0.55, 0.15), 0.2)
	var leather := _material(Color(0.3, 0.12, 0.05))
	for slot: String in SLOT_BONES:
		var bone_name: String = SLOT_BONES[slot]
		var bone := skeleton.find_bone(bone_name)
		var attachment := BoneAttachment3D.new()
		attachment.name = slot + "Attachment"
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		var equipment := Node3D.new()
		equipment.name = slot + "Sample"
		attachment.add_child(equipment)
		slots[slot] = equipment
		match slot:
			"Helmet":
				_piece(equipment, _box(Vector3(0.30, 0.13, 0.30)), Vector3(0, 1.79, 0), steel, bone)
				_piece(equipment, _box(Vector3(0.035, 0.10, 0.32)), Vector3(0, 1.89, 0), gold, bone)
			"Chest":
				_piece(equipment, _box(Vector3(0.43, 0.33, 0.29)), Vector3(0, 1.23, 0), steel, bone)
				_piece(equipment, _box(Vector3(0.09, 0.09, 0.02)), Vector3(0, 1.28, 0.155), gold, bone)
			"Weapon":
				_piece(equipment, _box(Vector3(0.035, 0.17, 0.035)), Vector3(-0.355, 0.725, 0), leather, bone)
				_piece(equipment, _box(Vector3(0.21, 0.035, 0.05)), Vector3(-0.355, 0.62, 0), gold, bone)
				_piece(equipment, _box(Vector3(0.065, 0.52, 0.022)), Vector3(-0.355, 0.35, 0), steel, bone)
		equipment.visible = false


func set_equipment(slot: String, enabled: bool) -> void:
	if not slots.has(slot):
		_fail("Unknown equipment slot: " + slot)
		return
	var equipment: Node3D = slots[slot]
	equipment.visible = enabled
	var option: OptionButton = slot_options[slot]
	option.select(1 if enabled else 0)


func set_resolution(resolution: int) -> void:
	if not RESOLUTIONS.has(resolution):
		_fail("Unsupported render resolution: " + str(resolution))
		return
	viewport.size = Vector2i(resolution, resolution)
	resolution_option.select(RESOLUTIONS.find(resolution))


func set_angle(degrees: float) -> void:
	var radians := deg_to_rad(degrees)
	var target := Vector3(0, 0.95, 0)
	camera.position = target + Vector3(sin(radians) * 5.0, 0.35, cos(radians) * 5.0)
	camera.look_at(target, Vector3.UP)
	angle_slider.set_value_no_signal(degrees)


func set_paused(value: bool) -> void:
	paused = value
	if ready_ok:
		animation.speed_scale = 0.0 if paused else 1.0
	pause_button.text = "Resume walk" if paused else "Pause walk"
