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
const LIGHT_SHADER = preload("res://games/puppy_kraft/world/terrain_lighting.gdshader")
const Lighting = preload("res://games/puppy_kraft/sim/lighting.gd")
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
var _material: ShaderMaterial
var _environment: Environment
var _stick_material: StandardMaterial3D
var _target: MeshInstance3D
var _cracks: MeshInstance3D
var _stick: MeshInstance3D
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
var _mesh_light_versions: Dictionary[Vector2i, int] = {}
var _nose: Dictionary[Vector2i, int] = {}
var _nose_cell := Vector2i(-1, -1)
var _nose_revision := -1


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
	_environment = environment
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
	_material = ShaderMaterial.new()
	_material.shader = LIGHT_SHADER
	_material.set_shader_parameter("tile_texture", _tile_texture())
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 200.0
	camera.current = true
	_stage.add_child(camera)
	puppy = Puppy.new()
	_stage.add_child(puppy)
	_build_stick()
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
	var relit := false
	for count in REMESHES_PER_FRAME:
		if _pending.is_empty():
			break
		var cold := not _world.lighting.is_current(_world.grid, _pending[0])
		if cold and relit:
			break
		_remesh(_pending.pop_front())
		relit = relit or cold
	_apply_actor_light(_world)


func present(world: World, delta: float = 0.0) -> void:
	if _world != world:
		for mesh: MeshInstance3D in _meshes.values():
			mesh.queue_free()
		_meshes.clear()
		_pending.clear()
		_mesh_light_versions.clear()
		_nose.clear()
		_nose_cell = Vector2i(-1, -1)
		_nose_revision = -1
		_world = world
		_camera_ready = false
		_crack_step = -1
		if bark_rings != null:
			bark_rings.clear()
	if world == null or camera == null:
		if _stick != null:
			_stick.hide()
		if scent_trails != null:
			scent_trails.hide()
			_vision_material.set_shader_parameter("scent_amount", 0.0)
		if bark_rings != null:
			bark_rings.clear()
		return
	puppy.reduced_motion = reduced_motion
	puppy.present(world.body, delta)
	_update_lighting(world)
	_stick.show()
	if world.stick.carried:
		_stick.position = puppy.position + Vector3(world.body.facing * 0.28, 0.075, 0.07)
	else:
		_stick.position = Vector3(world.stick.position.x * Mesher.CELL_METRES,
			-world.stick.position.y * Mesher.CELL_METRES, 0.34)
	_stick.rotation.y = PI if world.stick.carried and world.body.facing < 0 else 0.0
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
	var result := {
		"loaded_chunks": _meshes.size(), "queued_chunks": _pending.size(),
		"max_remesh_ms": float(_max_remesh_usec) / 1000.0,
		"mean_remesh_ms": float(_remesh_total_usec) / maxf(1, _remesh_count) / 1000.0,
		"world_draw_calls": world_viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME
		),
	}
	if _world != null:
		result.merge(_world.lighting.metrics())
	return result


func _update_loaded_chunks() -> void:
	var centre := Grid.chunk_coordinate(Vector2i(_world.body.position.floor()))
	centre.x = clampi(centre.x, 0, floori(float(_world.grid.width - 1) / Chunk.SIZE))
	centre.y = clampi(centre.y, 0, floori(float(_world.grid.height - 1) / Chunk.SIZE))
	var needed: Dictionary[Vector2i, bool] = {}
	for coordinate: Vector2i in _world.lighting.changed_chunks(_world.grid):
		if _meshes.has(coordinate) and not _pending.has(coordinate):
			_pending.append(coordinate)
	for row in range(centre.y - LOAD_RADIUS.y, centre.y + LOAD_RADIUS.y + 1):
		for column in range(centre.x - LOAD_RADIUS.x, centre.x + LOAD_RADIUS.x + 1):
			var coordinate := Vector2i(column, row)
			if not _world.grid.contains(coordinate * Chunk.SIZE):
				continue
			needed[coordinate] = true
			if (not _meshes.has(coordinate) or _world.grid.dirty_chunks.has(coordinate)
				or _mesh_light_versions.get(coordinate, -1) != _world.lighting.version(coordinate)) \
				and not _pending.has(coordinate):
				_pending.append(coordinate)
	for coordinate: Vector2i in _meshes.keys():
		if not needed.has(coordinate):
			_meshes[coordinate].queue_free()
			_meshes.erase(coordinate)
			_mesh_light_versions.erase(coordinate)
	_world.lighting.retain_chunks(needed)
	_pending = _pending.filter(func(at: Vector2i) -> bool: return needed.has(at))
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(centre) < b.distance_squared_to(centre))


func _remesh(coordinate: Vector2i) -> void:
	_world.grid.chunk_at(coordinate)
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbour := coordinate + offset
		if _world.grid.contains(neighbour * Chunk.SIZE):
			_world.grid.chunk_at(neighbour)
	var codes := _world.lighting.mesh_codes(_world.grid, coordinate, _nose)
	var start := Time.get_ticks_usec()
	var mesh := Mesher.build(_world.grid, coordinate, codes)
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
	_mesh_light_versions[coordinate] = _world.lighting.version(coordinate)
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


func _build_stick() -> void:
	var builder := Builder.new()
	builder.box(Vector3.ZERO, Vector3(0.35, 0.06, 0.055), Color("a96d44"))
	for end: float in [-0.16, 0.16]:
		builder.box(Vector3(end, 0, 0.002), Vector3(0.03, 0.062, 0.057), Color("edc592"))
	builder.box(Vector3(0.065, 0.035, 0), Vector3(0.06, 0.04, 0.045), Color("b98554"))
	var material := StandardMaterial3D.new()
	_stick_material = material
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	_stick = MeshInstance3D.new()
	_stick.name = "FetchStick"
	_stick.mesh = builder.finish()
	_stick.material_override = material
	_stick.hide()
	_stage.add_child(_stick)


func _update_lighting(world: World) -> void:
	var at := Vector2i(world.body.position.floor())
	if at != _nose_cell or world.grid.revision != _nose_revision:
		_queue_nose_chunks(_nose_cell)
		_nose = world.lighting.nose_field(world.grid, at)
		_nose_cell = at
		_nose_revision = world.grid.revision
		_queue_nose_chunks(at)
	var daylight := world.clock.daylight()
	_material.set_shader_parameter("daylight", daylight)
	_environment.background_color = Color("17233f").lerp(Color("bed9d7"), daylight)
	_apply_actor_light(world)


func _apply_actor_light(world: World) -> void:
	var at := Vector2i(world.body.position.floor())
	if world.grid.contains(at) \
		and not world.lighting.is_current(world.grid, Grid.chunk_coordinate(at)):
		return
	var daylight := world.clock.daylight()
	var level := world.lighting.level_at(world.grid, at, daylight, _nose)
	puppy.set_illumination(_light_color(level, daylight), level < 8.0)
	var stick_cell := Vector2i(world.stick.position.floor())
	var distance := Grid.chunk_coordinate(stick_cell) - Grid.chunk_coordinate(at)
	if world.stick.carried:
		_stick_material.albedo_color = _light_color(level, daylight)
	elif absi(distance.x) <= LOAD_RADIUS.x and absi(distance.y) <= LOAD_RADIUS.y:
		if world.grid.contains(stick_cell) \
			and not world.lighting.is_current(world.grid, Grid.chunk_coordinate(stick_cell)):
			return
		_stick_material.albedo_color = _light_color(
			world.lighting.level_at(world.grid, stick_cell, daylight, _nose), daylight)


func _queue_nose_chunks(at: Vector2i) -> void:
	if at.x < 0:
		return
	var first := Grid.chunk_coordinate(at - Vector2i.ONE * Lighting.NOSE_LIGHT)
	var last := Grid.chunk_coordinate(at + Vector2i.ONE * Lighting.NOSE_LIGHT)
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			var coordinate := Vector2i(column, row)
			if _meshes.has(coordinate) and not _pending.has(coordinate):
				_pending.append(coordinate)


func _light_color(level: float, daylight: float) -> Color:
	var color := Color("a4bdec").lerp(Color.WHITE, daylight) \
		* (0.2 + 0.8 * clampf(level / Lighting.MAX_LIGHT, 0.0, 1.0))
	color.a = 1.0
	return color


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
