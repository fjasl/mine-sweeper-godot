extends Node2D
class_name StateFace

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
# **只处理鼠标/触摸点击**：手柄 A 属于棋盘(翻开格子)，不在这里处理。
# 本节点在 Main.tscn 里排在 Board 之后，而 _unhandled_input 按场景树反序传播，
# 所以这里会**先于棋盘**拿到事件 —— 因此凡是本函数消费掉的事件，棋盘就再也收不到。
# 这也是为什么必须严格限制命中条件：一旦条件恒成立，棋盘的 action_a 会被永久吞掉。
func _unhandled_input(event: InputEvent) -> void:
	# 只认**指针事件**。
	# 绝不能用"手柄 A 键"来点笑脸：joypad 事件没有坐标，把它当成"点在笑脸自身"
	# 会让命中测试恒成立；而本节点在场景树里排在 Board 之后，_unhandled_input
	# 反序传播 → 笑脸会抢先把棋盘的 action_a 吃掉，表现为"手柄 A 一直重开、翻不开格子"。
	# 手柄 A 的归属是棋盘(翻开)，不是笑脸。
	if not (event is InputEventMouseButton):
		return
	if not (event as InputEventMouseButton).is_action_pressed("action_a"):
		return
	# 点击点的屏幕坐标。position 只在 InputEventMouse* 子类上是确定的 Vector2，
	# 所以上面先收窄类型，否则 := 推断不出类型。
	var screen_pos: Vector2 = (event as InputEventMouseButton).position
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
