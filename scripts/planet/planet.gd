@tool
class_name Planet
extends StaticBody3D

@export var planet_data: PlanetData:
	set(val):
		planet_data = val
		on_data_changed()
		if planet_data != null and not planet_data.is_connected("changed", on_data_changed):
			planet_data.connect("changed", on_data_changed)

@export var bake_output_path: String = "res://assets/baked_planets/"
@export_tool_button("Bake Planet") var _bake_btn: Callable = bake_planet
@export_tool_button("Add Golf Hole") var _add_hole_btn: Callable = add_golf_hole


func _ready() -> void:
	on_data_changed()


func on_data_changed() -> void:
	if planet_data == null:
		return
	planet_data.min_height = 99999.0
	planet_data.max_height = 0.0
	planet_data.regenerate_plateaus()

	for child: Node in get_children():
		if child.get_meta("plateau_gravity", false):
			child.queue_free()

	var planet_gravity: float = 9.8
	for child: Node in get_children():
		if child is Area3D and not child.get_meta("plateau_gravity", false):
			planet_gravity = child.gravity
			break

	for plateau: PlanetPlateau in planet_data.plateaus:
		var plateau_surface_height: float = planet_data.radius * (plateau.flat_elevation + 1.0)
		var dome_r: float = planet_data.plateau_radius + planet_data.plateau_dome_height * 0.5
		var dome_center: Vector3 = plateau.direction * plateau_surface_height
		var area: Area3D = Area3D.new()
		area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		area.priority = 1
		area.gravity_point = false
		area.gravity_direction = -plateau.direction
		area.gravity = planet_gravity
		area.set_meta("plateau_gravity", true)
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = dome_r
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = shape
		col.position = dome_center
		area.add_child(col)
		add_child(area)

	var biome_texture: ImageTexture = planet_data.update_biome_texture()
	var hole_pos: Vector3 = Vector3.ZERO
	var hole_normal: Vector3 = Vector3.ZERO
	var hole_radius: float = 0.0
	for child: Node3D in get_children():
		if child is GolfHole:
			hole_pos = planet_data.point_on_planet(child.surface_direction)
			hole_normal = planet_data.plateau_normal_at(child.surface_direction)
			hole_radius = GolfHole.HOLE_RADIUS
			break
	for child: Node3D in get_children():
		if child is PlanetMeshFace:
			child.regenerate_mesh(planet_data, biome_texture, hole_pos, hole_normal, hole_radius)
		elif child is GolfHole:
			child._rebuild()


func add_golf_hole() -> void:
	if not Engine.is_editor_hint():
		return
	var hole: GolfHole = GolfHole.new()
	hole.name = "GolfHole"
	add_child(hole)
	hole.owner = EditorInterface.get_edited_scene_root()


func bake_planet() -> void:
	if not Engine.is_editor_hint():
		return

	var baked: Node = duplicate(15)
	_strip_generation_scripts(baked)

	var scene: PackedScene = PackedScene.new()
	scene.pack(baked)
	baked.queue_free()

	DirAccess.make_dir_recursive_absolute(bake_output_path)
	var save_path: String = bake_output_path + name + "_baked.scn"
	var err: int = ResourceSaver.save(scene, save_path)
	if err == OK:
		print("Planet baked to: ", save_path)
		EditorInterface.get_resource_filesystem().scan()
	else:
		push_error("Failed to bake planet (error %d)" % err)


func _strip_generation_scripts(node: Node) -> void:
	if node.get_script() == get_script() or node is PlanetMeshFace or node is GolfHole:
		node.set_script(null)
	for child: Node in node.get_children():
		_strip_generation_scripts(child)
