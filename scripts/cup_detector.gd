class_name CupDetector
extends Area3D

var _timer: Timer
var _completed: bool = false


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if _completed or not body is Ball:
		return
	_timer.start()


func _on_body_exited(body: Node3D) -> void:
	if _completed or not body is Ball:
		return
	_timer.stop()


func _on_timer_timeout() -> void:
	_completed = true
	GameState.hole_completed.emit()
