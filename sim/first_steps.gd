extends RefCounted

## Five ordered, non-blocking lessons; only achieved actions advance the current prompt.

enum Step { MOVE, DIG, SNIFF, BARK, HOME, DONE }
const WALK_DISTANCE := 4.0

var step: int = Step.MOVE
var walked := 0.0


func walk(distance: float) -> void:
	assert(is_finite(distance) and distance >= 0.0, "Record actual horizontal travel.")
	if step != Step.MOVE:
		return
	walked = minf(WALK_DISTANCE, walked + distance)
	if walked >= WALK_DISTANCE:
		step = Step.DIG


func achieve(action: Step) -> void:
	assert(action >= Step.DIG and action <= Step.HOME, "Record an achieved tutorial action.")
	if step == action:
		step += 1


func skip() -> void:
	walked = WALK_DISTANCE
	step = Step.DONE


func snapshot() -> Dictionary:
	return {"step": step, "walked": walked}


func restore(state: Dictionary) -> void:
	step = state["step"]
	walked = state["walked"]


static func validate(state: Variant) -> String:
	if typeof(state) != TYPE_DICTIONARY:
		return "The saved First Steps progress is invalid."
	var progress: Dictionary = state
	if typeof(progress.get("step")) != TYPE_INT \
		or int(progress["step"]) < Step.MOVE or int(progress["step"]) > Step.DONE:
		return "The saved First Steps prompt is invalid."
	var distance: Variant = progress.get("walked")
	if typeof(distance) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(distance)) \
		or float(distance) < 0.0 or float(distance) > WALK_DISTANCE:
		return "The saved First Steps walking distance is invalid."
	if (int(progress["step"]) == Step.MOVE and float(distance) >= WALK_DISTANCE) \
		or (int(progress["step"]) != Step.MOVE and float(distance) != WALK_DISTANCE):
		return "The saved First Steps prompt and walking distance do not agree."
	return ""
