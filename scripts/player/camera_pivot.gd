extends Node3D

@export var input_response: float = 0.6
@export var interpolation_weight: float = 3.0
@export var target: Node3D


func _process(delta: float) -> void:
	if target == null:
		return
	var camera_angular_velocity: float = (
			Input.get_axis("camera_pitch_up", "camera_pitch_down") * input_response
	)
	position = position.lerp(target.global_position, interpolation_weight * delta)
	basis = basis.rotated(basis.x, -camera_angular_velocity * PI * delta)
	basis = basis.orthonormalized()
