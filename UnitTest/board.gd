extends Node2D
class_name Board

@onready var mines: Mines = $Mines

func _ready() -> void:
	mines.start_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cell := mines.local_to_map(mines.get_local_mouse_position())
		if not mines.in_bounds(cell): return
		match event.button_index:
			MOUSE_BUTTON_LEFT:  mines.reveal(cell)
			MOUSE_BUTTON_RIGHT: mines.toggle_flag(cell)
