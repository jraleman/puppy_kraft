extends Control

## An isolated side-on 3D diorama; two remeshes per frame and 35 resident chunks.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Builder = preload("res://games/puppy_kraft/world/mesh_builder.gd")
const Mesher = preload("res://games/puppy_kraft/world/chunk_mesher.gd")
const Puppy = preload("res://games/puppy_kraft/world/puppy_rig.gd")
const Trails = preload("res://games/puppy_kraft/world/scent_trails.gd")
const BarkRings = preload("res://games/puppy_kraft/world/bark_rings.gd")
const SNIFF_SHADER = preload("res://games/puppy_kraft/world/sniff_vision.gdshader")
const LOAD_RADIUS := Vector2i(3, 2)
const REMESHES_PER_FRAME := 2
const CAMERA_FOV := 28.0
const CAMERA_HEIGHT_CELLS := 24.0

var reduced_motion := false
var intense_effects := true
var zoom := 1.0
var world_viewport: SubViewport
var camera: Camera3D
var puppy: Puppy
var scent_trails: Trails
var bark_rings: BarkRings
var _container: SubViewportContainer
var _stage: Node3D
var _material: StandardMaterial3D
var _target: MeshInstance3D
var _cracks: MeshInstance3D
var _marker_material: StandardMaterial3D
var _vision_material: ShaderMaterial
var _world: World
var _meshes: Dictionary[Vector2i, MeshInstance3D] = {}
var _pending: Array[Vector2i] = []
var _focus := Vector2.ZERO
var _camera_ready := false
var _crack_step := -1
var _remesh_total_usec := 0
var _remesh_count := 0
var _max_remesh_usec := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	_container = SubViewportContainer.new()
	_container.name = "WorldContainer"
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vision_material = ShaderMaterial.new()
	_vision_material.shader = SNIFF_SHADER
	_container.material = _vision_material
	add_child(_container)
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_viewport = SubViewport.new()
	world_viewport.name = "MeadowViewport"
	world_viewport.own_world_3d = true
	world_viewport.gui_disable_input = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d = Viewport.MSAA_2X
	_container.add_child(world_viewport)
	_stage = Node3D.new()
	world_viewport.add_child(_stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("bed9d7")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e6ed")
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var lighting := WorldEnvironment.new()
	lighting.environment = environment
	_stage.add_child(lighting)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 0.8
	sun.shadow_enabled = false
	_stage.add_child(sun)
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 1.0
	_material.albedo_texture = _tile_texture()
	_material.texture_repeat = true
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 200.0
	camera.current = true
	_stage.add_child(camera)
	puppy = Puppy.new()
	_stage.add_child(puppy)
	_build_marker()
	scent_trails = Trails.new()
	scent_trails.name = "ScentTrails"
	add_child(scent_trails)
	scent_trails.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scent_trails.hide()
	bark_rings = BarkRings.new()
	bark_rings.name = "BarkRings"
	add_child(bark_rings)
	bark_rings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bark_rings.hide()
	resized.connect(_resize_viewport)
	_resize_viewport()


func _process(_delta: float) -> void:
	if _world == null or not visible:
		return
	_update_loaded_chunks()
	for count in REMESHES_PER_FRAME:
		if _pending.is_empty():
			break
		_remesh(_pending.pop_front())


func present(world: World, delta: float = 0.0) -> void:
	if _world != world:
		for mesh: MeshInstance3D in _meshes.values():
			mesh.queue_free()
		_meshes.clear()
		_pending.clear()
		_world = world
		_camera_ready = false
		_crack_step = -1
		if bark_rings != null:
			bark_rings.clear()
	if world == null or camera == null:
		if scent_trails != null:
			scent_trails.hide()
			_vision_material.set_shader_parameter("scent_amount", 0.0)
		if bark_rings != null:
			bark_rings.clear()
		return
	puppy.reduced_motion = reduced_motion
	puppy.present(world.body, delta)
	var ahead := 0.0 if reduced_motion else world.body.facing * 2.5
	var desired := world.body.position + Vector2(ahead, -3.0)
	if not _camera_ready or reduced_motion:
		_focus = desired
	else:
		_focus = _focus.lerp(desired, 1.0 - exp(-delta * 8.0))
	_camera_ready = true
	var focus := Vector3(_focus.x * Mesher.CELL_METRES, -_focus.y * Mesher.CELL_METRES, 0)
	var distance := CAMERA_HEIGHT_CELLS * Mesher.CELL_METRES \
		/ (2.0 * tan(deg_to_rad(CAMERA_FOV * 0.5)) * zoom)
	camera.position = focus + Vector3(0, distance * 0.12, distance)
	camera.look_at(focus)
	_update_marker(world)
	_vision_material.set_shader_parameter("scent_amount", 0.82 if world.sniffing else 0.0)
	scent_trails.present(world, screen_position, delta, reduced_motion, intense_effects)
	bark_rings.present(world, screen_position, reduced_motion, intense_effects)


func show_bark(event: Dictionary) -> void:
	bark_rings.add_bark(event)


func clear_barks() -> void:
	bark_rings.clear()


func screen_to_cell(local: Vector2) -> Vector2i:
	var viewport_size := Vector2(world_viewport.size)
	var point := local * viewport_size / size
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var at := origin + direction * (-origin.z / direction.z)
	return Vector2i(floori(at.x / Mesher.CELL_METRES), floori(-at.y / Mesher.CELL_METRES))


func screen_position(cell_position: Vector2) -> Vector2:
	var point := Vector3(cell_position.x * Mesher.CELL_METRES,
		-cell_position.y * Mesher.CELL_METRES, 0.3)
	return camera.unproject_position(point) * size / Vector2(world_viewport.size)


func metrics() -> Dictionary:
	return {
		"loaded_chunks": _meshes.size(), "queued_chunks": _pending.size(),
		"max_remesh_ms": float(_max_remesh_usec) / 1000.0,
		"mean_remesh_ms": float(_remesh_total_usec) / maxf(1, _remesh_count) / 1000.0,
		"world_draw_calls": world_viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME
		),
	}


