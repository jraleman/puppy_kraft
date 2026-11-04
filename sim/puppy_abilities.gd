extends RefCounted

## Charge input is transient; energy and the Ruff cooldown survive pauses and reloads.

const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Needs = preload("res://games/puppy_kraft/sim/needs.gd")
const WOOF_TICKS := 30
const RUFF_TICKS := 72
const TAP_WAIT_TICKS := 36
const COOLDOWN_TICKS := 60
const BARKS: Array[Dictionary] = [
	{"name": "Yip", "range": 4.0, "cost": 0},
	{"name": "Woof", "range": 7.0, "cost": 3},
	{"name": "Ruff", "range": 10.0, "cost": 8},
]

var tap_mode := false
var charge_level := 0
var charge_ticks := 0
var cooldown_ticks := 0
var caption := ""
var caption_ticks := 0
var emitted_total := 0
var last_level := 0
var _tap_wait := 0


func set_tap_mode(enabled: bool) -> void:
	if tap_mode != enabled:
		tap_mode = enabled
		cancel()


func cancel() -> void:
	_stop_charging()
	caption = ""
	caption_ticks = 0


func step(frame: Frame, needs: Needs, allowed: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	cooldown_ticks = maxi(0, cooldown_ticks - 1)
	caption_ticks = maxi(0, caption_ticks - 1)
	if caption_ticks == 0:
		caption = ""
	if not allowed:
		_stop_charging()
		if frame.bark_edges.has(true):
			_say("End sniffing to bark.")
		return result
	for pressed: bool in frame.bark_edges:
		if pressed:
			if cooldown_ticks > 0:
				_say("Ruff is resting. Wait for the bark cooldown.")
			elif tap_mode:
				charge_level = charge_level % 3 + 1
				_tap_wait = TAP_WAIT_TICKS
			else:
				charge_level = 1
				charge_ticks = 0
		elif not tap_mode and charge_level > 0:
			_fire(needs, result)
	if tap_mode and charge_level > 0:
		_tap_wait -= 1
		if _tap_wait <= 0:
			_fire(needs, result)
	elif not tap_mode and charge_level > 0:
		if frame.bark:
			charge_ticks += 1
			charge_level = 3 if charge_ticks >= RUFF_TICKS \
				else (2 if charge_ticks >= WOOF_TICKS else 1)
		else:
			_fire(needs, result)
	return result


func charge_caption() -> String:
	if charge_level == 0:
		return caption if not caption.is_empty() else (
			"Cooldown %.1fs" % (float(cooldown_ticks) / 60.0)
			if cooldown_ticks > 0 else "Ready")
	var pips := PackedStringArray()
	for pip in range(1, 4):
		pips.append("[%d]" % pip if pip <= charge_level else " %d " % pip)
	return "%s %s / %s" % [
		" ".join(pips), str(BARKS[charge_level - 1]["name"]),
		"tap again or wait 0.6s" if tap_mode else "release to bark",
	]


func _fire(needs: Needs, result: Array[Dictionary]) -> void:
	var level := charge_level
	var definition := BARKS[level - 1]
	charge_level = 0
	charge_ticks = 0
	_tap_wait = 0
	if not needs.spend(int(definition["cost"])):
		_say("Need %d energy for %s. Stand still to rest." % [
			int(definition["cost"]), str(definition["name"]),
		])
		return
	last_level = level
	emitted_total += 1
	_say(str(definition["name"]) + "!")
	if level == 3:
		cooldown_ticks = COOLDOWN_TICKS
	result.append({
		"type": "barked", "level": level, "name": definition["name"],
		"range": definition["range"], "cost": definition["cost"],
	})


func _say(message: String) -> void:
	caption = message
	caption_ticks = 90


func _stop_charging() -> void:
	charge_level = 0
	charge_ticks = 0
	_tap_wait = 0
