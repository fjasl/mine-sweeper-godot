extends Node2D
class_name Board

signal started
signal flags_changed(remaining: int)
signal won
signal lost

@onready var mines: Mines = $Mines
@onready var cursor: Cursor = $Mines/CursorOverlay

var cursor_cell := Vector2i.ZERO

func _ready() -> void:
	mines.start_game()
	cursor.setup(mines)
	cursor.set_cell(cursor_cell)
	# 把 mines 的信号转发成 Board 的信号
	mines.started.connect(func(): started.emit())
	mines.flags_changed.connect(func(r): flags_changed.emit(r))
	mines.won.connect(func(): won.emit())
	mines.lost.connect(func(): lost.emit())

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
	cursor_cell = target
	clamp_cursor()

# 光标颜色(纯表现)：main 从这里改，不直接钻 board.cursor
func set_cursor_color(c: Color) -> void:
	cursor.color = c
	cursor.queue_redraw()

# ---- 尺寸相关：Board 是棋盘对外的唯一门面 ----

# 当前规格，供 UI 回显 / 判断是否真的变化
func spec() -> Vector3i:
	return Vector3i(mines.cols, mines.rows, mines.mine_count)

# 剩余雷数：规则层的数据，由 Board 代传。
# 有了它，main 就不必再直接钻 board.mines —— Board 的对外接口只留一条路
func remaining_mines() -> int:
	return mines.remaining_mines()

# 改规格：只负责数据，不开局。返回是否真的变了
func apply_spec(c: int, r: int, m: int) -> bool:
	var s := Mines.clamp_spec(c, r, m)
	if s == spec():
		return false
	mines.cols = s.x
	mines.rows = s.y
	mines.mine_count = s.z
	return true

# 开新局：重铺棋盘 + 光标归位。光标是 Board 的状态，所以由 Board 收尾
func new_game() -> void:
	mines.start_game()
	clamp_cursor()

# 把光标夹回当前边界内(尺寸变化后必须调用，否则会残留界外坐标)
func clamp_cursor() -> void:
	cursor_cell = cursor_cell.clamp(Vector2i.ZERO, Vector2i(mines.cols - 1, mines.rows - 1))
	cursor.set_cell(cursor_cell)
