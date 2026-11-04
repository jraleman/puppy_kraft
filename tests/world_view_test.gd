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
	var view := View.new()
	get_root().add_child(view)
	var layouts: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(540, 960), Vector2i(2560, 1080)]
	for layout in layouts:
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
	view.free()
	await process_frame
	if _failures.is_empty():
		print("Puppy Kraft world-view tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
