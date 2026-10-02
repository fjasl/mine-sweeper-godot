extends Node2D
class_name Smiley

signal restart_requested

# button.bmp 单个脸的实际像素(改成你的)
@export var frame_w := 24.0
@export var frame_h := 24.0
## 点击热区的最小边长：触摸手指比鼠标粗，原版也是刻意做大的
@export var min_tap_size := 44.0

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
		# 脸的贴图尺寸没法从代码算(整张 button.bmp 是图集)，所以在运行期读场景里
		# 设好的 region_rect，热区才和实际画出来的脸一致
		frame_w = face.region_rect.size.x
		frame_h = face.region_rect.size.y
	set_state("normal")

# 点笑脸 → 重开(对应原版的"点脸重开")。
# 事件必须先到 GameObject 那侧：本节点在 Main.tscn 里排在 Board 之后，
# _unhandled_input 按场景树反序传播，所以这里先拿到；命中后 set_input_as_handled()
# 拦住事件，免得同一次点击又被棋盘当成"翻开格子"。
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("action_a"):
		return
	# 取"点击点"的屏幕坐标。
	# 必须显式收窄成鼠标事件：position 只在 InputEventMouse* 子类上是确定的 Vector2，
	# 直接对基类 InputEvent 取 .position 得到的是 Variant，:= 推断不出来。
	# 手柄 A 键(joypad)根本没有坐标 —— 那就把点击点算作笑脸自身所在位置。
	var screen_pos: Vector2
	if event is InputEventMouseButton:
		screen_pos = (event as InputEventMouseButton).position
	else:
		screen_pos = get_viewport().get_canvas_transform() * get_global_position()
	# 用显式两段变换，不用 make_input_local()：后者对
	# Input.parse_input_event() 注入的合成事件(移动端)并不等价，相机一动热区就偏
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var local_pos: Vector2 = to_local(world)
	var w := maxf(frame_w, min_tap_size)
	var h := maxf(frame_h, min_tap_size)
	if Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)).has_point(local_pos):
		get_viewport().set_input_as_handled()
		restart_requested.emit()

# 名字对应 STATE 的键: "normal" / "win" / "lose"
# (形参不叫 name：会遮蔽 Node.name)
func set_state(state_name: String) -> void:
	_state = state_name
	var atlas: Vector2i = STATE[state_name]
	face.region_rect = Rect2(atlas.x * frame_w, atlas.y * frame_h, frame_w, frame_h)

func display_size() -> Vector2:
	return Vector2(frame_w, frame_h)
