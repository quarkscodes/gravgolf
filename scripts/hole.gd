@tool
class_name GolfHole
extends Node3D

const HOLE_RADIUS: float = 0.25
const HOLE_DEPTH: float = 0.5
const SEGMENTS: int = 32

@export var surface_direction: Vector3 = Vector3.UP:
	set(v):
		surface_direction = v.normalized() if v.length() > 0.001 else Vector3.UP
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var planet: Planet = get_parent() as Planet
	if planet == null or planet.planet_data == null:
		return
	var surface_pos: Vector3 = planet.planet_data.point_on_planet(surface_direction)
	var up: Vector3 = planet.planet_data.plateau_normal_at(surface_direction)
	var perp: Vector3 = up.cross(Vector3.FORWARD)
	if perp.length() < 0.001:
		perp = up.cross(Vector3.RIGHT)
	var local_x: Vector3 = perp.normalized()
	var local_z: Vector3 = up.cross(local_x).normalized()
	transform = Transform3D(Basis(local_x, up, local_z), surface_pos)