func _update_loaded_chunks() -> void:
	var centre := Grid.chunk_coordinate(Vector2i(_world.body.position.floor()))
	centre.x = clampi(centre.x, 0, floori(float(_world.grid.width - 1) / Chunk.SIZE))
	centre.y = clampi(centre.y, 0, floori(float(_world.grid.height - 1) / Chunk.SIZE))
	var needed: Dictionary[Vector2i, bool] = {}
	for row in range(centre.y - LOAD_RADIUS.y, centre.y + LOAD_RADIUS.y + 1):
		for column in range(centre.x - LOAD_RADIUS.x, centre.x + LOAD_RADIUS.x + 1):
			var coordinate := Vector2i(column, row)
			if not _world.grid.contains(coordinate * Chunk.SIZE):
				continue
			needed[coordinate] = true
			if (not _meshes.has(coordinate) or _world.grid.dirty_chunks.has(coordinate)) \
				and not _pending.has(coordinate):
				_pending.append(coordinate)
	for coordinate: Vector2i in _meshes.keys():
		if not needed.has(coordinate):
			_meshes[coordinate].queue_free()
			_meshes.erase(coordinate)
	_pending = _pending.filter(func(at: Vector2i) -> bool: return needed.has(at))
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(centre) < b.distance_squared_to(centre))


func _remesh(coordinate: Vector2i) -> void:
	_world.grid.chunk_at(coordinate)
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbour := coordinate + offset
		if _world.grid.contains(neighbour * Chunk.SIZE):
			_world.grid.chunk_at(neighbour)
	var start := Time.get_ticks_usec()
	var mesh := Mesher.build(_world.grid, coordinate)
	var elapsed := Time.get_ticks_usec() - start
	_remesh_total_usec += elapsed
	_remesh_count += 1
	_max_remesh_usec = maxi(_max_remesh_usec, elapsed)
	if not _meshes.has(coordinate):
		var instance := MeshInstance3D.new()
		instance.name = "Chunk_%d_%d" % [coordinate.x, coordinate.y]
		instance.material_override = _material
		_stage.add_child(instance)
		_meshes[coordinate] = instance
	_meshes[coordinate].mesh = mesh if mesh.get_surface_count() > 0 else null
	_world.grid.mark_clean(coordinate)


func _tile_texture() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for pixel in 32:
		image.set_pixel(0, pixel, Color("c9c4b9"))
		image.set_pixel(pixel, 0, Color("c9c4b9"))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _resize_viewport() -> void:
	if _container != null:
		_container.stretch_shrink = maxi(1, ceili(maxf(size.x / 1920.0, size.y / 1080.0)))
	if _world != null:
		present(_world)


func _build_marker() -> void:
	var builder := Builder.new()
	for side: float in [-0.255, 0.255]:
		builder.box(Vector3(side, 0, 0.23), Vector3(0.014, 0.52, 0.014), Color.WHITE)
		builder.box(Vector3(0, side, 0.23), Vector3(0.52, 0.014, 0.014), Color.WHITE)
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.vertex_color_use_as_albedo = true
	_target = MeshInstance3D.new()
	_target.mesh = builder.finish()
	_target.material_override = _marker_material
	_target.hide()
	_stage.add_child(_target)
	_cracks = MeshInstance3D.new()
	_cracks.material_override = _marker_material
	_stage.add_child(_cracks)


func _update_marker(world: World) -> void:
	_target.visible = not world.sniffing and world.grid.contains(world.target_cell)
	_target.position = Mesher.cell_centre(world.target_cell)
	_marker_material.albedo_color = Color("fff4bd") if world.target_in_reach else Color("e69b8a")
	_cracks.position = _target.position
	var crack_step := floori(world.dig_fraction() * 4.0)
	_cracks.visible = crack_step > 0 and _target.visible
	if crack_step == _crack_step:
		return
	_crack_step = crack_step
	var builder := Builder.new()
	for step in crack_step:
		var y := 0.15 - step * 0.08
		var x := -0.10 if step % 2 == 0 else 0.01
		builder.box(Vector3(x, y, 0.245), Vector3(0.15, 0.014, 0.012), Color("443c39"))
		builder.box(Vector3(x + 0.065, y - 0.025, 0.245),
			Vector3(0.014, 0.06, 0.012), Color("443c39"))
	var mesh := builder.finish()
	_cracks.mesh = mesh if mesh.get_surface_count() > 0 else null
