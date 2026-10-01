extends Camera2D

# 注意：不要把 position_smoothing_enabled 打开。中键拖动属于"直接操作"，
# 位置平滑会让它变成拖一块有弹性的布；平滑适合留给"跳到目标点"的场合。

@export var min_zoom := 0.5
@export var max_zoom := 5.0
@export var move_speed := 400.0
@export var zoom_step := 1.1

var _panning := false      # 中键拖动是否进行中(供 board 的鼠标跟随让路)
var _bounds := Rect2()     # 相机中心允许活动的世界矩形(棋盘面板)，由 main 同步

func _process(delta: float) -> void:
	# 平移：ui_* 内置 action(拖动期间不叠加键盘平移，免得两个来源抢方向)
	# 语义与中键拖动一致：按哪个方向，画面内容就往哪个方向走
	if not _panning:
		position -= Input.get_vector("ui_left","ui_right","ui_up","ui_down") * move_speed * delta

	# 缩放：自定义 action，滚轮每滚一格是"刚按下"，用 is_action_just_pressed
	if Input.is_action_just_pressed("zoom_in"):
		_zoom_at_mouse(zoom_step)
	if Input.is_action_just_pressed("zoom_out"):
		_zoom_at_mouse(1.0 / zoom_step)

	_clamp_to_bounds()

func _unhandled_input(event: InputEvent) -> void:
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
func _zoom_at_mouse(f: float) -> void:
	var before := get_global_mouse_position()
	zoom = (zoom * f).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	position += before - get_global_mouse_position()
