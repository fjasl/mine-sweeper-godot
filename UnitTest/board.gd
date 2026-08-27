extends Node2D
class_name Board

@onready var mines: Mines = $Mines
@onready var cursor: Cursor = $CursorOverlay

var cursor_cell := Vector2i.ZERO

func _ready() -> void:
	mines.start_game()
	cursor.setup(mines)
	cursor.set_cell(cursor_cell)

func _unhandled_input(event: InputEvent) -> void:
	# 移动光标：方向键 / 手柄 dpad
	if event.is_action_pressed("move_left"):
		_move(cursor_cell + Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		_move(cursor_cell + Vector2i(1, 0))
	elif event.is_action_pressed("move_up"):
		_move(cursor_cell + Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):
		_move(cursor_cell + Vector2i(0, 1))

	# 鼠标移动跟随
	elif event is InputEventMouseMotion:
		var mc := mines.local_to_map(mines.get_local_mouse_position())
		if mines.in_bounds(mc):
			cursor_cell = mc
			cursor.set_cell(mc)

	# 翻开 / 插旗（鼠标左/右键 和 手柄 A/B 都绑到了 action_a / action_b）
	elif event.is_action_pressed("action_a"):
		mines.reveal(cursor_cell)
	elif event.is_action_pressed("action_b"):
		mines.toggle_flag(cursor_cell)

func _move(target: Vector2i) -> void:
	cursor_cell = target.clamp(Vector2i.ZERO, Vector2i(mines.cols - 1, mines.rows - 1))
	cursor.set_cell(cursor_cell)
