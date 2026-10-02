extends Node2D
class_name CursorOverlay

@export var color := Color(1, 0.9, 0.3)
@export var line_width := 2.0

var mines: TileMapLayer
var cell_size := Vector2(16, 16)

func setup(m: TileMapLayer) -> void:
	mines = m
	cell_size = Vector2(m.tile_set.tile_size)   # 取瓦片尺寸

func set_cell(c: Vector2i) -> void:
	if mines:
		position = mines.map_to_local(c)     # map_to_local 返回格子中心
		queue_redraw()

func _draw() -> void:
	var s := cell_size
	draw_rect(Rect2(-s / 2, s), color, false, line_width)   # 描边，不填充
