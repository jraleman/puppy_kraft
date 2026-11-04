extends SceneTree

## Real keyboard bindings, Den Door, saved edits, pause, exit and the outing diary.

const Game = preload("res://games/puppy_kraft/game.gd")
const Options = preload("res://games/puppy_kraft/puppy_kraft_options.gd")
const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Saves = preload("res://games/puppy_kraft/sim/world_save.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Sound = preload("res://games/puppy_kraft/audio/bark_audio.gd")

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
	_settings.call("set_value", Options.SNIFF_MODE_KEY, Options.SNIFF_HOLD)
	_settings.call("set_value", Options.BARK_CHARGE_KEY, Options.BARK_HOLD)
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
		"Building and save status must clear the shared controls hint.")
	var view := game.get("_view") as Control
	var usual_height := view.size.y
	game.call("_set_capture_inset", 260.0)
	await process_frame
	_expect(dock.get_global_rect().end.y <= get_root().get_visible_rect().end.y - 260.0
		and view.size.y < usual_height,
		"Recorder clearance must lift the real ability HUD above its lesson card.")
	game.call("_set_capture_inset", 0.0)
	await process_frame
	_expect(is_equal_approx(view.size.y, usual_height),
		"Recorder-only clearance must not change the ordinary gameplay layout.")
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
	await _test_sniff_controls(game, world)
	await _test_bark_controls(game, world)
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
	_settings.call("set_value", Options.SNIFF_MODE_KEY, Options.SNIFF_TOGGLE)
	Input.action_press(Options.SNIFF)
	game.call("_update_round", Body.STEP, 0.0)
	Input.action_release(Options.SNIFF)
	game.call("_update_round", Body.STEP, 0.0)
	_expect(world.sniffing, "The real Toggle setting must latch after a registered key release.")
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
	_expect(not world.sniffing and not (game.get("_view") as Control).get("scent_trails").visible,
		"Opening a shared menu must clear the sniff toggle and its live trail overlay.")
	var pause_menu := game.get("_pause_menu") as Node
	pause_menu.call("resume")
	await process_frame
	_expect(not paused, "The shared Resume action must unpause the world.")
	game.call("_update_round", Body.STEP, 0.0)
	_expect(not world.sniffing, "Resume must not restart a cancelled sniff toggle.")
	_settings.call("set_value", Options.SNIFF_MODE_KEY, Options.SNIFF_HOLD)
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
	Input.action_press(Options.BARK)
	game.call("_update_round", Body.STEP * 35.0, 0.0)
	_expect(world.abilities.charge_level == 2,
		"The nap fixture must begin with a real unfinished bark charge.")
	Input.action_release(Options.BARK)
	game.call("_show_nap")
	var nap := game.get("_nap_dialog") as ConfirmationDialog
	_expect(nap.visible and world.abilities.charge_level == 0,
		"Call it a day must require the starting bed and cancel unfinished barking.")
	nap.hide()
	var bark_at_bed := Frame.new()
	bark_at_bed.bark = true
	bark_at_bed.bark_edges.append(true)
	world.advance(Body.STEP, bark_at_bed)
	bark_at_bed.bark_edges.clear()
	world.advance(Body.STEP * 30.0, bark_at_bed)
	bark_at_bed.bark = false
	bark_at_bed.bark_edges.append(false)
	bark_at_bed.mouse_aim = true
	bark_at_bed.mouse_cell = world.grid.generator.layout.bed_cell
	bark_at_bed.dig = true
	bark_at_bed.dig_pressed = true
	world.advance(Body.STEP, bark_at_bed)
	game.call("_update_round", 0.0, 0.0)
	_expect(nap.visible and world.abilities.emitted_total == 1
		and not (game.get("_view") as Control).get("bark_rings").visible,
		"A bark and bed-use in one tick must settle before the modal clears their feedback.")
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


func _test_sniff_controls(game: Node, world: World) -> void:
	var before := world.blocks_dug
	Input.action_press(Options.SNIFF)
	Input.action_press(Options.DIG)
	game.call("_update_round", Body.STEP, 0.0)
	var view := game.get("_view") as Control
	var dock := game.get("_dock") as Control
	var caption := dock.get("_target") as Label
	_expect(world.sniffing and world.blocks_dug == before and world.dig_progress == 0
		and caption.text.contains("Strong scent:") and view.get("scent_trails").visible,
		"Registered Hold sniff must suppress digging and show the actual strongest-scent caption.")
	await _capture("sniffing")
	Input.action_release(Options.SNIFF)
	Input.action_release(Options.DIG)
	game.call("_update_round", Body.STEP, 0.0)
	_expect(not world.sniffing and not view.get("scent_trails").visible,
		"Releasing the real Hold key must restore the ordinary world view.")
	var sniff_key := "controls/puppy_kraft_sniff"
	var original := int(_settings.call("binding_keycode", sniff_key))
	_expect(bool(_settings.call("set_binding_key", sniff_key, KEY_N, Options.GAME_ID)),
		"Sniff must be rebindable through the shared Controls registry.")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_N
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	_expect(world.sniffing and (game.get_node("%Hint") as Label).text.contains("N sniff"),
		"The rebound physical Sniff key and visible hint must agree.")
	key = InputEventKey.new()
	key.physical_keycode = KEY_N
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	_settings.call("set_binding_key", sniff_key, original, Options.GAME_ID)
	_settings.call("set_value", Options.SNIFF_MODE_KEY, Options.SNIFF_TOGGLE)
	Input.action_press(Options.SNIFF)
	game.call("_update_round", Body.STEP, 0.0)
	Input.action_release(Options.SNIFF)
	game.call("_update_round", Body.STEP, 0.0)
	_expect(world.sniffing, "A live switch to Toggle must use edge-triggered input.")
	_settings.call("set_value", Options.SNIFF_MODE_KEY, Options.SNIFF_HOLD)
	_expect(not world.sniffing,
		"Changing the sniff control mode must stop the old mode rather than inherit its latch.")


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


