extends SceneTree

## Two-process fixture: trigger the real close hook, then independently read its save.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Saves = preload("res://games/puppy_kraft/sim/world_save.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const DIRECTORY := "user://puppy_kraft_window_close_fixture"
const EDIT_CELL := Vector2i(790, 120)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var saves := Saves.new(DIRECTORY)
	if OS.get_cmdline_user_args().has("--verify-window-close"):
		var result := saves.read_slot(1)
		if int(result["error"]) != OK:
			printerr("Window close did not leave a readable world: ", result)
			quit(1)
			return
		var world: World = result["world"]
		var valid := world.grid.get_block(EDIT_CELL) == Blocks.AIR and world.points_pending == 17
		assert(int(saves.delete_slot(1)["error"]) == OK)
		assert(DirAccess.remove_absolute(DIRECTORY) == OK)
		if valid:
			print("Window-close autosave verified in a separate process.")
		else:
			printerr("Window close lost the latest terrain or pending points.")
		quit(0 if valid else 1)
		return
	GameCatalog.select("puppy_kraft")
	get_root().get_node("GameSession").call("configure_single_player")
	var packed := load("res://games/puppy_kraft/gameplay.tscn") as PackedScene
	var game := packed.instantiate()
	game.set("save_directory", DIRECTORY)
	game.set_process(false)
	get_root().add_child(game)
	await process_frame
	game.call("_create_world", 1, "Pup", "window close")
	var world: World = game.get("_world")
	if world == null:
		printerr("Could not prepare the window-close world.")
		quit(1)
		return
	assert(world.grid.set_block(EDIT_CELL, Blocks.AIR) == OK)
	world.points_pending = 17
	print("Triggering WM_CLOSE_REQUEST with unsaved edits.")
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
