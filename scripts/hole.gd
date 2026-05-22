@tool
class_name GolfHole
extends MeshInstance3D

const HOLE_RADIUS: float = 0.25
const HOLE_DEPTH: float = 0.5
const SEGMENTS: int = 32

@export var planet_data: PlanetData:
	set(v):
		planet_data = v
		_rebuild()

@export var surface_direction: Vector3 = Vector3.UP:
	set(v):
		surface_direction = v.normalized() if v.length() > 0.001 else Vector3.UP
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if planet_data == null:
		return
	var surface_pos: Vector3 = planet_data.point_on_planet(surface_direction)
	var perp: Vector3 = surface_direction.cross(Vector3.FORWARD)
	if perp.length() < 0.001:
		perp = surface_direction.cross(Vector3.RIGHT)
	var local_x: Vector3 = perp.normalized()
	var local_z: Vector3 = surface_direction.cross(local_x).normalized()
	transform = Transform3D(Basis(local_x, surface_direction, local_z), surface_pos)
	call_deferred("_build_mesh")


func _build_mesh() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var wall_verts: PackedVector3Array = PackedVector3Array()
	var wall_normals: PackedVector3Array = PackedVector3Array()
	var wall_indices: PackedInt32Array = PackedInt32Array()

	wall_verts.resize(SEGMENTS * 2)
	wall_normals.resize(SEGMENTS * 2)
	wall_indices.resize(SEGMENTS * 6)

	for i: int in range(SEGMENTS):
		var a: float = float(i) / float(SEGMENTS) * TAU
		var cx: float = cos(a)
		var cz: float = sin(a)
		# Bottom vertex (toward planet center)
		wall_verts[i * 2] = Vector3(cx * HOLE_RADIUS, -HOLE_DEPTH, cz * HOLE_RADIUS)
		wall_normals[i * 2] = Vector3(-cx, 0.0, -cz)
		# Top vertex (at surface opening)
		wall_verts[i * 2 + 1] = Vector3(cx * HOLE_RADIUS, 0.0, cz * HOLE_RADIUS)
		wall_normals[i * 2 + 1] = Vector3(-cx, 0.0, -cz)

		var next: int = (i + 1) % SEGMENTS
		var bi: int = i * 2
		var bn: int = next * 2
		# CCW winding viewed from inside the cylinder (two triangles per quad)
		wall_indices[i * 6 + 0] = bi
		wall_indices[i * 6 + 1] = bn + 1
		wall_indices[i * 6 + 2] = bi + 1
		wall_indices[i * 6 + 3] = bi
		wall_indices[i * 6 + 4] = bn
		wall_indices[i * 6 + 5] = bn + 1

	arrays[Mesh.ARRAY_VERTEX] = wall_verts
	arrays[Mesh.ARRAY_NORMAL] = wall_normals
	arrays[Mesh.ARRAY_INDEX] = wall_indices

	var cap_arrays: Array = []
	cap_arrays.resize(Mesh.ARRAY_MAX)

	var cap_verts: PackedVector3Array = PackedVector3Array()
	var cap_normals: PackedVector3Array = PackedVector3Array()
	var cap_indices: PackedInt32Array = PackedInt32Array()

	cap_verts.resize(SEGMENTS + 1)
	cap_normals.resize(SEGMENTS + 1)
	cap_indices.resize(SEGMENTS * 3)

	# Center vertex of the bottom cap
	cap_verts[0] = Vector3(0.0, -HOLE_DEPTH, 0.0)
	cap_normals[0] = Vector3(0.0, 1.0, 0.0)

	for i: int in range(SEGMENTS):
		var a: float = float(i) / float(SEGMENTS) * TAU
		cap_verts[i + 1] = Vector3(cos(a) * HOLE_RADIUS, -HOLE_DEPTH, sin(a) * HOLE_RADIUS)
		cap_normals[i + 1] = Vector3(0.0, 1.0, 0.0)
		var next: int = (i + 1) % SEGMENTS
		# CCW fan from center viewed from above (from opening)
		cap_indices[i * 3 + 0] = 0
		cap_indices[i * 3 + 1] = next + 1
		cap_indices[i * 3 + 2] = i + 1

	cap_arrays[Mesh.ARRAY_VERTEX] = cap_verts
	cap_arrays[Mesh.ARRAY_NORMAL] = cap_normals
	cap_arrays[Mesh.ARRAY_INDEX] = cap_indices

	var hole_mesh: ArrayMesh = ArrayMesh.new()
	hole_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	hole_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cap_arrays)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	hole_mesh.surface_set_material(0, mat)
	hole_mesh.surface_set_material(1, mat)

	mesh = hole_mesh

	for child: StaticBody3D in get_children():
		child.free()
	create_trimesh_collision()
