extends RefCounted

## Adapted from Cube Trials' original builder; packed indexed quads suit chunk tiles.

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var first := _vertices.size()
	var normal := (b - a).cross(c - a).normalized()
	for point: Vector3 in [a, b, c, d]:
		_vertices.append(point)
		_normals.append(normal)
		_colors.append(color)
		_uvs.append(Vector2(point.x, -point.y) * 2.0)
	# Godot's front-facing winding is clockwise; the exterior normal is unchanged.
	for index: int in [0, 2, 1, 0, 3, 2]:
		_indices.append(first + index)


func box(at: Vector3, dimensions: Vector3, color: Color) -> void:
	var half := dimensions * 0.5
	var a := at - half
	var b := at + half
	quad(Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z),
		Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z), color)
	quad(Vector3(b.x, a.y, a.z), Vector3(a.x, a.y, a.z),
		Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), color)
	quad(Vector3(a.x, b.y, a.z), Vector3(a.x, b.y, b.z),
		Vector3(b.x, b.y, b.z), Vector3(b.x, b.y, a.z), color)
	quad(Vector3(a.x, a.y, b.z), Vector3(a.x, a.y, a.z),
		Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), color)
	quad(Vector3(b.x, a.y, b.z), Vector3(b.x, a.y, a.z),
		Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), color)
	quad(Vector3(a.x, a.y, a.z), Vector3(a.x, a.y, b.z),
		Vector3(a.x, b.y, b.z), Vector3(a.x, b.y, a.z), color)


func finish() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
