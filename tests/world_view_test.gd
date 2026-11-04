extends SceneTree

## Actual rendered layouts, mouse projection, remeshing and bounded viewport draw calls.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const View = preload("res://games/puppy_kraft/world/world_view.gd")
const Mesher = preload("res://games/puppy_kraft/world/chunk_mesher.gd")

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
	world.advance(Body.STEP, Frame.new())
	var resource := Vector2i(world.body.position.floor()) + Vector2i(4, 4)
	assert(world.grid.set_block(resource, Blocks.CRYSTAL) == OK)
	var composite := SubViewport.new()
	composite.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(composite)
	var view := View.new()
	composite.add_child(view)
	var layouts: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(540, 960), Vector2i(2560, 1080)]
	for layout in layouts:
		composite.size = layout
		view.size = Vector2(layout)
		view.present(world)
		for frame in 24:
			var queued_before := int(view.metrics()["queued_chunks"])
			await process_frame
			view.present(world)
			_expect(queued_before - int(view.metrics()["queued_chunks"]) <= 2,
				"A single graphics frame must process at most two queued chunk remeshes.")
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
		await _test_sniff_pixels(world, view, composite, resource, layout)
		await _test_bark_pixels(world, view, composite, layout)
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
