@tool
extends StaticBody3D

@export var planet_data: PlanetData:
	set(val):
		planet_data = val
		on_data_changed()
		if planet_data != null and not planet_data.is_connected("changed", on_data_changed):
			planet_data.connect("changed", on_data_changed)

@export var bake_output_path: String = "res://assets/baked_planets/"
@export_tool_button("Bake Planet") var _bake_btn: Callable = bake_planet


func _ready() -> void:
	on_data_changed()


func on_data_changed() -> void:
	if planet_data == null:
		return
	planet_data.min_height = 99999.0
	planet_data.max_height = 0.0
	var biome_texture: ImageTexture = planet_data.update_biome_texture()
	for child: Node3D in get_children():
		if child is PlanetMeshFace:
			var face: PlanetMeshFace = child
			face.regenerate_mesh(planet_data, biome_texture)


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
	if node.get_script() == get_script() or node is PlanetMeshFace:
		node.set_script(null)
	for child: Node in node.get_children():
		_strip_generation_scripts(child)
