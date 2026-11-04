extends RefCounted

## Stable block ids are part of both generator PK1 and the save format.

const AIR := 0
const MEADOW_SOIL := 1
const GRASS := 2
const CLAY := 3
const STONE := 4
const WOOD := 5
const LEAVES := 6
const ROOT := 7
const CRYSTAL := 8
const GLOW_MOSS := 9
const BED := 10
const LADDER := 11
const BEDROCK := 12
const COUNT := 13

const SOLID := 1
const CLIMBABLE := 2
const PLACEABLE_BACK := 4
const UNBREAKABLE := 8
const FREE_SUPPORT := 16

const DATA: Array[Dictionary] = [
	{"id": "air", "title": "Air", "hardness": "soft", "dig_seconds": 0.0,
		"drops": AIR, "light": 0, "flags": PLACEABLE_BACK, "warmth": 0, "scent": ""},
	{"id": "meadow_soil", "title": "Meadow soil", "hardness": "soft", "dig_seconds": 0.25,
		"drops": MEADOW_SOIL, "light": 0, "flags": SOLID | PLACEABLE_BACK,
		"warmth": 0, "scent": ""},
	{"id": "grass", "title": "Grass", "hardness": "soft", "dig_seconds": 0.25,
		"drops": MEADOW_SOIL, "light": 0, "flags": SOLID | PLACEABLE_BACK,
		"warmth": 0, "scent": "meadow"},
	{"id": "clay", "title": "Clay", "hardness": "firm", "dig_seconds": 0.6,
		"drops": CLAY, "light": 0, "flags": SOLID | PLACEABLE_BACK,
		"warmth": 0, "scent": ""},
	{"id": "stone", "title": "Stone", "hardness": "stone", "dig_seconds": 1.2,
		"drops": STONE, "light": 0, "flags": SOLID | PLACEABLE_BACK,
		"warmth": 0, "scent": ""},
	{"id": "wood", "title": "Wood", "hardness": "firm", "dig_seconds": 0.65,
		"drops": WOOD, "light": 0, "flags": SOLID | PLACEABLE_BACK,
		"warmth": 0, "scent": "wood"},
	{"id": "leaves", "title": "Leaves", "hardness": "soft", "dig_seconds": 0.25,
		"drops": LEAVES, "light": 0, "flags": SOLID | PLACEABLE_BACK,
		"warmth": 0, "scent": "meadow"},
	{"id": "root", "title": "Climbing root", "hardness": "soft", "dig_seconds": 0.25,
		"drops": ROOT, "light": 0, "flags": CLIMBABLE | FREE_SUPPORT,
		"warmth": 0, "scent": "wood"},
	{"id": "crystal", "title": "Crystal", "hardness": "crystal", "dig_seconds": 1.8,
		"drops": CRYSTAL, "light": 9, "flags": SOLID | PLACEABLE_BACK,
		"warmth": 0, "scent": "crystal"},
	{"id": "glow_moss", "title": "Glow moss", "hardness": "soft", "dig_seconds": 0.25,
		"drops": GLOW_MOSS, "light": 6, "flags": PLACEABLE_BACK,
		"warmth": 0, "scent": "crystal"},
	{"id": "bed", "title": "Starting straw bed", "hardness": "soft", "dig_seconds": 0.0,
		"drops": AIR, "light": 0, "flags": UNBREAKABLE,
		"warmth": 1, "scent": "home"},
	{"id": "ladder", "title": "Ladder", "hardness": "firm", "dig_seconds": 0.45,
		"drops": LADDER, "light": 0, "flags": CLIMBABLE | FREE_SUPPORT,
		"warmth": 0, "scent": ""},
	{"id": "bedrock", "title": "World boundary", "hardness": "ancient",
		"dig_seconds": 0.0, "drops": AIR, "light": 0, "flags": SOLID | UNBREAKABLE,
		"warmth": 0, "scent": ""},
]

const BUILDING_BLOCKS: Array[int] = [
	MEADOW_SOIL, CLAY, STONE, WOOD, LEAVES, ROOT, CRYSTAL, GLOW_MOSS, LADDER,
]


static func is_valid(id: int) -> bool:
	return id >= AIR and id < COUNT


static func has_flag(id: int, flag: int) -> bool:
	return (int(DATA[id]["flags"]) & flag) != 0


static func title(id: int) -> String:
	return str(DATA[id]["title"])


static func dig_ticks(id: int) -> int:
	return ceili(float(DATA[id]["dig_seconds"]) * 60.0)
