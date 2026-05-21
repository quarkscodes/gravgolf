extends Node

enum Focus { SHIP, BALL }

var focus: Focus = Focus.SHIP


func toggle_focus() -> void:
	focus = Focus.BALL if focus == Focus.SHIP else Focus.SHIP
