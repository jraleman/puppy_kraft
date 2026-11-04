extends RefCounted

## Packed layers keep a finite world cheap; dirtiness is independent of save deltas.

const SIZE := 32
const CELLS := SIZE * SIZE
const FRONT := 0
const BACK := 1

var coordinate := Vector2i.ZERO
var front := PackedInt32Array()
var back := PackedInt32Array()
var dirty := true


func _init(at := Vector2i.ZERO) -> void:
	coordinate = at
	front.resize(CELLS)
	back.resize(CELLS)


static func index(local: Vector2i) -> int:
	return local.x + local.y * SIZE


func get_block(local: Vector2i, layer := FRONT) -> int:
	return front[index(local)] if layer == FRONT else back[index(local)]


func set_block(local: Vector2i, id: int, layer := FRONT) -> void:
	if layer == FRONT:
		front[index(local)] = id
	else:
		back[index(local)] = id
	dirty = true
