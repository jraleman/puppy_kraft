extends RefCounted

## Records the real starter meadow through registered actions, never assigned poses or edits.

signal keycap_requested(text: String)

const Options = preload("res://games/puppy_kraft/puppy_kraft_options.gd")
const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Saves = preload("res://games/puppy_kraft/sim/world_save.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const STEPS: Array[Dictionary] = [
	{"time": 0.0, "title": "Your pup, your saved world",
		"body": "Choose a Den Door slot and enter a name and seed. Blank name means Pup; blank seed makes a random meadow."},
	{"time": 3.0, "title": "Run, jump and climb",
		"body": "A and D run, Space jumps, and W and S climb roots or ladders. One-cell tunnels fit. Falls never hurt."},
	{"time": 10.5, "title": "Dig to gather toy blocks",
		"body": "Face a block and hold J. Harder blocks take longer. Releasing the key cancels an unfinished dig."},
	{"time": 13.0, "title": "Back walls are a separate layer",
		"body": "Hold Shift while digging or placing to work behind the front blocks. Back walls never stop your puppy."},
	{"time": 15.0, "title": "Build with your material bag",
		"body": "Q and R cycle materials; K places one block. Most blocks need support, and you cannot build through the pup."},
	{"time": 18.2, "title": "Follow your nose",
		"body": "Hold L to sniff through walls: zigzags lead to crystal or glow moss, pawprints lead home. Read the strongest-scent caption. Toggle is available in Settings."},
	{"time": 20.4, "title": "Yip, Woof, Ruff!",
		"body": "Hold I and release at the numbered pips. Woof costs 3 energy, Ruff costs 8. Strong barks shake leaves; standing still restores energy. Tap to cycle is in Settings."},
	{"time": 29.0, "title": "Save, then return to your bed",
		"body": "Save world keeps your edits. Call it a day opens the saved diary; Keep going returns without regenerating terrain."},
]
const ACTIONS: Array[StringName] = [
	Options.LEFT, Options.RIGHT, Options.UP, Options.DOWN, Options.JUMP,
	Options.DIG, Options.PLACE, Options.BACK_WALL, Options.WHEEL_PREV, Options.WHEEL_NEXT,
	Options.SNIFF, Options.BARK,
]

var _done: Dictionary[String, bool] = {}
var _directory := ""


func configure(variant: String) -> bool:
	_done.clear()
	return variant == "solo"


func steps() -> Array[Dictionary]:
	return STEPS


func duration() -> float:
	return 34.0


func settings_overrides() -> Dictionary:
	return {
		Options.CAMERA_ZOOM_KEY: 1.0, Options.SNIFF_MODE_KEY: Options.SNIFF_HOLD,
		Options.BARK_CHARGE_KEY: Options.BARK_HOLD,
	}


func configure_session(session: Node) -> void:
	session.call("configure_single_player")


func start(scene: Node) -> void:
	_release_controls()
	_directory = "user://puppy_kraft_tutorial_%d" % OS.get_process_id()
	var saves := Saves.new(_directory)
	scene.set("save_directory", _directory)
	scene.set("_saves", saves)
	var door := scene.get("_door") as Control
	door.call("refresh", saves)
	door.call("_choose_slot", 1, false)
	(door.get_node("%PupName") as LineEdit).text = "Pup"
	(door.get_node("%SeedText") as LineEdit).text = "a sunny meadow"


