extends Control

## Projected over the diorama so underground trails stay legible through solid blocks.

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Scent = preload("res://games/puppy_kraft/sim/scent.gd")
const SHADOW := Color(0.04, 0.08, 0.10, 0.85)
const SPACING := 24.0

var _world: World
var _project: Callable
var _phase := 0.0
var _reduced_motion := false
var _intense_effects := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func present(world: World, projection: Callable, delta: float,
	reduced_motion: bool, intense_effects: bool) -> void:
	_world = world
	_project = projection
	_reduced_motion = reduced_motion
	_intense_effects = intense_effects
	visible = world != null and world.sniffing
	_phase = 0.0 if reduced_motion or not visible else fposmod(_phase + delta * 16.0, SPACING)
	queue_redraw()


func _draw() -> void:
	if not visible or _world == null or not _project.is_valid():
		return
	for source: Dictionary in _world.scent.outlines:
		var cell := Vector2(source["cell"])
		var points := PackedVector2Array()
		for corner: Vector2 in [Vector2(0.06, 0.06), Vector2(0.94, 0.06),
			Vector2(0.94, 0.94), Vector2(0.06, 0.94), Vector2(0.06, 0.06)]:
			points.append(_project.call(cell + corner))
		_stroke(points, Scent.STYLES[str(source["kind"])]["color"], 2.5)
	var origin: Vector2 = _project.call(
		_world.body.position + Vector2(_world.body.facing * 0.4, -0.15))
	for source: Dictionary in _world.scent.trails:
		var style: Dictionary = Scent.STYLES[str(source["kind"])]
		var target: Vector2 = _project.call(Vector2(source["cell"]) + Vector2.ONE * 0.5)
		target = _clip_target(origin, target)
		var direction := (target - origin).normalized()
		var length := origin.distance_to(target)
		var color: Color = style["color"]
		color.a = 1.0 if _intense_effects else 0.8
		if str(style["shape"]) == "zigzag":
			_zigzag(origin, target, color)
		else:
			var distance := 16.0 + _phase
			while distance < length - 12.0:
				_paw(origin + direction * distance, direction.angle(), color, 0.55)
				distance += SPACING
		if _reduced_motion:
			var distance := 20.0
			while distance < length - 16.0:
				_arrow(origin + direction * distance, direction, color)
				distance += SPACING * 1.5
		elif str(style["shape"]) == "zigzag":
			var distance := 10.0 + _phase
			while distance < length - 12.0:
				draw_circle(origin + direction * distance, 2.5, Color.WHITE)
				distance += SPACING
		_icon(target, str(source["kind"]), color)
		var caption := str(style["icon"])
		var at := Vector2(clampf(target.x + 12.0, 12.0, size.x - 62.0),
			clampf(target.y - 10.0, 22.0, size.y - 12.0))
		draw_string(ThemeDB.fallback_font, at + Vector2.ONE, caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, SHADOW)
		draw_string(ThemeDB.fallback_font, at, caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, color)


func _clip_target(origin: Vector2, target: Vector2) -> Vector2:
	var offset := target - origin
	var fraction := 1.0
	if offset.x > 0.0:
		fraction = minf(fraction, (size.x - 22.0 - origin.x) / offset.x)
	elif offset.x < 0.0:
		fraction = minf(fraction, (22.0 - origin.x) / offset.x)
	if offset.y > 0.0:
		fraction = minf(fraction, (size.y - 22.0 - origin.y) / offset.y)
	elif offset.y < 0.0:
		fraction = minf(fraction, (22.0 - origin.y) / offset.y)
	return origin + offset * maxf(0.0, fraction)


func _zigzag(origin: Vector2, target: Vector2, color: Color) -> void:
	var direction := (target - origin).normalized()
	var normal := direction.orthogonal()
	var length := origin.distance_to(target)
	var points := PackedVector2Array([origin])
	var distance := 10.0
	var side := 1.0
	while distance < length:
		points.append(origin + direction * distance + normal * side * 3.5)
		side = -side
		distance += 10.0
	points.append(target)
	_stroke(points, color, 2.5)


func _arrow(at: Vector2, direction: Vector2, color: Color) -> void:
	var normal := direction.orthogonal()
	_stroke(PackedVector2Array([
		at - direction * 5.0 + normal * 4.0, at + direction * 2.0,
		at - direction * 5.0 - normal * 4.0,
	]), color, 2.5)


func _paw(at: Vector2, angle: float, color: Color, scale_factor: float = 1.0) -> void:
	draw_circle(at, 5.5 * scale_factor, SHADOW)
	draw_circle(at, 4.0 * scale_factor, color)
	for toe: Vector2 in [Vector2(5, -4), Vector2(7, 0), Vector2(5, 4)]:
		var point := at + toe.rotated(angle) * scale_factor
		draw_circle(point, 3.1 * scale_factor, SHADOW)
		draw_circle(point, 2.1 * scale_factor, color)


func _icon(at: Vector2, kind: String, color: Color) -> void:
	if kind == "home":
		_paw(at, -PI * 0.5, color)
		return
	var points := PackedVector2Array([
		at + Vector2(0, -9), at + Vector2(6, 0),
		at + Vector2(0, 9), at + Vector2(-6, 0), at + Vector2(0, -9),
	])
	draw_colored_polygon(points, color)
	_stroke(points, color, 2.0)


func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(points, SHADOW, width + 3.0, true)
	draw_polyline(points, color, width, true)
