@tool
class_name PlanetMeshFace
extends MeshInstance3D

@export var normal: Vector3


func regenerate_mesh(planet_data: PlanetData, biome_texture: ImageTexture) -> void:
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
	call_deferred("_update_mesh", arrays, planet_data, biome_texture)


func _update_mesh(arrays: Array, planet_data: PlanetData, biome_texture: ImageTexture) -> void:
	var _mesh: ArrayMesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = _mesh

	material_override.set_shader_parameter("min_height", planet_data.min_height)
	material_override.set_shader_parameter("max_height", planet_data.max_height)
	material_override.set_shader_parameter("height_color", biome_texture)
	
	# create_trimesh_collision() appends new children each call, so free the old ones first
	for child: StaticBody3D in get_children():
		child.free()
	
	self.create_trimesh_collision()
