@tool
class_name GolfHole
extends Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var planet: Planet = get_parent() as Planet
	if planet == null or planet.planet_data == null or planet.planet_data.hole == null:
		return
	var hole_data: HoleData = planet.planet_data.hole
	var surface_pos: Vector3 = planet.planet_data.point_on_planet(hole_data.surface_direction)
	var up: Vector3 = planet.planet_data.plateau_normal_at(hole_data.surface_direction)
	var perp: Vector3 = up.cross(Vector3.FORWARD)
	if perp.length() < 0.001:
		perp = up.cross(Vector3.RIGHT)
	var local_x: Vector3 = perp.normalized()
	var local_z: Vector3 = up.cross(local_x).normalized()
	transform = Transform3D(Basis(local_x, up, local_z), surface_pos)
