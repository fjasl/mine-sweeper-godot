extends Node2D


@onready var cam = $Camera2D
@onready var background = $Background
@onready var board = $Background/Board
@onready var timer = $Background/ScoreTimer
@onready var counter = $Background/MineCounter
@onready var face = $Background/StateFace

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 摆放：背景只提供几何(格子原点/计分板矩形)，具体位置由这里决定
	board.position  = background.board_grid_origin()
	timer.position  = _place_display(background, timer,   "right", 8)
	counter.position = _place_display(background, counter, "left", 8)
	face.position = _place_display(background, face, "center", 0)

	# 移动相机到正确视野
	cam.position = background.position + background.board_size() / 2.0
	cam.zoom = Vector2(1, 1)

	# board 的信号 → UI
	board.started.connect(func(): timer.start())
	board.flags_changed.connect(func(r): counter.set_number(r))
	board.won.connect(func():
		timer.stop()
		face.set_state("win")
	)
	board.lost.connect(func():
		timer.stop()
		face.set_state("lose")
	)

	# 开局显示剩余雷数
	counter.set_number(board.mines.remaining_mines())

	# 输掉后点表情 → 重开
	face.restart_requested.connect(_restart)


func _restart() -> void:
	board.mines.start_game()               # 重新布雷、填满
	timer.reset()                          # 计时器归零且不计时
	counter.set_number(board.mines.remaining_mines())
	face.set_state("normal")

# 一块计分显示：贴 left/right/居中、留 inset、垂直居中
func _place_display(bg, display, side: String, inset: float) -> Vector2:
	var rect = bg.scoreboard_rect()
	var tsize = display.display_size()
	var y = rect.position.y + (rect.size.y - tsize.y) / 2.0
	var x
	match side:
		"right":  x = rect.position.x + rect.size.x - inset - tsize.x
		"left":   x = rect.position.x + inset
		"center": x = rect.position.x + (rect.size.x - tsize.x) / 2.0
	return Vector2(x, y)
