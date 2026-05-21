@tool
class_name PlanetBiome
extends Resource

@export var gradient: GradientTexture1D:
	set(val):
		gradient = val
		emit_changed()
@export var start_height: float:
	set(val):
		start_height = val
		emit_changed()
