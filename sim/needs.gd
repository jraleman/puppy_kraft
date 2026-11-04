extends RefCounted

## Only the bark energy budget is active; other survival needs remain unimplemented.

const MAX_ENERGY := 100.0
const REST_DELAY_TICKS := 60
const RESTORE_PER_TICK := 2.0 / 60.0

var energy := MAX_ENERGY
var rest_ticks := 0


func step(resting: bool) -> void:
	if not resting:
		rest_ticks = 0
	elif rest_ticks < REST_DELAY_TICKS:
		rest_ticks += 1
	else:
		energy = minf(MAX_ENERGY, energy + RESTORE_PER_TICK)


func spend(amount: int) -> bool:
	assert(amount >= 0, "Energy costs cannot be negative.")
	if energy + 0.00000001 < amount:
		return false
	energy = maxf(0.0, energy - amount)
	rest_ticks = 0
	return true
