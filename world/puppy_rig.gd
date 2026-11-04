extends Node3D

## Original box-and-ears grey box; its pose is cosmetic and never a collision source.

const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Builder = preload("res://games/puppy_kraft/world/mesh_builder.gd")
const Mesher = preload("res://games/puppy_kraft/world/chunk_mesher.gd")

var reduced_motion := false
var _tail: Node3D
var _time := 0.0


func _ready() -> void:
	var builder := Builder.new()
	var fur := Color("d8af82")
	var cream := Color("f3dfb8")
	var dark := Color("4c3c36")
	builder.box(Vector3(-0.035, 0.015, 0), Vector3(0.33, 0.22, 0.23), fur)
	builder.box(Vector3(0.15, 0.105, 0), Vector3(0.18, 0.18, 0.22), cream)
	builder.box(Vector3(0.255, 0.075, 0), Vector3(0.07, 0.07, 0.12), cream)
	builder.box(Vector3(0.29, 0.085, 0), Vector3(0.035, 0.04, 0.07), dark)
	for side: float in [-1.0, 1.0]:
		builder.box(Vector3(0.12, 0.12, side * 0.12), Vector3(0.075, 0.20, 0.035), fur)
		builder.box(Vector3(0.205, 0.14, side * 0.116), Vector3(0.026, 0.033, 0.018), dark)
		for leg: float in [-0.135, 0.09]:
			builder.box(Vector3(leg, -0.125, side * 0.085),
				Vector3(0.07, 0.15, 0.075), cream)
	builder.box(Vector3(0.075, 0.015, 0), Vector3(0.035, 0.22, 0.25), Color("ce776c"))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = builder.finish()
	mesh.material_override = material
	add_child(mesh)
	_tail = Node3D.new()
	_tail.position = Vector3(-0.20, 0.055, 0)
	add_child(_tail)
	var tail_builder := Builder.new()
	tail_builder.box(Vector3(-0.04, 0.04, 0), Vector3(0.07, 0.16, 0.06), cream)
	var tail_mesh := MeshInstance3D.new()
	tail_mesh.mesh = tail_builder.finish()
	tail_mesh.material_override = material
	_tail.add_child(tail_mesh)


func present(body: Body, delta: float) -> void:
	position = Vector3(body.position.x * Mesher.CELL_METRES,
		-body.position.y * Mesher.CELL_METRES, 0.30)
	rotation.y = 0.0 if body.facing > 0 else PI
	if not reduced_motion:
		_time += delta
	if _tail != null:
		_tail.rotation.z = 0.0 if reduced_motion else sin(_time * 9.0) * 0.22
