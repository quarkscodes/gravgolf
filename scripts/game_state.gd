extends Node

signal hole_completed

enum Focus { SHIP, BALL }

var focus: Focus = Focus.SHIP
var swinging: bool = false


func toggle_focus() -> void:
	if swinging:
		return
	focus = Focus.BALL if focus == Focus.SHIP else Focus.SHIP
