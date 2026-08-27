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

# 一块计分显示：贴 left/right、留 inset、垂直居中
func _place_display(bg, display, side: String, inset: float) -> Vector2:
	var rect = bg.scoreboard_rect()
	var tsize = display.display_size()
	var y = rect.position.y + (rect.size.y - tsize.y) / 2.0
	var x
	match side:
		"right":  x = rect.position.x + rect.size.x - inset - tsize.x
		"left":   x = rect.position.x + inset
		"center": x = rect.position.x + (rect.size.x - tsize.x) / 2.0   # 水平居中
	return Vector2(x, y)
