@tool
class_name HoleData
extends Resource

@export var surface_direction: Vector3 = Vector3.UP:
	set(val):
		surface_direction = val.normalized() if val.length() > 0.001 else Vector3.UP
		emit_changed()

@export var radius: float = 0.25:
	set(val):
		radius = val
		emit_changed()

@export var depth: float = 0.5:
	set(val):
		depth = val
		emit_changed()

@export var segments: int = 32:
	set(val):
		segments = val
		emit_changed()
