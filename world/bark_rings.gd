extends Control

## Model events drive bounded feedback; reduced motion uses static, fading rings.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const LIFE_TICKS := 42
const MAX_RINGS := 4
const INK := Color(0.04, 0.08, 0.10, 0.8)

var _world: World
var _project: Callable
var _rings: Array[Dictionary] = []
var _reduced_motion := false
var _intense_effects := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func add_bark(event: Dictionary) -> void:
	if _rings.size() >= MAX_RINGS:
		_rings.pop_front()
	_rings.append(event.duplicate())
	queue_redraw()


func clear() -> void:
	_rings.clear()
	hide()
	queue_redraw()


func present(world: World, projection: Callable,
	reduced_motion: bool, intense_effects: bool) -> void:
	_world = world
	_project = projection
	_reduced_motion = reduced_motion
	_intense_effects = intense_effects
	if world == null or world.sniffing:
		clear()
		return
	for index in range(_rings.size() - 1, -1, -1):
		if world.ticks - int(_rings[index]["tick"]) >= LIFE_TICKS:
			_rings.remove_at(index)
	visible = not _rings.is_empty()
	queue_redraw()


func _draw() -> void:
	if _world == null or not _project.is_valid():
		return
	for index in _rings.size():
		var ring := _rings[index]
		var age := float(_world.ticks - int(ring["tick"])) / LIFE_TICKS
		var radius := float(ring["range"])
		if not _reduced_motion:
			radius *= lerpf(0.15, 1.0, 1.0 - pow(1.0 - age, 2.0))
		var origin: Vector2 = ring["position"]
		var points := PackedVector2Array()
		for segment in 65:
			var angle := TAU * segment / 64.0
			points.append(_project.call(origin + Vector2(cos(angle), sin(angle)) * radius))
		var color := Color("ffdc82") if _intense_effects else Color("c2d7c6")
		color.a = (1.0 - age) * (0.95 if _intense_effects else 0.65)
		var shadow := INK
		shadow.a *= 1.0 - age
		draw_polyline(points, shadow, 5.0 if _intense_effects else 3.5, true)
		draw_polyline(points, color, 2.5 if _intense_effects else 1.5, true)
		if index == _rings.size() - 1:
			var caption := "%s! [%d]" % [str(ring["name"]), int(ring["level"])]
			if int(ring.get("leaves", 0)) > 0:
				caption += " +%d leaves" % int(ring["leaves"])
			var at: Vector2 = _project.call(origin)
			at += Vector2(12, -18)
			draw_string(ThemeDB.fallback_font, at + Vector2.ONE, caption,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, shadow)
			draw_string(ThemeDB.fallback_font, at, caption,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, color)
