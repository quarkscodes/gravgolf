extends Node3D

@export var input_response: float = 0.6
@export var interpolation_weight: float = 3.0
@export var ship_target: Node3D
@export var ball_target: Node3D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("focus_toggle"):
		GameState.toggle_focus()


func _process(delta: float) -> void:
	var camera_pitch: float = (
			Input.get_axis("camera_pitch_up", "camera_pitch_down") * input_response
	)
	match GameState.focus:
		GameState.Focus.SHIP:
			_follow_ship(delta, camera_pitch)
		GameState.Focus.BALL:
			_orbit_ball(delta, camera_pitch)


func _follow_ship(delta: float, camera_pitch: float) -> void:
	if ship_target == null:
		return
	basis = basis.slerp(ship_target.global_transform.basis, interpolation_weight * delta)
	basis = basis.rotated(basis.x, -camera_pitch * PI * delta)
	basis = basis.orthonormalized()
	position = position.lerp(ship_target.global_position, interpolation_weight * delta)


func _orbit_ball(delta: float, camera_pitch: float) -> void:
	if ball_target == null:
		return
	var yaw: float = Input.get_axis("yaw_left", "yaw_right") * input_response
	basis = basis.rotated(basis.y, -yaw * PI * delta)
	basis = basis.rotated(basis.x, -camera_pitch * PI * delta)
	basis = basis.orthonormalized()
	position = position.lerp(ball_target.global_position, interpolation_weight * delta)
