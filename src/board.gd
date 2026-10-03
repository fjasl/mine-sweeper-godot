extends Node2D
class_name Board

signal started
signal flags_changed(remaining: int)
signal won
signal lost
signal progress_changed(ratio: float)   # 翻开进度(0..1)：给背景用，main 转给 backdrop

@onready var mines: MineField = $MineField
@onready var cursor: CursorOverlay = $MineField/CursorOverlay

## 触控板指针的唯一真值所在。桌面端它是"未接管"状态，
## 此时回退到引擎的真鼠标位置，两种平台走同一条分支。
@onready var touch: TouchBindings = get_node_or_null("/root/Main/TouchBindings")
## 相机。缩放锚点每帧由这里同步进去(滚轮缩放要锚在虚拟光标上)。
@onready var cam: GameCamera = get_node_or_null("/root/Main/Camera2D")

var cursor_cell := Vector2i.ZERO

## 本帧指针是否落在棋盘内。为 false 时点击无效(顺带堵掉"指针在棋盘外，
## 点到的却是上一次残留的那一格"这个坑)
## **只对指针点击生效**：手柄 A/B 与 InputEventAction(移动端双指插旗)没有坐标，
## 由 _may_act_on_cursor 直接放行，不受这个标志约束。
var _pointer_on_board := true

## 黄框这一路的"是否该由指针接管"的判据：记住上一帧指针的**位置**与它算出的**格子**。
##   - 位置变了(鼠标/手指/虚拟指针动了，哪怕只在同一格内挪) → 指针接管
##   - 格子变了(相机平移/缩放让世界在指针底下滑动)          → 指针接管
## 两者都没变，就说明"指针和世界都静止"，此时保留十字键直接挪到的格子，
## 不然每帧重算会把十字键挪的格子抹回去(桌面端十字键挪不动黄框就是这么来的)。
var _pointer_pos := Vector2.ZERO
var _pointer_cell := Vector2i.ZERO
var _pointer_seen := false

func _ready() -> void:
	mines.start_game()
	cursor.setup(mines)
	cursor.set_cell(cursor_cell)
	# 把 mines 的信号转发成 Board 的信号
	mines.started.connect(func(): started.emit())
	mines.flags_changed.connect(func(r): flags_changed.emit(r))
	mines.won.connect(func(): won.emit())
	mines.lost.connect(func(): lost.emit())
	# 进度同样只转发"比例"，不让 main 去钻 board.mines 算
	mines.revealed_changed.connect(func(_n: int): progress_changed.emit(revealed_progress()))

# 黄框跟随指针。
#
# 刻意放在 _process 而不是鼠标事件里，有两个原因：
#  1) 相机平移/缩放根本不会产生鼠标事件。若只靠 InputEventMouseMotion 更新，
#     一旦拖了相机，指针与黄框的对应关系就再也对不上(表现为"格子选中不再动")。
#  2) 移动端合成事件不改变引擎记录的鼠标位置，读 get_global_mouse_position()
#     是错的，所以位置统一从 TouchBindings 取。
#
# 但**不是无条件覆盖**：十字键直接挪过的格子必须留得住，所以只在"指针或世界动过"
# 时才接管 —— 判据与理由见 _update_cursor_from_pointer() 与 _pointer_pos 的声明。
func _process(_delta: float) -> void:
	_update_cursor_from_pointer()
	# 缩放锚点跟着指针走(相机在缩放时保持这个点不动)。
	# 用**指针**而不是黄框所在格的中心：指针是连续量，缩放时画面不会一格一格地跳，
	# 而黄框本来就是这个指针所在的那一格。
	# 桌面端 _pointer_viewport_pos() 回退到系统鼠标位置，行为与以前一致；
	# 移动端它才是真正的虚拟光标(TouchBindings 持有)。
	if cam != null:
		cam.set_zoom_anchor(_pointer_viewport_pos())

## 指针的**视口坐标** —— 画布(棋盘/世界)这一侧要的是这个空间。
## GUI 命中测试要的是窗口坐标(见 pointer_window_pos)，两者差一个拉伸比，
## 所以必须分开取，不能混用：混用的后果是"控件点得准、棋盘就偏"，或反过来。
func _pointer_viewport_pos() -> Vector2:
	if touch != null and touch.is_tracking_pointer():
		return touch.pointer_viewport_pos()
	return get_viewport().get_mouse_position()

## 视口坐标 → 本节点局部坐标。
## 直接由**相机状态**推导世界坐标：world = 相机屏幕中心 + (视口点 - 视口中心) / zoom。
## 刻意不依赖 get_global_mouse_position() 或 get_canvas_transform()：
## 那两个都要先确定"喂进去的是窗口还是视口坐标"，一旦喂错就整体缩放走样，
## 而合成事件又确实会改变引擎内部记录的鼠标位置 —— 变量太多。
## 这里只用三个确定量：相机屏幕中心、zoom、视口矩形。
func _screen_to_local(viewport_pos: Vector2) -> Vector2:
	if cam == null:
		return to_local(viewport_pos)
	var vis := get_viewport().get_visible_rect()
	var world := cam.get_screen_center_position() + (viewport_pos - vis.position - vis.size * 0.5) / cam.zoom
	return to_local(world)

