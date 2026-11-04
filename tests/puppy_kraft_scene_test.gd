extends SceneTree

## Real keyboard bindings, Den Door, saved edits, pause, exit and the outing diary.

const Game = preload("res://games/puppy_kraft/game.gd")
const Options = preload("res://games/puppy_kraft/puppy_kraft_options.gd")
const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Saves = preload("res://games/puppy_kraft/sim/world_save.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")

var _failures := PackedStringArray()
var _directory := ""
var _settings: Node
var _restore: Dictionary = {}
var _save_timer: Timer
var _save_mode := Node.PROCESS_MODE_INHERIT
var _capture_directory := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--puppy-capture-dir="):
			_capture_directory = argument.trim_prefix("--puppy-capture-dir=")
	_run.call_deferred()


func _run() -> void:
	print("Scene-test user profile: ", OS.get_user_data_dir())
	var manifest := Game.manifest()
	_expect(GameCatalog.get_manifest(manifest.id) != null,
		"The preload-safe manifest must be discovered by the real host catalog.")
	_settings = get_root().get_node("Settings")
	_restore = (_settings.get("_values") as Dictionary).duplicate(true)
	_save_timer = _settings.get("_save_timer") as Timer
	_save_mode = _save_timer.process_mode
	_save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	_save_timer.stop()
	var session := get_root().get_node("GameSession")
	session.call("configure_single_player")
	GameCatalog.select(Options.GAME_ID)
	_directory = "user://puppy_kraft_scene_test_%d" % OS.get_process_id()
	var game := await _open_game()
	if game == null:
		_finish()
		return
	var door := game.get("_door") as Control
	if door == null:
		_expect(false, "The live gameplay must construct its world selector.")
		game.free()
		_finish()
		return
	_expect(door.visible and game.get("_world") == null,
		"Den Door must appear before any world model starts ticking.")
	_expect((game.get_node("%RoundTimer") as Timer).is_stopped(),
		"The shell's countdown must never time out the sandbox.")
	await _capture("den_door")
	door.call("refresh", game.get("_saves"))
	door.call("refresh", game.get("_saves"))
	door.call("_choose_slot", 1, false)
	await process_frame
	_expect((door.get_node("%PupName") as LineEdit).has_focus(),
		"Queued slot refreshes must not focus removed buttons or steal the name form's focus.")
	(door.get_node("%PupName") as LineEdit).text = "Biscuit"
	(door.get_node("%SeedText") as LineEdit).text = "the first meadow"
	await _capture("new_world")
	(door.get_node("%CreateWorld") as Button).pressed.emit()
	var world: World = game.get("_world")
	if world == null:
		_expect(false, "The actual new-world form must create a saved, playable world.")
		game.free()
		_finish()
		return
	_expect(world.pup_name == "Biscuit" and not door.visible,
		"The player's pup name must reach the live world and close Den Door.")
	game.call("_update_round", Body.STEP, 0.0)
	var saves: Saves = game.get("_saves")
	_expect(saves.exists(1), "A created world must be persistent before its outing starts.")
	await process_frame
	await process_frame
	var dock := game.get("_dock") as Control
	var hint := game.get_node("%Hint") as Control
	_expect(dock.get_global_rect().end.y + 12.0 <= hint.get_global_rect().position.y,
		"Building and save status must clear the shared two-line controls hint.")
	await _capture("gameplay")
	var start := world.body.position
	Input.action_press(Options.RIGHT)
	for tick in 20:
		game.call("_update_round", Body.STEP, 0.0)
	Input.action_release(Options.RIGHT)
	for tick in 10:
		game.call("_update_round", Body.STEP, 0.0)
	_expect(world.body.position.x > start.x + 1.0,
		"The real keyboard adapter must run the puppy through the live model.")
	var jump_key := "controls/puppy_kraft_jump"
	var original_key := int(_settings.call("binding_keycode", jump_key))
	_expect(bool(_settings.call("set_binding_key", jump_key, KEY_Z, Options.GAME_ID)),
		"Jump must be rebindable through the shared Settings registry.")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	_expect(world.body.velocity.y < 0.0 and (game.get_node("%Hint") as Label).text.contains("Z jump"),
		"A rebound physical key must drive jumping and update the visible hint immediately.")
	key = InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	_settings.call("set_binding_key", jump_key, original_key, Options.GAME_ID)
	for tick in 120:
		game.call("_update_round", Body.STEP, 0.0)
	Input.action_press(Options.DOWN)
	Input.action_press(Options.DIG)
	for tick in Blocks.dig_ticks(Blocks.GRASS):
		game.call("_update_round", Body.STEP, 0.0)
	Input.action_release(Options.DOWN)
	Input.action_release(Options.DIG)
	_expect(world.blocks_dug == 1, "Holding the live Dig key must remove actual generated terrain.")
	var dug_cell := world.target_cell
	_expect(world.grid.get_block(dug_cell) == Blocks.AIR,
		"The dug tunnel must exist in the authoritative grid, not only its mesh.")
	world.points_pending = 73
	world.ticks = World.DAY_TICKS - 1
	game.call("_update_round", Body.STEP, 0.0)
	var saved := saves.read_slot(1)
	_expect(int(saved["error"]) == OK and (saved["world"] as World).ticks == World.DAY_TICKS
		and (saved["world"] as World).points_pending == 73,
		"The live dawn event must autosave the new day and unpaid outing points.")
	game.call("open_pause_menu")
	await process_frame
	var paused_ticks := world.ticks
	await process_frame
	await process_frame
	saved = saves.read_slot(1)
	_expect(paused and world.ticks == paused_ticks and int(saved["error"]) == OK
		and (saved["world"] as World).grid.get_block(dug_cell) == Blocks.AIR
		and (saved["world"] as World).points_pending == 73,
		"Pause must freeze simulation and persist terrain plus unpaid outing points.")
	var pause_menu := game.get("_pause_menu") as Node
	pause_menu.call("resume")
	await process_frame
	_expect(not paused, "The shared Resume action must unpause the world.")
	var old_zoom := float(_settings.call("tunable", Options.CAMERA_ZOOM_KEY))
	_settings.call("set_value", Options.CAMERA_ZOOM_KEY, 1.25)
	_expect(is_equal_approx(float((game.get("_view") as Control).get("zoom")), 1.25),
		"Camera zoom must apply live through the manifest setting.")
	_settings.call("set_value", Options.CAMERA_ZOOM_KEY, old_zoom)
	game.call("_set_reduced_motion_enabled", true)
	_expect(bool(game.get("_reduced_motion_enabled"))
		and bool((game.get("_view") as Control).get("reduced_motion")),
		"Reduced motion must update both the shared shell and world view.")
	game.call("_set_intense_effects_enabled", false)
	_expect(not bool(game.get("_intense_effects_enabled"))
		and not bool((game.get("_view") as Control).get("intense_effects")),
		"Intense effects must retain the shell's super-call contract.")
	Input.action_press(Options.RIGHT)
	game.call("_update_round", Body.STEP, 0.0)
	Input.action_release(Options.RIGHT)
	world.advance(Body.STEP * 0.5, Frame.new())
	var position := world.body.position
	var remainder := world.accumulator
	game.free()
	await process_frame
	saved = saves.read_slot(1)
	_expect(int(saved["error"]) == OK and (saved["world"] as World).body.position == position,
		"Leaving the gameplay tree must preserve the latest pup position.")
	game = await _open_game()
	game.call("_load_world", 1)
	world = game.get("_world")
	_expect(world != null and world.grid.get_block(dug_cell) == Blocks.AIR
		and world.points_pending == 73 and world.blocks_dug == 1
		and is_equal_approx(world.accumulator, remainder),
		"Reopening the slot must retain its tunnel, unfinished outing and fixed-step remainder.")
	if world == null:
		game.free()
		_finish()
		return
	world.body.position = Vector2(world.grid.generator.layout.bed_cell) + Vector2(0.5, 0.6)
	world.body.velocity = Vector2.ZERO
	world.advance(Body.STEP, Frame.new())
	game.call("_show_nap")
	var nap := game.get("_nap_dialog") as ConfirmationDialog
	_expect(nap.visible, "Call it a day must require the actual starting bed.")
	nap.hide()
	nap.confirmed.emit()
	_expect(not bool(game.get("_round_active")) and (game.get_node("%RoundOver") as Control).visible
		and (game.get_node("%ResultLabel") as Label).text.contains("DIARY"),
		"Confirming a real nap must reach the shared results panel.")
	_expect(not (game.get_node("%Announcement") as Control).visible,
		"A short outing must not leave its GO announcement over the diary.")
	await _capture("diary")
	saved = saves.read_slot(1)
	_expect(int(saved["error"]) == OK and not (saved["world"] as World).outing_open
		and (saved["world"] as World).points_pending == 73,
		"Closing an outing must be saved and must not erase points before rewards exist.")
	game.call("_on_play_again_pressed")
	_expect(bool(game.get("_round_active")) and world.outing_open
		and world.blocks_dug == 0 and world.grid.get_block(dug_cell) == Blocks.AIR
		and world.accumulator == 0.0,
		"Keep going must reset closed-outing statistics and timing, not regenerate terrain.")
	game.free()
	await process_frame
	_finish()


func _open_game() -> Node:
	var packed := load("res://games/puppy_kraft/gameplay.tscn") as PackedScene
	if packed == null:
		_expect(false, "The inherited gameplay scene must load after autoloads exist.")
		return null
	var game := packed.instantiate()
	game.set("save_directory", _directory)
	get_root().add_child(game)
	game.set_process(false)
	await process_frame
	await process_frame
	return game


func _finish() -> void:
	if _settings != null:
		_settings.set("_values", _restore)
		_save_timer.process_mode = _save_mode
	var saves := Saves.new(_directory)
	if saves.exists(1):
		_expect(int(saves.delete_slot(1)["error"]) == OK, "The scene fixture must clean up its world.")
	if DirAccess.dir_exists_absolute(_directory):
		_expect(DirAccess.remove_absolute(_directory) == OK,
			"The scene fixture must clean up only its own save directory.")
	await create_timer(0.15, true, false, true).timeout
	if _failures.is_empty():
		print("Puppy Kraft scene tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _capture(name: String) -> void:
	if _capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await create_timer(1.2, true, false, true).timeout
	await RenderingServer.frame_post_draw
	assert(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK)
	var image := get_root().get_texture().get_image()
	assert(image.save_png(_capture_directory.path_join(name + ".png")) == OK)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
