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
const Progress = preload("res://games/puppy_kraft/sim/first_steps.gd")

var _failures := PackedStringArray()
var _directory := ""
var _settings: Node
var _restore: Dictionary = {}
var _save_timer: Timer
var _save_mode := Node.PROCESS_MODE_INHERIT
var _capture_directory := ""


func _test_clock_controls(game: Node, world: World) -> void:
	var before := world.clock.snapshot()
	var dock := game.get("_dock") as Control
	dock.call("show_message", "Retry the last save.", true)
	var status := (dock.get("_status") as Label).text
	world.clock.day = 8
	world.clock.phase_units = world.clock.DUSK_START - 10
	game.call("_update_round", Body.STEP, 0.0)
	_expect((game.get("_callout") as Label).text.contains("head home")
		and (game.get("_time_caption") as Label).text == "DUSK",
		"Dusk must warn through the live shell without reusing the persistent save status.")
	await _capture("dusk")
	await _expect_readable_label(game.get("_callout") as Label,
		"The dusk warning must occupy readable, high-contrast pixels over the daytime sky.")
	var units := world.clock.phase_units
	_settings.call("set_value", Options.DAY_LENGTH_KEY, Options.DAY_SHORT)
	_expect(world.clock.phase_units == units and world.clock.day == 8,
		"Changing the real day-length setting must not skip the day or its current phase.")
	game.call("_update_round", Body.STEP, 0.0)
	_expect(world.clock.phase_units == units + 15,
		"The live clock must advance at the newly selected Short pace.")
	var night := world.clock.snapshot()
	night["phase_units"] = world.clock.NIGHT_START
	world.clock.restore(night)
	game.call("_update_round", 0.0, 0.0)
	_expect((game.get("_time_caption") as Label).text == "FULL MOON"
		and (dock.get("_status") as Label).text == status,
		"The eighth night must show its full-moon label while preserving save feedback.")
	await _capture("full_moon")
	_settings.call("set_value", Options.DAY_LENGTH_KEY, Options.DAY_NORMAL)
	world.clock.restore(before)
	game.call("_update_round", 0.0, 0.0)


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
	_settings.call("set_value", Options.DAY_LENGTH_KEY, Options.DAY_NORMAL)
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
	var first_steps := dock.get("_first_steps") as Control
	var prompt := first_steps.get("_prompt") as Label
	_expect(first_steps.visible and (first_steps.get("_title") as Label).text.contains("1/5")
		and world.first_steps.step == Progress.Step.MOVE,
		"A new world must show its first non-blocking lesson in the real HUD.")
	var temporary := saves.slot_path(1).get_basename() + ".tmp"
	var before_skip := world.first_steps.snapshot()
	var before_file := FileAccess.get_file_as_bytes(saves.slot_path(1))
	assert(DirAccess.make_dir_absolute(temporary) == OK)
	(first_steps.get("_skip") as Button).pressed.emit()
	_expect(world.first_steps.snapshot() == before_skip and first_steps.visible
		and (dock.get("_status") as Label).text.contains("SAVE FAILED")
		and FileAccess.get_file_as_bytes(saves.slot_path(1)) == before_file,
		"A failed Skip save must keep the lesson visible and preserve the prior world.")
	assert(DirAccess.remove_absolute(temporary) == OK)
	var hint := game.get_node("%Hint") as Control
	await process_frame
	await process_frame
	_expect(dock.get_global_rect().end.y + 12.0 <= hint.get_global_rect().position.y,
		"Building and save status must clear the shared controls hint.")
	var view := game.get("_view") as Control
	var usual_height := view.size.y
	game.call("_set_capture_inset", 260.0)
	await process_frame
	_expect(dock.get_global_rect().end.y <= get_root().get_visible_rect().end.y - 260.0
		and view.size.y < usual_height,
		"Recorder clearance must lift the real ability HUD above its lesson card: dock=%s, view=%s, root=%s."
			% [dock.get_global_rect(), view.get_global_rect(), get_root().get_visible_rect()])
	game.call("_set_capture_inset", 0.0)
	await process_frame
	_expect(is_equal_approx(view.size.y, usual_height),
		"Recorder-only clearance must not change the ordinary gameplay layout: %s vs %s."
			% [view.size.y, usual_height])
	await _capture("gameplay")
	await _expect_readable_label(first_steps.get("_title") as Label,
		"First Steps must occupy actual readable HUD pixels at this window size.")
	var move_binding := "controls/puppy_kraft_right"
	var original_move := int(_settings.call("binding_keycode", move_binding))
	_expect(bool(_settings.call("set_binding_key", move_binding, KEY_B, Options.GAME_ID))
		and prompt.text.contains(" / B."),
		"Rebinding a tutorial action must update its live prompt without waiting for physics.")
	var start := world.body.position
	_key_event(KEY_B, true)
	await process_frame
	for tick in 20:
		game.call("_update_round", Body.STEP, 0.0)
	_key_event(KEY_B, false)
	await process_frame
	for tick in 10:
		game.call("_update_round", Body.STEP, 0.0)
	_expect(world.body.position.x > start.x + 1.0,
		"The real keyboard adapter must run the puppy through the live model.")
	_settings.call("set_binding_key", move_binding, original_move, Options.GAME_ID)
	_expect(world.first_steps.step == Progress.Step.MOVE and world.first_steps.walked > 1.0,
		"Real movement must retain partial progress until the four-cell walking goal.")
	_expect(bool(game.call("_save_world", "First Steps progress saved.")),
		"The live Save action must accept partial walking progress.")
	var walking_save := saves.read_slot(1)
	_expect(int(walking_save["error"]) == OK
		and (walking_save["world"] as World).first_steps.step == world.first_steps.step
		and is_equal_approx((walking_save["world"] as World).first_steps.walked,
			world.first_steps.walked),
		"The live Save action must persist partial walking progress.")
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
	await _test_carry_controls(game, world)
	await _test_clock_controls(game, world)
	var down_key: Key = _settings.call("binding_keycode", "controls/puppy_kraft_down")
	var dig_key: Key = _settings.call("binding_keycode", "controls/puppy_kraft_dig")
	# Real keyboard events also reclaim directional aim from a hovering mouse.
	_key_event(down_key, true)
	_key_event(dig_key, true)
	await process_frame
	for tick in Blocks.dig_ticks(Blocks.GRASS):
		game.call("_update_round", Body.STEP, 0.0)
	_key_event(down_key, false)
	_key_event(dig_key, false)
	await process_frame
	_expect(world.blocks_dug == 1,
		"Holding the live Dig key must remove actual generated terrain: %s." % world.hint)
	_expect(world.first_steps.step == Progress.Step.SNIFF and prompt.text.contains("Hold"),
		"A real dig must advance the contextual prompt to the active sniff mode.")
	var dug_cell := world.target_cell
	_expect(world.grid.get_block(dug_cell) == Blocks.AIR,
		"The dug tunnel must exist in the authoritative grid, not only its mesh.")
	world.points_pending = 73
	world.ticks = World.DAY_TICKS - 1
	world.clock.restore_legacy(world.ticks)
	game.call("_update_round", Body.STEP, 0.0)
	var saved := saves.read_slot(1)
	_expect(int(saved["error"]) == OK and (saved["world"] as World).ticks == World.DAY_TICKS
		and (saved["world"] as World).points_pending == 73,
		"The live dawn event must autosave the new day and unpaid outing points.")
	_settings.call("set_value", Options.SNIFF_MODE_KEY, Options.SNIFF_TOGGLE)
	_expect(prompt.text.begins_with("Press "),
		"The sniff lesson must immediately reflect Toggle without a simulation tick.")
	Input.action_press(Options.SNIFF)
	game.call("_update_round", Body.STEP, 0.0)
	Input.action_release(Options.SNIFF)
	game.call("_update_round", Body.STEP, 0.0)
	_expect(world.sniffing, "The real Toggle setting must latch after a registered key release.")
	_expect(world.first_steps.step == Progress.Step.BARK
		and prompt.text.begins_with("Press L again to stop sniffing first."),
		"The next lesson must explain how to leave the active sniff mode before barking.")
	game.call("open_pause_menu")
	await process_frame
	var paused_ticks := world.ticks
	var paused_clock := world.clock.snapshot()
	var paused_progress := world.first_steps.snapshot()
	(first_steps.get("_skip") as Button).pressed.emit()
	await process_frame
	await process_frame
	saved = saves.read_slot(1)
	_expect(paused and world.ticks == paused_ticks and world.clock.snapshot() == paused_clock
		and world.first_steps.snapshot() == paused_progress
		and int(saved["error"]) == OK
		and (saved["world"] as World).first_steps.snapshot() == paused_progress
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
	_settings.call("set_value", Options.BARK_CHARGE_KEY, Options.BARK_TAP)
	_expect(prompt.text.contains("wait 0.6 seconds") and not world.sniffing,
		"The bark lesson must immediately describe the real Tap-to-cycle quiet window.")
	_settings.call("set_value", Options.BARK_CHARGE_KEY, Options.BARK_HOLD)
	_expect(prompt.text.begins_with("Tap and release "),
		"Returning to Hold must update the lesson without advancing its saved progress.")
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
	first_steps = (game.get("_dock") as Control).get("_first_steps") as Control
	_expect(world != null and world.grid.get_block(dug_cell) == Blocks.AIR
		and world.points_pending == 73 and world.blocks_dug == 1
		and world.first_steps.snapshot() == paused_progress and first_steps.visible
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
	var lesson_before_nap := world.first_steps.snapshot()
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
		and lesson_before_nap["step"] == Progress.Step.BARK
		and world.first_steps.step == Progress.Step.HOME
		and not (game.get("_view") as Control).get("bark_rings").visible,
		"A bark and bed-use in one tick must settle before the modal clears their feedback.")
	await _capture("first_steps_home")
	nap.hide()
	temporary = saves.slot_path(1).get_basename() + ".tmp"
	before_file = FileAccess.get_file_as_bytes(saves.slot_path(1))
	assert(DirAccess.make_dir_absolute(temporary) == OK)
	game.call("_call_it_a_day")
	_expect(world.outing_open and bool(game.get("_round_active"))
		and world.first_steps.step == Progress.Step.HOME
		and FileAccess.get_file_as_bytes(saves.slot_path(1)) == before_file,
		"A failed bed save must not finish the outing or its last lesson.")
	assert(DirAccess.remove_absolute(temporary) == OK)
	nap.confirmed.emit()
	_expect(not bool(game.get("_round_active")) and (game.get_node("%RoundOver") as Control).visible
		and (game.get_node("%ResultLabel") as Label).text.contains("DIARY"),
		"Confirming a real nap must reach the shared results panel.")
	_expect(not (game.get_node("%Announcement") as Control).visible,
		"A short outing must not leave its GO announcement over the diary.")
	await _capture("diary")
	saved = saves.read_slot(1)
	_expect(int(saved["error"]) == OK and not (saved["world"] as World).outing_open
		and (saved["world"] as World).first_steps.step == Progress.Step.DONE
		and (saved["world"] as World).points_pending == 73,
		"Closing an outing must be saved and must not erase points before rewards exist.")
	game.call("_on_play_again_pressed")
	_expect(bool(game.get("_round_active")) and world.outing_open
		and world.blocks_dug == 0 and world.grid.get_block(dug_cell) == Blocks.AIR
		and world.accumulator == 0.0,
		"Keep going must reset closed-outing statistics and timing, not regenerate terrain.")
	_expect(world.first_steps.step == Progress.Step.DONE and not first_steps.visible,
		"Finished First Steps must not restart when the player keeps going.")
	game.free()
	await process_frame
	await _test_skip_first_steps()
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
	_key_event(KEY_N, true)
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
	_key_event(KEY_N, false)
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
		_key_event(KEY_N, true)
		_key_event(KEY_N, false)
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


func _test_carry_controls(game: Node, world: World) -> void:
	_walk_to_stick(game, world)
	var binding := "controls/puppy_kraft_carry"
	var original := int(_settings.call("binding_keycode", binding))
	_expect(bool(_settings.call("set_binding_key", binding, KEY_N, Options.GAME_ID)),
		"Carry must be registered and rebindable through the shared Controls tab.")
	var dock := game.get("_dock") as Control
	var mouth := dock.get("_mouth") as Label
	var status := dock.get("_status") as Label
	dock.call("show_message", "Retry the last save.", true)
	_key_event(KEY_N, true)
	_key_event(KEY_N, false)
	await process_frame
	game.call("_update_round", Body.STEP * 0.5, 0.0)
	_expect(not world.stick.carried, "A short physical Carry tap must wait for its fixed tick.")
	game.call("_update_round", Body.STEP * 0.5, 0.0)
	_expect(world.stick.carried and mouth.text.contains("Mouth: stick")
		and (game.get_node("%Hint") as Label).text.contains("N carry/drop"),
		"A rebound tap entirely between samples must pick up and update the real mouth HUD.")
	_expect(status.text.contains("SAVE FAILED") and status.text.contains("Retry"),
		"Pickup feedback must not overwrite an outstanding save failure.")
	await _capture("carrying")
	_key_event(KEY_N, true)
	await process_frame
	game.call("_update_round", Body.STEP * 0.5, 0.0)
	game.call("open_pause_menu")
	await process_frame
	(game.get("_pause_menu") as Node).call("resume")
	await process_frame
	game.call("_update_round", Body.STEP * 0.5, 0.0)
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_N
	echo.pressed = true
	echo.echo = true
	Input.parse_input_event(echo)
	await process_frame
	game.call("_update_round", Body.STEP * 4.0, 0.0)
	_expect(world.stick.carried,
		"Pause must cancel a queued drop; a held key or its echo must not drop again on resume.")
	_key_event(KEY_N, false)
	await process_frame
	_key_event(KEY_N, true)
	await process_frame
	game.call("_update_round", Body.STEP * 8.0, 0.0)
	_expect(not world.stick.carried and mouth.text.contains("Dropped"),
		"A stopped press must drop once, not repick the stick on every held tick.")
	_key_event(KEY_N, false)
	await process_frame
	_key_event(KEY_N, true)
	_key_event(KEY_N, false)
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	Input.action_press(Options.RIGHT)
	game.call("_update_round", Body.STEP * 12.0, 0.0)
	_key_event(KEY_N, true)
	_key_event(KEY_N, false)
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	Input.action_release(Options.RIGHT)
	_expect(not world.stick.carried and world.stick.velocity.x > 0.0
		and world.stick.velocity.y < 0.0 and mouth.text.contains("Fetch!"),
		"The live running Carry input must throw the actual stick and caption it.")
	game.call("_update_round", Body.STEP * 12.0, 0.0)
	await _capture("fetching")
	game.call("open_pause_menu")
	await process_frame
	var airborne := world.stick.snapshot()
	var saves: Saves = game.get("_saves")
	var saved := saves.read_slot(1)
	await process_frame
	_expect(paused and world.stick.snapshot() == airborne and int(saved["error"]) == OK
		and (saved["world"] as World).stick.snapshot() == airborne,
		"Shared pause must freeze and save an in-flight stick without recalling or landing it.")
	(game.get("_pause_menu") as Node).call("resume")
	await process_frame
	game.call("_update_round", Body.STEP * 90.0, 0.0)
	Input.action_press(Options.SNIFF)
	game.call("_update_round", Body.STEP, 0.0)
	var found := false
	for source: Dictionary in world.scent.trails:
		found = found or source["kind"] == "stick"
	_expect(found and world.stick.velocity == Vector2.ZERO,
		"The landed throwable must become a genuine lost-item scent in live gameplay.")
	_walk_to_stick(game, world)
	_key_event(KEY_N, true)
	_key_event(KEY_N, false)
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	found = false
	for source: Dictionary in world.scent.trails:
		found = found or source["kind"] == "stick"
	_expect(world.sniffing and world.stick.carried and not found,
		"Following the trail and pressing Carry must recover that same stick while sniffing.")
	var prompt := ((dock.get("_first_steps") as Control).get("_prompt") as Label).text
	_expect(world.first_steps.step == Progress.Step.DIG
		and prompt.begins_with("Release L to stop sniffing first.")
		and prompt.contains("Drop your stick with N first."),
		"The dig lesson must explain both blockers using the actual rebound Carry key.")
	await _capture("stick_recovered")
	Input.action_release(Options.SNIFF)
	game.call("_update_round", Body.STEP, 0.0)
	_key_event(KEY_N, true)
	_key_event(KEY_N, false)
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	_expect(not world.stick.carried,
		"A stopped drop after fetching must free the mouth for the next building action.")
	_settings.call("set_binding_key", binding, original, Options.GAME_ID)


func _walk_to_stick(game: Node, world: World) -> void:
	for tick in 300:
		var offset := world.stick.position.x - world.body.position.x
		if absf(offset) <= 0.8:
			break
		Input.action_release(Options.LEFT)
		Input.action_release(Options.RIGHT)
		Input.action_press(Options.RIGHT if offset > 0.0 else Options.LEFT)
		game.call("_update_round", Body.STEP, 0.0)
	Input.action_release(Options.LEFT)
	Input.action_release(Options.RIGHT)
	game.call("_update_round", Body.STEP * 12.0, 0.0)
	_expect(world.body.position.distance_to(world.stick.position) <= 1.5,
		"The scene fixture must walk to the real toy, never assign its pose.")


func _test_skip_first_steps() -> void:
	var game := await _open_game()
	if game == null:
		return
	game.call("_create_world", 2, "Scout", "skip the lesson")
	var world: World = game.get("_world")
	var panel := (game.get("_dock") as Control).get("_first_steps") as Control
	var body := world.body.snapshot()
	var bag := world.inventory.duplicate()
	var edits := world.grid.edits.duplicate(true)
	(panel.get("_skip") as Button).pressed.emit()
	var saved := (game.get("_saves") as Saves).read_slot(2)
	_expect(world.first_steps.step == Progress.Step.DONE and not panel.visible
		and world.body.snapshot() == body and world.inventory == bag
		and world.grid.edits == edits and world.blocks_dug == 0 and world.blocks_placed == 0
		and int(saved["error"]) == OK
		and (saved["world"] as World).first_steps.step == Progress.Step.DONE,
		"The actual Skip button must save its dismissal without changing movement or inventory.")
	game.free()
	await process_frame
	game = await _open_game()
	game.call("_load_world", 2)
	panel = (game.get("_dock") as Control).get("_first_steps") as Control
	_expect(not panel.visible,
		"Reopening a skipped world must not repeat the prompts.")
	game.free()
	await process_frame


func _key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _finish() -> void:
	if _settings != null:
		_settings.set("_values", _restore)
		_save_timer.process_mode = _save_mode
	var saves := Saves.new(_directory)
	for slot in range(1, Saves.SLOT_COUNT + 1):
		if saves.exists(slot):
			_expect(int(saves.delete_slot(slot)["error"]) == OK,
				"The scene fixture must clean up its worlds.")
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


func _expect_readable_label(label: Label, message: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var bounds := label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, label.size)
	var image := get_root().get_texture().get_image()
	var pixel_scale := Vector2(image.get_size()) / get_root().get_visible_rect().size
	bounds = Rect2(bounds.position * pixel_scale, bounds.size * pixel_scale)
	var cream_pixels := 0
	for y in range(maxi(0, ceili(bounds.position.y)), mini(image.get_height(), floori(bounds.end.y))):
		for x in range(maxi(0, ceili(bounds.position.x)), mini(image.get_width(), floori(bounds.end.x))):
			var color := image.get_pixel(x, y)
			if color.r > 0.8 and color.r > color.b + 0.12 and color.g > color.b + 0.05:
				cream_pixels += 1
	_expect(label.is_visible_in_tree() and cream_pixels > 10,
		message + " (%d pixels in %s)" % [cream_pixels, bounds])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
