@tool
class_name PlanetNoise
extends Resource

@export var amplitude: float = 1.0:
	set(val):
		amplitude = val
		emit_changed()
@export var min_height: float = 0.0:
	set(val):
		min_height = val
		emit_changed()
@export var noise_map: FastNoiseLite:
	set(val):
		noise_map = val
		emit_changed()
		if noise_map != null and not noise_map.changed.is_connected(emit_changed):
			noise_map.changed.connect(emit_changed)
@export var noise_scale: float = 100.0:
	set(val):
		noise_scale = val
		emit_changed()
@export var use_first_layer_as_mask: bool = false:
	set(val):
		use_first_layer_as_mask = val
		emit_changed()
