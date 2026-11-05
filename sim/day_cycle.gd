extends RefCounted

## Integer phase units preserve exact time when switching between 12/18/30-minute days.

const SHORT := 0
const NORMAL := 1
const LONG := 2
const NORMAL_TICKS := 18 * 60 * 60
const CYCLE_UNITS := 648000
const DAWN_END := 36000
const DUSK_START := 396000
const NIGHT_START := 432000
const UNITS_PER_TICK: Array[int] = [15, 10, 6]
const PHASE_NAMES: Array[String] = ["Dawn", "Day", "Dusk", "Night"]
const CAPTION_TICKS := 6 * 60
enum Phase { DAWN, DAY, DUSK, NIGHT }

var day := 1
var phase_units := 0
var pace := NORMAL
var caption := ""
var _caption_ticks := 0


func step() -> void:
	var before := phase()
	_caption_ticks = maxi(0, _caption_ticks - 1)
	if _caption_ticks == 0:
		caption = ""
	phase_units += UNITS_PER_TICK[pace]
	if phase_units >= CYCLE_UNITS:
		phase_units -= CYCLE_UNITS
		day += 1
	if before != Phase.DUSK and phase() == Phase.DUSK:
		caption = "The sun is setting - time to head home?"
		_caption_ticks = CAPTION_TICKS


func set_pace(value: int) -> void:
	assert(value >= SHORT and value <= LONG, "Choose Short, Normal or Long days.")
	pace = value


func phase() -> Phase:
	if phase_units < DAWN_END:
		return Phase.DAWN
	if phase_units < DUSK_START:
		return Phase.DAY
	return Phase.DUSK if phase_units < NIGHT_START else Phase.NIGHT


func phase_name() -> String:
	return "Full moon" if is_full_moon() else PHASE_NAMES[phase()]


func is_night() -> bool:
	return phase() == Phase.NIGHT


func is_full_moon() -> bool:
	return is_night() and day % 8 == 0


func daylight() -> float:
	var night := 0.4 if day % 8 == 0 else 0.25
	if phase_units < DAWN_END:
		var previous_night := 0.4 if day > 1 and (day - 1) % 8 == 0 else 0.25
		return lerpf(previous_night, 1.0, smoothstep(0.0, float(DAWN_END), phase_units))
	if phase_units < DUSK_START:
		return 1.0
	if phase_units < NIGHT_START:
		return lerpf(1.0, night,
			smoothstep(float(DUSK_START), float(NIGHT_START), phase_units))
	return night


func restore_legacy(ticks: int) -> void:
	caption = ""
	_caption_ticks = 0
	@warning_ignore("integer_division")
	day = 1 + ticks / NORMAL_TICKS
	phase_units = (ticks % NORMAL_TICKS) * UNITS_PER_TICK[NORMAL]
	pace = NORMAL


func snapshot() -> Dictionary:
	return {"day": day, "phase_units": phase_units, "pace": pace}


func restore(state: Dictionary) -> void:
	caption = ""
	_caption_ticks = 0
	day = state["day"]
	phase_units = state["phase_units"]
	pace = state["pace"]


static func validate(state: Variant) -> String:
	if typeof(state) != TYPE_DICTIONARY:
		return "The saved day clock is invalid."
	var clock: Dictionary = state
	for key in ["day", "phase_units", "pace"]:
		if typeof(clock.get(key)) != TYPE_INT:
			return "The saved day clock has an invalid %s." % key
	if int(clock["day"]) < 1 or int(clock["day"]) >= 9223372036854775807 \
		or int(clock["phase_units"]) < 0 or int(clock["phase_units"]) >= CYCLE_UNITS \
		or int(clock["pace"]) < SHORT or int(clock["pace"]) > LONG:
		return "The saved day clock is outside its supported range."
	return ""
