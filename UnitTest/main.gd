extends Node2D


@onready var cam: Camera2D = $Camera2D
@onready var background: Node2D = $Background
@onready var board: Node2D = $Background/Board   # 你已在 Background 下手动实例化的棋盘

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	background.setup_board(board)                             # 只负责对齐
	#移动相机到正确视野
	cam.position = background.position + background.board_size() / 2.0
	#相机缩放
	cam.zoom = Vector2(1,1)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