## 暂停/恢复"黄框跟随指针"。
##
## 有新局之外的 UI 覆盖时(设置抽屉、结算弹窗)应当暂停：
## 黄框是"下一击会作用在哪"的指示器，被面板挡着还在背后乱跑只会让人误判。
## 暂停时用 set_process(false)，所以是真的停下，不是每帧空转。
##
## 刻意不把"何时暂停"写死在 Board 里：调用方是 main(菜单开关)与
## GameStateMachine(对局阶段)，它们才是"当前有没有 UI 覆盖"的知情者。
func pause_tracking(paused: bool) -> void:
	set_process(not paused)
	if not paused:
		# 立即对齐一次，免得恢复后要等下一帧才追上指针
		# (顺带重算 _pointer_on_board，所以冻结期间不需要专门去清它)
		_update_cursor_from_pointer()

func _update_cursor_from_pointer() -> void:
	var p := _pointer_viewport_pos()
	var mc := mines.local_to_map(_screen_to_local(p))
	# 指针和世界都没动过 → 这一帧别碰黄框，把十字键挪到的格子留住。
	# 判据见 _pointer_pos / _pointer_cell 的声明处。
	if _pointer_seen and p == _pointer_pos and mc == _pointer_cell:
		return
	_pointer_seen = true
	_pointer_pos = p
	_pointer_cell = mc
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
	# 翻开 / 插旗。
	# 放在方向键判断**之前**：两者可能同时命中同一个手柄按键，
	# 而"动作"比"移动光标"更该生效(否则一次按下只挪格子、不翻开，看起来就像失效)。
	# 这里**按事件类型分流**：带坐标的(鼠标点击 / 移动端合成的点击)必须在棋盘内，
	# 不带坐标的(手柄 A/B、InputEventAction)一律放行 —— 见 _may_act_on_cursor。
	# 一刀切地看 _pointer_on_board 会让手柄按 A 直接失效。
	if event.is_action_pressed("action_a"):
		if _may_act_on_cursor(event):
			mines.reveal(cursor_cell)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action_b"):
		if _may_act_on_cursor(event):
			mines.toggle_flag(cursor_cell)
			get_viewport().set_input_as_handled()
	# 被 _may_act_on_cursor 挡掉时**刻意不** set_input_as_handled()：
	# 那一次什么都没做，没有理由把它从事件管线里吞掉。

	# 移动光标：方向键 / 手柄 dpad。归属随平台走，见 _nudge
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventKey:
		var d := Vector2i.ZERO
		if event.is_action_pressed("move_left"):    d = Vector2i(-1, 0)
		elif event.is_action_pressed("move_right"): d = Vector2i(1, 0)
		elif event.is_action_pressed("move_up"):    d = Vector2i(0, -1)
		elif event.is_action_pressed("move_down"):  d = Vector2i(0, 1)
		if d != Vector2i.ZERO:
			_nudge(d, true)

# 这一次"动作"是否允许作用在当前选中格上。
#
# 分流依据是**事件带不带坐标**，而不是一刀切地看 _pointer_on_board：
#  - 鼠标事件(桌面左键 / 移动端 TouchBindings 合成的点击)带坐标 → 要求指针
#    此刻在棋盘内。否则指针移到棋盘外再点，翻开的会是上一次残留的那一格。
#  - 手柄 A/B 与 InputEventAction(移动端双指轻点插旗)没有坐标，与指针无关 → 放行。
#
# 这里读**上一帧**的 _pointer_on_board，而不是拿事件坐标现算一格出来：
# cursor_cell 也是由同一条 _process 路径推出来的，两者同源同延迟，于是
# "允许作用"与"作用在哪一格"必然一致；现算反而会引入第二套"屏幕点 → 世界点"
# 的推导(项目里已经有这个隐患了，不再添一处)。
func _may_act_on_cursor(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _pointer_on_board
	return true

# 按"一格"移动选中(方向键 / 手柄 dpad)。
#
# **归属随平台走**，两边不能同时做，否则一次按下会挪两格或落点不一致：
#  - 移动端：推虚拟指针。轻点是"点在指针处"，只挪黄框会让点击落在原来那格。
#    nudge_pointer() 收的是**视口逻辑坐标**(和 pointer_pos 同一空间)，所以这里量出
#    "一格在视口里有多长"：格子尺寸是世界像素(如 16×16)，乘 canvas transform 即得。
#  - 桌面端：没有虚拟指针可推(推了引擎也不认，指针仍是系统鼠标)，就直接挪黄框自己。
#    这样挪完不会被每帧重算抹掉 —— _update_cursor_from_pointer() 只在"指针或世界动过"
#    时才接管，鼠标一动手柄交还，两边都不打架。
func _nudge(dir: Vector2i, from_pad := false) -> void:
	if from_pad:
		# 手柄/键盘：直接挪黄框，不碰虚拟指针
		set_cursor_cell((cursor_cell + dir).clamp(Vector2i.ZERO, Vector2i(mines.cols - 1, mines.rows - 1)))
		return
	if touch != null and touch.is_tracking_pointer():
		var xform: Transform2D = get_viewport().get_canvas_transform()
		var cell := Vector2(mines.tile_set.tile_size)
		var viewport_per_cell := (xform * cell - xform * Vector2.ZERO).abs()
		touch.nudge_pointer(Vector2(dir) * viewport_per_cell)
		return
	set_cursor_cell((cursor_cell + dir).clamp(Vector2i.ZERO, Vector2i(mines.cols - 1, mines.rows - 1)))

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

# 翻开进度(0..1) = 已翻开数 / 通关所需数。和 remaining_mines() 一样"由 Board 代传"，
# 调用方(main → 背景)不必知道 mines 内部怎么算
func revealed_progress() -> float:
	var target: int = mines.reveal_target()
	if target <= 0:
		return 0.0
	return clampf(float(mines.revealed_count) / float(target), 0.0, 1.0)

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
