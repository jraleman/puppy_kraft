extends SceneTree

## Actual rendered layouts, mouse projection, remeshing and bounded viewport draw calls.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const View = preload("res://games/puppy_kraft/world/world_view.gd")
const Mesher = preload("res://games/puppy_kraft/world/chunk_mesher.gd")
const Grid = preload("res://games/puppy_kraft/sim/world_grid.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")

var _failures := PackedStringArray()
var _capture_directory := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Puppy Kraft world-view tests require a real graphics window.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--puppy-capture-dir="):
			_capture_directory = argument.trim_prefix("--puppy-capture-dir=")
	_run.call_deferred()


func _run() -> void:
	var world := World.new(42)
	world.clock.phase_units = world.clock.DAWN_END
	world.advance(Body.STEP, Frame.new())
	var resource := Vector2i(world.body.position.floor()) + Vector2i(4, 4)
	assert(world.grid.set_block(resource, Blocks.CRYSTAL) == OK)
	var composite := SubViewport.new()
	composite.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(composite)
	var view := View.new()
	composite.add_child(view)
	var cave := _cave_world()
	var layouts: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(540, 960), Vector2i(2560, 1080)]
	for layout in layouts:
		composite.size = layout
		view.size = Vector2(layout)
		view.present(world)
		for frame in 48:
			var queued_before := int(view.metrics()["queued_chunks"])
			var lights_before := int(world.lighting.metrics()["light_builds"])
			await process_frame
			view.present(world)
			_expect(queued_before - int(view.metrics()["queued_chunks"]) <= 2,
				"A single graphics frame must process at most two queued chunk remeshes.")
			_expect(int(world.lighting.metrics()["light_builds"]) - lights_before <= 1,
				"Presentation and meshing together must prepare at most one cold light field per frame.")
		await RenderingServer.frame_post_draw
		_expect(view.world_viewport.own_world_3d and view.world_viewport.gui_disable_input,
			"The real rendered viewport must remain isolated from shell input and physics.")
		var pup := view.screen_position(world.body.position)
		var target := view.screen_position(Vector2(world.target_cell) + Vector2.ONE * 0.5)
		var bounds := Rect2(Vector2.ONE * 12, view.size - Vector2.ONE * 24)
		_expect(bounds.has_point(pup) and bounds.has_point(target),
			"Pup and target must stay in shot for %s." % layout)
		_expect(view.screen_to_cell(target) == world.target_cell,
			"Mouse projection must aim at the rendered tile for %s." % layout)
		var metrics := view.metrics()
		_expect(int(metrics["loaded_chunks"]) <= 35 and int(metrics["queued_chunks"]) == 0,
			"The renderer must finish its bounded two-per-frame queue without exceeding 35 chunks.")
		_expect(int(metrics["world_draw_calls"]) > 0 and int(metrics["world_draw_calls"]) < 100,
			"The rendered surface shot must use fewer than 100 real world draw calls.")
		_expect(float(metrics["max_remesh_ms"]) < 2.0,
			"A warmed chunk remesh must stay under the 2 ms spike budget on the test desktop.")
		var image := view.world_viewport.get_texture().get_image()
		_expect(not image.is_empty(), "A graphics test must capture actual pixels, not a dummy texture.")
		var pup_pixel := Vector2i(pup * Vector2(image.get_size()) / view.size)
		var sky := image.get_pixel(0, 0)
		_expect(not image.get_pixelv(pup_pixel).is_equal_approx(sky),
			"The projected puppy must occupy actual rendered pixels, not only a model transform.")
		_expect(not image.get_pixel(image.get_width() / 2, image.get_height() * 2 / 3)
			.is_equal_approx(sky), "The surface shot must contain actual terrain below the pup.")
		print("World view ", layout, ": ", metrics)
		if not _capture_directory.is_empty():
			assert(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK)
			assert(image.save_png(_capture_directory.path_join(
				"world_%dx%d.png" % [layout.x, layout.y])) == OK)
		await _test_daylight_pixels(world, view, composite, layout)
		await _test_sniff_pixels(world, view, composite, resource, layout)
		await _test_bark_pixels(world, view, composite, layout)
		await _test_stick_pixels(world, view, composite, layout)
		await _test_cave_pixels(cave, view, composite, layout)
		view.present(world)
		for frame in 24:
			await process_frame
	var burst := Frame.new()
	for bark in 8:
		burst.bark_edges.append_array([true, false])
	world.advance(Body.STEP, burst)
	for event: Dictionary in world.take_events():
		if str(event["type"]) == "barked":
			view.show_bark(event)
	view.present(world)
	_expect((view.bark_rings.get("_rings") as Array).size() == 4,
		"A burst of real bark events must not grow the feedback queue beyond four rings.")
	view.clear_barks()
	var changed := world.target_cell
	assert(world.grid.set_block(changed, Blocks.WOOD) == OK)
	view.present(world)
	for frame in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	_expect(not world.grid.dirty_chunks.has(
		preload("res://games/puppy_kraft/sim/world_grid.gd").chunk_coordinate(changed)),
		"A real terrain edit must remesh its visible chunk.")
	view.reduced_motion = true
	view.present(world, 0.5)
	var tail := view.puppy.get("_tail") as Node3D
	var tail_rotation := tail.rotation
	view.present(world, 1.0)
	_expect(tail.rotation == tail_rotation,
		"Reduced motion must park the decorative tail in actual rendered gameplay.")
	composite.free()
	await process_frame
	if _failures.is_empty():
		print("Puppy Kraft world-view tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_sniff_pixels(world: World, view: View, composite: SubViewport,
	resource: Vector2i, layout: Vector2i) -> void:
	var normal := composite.get_texture().get_image()
	var frame := Frame.new()
	frame.sniff = true
	world.advance(Body.STEP, frame)
	view.present(world, 0.2)
	await process_frame
	await RenderingServer.frame_post_draw
	var sniff := composite.get_texture().get_image()
	var normal_sky := normal.get_pixel(0, 0)
	var sniff_sky := sniff.get_pixel(0, 0)
	_expect(absf(sniff_sky.r - sniff_sky.g) < absf(normal_sky.r - normal_sky.g) * 0.5,
		"Sniff-vision must desaturate actual world pixels without recolouring the shell.")
	var at := Vector2i(view.screen_position(Vector2(resource) + Vector2.ONE * 0.5))
	var marker := sniff.get_pixelv(at)
	_expect(marker.g > marker.r + 0.15 and marker.b > marker.r + 0.15,
		"A buried ore trail must render a coloured, shaped marker through solid front terrain.")
	_expect(view.scent_trails.visible and not world.scent.outlines.is_empty(),
		"The live composite must include model-derived buried-resource outlines.")
	if not _capture_directory.is_empty():
		assert(sniff.save_png(_capture_directory.path_join(
			"sniff_%dx%d.png" % [layout.x, layout.y])) == OK)
	view.reduced_motion = true
	view.present(world, 1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var parked := composite.get_texture().get_image()
	view.present(world, 1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(parked.get_data() == composite.get_texture().get_image().get_data(),
		"Reduced motion must park scent arrows and decorative animation in real rendered pixels.")
	world.advance(Body.STEP, Frame.new())
	view.reduced_motion = false
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(not view.scent_trails.visible,
		"Ending sniffing must remove its overlay rather than leave stale resource markers.")


func _test_daylight_pixels(world: World, view: View, composite: SubViewport,
	layout: Vector2i) -> void:
	view.reduced_motion = true
	var day := world.clock.day
	world.clock.day = 1
	world.clock.phase_units = world.clock.DAWN_END
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var daylight := composite.get_texture().get_image()
	var builds := int(world.lighting.metrics()["light_builds"])
	world.clock.phase_units = world.clock.NIGHT_START
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var night := composite.get_texture().get_image()
	var ground := Vector2i(view.screen_position(world.body.position + Vector2(0, 1.0)))
	_expect(_luminance(night.get_pixel(0, 0)) < _luminance(daylight.get_pixel(0, 0)) * 0.8
		and _luminance(night.get_pixelv(ground)) < _luminance(daylight.get_pixelv(ground)) * 0.8
		and _luminance(night.get_pixelv(ground)) > 0.025,
		"Night must darken actual sky and terrain pixels while keeping the ground readable in %s." % layout)
	_expect(int(world.lighting.metrics()["light_builds"]) == builds,
		"Changing daylight must reuse vertex light, not relight every loaded chunk.")
	if not _capture_directory.is_empty():
		assert(night.save_png(_capture_directory.path_join(
			"night_%dx%d.png" % [layout.x, layout.y])) == OK)
	world.clock.day = 8
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var moon := composite.get_texture().get_image()
	_expect(_luminance(moon.get_pixel(0, 0)) > _luminance(night.get_pixel(0, 0)),
		"A full moon must brighten the real night, not only change a model flag.")
	world.clock.day = day
	world.clock.phase_units = world.clock.DAWN_END
	view.reduced_motion = false
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw


func _cave_world() -> World:
	var cave := World.new(42)
	var grid := Grid.new(42)
	grid.width = 192
	grid.height = 192
	for row in 6:
		for column in 6:
			var coordinate := Vector2i(column, row)
			var chunk := Chunk.new(coordinate)
			chunk.back.fill(Blocks.STONE)
			grid.chunks[coordinate] = chunk
	cave.grid = grid
	cave.body.position = Vector2(96.5, 98.6)
	cave.clock.phase_units = cave.clock.NIGHT_START
	for column in grid.width:
		assert(grid.set_block(Vector2i(column, 99), Blocks.STONE) == OK)
	assert(grid.set_block(Vector2i(101, 94), Blocks.CRYSTAL) == OK)
	return cave


func _test_cave_pixels(cave: World, view: View, composite: SubViewport,
	layout: Vector2i) -> void:
	cave.body.position = Vector2(96.5, 98.6)
	view.reduced_motion = true
	view.present(cave)
	for frame in 48:
		await process_frame
	await RenderingServer.frame_post_draw
	var before := composite.get_texture().get_image()
	var crystal := Vector2i(view.screen_position(Vector2(101.5, 94.5)))
	var dark := Vector2i(view.screen_position(Vector2(91.5, 92.5)))
	var glow_cell := Vector2(95.5, 98.5)
	var glowing := _luminance(before.get_pixelv(Vector2i(view.screen_position(glow_cell))))
	_expect(_luminance(before.get_pixelv(crystal)) > _luminance(before.get_pixelv(dark)) + 0.08,
		"Crystal must illuminate actual cave pixels even without skylight in %s." % layout)
	if not _capture_directory.is_empty():
		assert(before.save_png(_capture_directory.path_join(
			"cave_%dx%d.png" % [layout.x, layout.y])) == OK)
	cave.body.position.x += 2.0
	view.present(cave)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var after := composite.get_texture().get_image()
	var abandoned := _luminance(after.get_pixelv(Vector2i(view.screen_position(glow_cell))))
	_expect(glowing > abandoned + 0.015,
		"The nose must light nearby world pixels and leave them behind when moving under reduced motion.")
	_expect(int(view.metrics()["light_chunks"]) <= 35,
		"Cave travel must keep the light-field cache bounded along with its meshes.")
	view.reduced_motion = false


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_bark_pixels(world: World, view: View, composite: SubViewport,
	layout: Vector2i) -> void:
	var frame := Frame.new()
	frame.bark = true
	frame.bark_edges.append(true)
	world.advance(Body.STEP, frame)
	frame.bark_edges.clear()
	world.advance(Body.STEP * 29.0, frame)
	frame.bark = false
	frame.bark_edges.append(false)
	world.advance(Body.STEP, frame)
	var barks: Array[Dictionary] = []
	for event: Dictionary in world.take_events():
		if str(event["type"]) == "barked":
			barks.append(event)
	_expect(barks.size() == 1, "The graphics fixture must use a real emitted Woof.")
	if barks.size() != 1:
		return
	var bark := barks[0]
	var origin: Vector2 = bark["position"]
	view.present(world)
	for rendered in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var normal := composite.get_texture().get_image()
	view.show_bark(bark)
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var early := composite.get_texture().get_image()
	var start := view.screen_position(origin + Vector2(7.0 * 0.15, 0))
	_expect(_changed_near(normal, early, start),
		"An emitted bark must draw real wave pixels rather than only maintain a hidden event.")
	world.advance(Body.STEP * 12.0, Frame.new())
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var expanded := composite.get_texture().get_image()
	var radius := 7.0 * lerpf(0.15, 1.0, 1.0 - pow(1.0 - 12.0 / 42.0, 2.0))
	_expect(_changed_near(normal, expanded, view.screen_position(origin + Vector2(radius, 0))),
		"Ordinary bark feedback must expand with simulation time in the actual composite.")
	if not _capture_directory.is_empty():
		assert(expanded.save_png(_capture_directory.path_join(
			"bark_%dx%d.png" % [layout.x, layout.y])) == OK)
	view.clear_barks()
	view.reduced_motion = true
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	normal = composite.get_texture().get_image()
	view.show_bark(bark)
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var parked := composite.get_texture().get_image()
	var edge := view.screen_position(origin + Vector2(0, -7.0))
	_expect(_changed_near(normal, parked, edge),
		"Reduced motion must show the full static bark radius immediately.")
	view.present(world, 1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(parked.get_data() == composite.get_texture().get_image().get_data(),
		"Without simulation time, reduced-motion bark pixels must remain completely parked.")
	world.advance(Body.STEP * 6.0, Frame.new())
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var faded := composite.get_texture().get_image()
	_expect(_changed_near(normal, faded, edge),
		"Reduced-motion feedback may fade but must keep the same ring geometry.")
	view.intense_effects = false
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var calm := composite.get_texture().get_image()
	_expect(_changed_near(normal, calm, edge) and _changed_near(faded, calm, edge),
		"Disabling intense effects must visibly soften the ring without hiding useful feedback.")
	world.advance(Body.STEP * 42.0, Frame.new())
	view.present(world)
	_expect(not view.bark_rings.visible, "Expired bark events must remove their visual feedback.")
	view.reduced_motion = false
	view.intense_effects = true
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw


func _changed_near(before: Image, after: Image, point: Vector2) -> bool:
	var at := Vector2i(point)
	for y in range(maxi(0, at.y - 3), mini(after.get_height(), at.y + 4)):
		for x in range(maxi(0, at.x - 3), mini(after.get_width(), at.x + 4)):
			if not before.get_pixel(x, y).is_equal_approx(after.get_pixel(x, y)):
				return true
	return false


func _test_stick_pixels(world: World, view: View, composite: SubViewport,
	layout: Vector2i) -> void:
	world.stick.position = world.body.position + Vector2(1.0, 0.2)
	world.stick.velocity = Vector2.ZERO
	view.present(world)
	var stick := view.get("_stick") as MeshInstance3D
	stick.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var empty := composite.get_texture().get_image()
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var loose := composite.get_texture().get_image()
	_expect(_changed_near(empty, loose, view.screen_position(world.stick.position)),
		"The loose stick must occupy actual world pixels in %s." % layout)
	var frame := Frame.new()
	frame.carry_pressed = true
	world.advance(Body.STEP, frame)
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var held := composite.get_texture().get_image()
	var mouth := view.camera.unproject_position(stick.position) * view.size \
		/ Vector2(view.world_viewport.size)
	_expect(world.stick.carried and stick.position.distance_to(view.puppy.position) < 0.4
		and _changed_near(loose, held, mouth),
		"Real pickup must move visible stick pixels to the puppy's mouth in %s." % layout)
	frame.carry_pressed = false
	frame.move = 1.0
	world.advance(Body.STEP * 12.0, frame)
	frame.carry_pressed = true
	world.advance(Body.STEP, frame)
	world.advance(Body.STEP * 12.0, Frame.new())
	view.present(world, 0.2)
	await process_frame
	await RenderingServer.frame_post_draw
	if not _capture_directory.is_empty():
		assert(composite.get_texture().get_image().save_png(_capture_directory.path_join(
			"fetch_%dx%d.png" % [layout.x, layout.y])) == OK)
	view.reduced_motion = true
	var airborne := stick.position
	world.advance(Body.STEP * 6.0, Frame.new())
	view.present(world)
	_expect(not world.stick.carried and stick.position != airborne
		and is_equal_approx(stick.position.x, world.stick.position.x * Mesher.CELL_METRES),
		"Reduced motion must preserve essential model-driven projectile movement.")
	world.advance(Body.STEP * 180.0, Frame.new())
	frame = Frame.new()
	frame.sniff = true
	world.advance(Body.STEP, frame)
	view.present(world)
	await process_frame
	await RenderingServer.frame_post_draw
	var sniff := composite.get_texture().get_image()
	var origin := view.screen_position(
		world.body.position + Vector2(world.body.facing * 0.4, -0.15))
	var marker_at: Vector2 = view.scent_trails.call("_clip_target", origin,
		view.screen_position(world.stick.position))
	var marker := sniff.get_pixelv(Vector2i(marker_at))
	_expect(marker.r > marker.g + 0.12 and marker.g > marker.b + 0.08,
		"The actual lost-stick icon must render through the world, even clipped in portrait.")
	if not _capture_directory.is_empty():
		assert(sniff.save_png(_capture_directory.path_join(
			"stick_scent_%dx%d.png" % [layout.x, layout.y])) == OK)
	world.advance(Body.STEP, Frame.new())
	view.reduced_motion = false
	view.present(world, 0.2)
	await process_frame
	await RenderingServer.frame_post_draw