func update(scene: Node, time: float, _delta: float) -> void:
	if _once("create", time >= 2.0):
		var door := scene.get("_door") as Control
		(door.get_node("%CreateWorld") as Button).pressed.emit()
	var world := scene.get("_world") as World
	if world == null or not bool(scene.get("_round_active")):
		_release_controls()
		return
	var layout := world.grid.generator.layout
	var wall := layout.bed_cell + Vector2i(-3, 0)
	_done["jumped"] = _done.get("jumped", false) \
		or (time >= 3.5 and time < 5.0 and world.body.velocity.y < -1.0)
	_done["climbed"] = _done.get("climbed", false) \
		or (world.body.climbing and world.body.position.y < float(wall.y) - 1.5)
	_done["front_dug"] = _done.get("front_dug", false) \
		or world.grid.get_block(wall, Chunk.FRONT) == Blocks.AIR
	_done["back_dug"] = _done.get("back_dug", false) \
		or world.grid.get_block(wall, Chunk.BACK) == Blocks.AIR
	_done["sniffed"] = _done.get("sniffed", false) \
		or (world.sniffing and not world.scent.trails.is_empty())
	for level in range(1, 4):
		var milestone := "bark_%d" % level
		_done[milestone] = _done.get(milestone, false) or world.abilities.last_level == level
	_done["energy_recovered"] = _done.get("energy_recovered", false) \
		or (time >= 25.0 and time < 26.4 and world.needs.energy > 89.1
			and world.needs.energy < 100.0)
	var direction := 0.0
	if time >= 3.0 and time < 5.0:
		direction = float(layout.spawn_column) + 8.5 - world.body.position.x
	elif time >= 7.2 and time < 10.5:
		direction = -1.0
	elif time >= 26.4 and time < 28.8:
		direction = float(layout.bed_cell.x) + 0.5 - world.body.position.x
	# A physical cursor hovering over the window must not change the keyboard lesson.
	scene.set("_mouse_aim", false)
	_hold(Options.LEFT, direction < -0.12, "A")
	_hold(Options.RIGHT, direction > 0.12, "D")
	_hold(Options.UP, time >= 5.0 and time < 6.3, "W")
	_hold(Options.JUMP, time >= 3.65 and time < 3.8, "Space")
	_hold(Options.DIG, (time >= 10.8 and time < 12.5 and world.blocks_dug < 1)
		or (time >= 13.0 and time < 15.0 and world.blocks_dug < 2), "J")
	_hold(Options.WHEEL_NEXT, (time >= 15.0 and time < 15.1)
		or (time >= 15.25 and time < 15.35) or (time >= 15.5 and time < 15.6), "R")
	_hold(Options.BACK_WALL, (time >= 13.0 and time < 15.0)
		or (time >= 16.0 and time < 16.6), "Shift")
	_hold(Options.PLACE, (time >= 16.0 and time < 16.2)
		or (time >= 17.0 and time < 17.2), "K")
	_hold(Options.SNIFF, time >= 18.2 and time < 20.2, "L")
	_hold(Options.BARK, (time >= 20.4 and time < 20.5)
		or (time >= 21.0 and time < 21.6) or (time >= 22.4 and time < 23.8), "I")
	if _once("save", time >= 29.0):
		(scene.get("_dock") as Control).emit_signal("save_requested")
	if _once("nap", time >= 29.7):
		scene.call("_show_nap")
	if _once("diary", time >= 30.7):
		var dialog := scene.get("_nap_dialog") as ConfirmationDialog
		if not dialog.visible:
			push_error("The tutorial did not reach the bed for a real nap.")
			return
		dialog.hide()
		dialog.confirmed.emit()


func validate_finished(scene: Node) -> bool:
	_release_controls()
	var world := scene.get("_world") as World
	if world == null:
		push_error("The tutorial never created its world.")
		return false
	var complete := not world.outing_open and world.blocks_dug == 2 and world.blocks_placed == 2
	for milestone: String in [
		"jumped", "climbed", "front_dug", "back_dug", "sniffed",
		"bark_1", "bark_2", "bark_3", "energy_recovered", "save", "diary",
	]:
		complete = complete and _done.get(milestone, false)
	var saves := scene.get("_saves") as Saves
	var loaded := saves.read_slot(1)
	if int(loaded["error"]) != OK:
		push_error(str(loaded["message"]))
		return false
	var saved := loaded["world"] as World
	complete = complete and saved.body.position == world.body.position \
		and not saved.outing_open and saved.blocks_dug == 2 and saved.blocks_placed == 2 \
		and world.abilities.emitted_total == 3 \
		and is_equal_approx(saved.needs.energy, world.needs.energy)
	if not complete:
		push_error("Puppy tutorial incomplete: dug=%d, placed=%d, at=%s, milestones=%s."
			% [world.blocks_dug, world.blocks_placed, world.body.position, _done])
		return false
	scene.set("_quit_without_save", true)
	var deleted := saves.delete_slot(1)
	if int(deleted["error"]) != OK:
		push_error(str(deleted["message"]))
		return false
	var error := DirAccess.remove_absolute(_directory)
	if error != OK:
		push_error("Could not remove the tutorial's save directory: %s." % error_string(error))
		return false
	return true


func _hold(action: StringName, pressed: bool, label: String) -> void:
	if pressed == Input.is_action_pressed(action):
		return
	if pressed:
		Input.action_press(action)
		keycap_requested.emit(label)
	else:
		Input.action_release(action)


func _release_controls() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _once(key: String, ready: bool) -> bool:
	if not ready or _done.get(key, false):
		return false
	_done[key] = true
	return true
