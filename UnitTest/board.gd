extends Node2D
@onready var mines: Mines = $Mines
@onready var cursor: Cursor = $CursorOverlay

var cursor_cell := Vector2i.ZERO

func _ready():
	mines.start_game()
	cursor.setup(mines)
	cursor.set_cell(cursor_cell)          # 初始在 (0,0)

func _process(_dt):
	var dir := Vector2i.ZERO
	if Input.is_action_just_pressed("move_left"):  dir.x -= 1
	if Input.is_action_just_pressed("move_right"): dir.x += 1
	if Input.is_action_just_pressed("move_up"):    dir.y -= 1
	if Input.is_action_just_pressed("move_down"):  dir.y += 1
	if dir != Vector2i.ZERO:
		cursor_cell = (cursor_cell + dir).clamp(Vector2i.ZERO, Vector2i(mines.cols - 1, mines.rows - 1))
		cursor.set_cell(cursor_cell)
	if Input.is_action_just_pressed("action_a"): mines.reveal(cursor_cell)
	if Input.is_action_just_pressed("action_b"): mines.toggle_flag(cursor_cell)
