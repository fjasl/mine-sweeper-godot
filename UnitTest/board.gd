extends Node2D
class_name Board

@export var cols := 30
@export var rows := 16


const T_COVERED := Vector2i(0, 0)
@onready var mines_layer: TileMapLayer = $Mines

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for x in cols:
		for y in rows:
			mines_layer.set_cell(Vector2i(x, y), 0, T_COVERED)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