func _test_bark_controls(game: Node, world: World) -> void:
	var dock := game.get("_dock") as Control
	var view := game.get("_view") as Control
	var ability := dock.get("_ability") as Label
	var status := dock.get("_status") as Label
	dock.call("show_message", "Retry the last save.", true)
	Input.action_press(Options.BARK)
	game.call("_update_round", Body.STEP, 0.0)
	_expect(world.abilities.charge_level == 1 and ability.text.contains("[1]")
		and ability.text.contains("Energy 100/100"),
		"The live Hold key must show numbered charge pips and the real energy budget.")
	Input.action_release(Options.BARK)
	game.call("_update_round", Body.STEP, 0.0)
	_expect(world.abilities.last_level == 1 and world.abilities.emitted_total == 1
		and ability.text.contains("Yip!") and view.get("bark_rings").visible,
		"A real quick release must emit a captioned Yip and visible sound-wave feedback.")
	_expect(status.text.contains("SAVE FAILED") and status.text.contains("Retry"),
		"Bark feedback must not overwrite an outstanding save-failure status.")
	game.call("_save_world", "World saved.")
	var binding := "controls/puppy_kraft_bark"
	var original := int(_settings.call("binding_keycode", binding))
	_expect(bool(_settings.call("set_binding_key", binding, KEY_N, Options.GAME_ID)),
		"Bark must be rebindable through the shared Controls registry.")
	_bark_key(KEY_N, true)
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_N
	echo.pressed = true
	echo.echo = true
	Input.parse_input_event(echo)
	await process_frame
	for tick in 29:
		game.call("_update_round", Body.STEP, 0.0)
	_expect(ability.text.contains("[2]") and ability.text.contains("Woof")
		and (game.get_node("%Hint") as Label).text.contains("N bark"),
		"A held rebound key must cross the actual Woof threshold and update its control hint.")
	await _capture("bark_charge")
	_bark_key(KEY_N, false)
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	_expect(world.abilities.emitted_total == 2 and world.abilities.last_level == 2
		and is_equal_approx(world.needs.energy, 97.0) and ability.text.contains("Woof!"),
		"Releasing the physical key must bark once; key echo must not create extra charges.")
	var routed := false
	for child in get_root().get_node("AudioManager").get_children():
		if child is AudioStreamPlayer and child.bus == "SFX" and child.stream == Sound.bark(2):
			routed = true
	_expect(routed, "The live bark must use the shared volume-controlled SFX pool.")
	await _capture("barking")
	_settings.call("set_value", Options.BARK_CHARGE_KEY, Options.BARK_TAP)
	for tap in 3:
		_bark_key(KEY_N, true)
		_bark_key(KEY_N, false)
	await process_frame
	game.call("_update_round", Body.STEP * 0.5, 0.0)
	game.call("_update_round", Body.STEP * 0.5, 0.0)
	_expect(world.abilities.charge_level == 3 and ability.text.contains("[3]"),
		"Three physical taps between sampled render frames must select Ruff, not disappear.")
	for tick in 35:
		game.call("_update_round", Body.STEP, 0.0)
	_expect(world.abilities.emitted_total == 3 and world.abilities.last_level == 3
		and is_equal_approx(world.needs.energy, 89.0),
		"The accessible quiet window must emit exactly one Ruff with its real eight-point cost.")
	game.call("open_pause_menu")
	await process_frame
	var cooldown := world.abilities.cooldown_ticks
	var energy := world.needs.energy
	await process_frame
	var saves: Saves = game.get("_saves")
	var saved := saves.read_slot(1)
	_expect(paused and cooldown > 0 and world.abilities.cooldown_ticks == cooldown
		and world.needs.energy == energy and int(saved["error"]) == OK
		and (saved["world"] as World).abilities.cooldown_ticks == cooldown
		and (saved["world"] as World).needs.energy == energy,
		"Pause must save and freeze the real cooldown and energy instead of clearing either.")
	_expect(not view.get("bark_rings").visible,
		"Shared menus must clear bark visuals without leaking them over their overlay.")
	(game.get("_pause_menu") as Node).call("resume")
	await process_frame
	game.call("_update_round", Body.STEP * cooldown, 0.0)
	Input.action_press(Options.BARK)
	game.call("_update_round", Body.STEP, 0.0)
	Input.action_release(Options.BARK)
	game.call("_update_round", Body.STEP, 0.0)
	_settings.call("set_value", Options.BARK_CHARGE_KEY, Options.BARK_HOLD)
	game.call("_update_round", Body.STEP * 40.0, 0.0)
	_expect(world.abilities.emitted_total == 3 and world.abilities.charge_level == 0,
		"Changing bark modes must cancel a pending tap without firing it later.")
	Input.action_press(Options.BARK)
	game.call("_update_round", Body.STEP * 40.0, 0.0)
	game.call("open_pause_menu")
	Input.action_release(Options.BARK)
	await process_frame
	(game.get("_pause_menu") as Node).call("resume")
	await process_frame
	game.call("_update_round", Body.STEP * 40.0, 0.0)
	_expect(world.abilities.emitted_total == 3 and world.abilities.charge_level == 0,
		"Resuming after a cancelled Hold charge must not interpret its release as a bark.")
	_settings.call("set_binding_key", binding, original, Options.GAME_ID)


func _bark_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


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
	await create_timer(Sound.bark(3).get_length() + 0.05, true, false, true).timeout
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
