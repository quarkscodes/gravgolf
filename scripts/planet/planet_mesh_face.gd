@tool
class_name PlanetMeshFace
extends MeshInstance3D

const PLANET_SHADER: Shader = preload("res://shaders/planet_surface.gdshader")

@export var normal: Vector3


func regenerate_mesh(
		planet_data: PlanetData, 
		biome_texture: ImageTexture, 
		hole_pos: Vector3 = Vector3.ZERO, 
		hole_radius: float = 0.0
		) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertex_array: PackedVector3Array = PackedVector3Array()
	var uv_array: PackedVector2Array = PackedVector2Array()
	var normal_array: PackedVector3Array = PackedVector3Array()
	var index_array: PackedInt32Array = PackedInt32Array()
	
	var resolution: int = planet_data.resolution
	var num_vertices: int = resolution * resolution
	var num_indices: int = (resolution - 1) * (resolution - 1) * 6
	
	normal_array.resize(num_vertices)
	uv_array.resize(num_vertices)
	vertex_array.resize(num_vertices)
	index_array.resize(num_indices)
	
	var tri_index: int = 0
	# Swizzle (y,z,x) gives a vector perpendicular to `normal` for any axis-aligned face
	# without needing an arbitrary up vector, avoiding degenerate cross products
	var axisA: Vector3 = Vector3(normal.y, normal.z, normal.x)
	var axisB: Vector3 = normal.cross(axisA)
	
	for y: int in range(resolution):
		for x: int in range(resolution):
			var i: int = x + y * resolution
			var percent: Vector2 = Vector2(x, y) / (resolution - 1)
			# Map grid point to a cube face in [-1,1] space, then normalize to sphere
			var pointOnUnitCube: Vector3 = (
					normal + (percent.x - 0.5) * 2.0 * axisA + (percent.y - 0.5) * 2.0 * axisB
			)
			var pointOnUnitSphere: Vector3 = pointOnUnitCube.normalized()
			var biome_index: float = planet_data.biome_percent_from_point(pointOnUnitSphere)
			var pointOnPlanet: Vector3 = planet_data.point_on_planet(pointOnUnitSphere)
			
			vertex_array[i] = pointOnPlanet
			# UV.x unused; UV.y carries biome index so the shader can sample the biome texture row
			uv_array[i] = Vector2(0.0, biome_index)
			
			var l: float = pointOnPlanet.length()
			if l < planet_data.min_height:
				planet_data.min_height = l
			if l > planet_data.max_height:
				planet_data.max_height = l
			
			if x != resolution - 1 and y != resolution - 1:
				index_array[tri_index + 5] = i
				index_array[tri_index + 4] = i + 1
				index_array[tri_index + 3] = i + resolution + 1
				index_array[tri_index + 2] = i
				index_array[tri_index + 1] = i + resolution + 1
				index_array[tri_index] = i + resolution
				
				tri_index += 6
	
	# Accumulate face normals per vertex, then normalize — gives smooth shading across the face
	for a: int in range(0, index_array.size(), 3):
		var b: int = a + 1
		var c: int = a + 2
		
		var ab: Vector3 = vertex_array[index_array[b]] - vertex_array[index_array[a]]
		var bc: Vector3 = vertex_array[index_array[c]] - vertex_array[index_array[b]]
		var ca: Vector3 = vertex_array[index_array[a]] - vertex_array[index_array[c]]
		
		var cross_ab_bc: Vector3= ab.cross(bc) * -1.0
		var cross_bc_ca: Vector3= bc.cross(ca) * -1.0
		var cross_ca_ab: Vector3= ca.cross(ab) * -1.0
		
		normal_array[index_array[a]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
		normal_array[index_array[b]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
		normal_array[index_array[c]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
	
	for i: int in range(normal_array.size()):
		normal_array[i] = normal_array[i].normalized()
	
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	
	# Deferred so mesh and collision updates don't fire mid-physics-step or during @tool regeneration
	call_deferred("_update_mesh", arrays, planet_data, biome_texture, hole_pos, hole_radius)


func _update_mesh(
		arrays: Array,
		planet_data: PlanetData,
		biome_texture: ImageTexture,
		hole_pos: Vector3,
		hole_radius: float
		) -> void:
	var _mesh: ArrayMesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = _mesh

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = PLANET_SHADER
	mat.set_shader_parameter("min_height", planet_data.min_height)
	mat.set_shader_parameter("max_height", planet_data.max_height)
	mat.set_shader_parameter("height_color", biome_texture)
	mat.set_shader_parameter("hole_local_pos", hole_pos)
	mat.set_shader_parameter("hole_radius", hole_radius)
	self.material_override = mat

	for child: Node in get_children():
		child.queue_free()

	# Filter planet surface triangles that overlap the hole
	var face_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var face_idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var col_faces: PackedVector3Array = PackedVector3Array()
	var hole_radius_sq: float = hole_radius * hole_radius
	var had_hole: bool = false
	for i: int in range(0, face_idx.size(), 3):
		var v0: Vector3 = face_verts[face_idx[i]]
		var v1: Vector3 = face_verts[face_idx[i + 1]]
		var v2: Vector3 = face_verts[face_idx[i + 2]]
		if hole_radius > 0.0 and _closest_dist_sq(hole_pos, v0, v1, v2) < hole_radius_sq:
			had_hole = true
			continue
		col_faces.append(v0)
		col_faces.append(v1)
		col_faces.append(v2)

	if hole_radius > 0.0:
		var outer_indices: Dictionary = {}
		for i: int in range(0, face_idx.size(), 3):
			var v0: Vector3 = face_verts[face_idx[i]]
			var v1: Vector3 = face_verts[face_idx[i + 1]]
			var v2: Vector3 = face_verts[face_idx[i + 2]]
			if _closest_dist_sq(hole_pos, v0, v1, v2) < hole_radius_sq:
				for k: int in range(3):
					var idx: int = face_idx[i + k]
					if face_verts[idx].distance_squared_to(hole_pos) > hole_radius_sq:
						outer_indices[idx] = true

		var outer_verts: Array[Vector3] = []
		for idx: int in outer_indices:
			outer_verts.append(face_verts[idx])

		if outer_verts.size() >= 2:
			var up: Vector3 = hole_pos.normalized()
			var right: Vector3 = up.cross(Vector3.UP)
			if right.length_squared() < 0.001:
				right = up.cross(Vector3.FORWARD)
			right = right.normalized()
			var fwd: Vector3 = up.cross(right).normalized()

			outer_verts.sort_custom(func(a: Vector3, b: Vector3) -> bool:
				var da: Vector3 = a - hole_pos
				var db: Vector3 = b - hole_pos
				return atan2(da.dot(fwd), da.dot(right)) < atan2(db.dot(fwd), db.dot(right))
			)

			for j: int in range(outer_verts.size()):
				var v_a: Vector3 = outer_verts[j]
				var v_b: Vector3 = outer_verts[(j + 1) % outer_verts.size()]
				var off_a: Vector3 = v_a - hole_pos
				var off_b: Vector3 = v_b - hole_pos
				var tang_a: Vector3 = off_a - off_a.dot(up) * up
				var tang_b: Vector3 = off_b - off_b.dot(up) * up
				if tang_a.length_squared() < 0.0001 or tang_b.length_squared() < 0.0001:
					continue
				var inner_a: Vector3 = hole_pos + tang_a.normalized() * hole_radius
				var inner_b: Vector3 = hole_pos + tang_b.normalized() * hole_radius
				col_faces.append(v_a)
				col_faces.append(inner_b)
				col_faces.append(v_b)
				col_faces.append(v_a)
				col_faces.append(inner_a)
				col_faces.append(inner_b)

	var col_shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	col_shape.set_faces(col_faces)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = col_shape
	var body: StaticBody3D = StaticBody3D.new()
	body.add_child(col)
	add_child(body)
	if Engine.is_editor_hint():
		var scene_root: Node = EditorInterface.get_edited_scene_root()
		body.owner = scene_root
		col.owner = scene_root

	if not had_hole:
		return

	# Build cup geometry on the one face that contains the hole
	var up: Vector3 = hole_pos.normalized()
	var right: Vector3 = up.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = up.cross(Vector3.FORWARD)
	right = right.normalized()
	var fwd: Vector3 = up.cross(right).normalized()
	var floor_center: Vector3 = hole_pos - up * GolfHole.HOLE_DEPTH

	var wall_verts: PackedVector3Array = PackedVector3Array()
	var wall_normals: PackedVector3Array = PackedVector3Array()
	var wall_indices: PackedInt32Array = PackedInt32Array()
	wall_verts.resize(GolfHole.SEGMENTS * 2)
	wall_normals.resize(GolfHole.SEGMENTS * 2)
	wall_indices.resize(GolfHole.SEGMENTS * 6)
	for i: int in range(GolfHole.SEGMENTS):
		var a: float = float(i) / float(GolfHole.SEGMENTS) * TAU
		var radial: Vector3 = right * cos(a) + fwd * sin(a)
		wall_verts[i * 2] = floor_center + radial * GolfHole.HOLE_RADIUS
		wall_normals[i * 2] = -radial
		wall_verts[i * 2 + 1] = hole_pos + radial * GolfHole.HOLE_RADIUS
		wall_normals[i * 2 + 1] = -radial
		var next: int = (i + 1) % GolfHole.SEGMENTS
		var bi: int = i * 2
		var bn: int = next * 2
		wall_indices[i * 6 + 0] = bi
		wall_indices[i * 6 + 1] = bn + 1
		wall_indices[i * 6 + 2] = bi + 1
		wall_indices[i * 6 + 3] = bi
		wall_indices[i * 6 + 4] = bn
		wall_indices[i * 6 + 5] = bn + 1

	var cap_verts: PackedVector3Array = PackedVector3Array()
	var cap_normals: PackedVector3Array = PackedVector3Array()
	var cap_indices: PackedInt32Array = PackedInt32Array()
	cap_verts.resize(GolfHole.SEGMENTS + 1)
	cap_normals.resize(GolfHole.SEGMENTS + 1)
	cap_indices.resize(GolfHole.SEGMENTS * 3)
	cap_verts[0] = floor_center
	cap_normals[0] = up
	for i: int in range(GolfHole.SEGMENTS):
		var a: float = float(i) / float(GolfHole.SEGMENTS) * TAU
		cap_verts[i + 1] = floor_center + (right * cos(a) + fwd * sin(a)) * GolfHole.HOLE_RADIUS
		cap_normals[i + 1] = up
		var next: int = (i + 1) % GolfHole.SEGMENTS
		cap_indices[i * 3 + 0] = 0
		cap_indices[i * 3 + 1] = next + 1
		cap_indices[i * 3 + 2] = i + 1

	var wall_surface: Array = []
	wall_surface.resize(Mesh.ARRAY_MAX)
	wall_surface[Mesh.ARRAY_VERTEX] = wall_verts
	wall_surface[Mesh.ARRAY_NORMAL] = wall_normals
	wall_surface[Mesh.ARRAY_INDEX] = wall_indices

	var cap_surface: Array = []
	cap_surface.resize(Mesh.ARRAY_MAX)
	cap_surface[Mesh.ARRAY_VERTEX] = cap_verts
	cap_surface[Mesh.ARRAY_NORMAL] = cap_normals
	cap_surface[Mesh.ARRAY_INDEX] = cap_indices

	var cup_mesh: ArrayMesh = ArrayMesh.new()
	cup_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wall_surface)
	cup_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cap_surface)
	var cup_mat: StandardMaterial3D = StandardMaterial3D.new()
	cup_mat.albedo_color = Color.WHITE
	cup_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cup_mesh.surface_set_material(0, cup_mat)
	cup_mesh.surface_set_material(1, cup_mat)
	var cup_inst: MeshInstance3D = MeshInstance3D.new()
	cup_inst.mesh = cup_mesh
	add_child(cup_inst)

	var wall_col_faces: PackedVector3Array = PackedVector3Array()
	for i: int in range(0, wall_indices.size(), 3):
		wall_col_faces.append(wall_verts[wall_indices[i]])
		wall_col_faces.append(wall_verts[wall_indices[i + 1]])
		wall_col_faces.append(wall_verts[wall_indices[i + 2]])
	var wall_shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	wall_shape.set_faces(wall_col_faces)
	var wall_col: CollisionShape3D = CollisionShape3D.new()
	wall_col.shape = wall_shape
	var wall_body: StaticBody3D = StaticBody3D.new()
	wall_body.add_child(wall_col)
	add_child(wall_body)

	# BoxShape3D is more reliable than ConcavePolygonShape3D for repeated fast contacts
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(GolfHole.HOLE_RADIUS * 2.2, 0.05, GolfHole.HOLE_RADIUS * 2.2)
	var floor_col: CollisionShape3D = CollisionShape3D.new()
	floor_col.shape = floor_box
	floor_col.transform = Transform3D(Basis(right, up, fwd), floor_center - up * 0.025)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.add_child(floor_col)
	add_child(floor_body)

	if Engine.is_editor_hint():
		var scene_root_cup: Node = EditorInterface.get_edited_scene_root()
		cup_inst.owner = scene_root_cup
		wall_body.owner = scene_root_cup
		wall_col.owner = scene_root_cup
		floor_body.owner = scene_root_cup
		floor_col.owner = scene_root_cup


# Returns the squared distance from point p to the nearest point on triangle (a,b,c).
# Used to test whether a hole circle overlaps a triangle regardless of triangle size.
static func _closest_dist_sq(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = p - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return p.distance_squared_to(a)
	var bp: Vector3 = p - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return p.distance_squared_to(b)
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return p.distance_squared_to(a + (d1 / (d1 - d3)) * ab)
	var cp: Vector3 = p - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return p.distance_squared_to(c)
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return p.distance_squared_to(a + (d2 / (d2 - d6)) * ac)
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return p.distance_squared_to(b + ((d4 - d3) / ((d4 - d3) + (d5 - d6))) * (c - b))
	var denom: float = 1.0 / (va + vb + vc)
	return p.distance_squared_to(a + (vb * denom) * ab + (vc * denom) * ac)
