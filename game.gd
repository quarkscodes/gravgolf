extends Node3D

var _hole_label: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_hole_complete_ui()
	GameState.hole_completed.connect(_on_hole_completed)


func _build_hole_complete_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	_hole_label = Label.new()
	_hole_label.text = "HOLE COMPLETE!"
	_hole_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hole_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hole_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hole_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hole_label.visible = false
	var label_settings: LabelSettings = LabelSettings.new()
	label_settings.font_size = 72
	label_settings.font_color = Color.WHITE
	_hole_label.label_settings = label_settings
	canvas.add_child(_hole_label)


func _on_hole_completed() -> void:
	_hole_label.visible = true
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		_hole_label.visible = false
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused != true:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
