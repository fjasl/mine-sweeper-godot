extends Node2D
class_name MineCounter

@export var tile_w := 13.0
@export var tile_h := 23.0
@export var gap_px := 0.0

const LED := {
	"0": Vector2i(0, 11), "1": Vector2i(0, 10), "2": Vector2i(0, 9),
	"3": Vector2i(0, 8), "4": Vector2i(0, 7), "5": Vector2i(0, 6),
	"6": Vector2i(0, 5), "7": Vector2i(0, 4), "8": Vector2i(0, 3),
	"9": Vector2i(0, 2), "blank": Vector2i(0, 1), "negative": Vector2i(0, 0),
}

@onready var d: Array = [$D0, $D1, $D2]

func _ready() -> void:
	for i in 3:
		d[i].centered = false                     # 以左上角为锚点
		d[i].position = Vector2(i * (tile_w + gap_px), 0)
	set_number(0)

# n 可为负：剩余雷数 = 总雷数 - 已插旗数
func set_number(n: int) -> void:
	var neg := n < 0
	n = absi(n)
	n = mini(n, 999)
	@warning_ignore("integer_division")
	var h := n / 100
	@warning_ignore("integer_division")
	var t := (n / 10) % 10
	var o := n % 10
	d[0].region_rect = _rect(LED["negative"] if neg else LED[str(h)])   # 负数时最高位显示负号
	d[1].region_rect = _rect(LED[str(t)])
	d[2].region_rect = _rect(LED[str(o)])

func _rect(atlas: Vector2i) -> Rect2:
	return Rect2(atlas.x * tile_w, atlas.y * tile_h, tile_w, tile_h)

func display_size() -> Vector2:
	return Vector2(2 * (tile_w + gap_px) + tile_w, tile_h)
