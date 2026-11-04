extends RefCounted

## A saved, solo block-world prototype; unbuilt v1 features stay undeclared.

const Options = preload("res://games/puppy_kraft/puppy_kraft_options.gd")


static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Puppy Kraft"
	game.tagline = "Small pup. Big world. Bigger destiny."
	game.menu_order = 13
	game.gameplay_scene_path = "res://games/puppy_kraft/gameplay.tscn"
	game.tutorial_video_path = "res://games/puppy_kraft/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/puppy_kraft/assets/video/tutorial_poster.webp"
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.uses_shell_round_rules = false
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.tunables = Options.TUNABLES
	game.control_bindings = Options.CONTROL_BINDINGS
	game.save_files = Options.SAVE_FILES
	game.stats_url = "https://deskcansaw.com"
	game.copy = {
		"single_player_description": "Explore, dig and build in a saved meadow prototype.",
		"player_one_control_description": "Run, jump, climb, dig and place toy blocks.",
		"instructions_headline": "DIG. BUILD. GO, PUP!",
		"instructions_solo_summary": "Three saved worlds. One very small puppy.",
		"instructions_rules": (
			"This is the block-world prototype, not the finished adventure.\n"
			+ "Choose an empty Den Door slot, name your pup and enter any seed text. "
			+ "Blank seed text makes a random world. Its three seed words and number "
			+ "recreate the same terrain on another machine.\n"
			+ "Dig to gather materials, then place supported blocks. "
			+ "Ladders and roots can stand without support. You fit one-cell tunnels "
			+ "and never take fall damage.\n"
			+ "Return to the straw bed to Call it a day and see your diary. "
			+ "Save, pause, quitting and window close preserve your world. "
			+ "A failed save is reported, not treated as success.\n"
			+ "Needs, sniffing, crafting, quests, rewards, Pack mode and gamepad/touch "
			+ "controls arrive in later milestones."
		),
		"instructions_player_one_controls": (
			"Movement and directional aim share the four movement keys. "
			+ "Hold Dig, press Place, and cycle the selected building material. "
			+ "Hold the back-wall modifier to work on the recessed layer.\n"
			+ "Fixed solo mouse: left click digs, right click places, wheel cycles "
			+ "materials. Mouse reach is three cells; directional reach is 1.5 cells. "
			+ "Escape opens the shared pause menu."
		),
	}
	return game
