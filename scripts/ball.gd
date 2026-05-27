class_name Ball
extends RigidBody3D

@export var max_impulse: float = 5.0
@export var bar_speed: float = 1.0  # full oscillation cycles per second

enum State { IDLE, SWINGING }

var _state: State = State.IDLE
var _bar_value: float = 0.0
var _bar_dir: float = 1.0
var _swing_ui: Control
var _progress_bar: ProgressBar


func _ready() -> void:
	_build_swing_ui()


func _build_swing_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)

	_swing_ui = Control.new()
	_swing_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swing_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swing_ui.visible = false
	canvas.add_child(_swing_ui)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.anchor_left = 0.25
	_progress_bar.anchor_right = 0.75
	_progress_bar.anchor_top = 1.0
	_progress_bar.anchor_bottom = 1.0
	_progress_bar.offset_top = -120
	_progress_bar.offset_bottom = -80
	_progress_bar.show_percentage = false
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swing_ui.add_child(_progress_bar)


func _process(delta: float) -> void:
	if _state != State.SWINGING:
		return
	_bar_value += _bar_dir * bar_speed * delta
	if _bar_value >= 1.0:
		_bar_value = 1.0
		_bar_dir = -1.0
	elif _bar_value <= 0.0:
		_bar_value = 0.0
		_bar_dir = 1.0
	_progress_bar.value = _bar_value


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("swing"):
		return
	if GameState.focus != GameState.Focus.BALL:
		return
	match _state:
		State.IDLE:
			_begin_swing()
		State.SWINGING:
			_commit_swing()


func _begin_swing() -> void:
	_state = State.SWINGING
	_bar_value = 0.0
	_bar_dir = 1.0
	_swing_ui.visible = true
	GameState.swinging = true


func _commit_swing() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var shot_dir: Vector3 = -camera.global_transform.basis.z
		apply_central_impulse(shot_dir * _bar_value * max_impulse)
	_state = State.IDLE
	_swing_ui.visible = false
	GameState.swinging = false
