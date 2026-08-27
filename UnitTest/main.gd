extends Node2D


@onready var cam: Camera2D = $Camera2D
@onready var board: Node2D = $Background

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#移动相机到正确视野
	cam.position = board.position + board.board_size() / 2.0
	#相机缩放
	cam.zoom = Vector2(1,1)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
