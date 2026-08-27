extends Node2D
class_name Smiley

signal restart_requested

# button.bmp 单个脸的实际像素(改成你的)
@export var frame_w := 24.0
@export var frame_h := 24.0

const STATE := {
	"normal_press": Vector2i(0, 0),
	"win":          Vector2i(0, 1),
	"lose":         Vector2i(0, 2),
	"press":        Vector2i(0, 3),   # 放弃了,不用
	"normal":       Vector2i(0, 4),
}

# 一个 Sprite2D 子节点: texture = button.bmp, region_enabled = true
@onready var face: Sprite2D = $Face
var _state := "normal"

func _ready() -> void:
	if face:
		face.region_enabled = true
		face.centered = false          # ← 关键:以左上角为锚点(默认是中心)
	set_state("normal")

# 名字对应 STATE 的键: "normal" / "win" / "lose"
func set_state(name: String) -> void:
	_state = name
	var atlas: Vector2i = STATE[name]
	face.region_rect = Rect2(atlas.x * frame_w, atlas.y * frame_h, frame_w, frame_h)

func display_size() -> Vector2:
	return Vector2(frame_w, frame_h)
