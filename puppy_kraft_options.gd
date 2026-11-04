extends RefCounted

## Preload-safe identifiers; later mechanics do not get empty Settings rows.

const GAME_ID := "puppy_kraft"
const CAMERA_ZOOM_KEY := "game/puppy_kraft_camera_zoom"
const SURVIVAL_PACE_KEY := "game/puppy_kraft_survival_pace"
const THREATS_KEY := "game/puppy_kraft_threats"
const RETREAT_PENALTY_KEY := "game/puppy_kraft_retreat_penalty"
const DAY_LENGTH_KEY := "game/puppy_kraft_day_length"
const CRAFT_GESTURES_KEY := "game/puppy_kraft_craft_gestures"
const SNIFF_MODE_KEY := "game/puppy_kraft_sniff_mode"
const BARK_CHARGE_KEY := "game/puppy_kraft_bark_charge"
const SEASONAL_EVENTS_KEY := "game/puppy_kraft_seasonal_events"
const TOUCH_LAYOUT_KEY := "game/puppy_kraft_touch_layout"

const LEFT := &"puppy_kraft_left"
const RIGHT := &"puppy_kraft_right"
const UP := &"puppy_kraft_up"
const DOWN := &"puppy_kraft_down"
const JUMP := &"puppy_kraft_jump"
const DIG := &"puppy_kraft_dig"
const PLACE := &"puppy_kraft_place"
const BACK_WALL := &"puppy_kraft_back_wall"
const WHEEL_PREV := &"puppy_kraft_wheel_prev"
const WHEEL_NEXT := &"puppy_kraft_wheel_next"
const SNIFF := &"puppy_kraft_sniff"
const SNIFF_HOLD := 0
const SNIFF_TOGGLE := 1
const BARK := &"puppy_kraft_bark"
const BARK_HOLD := 0
const BARK_TAP := 1

const TUNABLES: Array[Dictionary] = [
	{
		"key": CAMERA_ZOOM_KEY, "default": 1.0, "min": 0.8, "max": 1.25,
		"step": 0.05, "format": GameManifest.FORMAT_PERCENT,
		"title": "Camera zoom", "heading": "World view",
		"description": "Show more terrain or bring the pup closer. Applies immediately.",
	},
	{
		"key": SNIFF_MODE_KEY, "type": GameManifest.OPTION_CHOICE, "default": SNIFF_HOLD,
		"choices": [
			{"value": SNIFF_HOLD, "title": "Hold"},
			{"value": SNIFF_TOGGLE, "title": "Toggle"},
		],
		"title": "Sniff control", "heading": "The pup",
		"description": "Hold Sniff, or press once to start and again to stop. Menus stop sniffing.",
	},
	{
		"key": BARK_CHARGE_KEY, "type": GameManifest.OPTION_CHOICE, "default": BARK_HOLD,
		"choices": [
			{"value": BARK_HOLD, "title": "Hold"},
			{"value": BARK_TAP, "title": "Tap to cycle"},
		],
		"title": "Bark charge", "heading": "The pup",
		"description": "Hold and release, or tap 1-3 times then pause 0.6s. Menus cancel charging.",
	},
]

const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": "controls/puppy_kraft_left", "action": LEFT, "default": KEY_A,
		"title": "Move left", "player": 0, "movement": true, "heading": "The pup",
	},
	{
		"key": "controls/puppy_kraft_right", "action": RIGHT, "default": KEY_D,
		"title": "Move right", "player": 0, "movement": true, "heading": "The pup",
	},
	{
		"key": "controls/puppy_kraft_up", "action": UP, "default": KEY_W,
		"title": "Aim up / climb", "player": 0, "movement": true, "heading": "The pup",
	},
	{
		"key": "controls/puppy_kraft_down", "action": DOWN, "default": KEY_S,
		"title": "Aim down / descend", "player": 0, "movement": true, "heading": "The pup",
	},
	{
		"key": "controls/puppy_kraft_jump", "action": JUMP, "default": KEY_SPACE,
		"title": "Jump", "player": 0, "heading": "The pup",
	},
	{
		"key": "controls/puppy_kraft_sniff", "action": SNIFF, "default": KEY_L,
		"title": "Sniff", "player": 0, "heading": "The pup",
		"description": "Find crystal, glow moss and a trail home, even through blocks.",
	},
	{
		"key": "controls/puppy_kraft_bark", "action": BARK, "default": KEY_I,
		"title": "Bark", "player": 0, "heading": "The pup",
		"description": "Yip, Woof or Ruff. Stronger barks spend energy and shake loose leaves.",
	},
	{
		"key": "controls/puppy_kraft_dig", "action": DIG, "default": KEY_J,
		"title": "Dig / use bed", "player": 0, "heading": "Building",
		"description": "Hold to dig. At the starting bed, call it a day.",
	},
	{
		"key": "controls/puppy_kraft_place", "action": PLACE, "default": KEY_K,
		"title": "Place block", "player": 0, "heading": "Building",
	},
	{
		"key": "controls/puppy_kraft_back_wall", "action": BACK_WALL,
		"default": KEY_SHIFT, "title": "Back-wall modifier", "player": 0,
		"heading": "Building", "description": "Hold while digging or placing the back layer.",
	},
	{
		"key": "controls/puppy_kraft_wheel_prev", "action": WHEEL_PREV,
		"default": KEY_Q, "title": "Previous building block", "player": 0,
		"heading": "Building",
	},
	{
		"key": "controls/puppy_kraft_wheel_next", "action": WHEEL_NEXT,
		"default": KEY_R, "title": "Next building block", "player": 0,
		"heading": "Building",
	},
]

const SAVE_FILES: Array[Dictionary] = [
	{
		"path": "user://puppy_kraft_world_1.cfg", "title": "World 1",
		"description": "Seed, pup, building materials and changed terrain.",
	},
	{
		"path": "user://puppy_kraft_world_2.cfg", "title": "World 2",
		"description": "Seed, pup, building materials and changed terrain.",
	},
	{
		"path": "user://puppy_kraft_world_3.cfg", "title": "World 3",
		"description": "Seed, pup, building materials and changed terrain.",
	},
]

const BREEDS: Array[Dictionary] = []
const STORE_CURRENCY := {}
const STORE_SLOTS: Array[Dictionary] = []
const STORE_ITEMS: Array[Dictionary] = []
const GALLERY_EXHIBITS: Array[Dictionary] = []
const ADVENTURE_POINTS := {}
