extends GameShell

## The shared shell around a saved solo world; Den Door and dialogs gate model ticks.

const Options = preload("res://games/puppy_kraft/puppy_kraft_options.gd")
const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Saves = preload("res://games/puppy_kraft/sim/world_save.gd")
const Seeds = preload("res://games/puppy_kraft/sim/seed_words.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Keys = preload("res://games/puppy_kraft/input/key_source.gd")
const View = preload("res://games/puppy_kraft/world/world_view.gd")
const BuildingHud = preload("res://games/puppy_kraft/ui/pk_hud.gd")
const Door = preload("res://games/puppy_kraft/ui/den_door.gd")
const DOOR_SCENE = preload("res://games/puppy_kraft/ui/den_door.tscn")
const DOCK_HEIGHT := 146.0

var save_directory := "user://"
var _saves: Saves
var _world: World
var _slot := 0
var _keys := Keys.new()
var _frame := Frame.new()
var _view: View
var _dock: BuildingHud
var _door: Door
var _nap_dialog: ConfirmationDialog
var _error_dialog: AcceptDialog
var _quit_dialog: ConfirmationDialog
var _mouse_aim := false
var _mouse_dig := false
var _mouse_place := false
var _wheel := 0
var _day_finished := false
var _quit_without_save := false
var _old_auto_accept_quit := true
var _last_save_ok := true


func game_id() -> String:
	return Options.GAME_ID


func _ready() -> void:
	_old_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	super()


func _prepare_session() -> void:
	if not GameSession.is_single_player():
		GameSession.configure_single_player()
	super()


func _load_round_settings() -> void:
	super()
	if _view != null:
		_view.zoom = float(Settings.tunable(Options.CAMERA_ZOOM_KEY))
		if _world != null:
			_view.present(_world)


func _build_playfield() -> void:
	_saves = Saves.new(save_directory)
	_view = View.new()
	_view.name = "PuppyWorld"
	_view.zoom = float(Settings.tunable(Options.CAMERA_ZOOM_KEY))
	_view.reduced_motion = _reduced_motion_enabled
	_view.intense_effects = _intense_effects_enabled
	_playfield.add_child(_view)
	_dock = BuildingHud.new()
	_dock.name = "BuildingHud"
	_dock.save_requested.connect(func() -> void: _save_world("World saved."))
	_dock.nap_requested.connect(_show_nap)
	_playfield.add_child(_dock)
	_dock.hide()
	_door = DOOR_SCENE.instantiate()
	_door.create_requested.connect(_create_world)
	_door.load_requested.connect(_load_world)
	_door.delete_requested.connect(_delete_world)
	_hud.add_child(_door)
	_nap_dialog = ConfirmationDialog.new()
	_nap_dialog.title = "Call it a day?"
	_nap_dialog.dialog_text = "Save this outing and open the Day's Diary? Keep going returns to this world."
	_nap_dialog.ok_button_text = "Call it a day"
	_nap_dialog.confirmed.connect(_call_it_a_day)
	_hud.add_child(_nap_dialog)
	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "World not saved"
	_hud.add_child(_error_dialog)
	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.title = "Quit without saving?"
	_quit_dialog.ok_button_text = "Quit without saving"
	_quit_dialog.confirmed.connect(func() -> void:
		_quit_without_save = true
		get_tree().quit())
	_hud.add_child(_quit_dialog)
	get_viewport().size_changed.connect(_resize_playfield)
	_hint.resized.connect(_resize_playfield)
	_dock.minimum_size_changed.connect(_resize_playfield)
	_resize_playfield()


func _begin_first_round() -> void:
	_start_round_after_transition()


func _reset_round_state() -> void:
	_day_finished = false
	_clear_controls()
	if _world == null:
		_door.refresh(_saves)
		_door.show()
		_dock.hide()
		return
	_world.begin_outing()
	_door.hide()
	_dock.show()
	_view.present(_world)
	_dock.present(_world)
	_save_world("Outing saved. Dig, build and return to the straw bed.")


func _activate_round() -> void:
	if _world != null:
		_show_announcement("GO, %s!" % _world.pup_name.to_upper(), StudioInfo.CREAM, 0.7)


func _create_world(slot: int, pup_name: String, seed_text: String) -> void:
	var seed := Seeds.from_text(seed_text)
	if seed_text.strip_edges().is_empty():
		var random := RandomNumberGenerator.new()
		random.randomize()
		seed = (int(random.randi()) << 32) | int(random.randi())
	var world := World.new(seed, pup_name, int(Time.get_unix_time_from_system()))
	var result := _saves.create_slot(slot, world)
	if int(result["error"]) != OK:
		_door.show_error(str(result["message"]))
		return
	_world = world
	_slot = slot
	_start_round()


func _load_world(slot: int) -> void:
	var result := _saves.read_slot(slot)
	if int(result["error"]) != OK:
		_door.show_error(str(result["message"]))
		return
	_world = result["world"]
	_slot = slot
	_start_round()


func _delete_world(slot: int) -> void:
	var result := _saves.delete_slot(slot)
	_door.refresh(_saves)
	if int(result["error"]) != OK:
		_door.show_error(str(result["message"]))


func _update_round(delta: float, _time_left: float) -> void:
	if _world == null or _door.visible or _nap_dialog.visible \
		or _error_dialog.visible or _quit_dialog.visible:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_dig = false
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_mouse_place = false
	var local_mouse := _view.get_local_mouse_position()
	var mouse_inside := Rect2(Vector2.ZERO, _view.size).has_point(local_mouse)
	var mouse_cell := _view.screen_to_cell(local_mouse) if mouse_inside else Vector2i.ZERO
	_frame = _keys.sample(mouse_cell, _mouse_aim and mouse_inside,
		_mouse_dig and mouse_inside, _mouse_place and mouse_inside, _wheel)
	_wheel = 0
	_world.advance(delta, _frame)
	for event: Dictionary in _world.take_events():
		match str(event["type"]):
			"dawn":
				_save_world("Dawn autosave / Day %d." % _world.day_number())
			"nap_requested":
				_show_nap()
			"error":
				push_error(str(event["message"]))
	_scores[PLAYER_ONE] = _world.points_pending
	_update_scores()
	_player_one_streak.show()
	_player_one_streak.text = "%d DUG / %d PLACED" % [_world.blocks_dug, _world.blocks_placed]
	_time_label.text = str(_world.day_number())
	_callout.text = _world.hint if not _world.hint.is_empty() else "SUNNY MEADOWS / PK1"
	_view.present(_world, delta)
	_dock.present(_world)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dig = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_place = false
	super(event)


func _handle_gameplay_input(event: InputEvent) -> void:
	if _world == null or _door.visible or _nap_dialog.visible \
		or _error_dialog.visible or _quit_dialog.visible:
		return
	if event is InputEventMouseMotion:
		if _view.get_global_rect().has_point(event.position):
			_mouse_aim = true
	elif event is InputEventMouseButton and event.pressed:
		if not _view.get_global_rect().has_point(event.position):
			return
		_mouse_aim = true
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_mouse_dig = true
			MOUSE_BUTTON_RIGHT:
				_mouse_place = true
			MOUSE_BUTTON_WHEEL_UP:
				_wheel -= 1
			MOUSE_BUTTON_WHEEL_DOWN:
				_wheel += 1
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		for action: StringName in [Options.LEFT, Options.RIGHT, Options.UP,
			Options.DOWN, Options.DIG, Options.PLACE]:
			if event.is_action_pressed(action):
				_mouse_aim = false
				break


func open_pause_menu() -> void:
	if _world != null and not _save_world("Autosaved before pause."):
		_error_dialog.dialog_text = (
			"Your latest changes could not be saved. The previous save is intact. "
			+ "Close this message and retry Save world before quitting."
		)
		_error_dialog.popup_centered(Vector2i(620, 220))
		return
	_clear_controls()
	super()


func _on_pause_closed() -> void:
	super()
	_clear_controls()


func _show_nap() -> void:
	if _world == null or not _world.near_bed() or not _round_active:
		return
	_clear_controls()
	_nap_dialog.popup_centered(Vector2i(620, 210))


func _call_it_a_day() -> void:
	if _world == null or not _round_active or not _world.near_bed():
		return
	_world.outing_open = false
	if not _save_world("Outing saved."):
		_world.outing_open = true
		return
	_day_finished = true
	_scores[PLAYER_ONE] = _world.points_pending
	_end_round()


func _finish_round() -> void:
	_clear_controls()
	if _announcement_tween and _announcement_tween.is_valid():
		_announcement_tween.kill()
	_announcement.hide()
	if _world != null and not _day_finished:
		_save_world("World saved.")


func _save_world(message: String) -> bool:
	if _world == null:
		return true
	var result := _saves.write_slot(_slot, _world)
	_last_save_ok = int(result["error"]) == OK
	if _last_save_ok:
		if is_instance_valid(_dock):
			_dock.show_message(message)
	else:
		var problem := str(result["message"])
		push_error("Puppy Kraft: %s" % problem)
		if is_instance_valid(_dock):
			_dock.show_message(problem, true)
	return _last_save_ok


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		if _world == null or _save_world("Saved before closing."):
			get_tree().quit()
		else:
			_clear_controls()
			_quit_dialog.dialog_text = (
				"Your latest changes could not be saved. Cancel to retry Save world, "
				+ "or quit and keep only the previous successful save."
			)
			_quit_dialog.popup_centered(Vector2i(620, 220))


func _exit_tree() -> void:
	if _world != null and not _quit_without_save:
		_save_world("Saved before leaving.")
	get_tree().auto_accept_quit = _old_auto_accept_quit


func _clear_controls() -> void:
	_keys.reset()
	_mouse_dig = false
	_mouse_place = false
	_wheel = 0
	if _world != null:
		_world.cancel_actions()


func _configure_mode_ui() -> void:
	super()
	_time_caption.text = "DAY" if _world != null else "DEN DOOR"
	_time_progress.hide()
	_player_one_streak.visible = _world != null
	_play_again_button.text = "Keep going"
	_round_instructions.text = "Keep going in this world, or return to the title."
	if _world != null:
		_player_one_caption.text += " / " + _world.pup_name
	_hint.text = "%s/%s run  |  %s/%s aim/climb  |  %s jump  |  %s dig  |  %s place" % [
		_key_label("left"), _key_label("right"), _key_label("up"), _key_label("down"),
		_key_label("jump"), _key_label("dig"), _key_label("place"),
	]
	_hint.text += "\n%s back wall  |  %s/%s material  |  Mouse: dig/place/wheel  |  Esc pause" % [
		_key_label("back_wall"), _key_label("wheel_prev"), _key_label("wheel_next"),
	]


func _key_label(suffix: String) -> String:
	return Settings.binding_key_label("controls/puppy_kraft_" + suffix)


func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key == Options.CAMERA_ZOOM_KEY:
		_load_round_settings()


func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.reduced_motion = value
		if _world != null:
			_view.present(_world)


func _set_intense_effects_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.intense_effects = value


func _playfield_bounds() -> Rect2:
	var bounds := super()
	var bottom := bounds.end.y
	if _hint.global_position.y > bounds.position.y:
		bottom = minf(bottom, _hint.global_position.y - 32.0)
	bounds.size.y = maxf(120.0, bottom - bounds.position.y - _dock_height())
	return bounds


func _dock_height() -> float:
	return maxf(DOCK_HEIGHT, _dock.get_combined_minimum_size().y + 8.0)


func _resize_playfield() -> void:
	var bounds := _playfield_bounds()
	_view.position = bounds.position
	_view.size = bounds.size
	_dock.position = Vector2(bounds.position.x, bounds.end.y + 8)
	_dock.size = Vector2(bounds.size.x, _dock_height() - 8)


func _round_totals() -> Dictionary:
	var changed := _world.blocks_dug + _world.blocks_placed if _world != null else 0
	return {"hits": changed, "attempts": changed}


func _player_stats(player_index: int) -> Dictionary:
	var active := player_index == PLAYER_ONE and _world != null
	return {
		"score": _scores[player_index], "hits": _world.blocks_dug if active else 0,
		"misses": _world.blocks_placed if active else 0, "accuracy": 0, "streak": 0,
		"details": [
			{"label": "Pup", "value": _world.pup_name},
			{"label": "World", "value": "Slot %d / Day %d / PK1" % [_slot, _world.day_number()]},
			{"label": "Seed", "value": Seeds.to_words(_world.grid.generator.layout.seed_value)},
			{"label": "Building", "value": "%d dug / %d placed" % [
				_world.blocks_dug, _world.blocks_placed,
			]},
			{"label": "Save", "value": "Saved locally" if _last_save_ok else "SAVE FAILED"},
			{"label": "Adventure", "value": "Rewards and Kibble arrive in later milestones."},
		] if active else [],
	}


func _describe_round_outcome(_player_one_total: int, _player_two_total: int) -> Dictionary:
	return {
		"result": "DAY'S DIARY / DAY %d" % _world.day_number() if _world != null \
			else "THE DEN DOOR",
		"subtitle": "%s dug %d %s and placed %d. %s" % [
			_world.pup_name, _world.blocks_dug,
			"block" if _world.blocks_dug == 1 else "blocks", _world.blocks_placed,
			"World saved." if _last_save_ok else "Latest changes NOT saved.",
		] if _world != null else "Choose a world slot to begin the block-world prototype.",
		"color": StudioInfo.CREAM,
	}


func _round_highlight_summary() -> String:
	return "%s / PK1 / terrain edits saved locally" % Seeds.to_words(
		_world.grid.generator.layout.seed_value
	) if _world != null else "Three saved worlds. One very small puppy."


func _round_points_earned(_player_one_total: int, _player_two_total: int) -> int:
	return 0
