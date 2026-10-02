extends Camera2D
class_name GameCamera

# 注意：不要把 position_smoothing_enabled 打开。中键拖动属于"直接操作"，
# 位置平滑会让它变成拖一块有弹性的布；平滑适合留给"跳到目标点"的场合。

@export var min_zoom := 0.5
@export var max_zoom := 5.0
@export var move_speed := 400.0
@export var zoom_step := 1.1

var _panning := false      # 中键拖动是否进行中(供 board 的鼠标跟随让路)
var _bounds := Rect2()     # 相机中心允许活动的世界矩形(棋盘面板)，由 main 同步
var _input_enabled := true # 用户输入是否生效(设置面板打开时由 main 关掉)

func _process(delta: float) -> void:
	# 平移：ui_* 内置 action(拖动期间不叠加键盘平移，免得两个来源抢方向)。
	# 语义：按哪个方向的键，**相机就往那个方向走**(视野朝该方向推进)。
	# 注意这与"按住中键拖动"的手感不同 —— 那里是抓住内容拖，相机要反向移动；
	# 键盘平移属于"移动镜头"，同向才符合直觉。
	if _input_enabled and not _panning:
		position += Input.get_vector("ui_left","ui_right","ui_up","ui_down") * move_speed * delta

	# 缩放：自定义 action，滚轮每滚一格是"刚按下"，用 is_action_just_pressed
	if _input_enabled:
		if Input.is_action_just_pressed("zoom_in"):
			_zoom_at_mouse(zoom_step)
		if Input.is_action_just_pressed("zoom_out"):
			_zoom_at_mouse(1.0 / zoom_step)

	_clamp_to_bounds()

func _unhandled_input(event: InputEvent) -> void:
	# 门控只挡"用户操作"，不挡 main 的 set_world_bounds()/zoom_by() 这类程序调用
	if not _input_enabled:
		return

	# 按住中键拖动平移：press/release 各锁存一次状态，不每帧轮询按键
	# (轮询在"松开时窗口失焦"的情况下会把状态粘住)
	if event.is_action_pressed("pan_drag"):
		_panning = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released("pan_drag"):
		_panning = false
		get_viewport().set_input_as_handled()
	elif _panning and event is InputEventMouseMotion:
		# relative 是视口逻辑坐标下的位移，除以 zoom 才是世界位移；
		# 不做这一步的话，放大后同样的手部位移会把画面拖得更快
		position -= event.relative / zoom
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	# 松开鼠标时窗口失焦 → release 事件收不到，会"粘"在拖动状态
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_panning = false

func is_panning() -> bool:
	return _panning

# 用户输入总开关：设置面板打开时 main 关掉它，菜单期间滚轮缩放与摇杆平移都不生效。
# 用"传值"而不是"通知"，是为了和 board.set_process_unhandled_input() 同一套意图：
# main 是唯一知道菜单开没开的地方，相机自己不持有那个布尔
func set_input_enabled(active: bool) -> void:
	_input_enabled = active
	if not active:
		# 正在中键拖动时被关掉(面板被手柄/空格唤出)，得顺手松开，
		# 否则摇杆平移虽被挡住，_panning 会一直粘着到下一次拖动
		_panning = false

# 设定相机中心允许活动的范围(棋盘面板的世界矩形)，main 在每次重排时同步
func set_world_bounds(r: Rect2) -> void:
	_bounds = r
	_clamp_to_bounds()

# 相机中心始终留在内容矩形内。取代原来的 _clamp_to_canvas()：
#  - 原版条件 `canvas.size >= half * 2` 只在 zoom >= 1 成立，且 zoom == 1 时
#    会把相机钉死在视口中心(任何拖动都被下一帧抹掉)；
#  - 现在任意缩放下都能拖动，同时棋盘中心一定还在屏幕内，丢不了。
func _clamp_to_bounds() -> void:
	if _bounds.size == Vector2.ZERO:
		return
	position = position.clamp(_bounds.position, _bounds.end)

# 以光标为锚点缩放(比以画面中心缩放更符合直觉)
# 只给桌面滚轮用：滚轮位置就是系统鼠标位置。触摸设备上"鼠标位置"没有意义
# (合成事件不会更新它)，捏合必须走 zoom_by() 显式传捏合中心。
func _zoom_at_mouse(f: float) -> void:
	zoom_by(f, get_viewport().get_mouse_position())

# 按比例缩放，以 window_anchor(**窗口坐标**) 为锚点。
#
# **锚点必须是窗口坐标**：内部走 get_canvas_transform()，那个变换吃的是窗口坐标
# (滚轮那条用 get_mouse_position()，正是同一空间)。
# 触摸侧拿到的是视口逻辑坐标，喂进来之前要先换算(TouchBindings.to_window())，
# 否则缩放中心会偏一个拉伸比，表现为"缩放时画面整体位移、指针与内容错位"。
func zoom_by(factor: float, window_anchor: Vector2) -> void:
	var before := _world_at(window_anchor)
	zoom = (zoom * factor).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	position += before - _world_at(window_anchor)
	_clamp_to_bounds()

# 窗口坐标 → 世界坐标(与 Node2D.get_global_mouse_position() 同一套算法)
func _world_at(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos
