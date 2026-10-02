extends Node2D
class_name Board

signal started
signal flags_changed(remaining: int)
signal won
signal lost

@onready var mines: Mines = $Mines
@onready var cursor: Cursor = $Mines/CursorOverlay

## 触控板指针的唯一真值所在。桌面端它是"未接管"状态，
## 此时回退到引擎的真鼠标位置，两种平台走同一条分支。
@onready var touch: TouchBindings = get_node_or_null("/root/Main/TouchBindings")

var cursor_cell := Vector2i.ZERO

## 本帧指针是否落在棋盘内。为 false 时点击无效(顺带堵掉"指针在棋盘外，
## 点到的却是上一次残留的那一格"这个坑)
var _pointer_on_board := true

func _ready() -> void:
	mines.start_game()
	cursor.setup(mines)
	cursor.set_cell(cursor_cell)
	# 把 mines 的信号转发成 Board 的信号
	mines.started.connect(func(): started.emit())
	mines.flags_changed.connect(func(r): flags_changed.emit(r))
	mines.won.connect(func(): won.emit())
	mines.lost.connect(func(): lost.emit())

# 黄框跟随指针。
#
# 刻意放在 _process 而不是鼠标事件里，有两个原因：
#  1) 相机平移/缩放根本不会产生鼠标事件。若只靠 InputEventMouseMotion 更新，
#     一旦拖了相机，指针与黄框的对应关系就再也对不上(表现为"格子选中不再动")。
#  2) 移动端合成事件不改变引擎记录的鼠标位置，读 get_global_mouse_position()
#     是错的，所以位置统一从 TouchBindings 取。
func _process(_delta: float) -> void:
	_update_cursor_from_pointer()

## 屏幕(视口)坐标 → 本节点局部坐标。
## 用**显式两段变换**，不用 make_input_local()：后者的语义是把"已进入视口的
## 事件"搬进节点空间，对真实鼠标事件成立，但对 Input.parse_input_event() 注入的
## 合成事件(以及每帧主动换算)并不等价，相机一动结果就偏。
func _screen_to_local(screen_pos: Vector2) -> Vector2:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	return to_local(world)

## 取本帧指针的屏幕坐标：触控板接管时用它，否则用真鼠标
func _pointer_screen_pos() -> Vector2:
	if touch != null and touch.is_tracking_pointer():
		return touch.pointer_screen_pos()
	return get_viewport().get_mouse_position()

func _update_cursor_from_pointer() -> void:
	var mc := mines.local_to_map(_screen_to_local(_pointer_screen_pos()))
	_pointer_on_board = mines.in_bounds(mc)
	# 指针在棋盘外(或相机把棋盘移出屏幕)时**什么都不做**：
	# 保留上一次的合法选中，不夹取、不隐藏 —— 界外移动不该改变内部选中。
	if _pointer_on_board:
		set_cursor_cell(mc)

## 移动黄框(方向键 / 手柄 dpad 与每帧指针跟随共用这一个入口)
func set_cursor_cell(c: Vector2i) -> void:
	if cursor_cell == c:
		return          # 每帧都会调用，格子没变就别重画
	cursor_cell = c
	cursor.set_cell(c)

func _unhandled_input(event: InputEvent) -> void:
	# 移动光标：方向键 / 手柄 dpad。
	# 走 nudge_pointer() 而不是直接改 cursor_cell —— 黄框每帧由指针位置算出来，
	# 直接改 cursor_cell 会在下一帧被 _process 抹掉。推动指针则一切自洽。
	# (桌面端 TouchBindings 未接管指针时，dpad 不生效；桌面用鼠标/相机即可)
	if event.is_action_pressed("move_left"):
		_nudge(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		_nudge(Vector2i(1, 0))
	elif event.is_action_pressed("move_up"):
		_nudge(Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):
		_nudge(Vector2i(0, 1))

	# 翻开 / 插旗（鼠标左/右键 和 手柄 A/B 都绑到了 action_a / action_b）
	# 注意这里不看事件坐标：黄框已经由 _process 跟到指针所在格，
	# 点击直接作用于黄框那一格，"点哪开哪"自然成立
	elif event.is_action_pressed("action_a"):
		if _pointer_on_board:
			mines.reveal(cursor_cell)
	elif event.is_action_pressed("action_b"):
		if _pointer_on_board:
			mines.toggle_flag(cursor_cell)

# 按"一格"推动虚拟指针(屏幕像素)。
# 格子尺寸是世界的像素(如 16×16)，而指针位置是屏幕像素，中间差一个 zoom；
# 直接用 canvas transform 量一格在屏幕上的长度，这样和上面 _screen_to_local()
# 用的是同一个变换，不会出现"两套坐标各说各话"。
func _nudge(dir: Vector2i) -> void:
	if touch == null or not touch.is_tracking_pointer():
		return
	var xform: Transform2D = get_viewport().get_canvas_transform()
	var cell := Vector2(mines.tile_set.tile_size)
	var screen_per_cell := (xform * cell - xform * Vector2.ZERO).abs()
	touch.nudge_pointer(Vector2(dir) * screen_per_cell)

# 光标颜色(纯表现)：main 从这里改，不直接钻 board.cursor
func set_cursor_color(c: Color) -> void:
	cursor.color = c
	cursor.queue_redraw()

# ---- 尺寸相关：Board 是棋盘对外的唯一门面 ----

# 当前规格，供 UI 回显 / 判断是否真的变化。
# 返回的是新建的值对象：真相始终在 mines 的那三个字段上，别把它存起来当状态
func spec() -> BoardSpec:
	return BoardSpec.make(mines.cols, mines.rows, mines.mine_count)

# 剩余雷数：规则层的数据，由 Board 代传。
# 有了它，main 就不必再直接钻 board.mines —— Board 的对外接口只留一条路
func remaining_mines() -> int:
	return mines.remaining_mines()

# 改规格：只负责数据，不开局。返回是否真的变了
# (形参叫 wanted 而不是 spec，免得和上面的 spec() 方法重名)
func apply_spec(wanted: BoardSpec) -> bool:
	var c := wanted.clamped()                    # 校验与夹取(规格约束的唯一出处)
	if c.equals(spec()):
		return false
	mines.cols = c.cols
	mines.rows = c.rows
	mines.mine_count = c.mine_count
	return true

# 开新局：重铺棋盘 + 光标归位。光标是 Board 的状态，所以由 Board 收尾
func new_game() -> void:
	mines.start_game()
	clamp_cursor()

# 把光标夹回当前边界内(尺寸变化后必须调用，否则会残留界外坐标)
func clamp_cursor() -> void:
	set_cursor_cell(cursor_cell.clamp(Vector2i.ZERO, Vector2i(mines.cols - 1, mines.rows - 1)))
